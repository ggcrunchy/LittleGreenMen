--- A version of the Morton-indexed walker tailored for "small" grids.
--
-- Design and motivation:
--
-- We are unlikely to use many elements, so if possible we want a sparse data structure. This
-- suggests a little bit of indirection.
--
-- At the same time, we want some coherence, that being part of the reason for using Morton
-- numbers in the first place. Some experimentation leads to the following.
--
-- By using 4 bits for each, we can address 16 blocks and 16 bins per block.
--
-- If a bin has 128 elements, we get 16 x 16 x 128 = 2^15 elements total.
--
-- Thus, we can safely interleave 3 integers in [0, 2^5), i.e. from 0 to 31.
--
-- In sum, each block has 16 x 128 (2K) elements, plus 16 x (128 / 32) = 64 int32 flags.
--
-- Given the above, we can assign a descriptor to each 4K swath of elements (2^15 elements
-- = 8 descriptors in all). This is further divvied up into 128-element chunks. Since there
-- are 4K / 128 = 32 of these, it is easy to flag which ones are in use. The elements are
-- stored in the blocks, of course; the descriptor just holds an 8-bit info packet for each
-- chunk, which tells us where (block and bin) to look.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Modules --
local ffi = require("ffi")
local common = require("marching_cubes.common")
local data_structure_ops = require("data_structure_ops")
local utils = require("utils")

-- Imports --
local band = bit.band
local bor = bit.bor
local Lg_PowerOf2 = utils.Lg_PowerOf2
local lshift = bit.lshift
local min = math.min
local MortonTriple = utils.MortonTriple
local Morton3 = utils.Morton3
local SetCellCorner = common.SetCellCorner
local SetCellCornerValue = common.SetCellCornerValue
local rshift = bit.rshift

-- --
local Block = ffi.typeof[[
	struct {
		double values[16][128]; // Raw values, divvied up into slices
		int32_t used[16][4]; // Which values are in valid?
	}
]]

-- --
local Cur = ffi.typeof([[
	struct {
		int32_t base, offset; // Base index of current slice (multiple of 128); offset into sub-slice (multiple of 32)
		int32_t descs, in_use, used; // Next value of descriptor, bin, and sub-slice usage flags
		int32_t desc_index; // Index of next descriptor to iterate, in [0, 8)
		$ * block; // Block containing current bin
		int32_t bin, uslot; // Current bin and sub-slice
	}
]], Block)

-- --
local State = ffi.typeof[[
	struct {
		int32_t ex, ey, ez; // Grid extents, i.e. maximum x, y, z (dimension - 1)
		int32_t id; // ID used to maintain GC resources
		int32_t cur_bin; // Current bin, which will be alloted from the newest block
		int32_t descs; // Which descriptors are in use?
		int32_t in_use[32]; // Which elements of info are valid? (for each 1K range of Morton numbers)
		uint8_t info[32][8]; // Where to look for each 128-element slice owned by this descriptor (block index = upper 4 bits, bin index = lower 4 bits)
		double none; // "Missing" value
	}
]]

-- Methods --
local MarchingCubes_MortonIndexedSmall = {}

--- Prepares the walker for iteration.
-- @treturn cur X
function MarchingCubes_MortonIndexedSmall:Begin ()
	local cur = Cur()

	cur.descs = self.descs

	return cur
end

-- --
local Blocks = data_structure_ops.NewStoreGroup(10)

--
local function BlockBin (id, info)
	return Blocks.GetItem(id, rshift(info, 4)), band(info, 0x0F)
end

--- Performs an iteration step.
-- @treturn boolean Is iteration done?
function MarchingCubes_MortonIndexedSmall:Next (cur)
	-- Jump to the best first step.
	if cur.used ~= 0 then
		goto used
	elseif cur.in_use ~= 0 then
		goto in_use
	elseif cur.descs == 0 then
		return false
	end

	-- Fetch the next descriptor state, then fall through.
	do
		local flag = band(cur.descs, -cur.descs)

		cur.descs = cur.descs - flag
		cur.desc_index = Lg_PowerOf2(flag)
		cur.in_use = self.in_use[cur.desc_index]
	end

::in_use::

	-- Fetch the next bin state, then fall through.
	do
		local flag = band(cur.in_use, -cur.in_use)
		local offset = Lg_PowerOf2(flag)
		local islot = rshift(offset, 2)

		cur.base = lshift(cur.desc_index, 10) + lshift(islot, 7)
		cur.block, cur.bin = BlockBin(self.id, self.info[cur.desc_index][islot])
		cur.in_use = cur.in_use - flag
		cur.uslot = band(offset, 0x3)
		cur.used = cur.block.used[cur.bin][cur.uslot]
	end

::used::

	-- Fetch the next sub-slice state, and report success.
	do
		local flag = band(cur.used, -cur.used)

		cur.offset = Lg_PowerOf2(flag)
		cur.used = cur.used - flag
	end

	return true
end

--- DOCME
function MarchingCubes_MortonIndexedSmall:Reset ()
	self.cur_bin = 0
	self.descs = 0

	ffi.fill(self.in_use, 128)

	Blocks.ClearStore(self.id)
end

--- DOCME
function MarchingCubes_MortonIndexedSmall:Set (x, y, z, value)
	if common.WithinGrid(self, x, y, z) then
		local morton = Morton3(x, y, z) -- In [0, 2^15)
		local dslot = rshift(morton, 10) -- Bits 10-14: descriptor slot, in [0, 32)

		-- If necessary, allot the index's 128-element slice.
		local lslot = band(rshift(morton, 5), 0x1F) -- Bits 5-9: slot in info table, in [0, 32)

		if band(self.in_use[dslot], lshift(0xF, band(lslot, 0x1C))) == 0 then -- Round lslot down to multiple of 4; use to shift 4-bit mask into plaace
			-- On the first time, and after every 16th slice has been alloted, add a new
			-- block; otherwise, continue to use the newest block. In either case, get the
			-- sub-range corresponding to the current bin.
			self.cur_bin = band(self.cur_bin, 0x0F)

			local block, index

			if self.cur_bin == 0 then
				block = Blocks.PopCache() or Block()
				index = Blocks.AddToStore(self.id, block)
			else
				block, index = Blocks.GetLastItem(self.id)
			end

			-- Prepare the slice for use.
			self.info[dslot][rshift(lslot, 2)] = lshift(index, 4) + self.cur_bin

		    ffi.fill(block.used[self.cur_bin], 16)

			self.cur_bin = self.cur_bin + 1
		end

		-- Mark the descriptor and the bin as in use. The former is a convenience for
		-- iteration, the latter necessary bookkeeping.
		self.descs = bor(self.descs, lshift(1, dslot))
		self.in_use[dslot] = bor(self.in_use[dslot], lshift(1, lslot))

		-- Assign the value and flag it as used.
		local ioffset = band(morton, 0x7F) -- Bits 0-6: offset into data bin, in [0, 128)
		local uslot = rshift(ioffset, 5) -- Bits 5-6: Sub-offset into slice usage, in [0, 4)
		local block, bin = BlockBin(self.id, self.info[dslot][rshift(lslot, 2)])

		block.used[bin][uslot] = bor(block.used[bin][uslot], lshift(1, band(morton, 0x1F))) -- Bits 0-4: Offset into slice usage, in [0, 32)
		block.values[bin][ioffset] = value -- bin * 128 + offset
	end
end

-- Assigns a corner value (according to whether it exists)
local function SetCorner (mcp, cell, ci, i, j, k, index)
	-- Put all the basics in the cell, including the "missing" value.
	SetCellCorner(cell, ci, i, j, k, mcp.none)

	-- Add a real value, if available.
	local dslot = rshift(index, 10)
	local lslot = band(rshift(index, 5), 0x1F)

	if band(mcp.in_use[dslot], lshift(1, lslot)) ~= 0 then
		local block, bin = BlockBin(mcp.id, mcp.info[dslot][rshift(lslot, 2)])

		if band(block.used[bin][band(lslot, 0x3)], lshift(1, band(index, 0x1F))) ~= 0 then
			SetCellCornerValue(cell, ci, block.values[bin][band(index, 0x7F)])
		end
	end
end

--- DOCME
function MarchingCubes_MortonIndexedSmall:SetCell (cell, cur)
	local offset = lshift(cur.uslot, 5) + cur.offset
	local index = cur.base + offset
	local i, j, k = MortonTriple(index)

	-- Mark the lowest-indexed corner, which is assumed to exist.
	SetCellCorner(cell, 0, i, j, k, cur.block.values[cur.bin][offset])

	-- Locate and add the other corner values, which may or may not exist.
	local i2, j2, k2 = min(i + 1, self.ex), min(j + 1, self.ey), min(k + 1, self.ez)
	local di = Morton3(i2, j, k) - index
	local dj = Morton3(i, j2, k) - index
	local dk = Morton3(i, j, k2) - index

	SetCorner(self, cell, 1, i2, j, k, index + di)
	SetCorner(self, cell, 2, i2, j, k2, (index + di) + dk)
	SetCorner(self, cell, 3, i, j, k2, index + dk)
	SetCorner(self, cell, 4, i, j2, k, index + dj)
	SetCorner(self, cell, 5, i2, j2, k, (index + di) + dj)
	SetCorner(self, cell, 6, i2, j2, k2, (index + di) + (dj + dk))
	SetCorner(self, cell, 7, i, j2, k2, index + (dj + dk))
end

--
ffi.metatype(State, {
	-- --
	__new = function(ct, nx, ny, nz, none)
		-- TODO: Validate n*?

		local id = Blocks.NewStore()

		return ffi.new(ct, nx - 1, ny - 1, nz - 1, id, none or 1)
	end,

	-- --
	__gc = function(mcp)
		Blocks.RemoveStore(mcp.id)
	end,

	-- --
	__index = MarchingCubes_MortonIndexedSmall
})

-- Export the class.
return State