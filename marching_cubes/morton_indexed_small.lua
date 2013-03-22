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
local Descriptor = ffi.typeof[[
	struct {
		int32_t in_use; // Which elements of info are valid?
		uint8_t info[8];//32]; // Where to look for each 128-element slice owned by this descriptor (block index = upper 4 bits, bin index = lower 4 bits)
	}
]]

-- --
local Block = ffi.typeof[[
	struct {
		double values[16][128];//2048]; // Raw values, divvied up in 16 128-element slices
		int32_t used[16][4]; // Which values are in valid? (4 int32's per slice)
	}
]]

-- --
local Cur = ffi.typeof([[
	struct {
		int32_t base, offset; // Base index of current slice (multiple of 128); offset into sub-slice (multiple of 32)
		int32_t in_use, used; // Next value of descriptor and slice usage flags
		int32_t desc_index; // Index of next descriptor to iterate, in [0, 8)
//		int32_t used_index; // Index of next element of used_arr to iterate, in [0, 4)
		$ * desc; // Currently iterated descriptor
		$ * bbb;
//		int32_t * used_arr; // Currently iterated "using which values in slice?" flags
		double * values; // Current slice values
		int32_t bin, iii;
	}
]], Descriptor, Block)

-- --
local State = ffi.typeof([[
	struct {
		int32_t ex, ey, ez; // Grid extents, i.e. maximum x, y, z (dimension - 1)
		int32_t id; // ID used to maintain GC resources
		int32_t cur_bin; // Current bin, which will be alloted from the newest block
		double none; // "Missing" value
		$ * descriptors[8]; // Descriptors for each 2K range of Morton numbers
	}
]], Descriptor)

-- Methods --
local MarchingCubes_MortonIndexedSmall = {}

--- Prepares the walker for iteration.
-- @treturn cur X
function MarchingCubes_MortonIndexedSmall:Begin ()
	local cur = Cur()

--	cur.used_index = 4

	return cur
end

-- --
local Blocks = data_structure_ops.NewStoreGroup(10)

--- Performs an iteration step.
-- @treturn boolean Is iteration done?
function MarchingCubes_MortonIndexedSmall:Next (cur)
	repeat
		-- Does the sub-slice have elements?
		if cur.used ~= 0 then
			local flag = band(cur.used, -cur.used)

			cur.offset = Lg_PowerOf2(flag)
			cur.used = cur.used - flag

			return true

		-- ...does the rest of the slice?
--[[		elseif cur.used_index < 4 then
			repeat
				cur.used = cur.used_arr[cur.used_index]
				cur.used_index = cur.used_index + 1
			until cur.used ~= 0 or cur.used_index == 4
]]
		-- ...does the descriptor?
		elseif cur.in_use ~= 0 then
			local flag = band(cur.in_use, -cur.in_use)
			local offset = Lg_PowerOf2(flag)
			local info = cur.desc.info[rshift(offset, 2)]
			local block = Blocks.GetItem(self.id, rshift(info, 4))--info.block)
	--		local to_slice = lshift(band(info, 15)--[[info.bin]], 7)
local bin = band(info, 15)
			cur.base = lshift(cur.desc_index - 1, 12) + lshift(offset, 7)
			cur.in_use = cur.in_use - flag
--			cur.used_arr = block.used[band(info, 15)]--info.bin]
			cur.used = block.used[bin][band(offset, 3)]--cur.used_arr[0]
--			cur.used_index = 1
--			cur.values = block.values + bin--to_slice
			cur.bbb = block
			cur.iii = band(offset, 3)
			cur.bin = bin

		-- ...do the rest of the descriptors?
		else
			while cur.desc_index < 8 do
				cur.desc = self.descriptors[cur.desc_index]
				cur.desc_index = cur.desc_index + 1

				if cur.desc ~= nil then
					cur.in_use = cur.desc.in_use

					break
				end
			end

			-- Iteration complete.
			if not (cur.desc_index < 8) then
				return false
			end
		end
	until false
end

-- --
local Descriptors = data_structure_ops.NewStoreGroup(10)

--- DOCME
function MarchingCubes_MortonIndexedSmall:Reset ()
	self.cur_bin = 0

	for i = 0, 7 do
		self.descriptors[i] = nil
	end

	Blocks.ClearStore(self.id)
	Descriptors.ClearStore(self.id)
end

--- DOCME
function MarchingCubes_MortonIndexedSmall:Set (x, y, z, value)
	if common.WithinGrid(self, x, y, z) then
		local morton = Morton3(x, y, z) -- In [0, 2^15)
		local dslot = rshift(morton, 12) -- Bits 12-14: descriptor slot, in [0, 8)

		-- Get the descriptor (adding one, if necessary) for the 4K range in which the index resides.
		local desc = self.descriptors[dslot]

		if desc == nil then
			desc = Descriptors.PopCache() or Descriptor()

			self.descriptors[dslot], desc.in_use = desc, 0

			Descriptors.AddToStore(self.id, desc)
		end

		-- If necessary, allot the index's 128-element sub-range.
		local islot = band(rshift(morton, 7), 31) -- Bits 7-11: slot in info table, in [0, 31)

		if band(desc.in_use, lshift(15, band(islot, 28))) == 0 then--band(desc.in_use, lshift(1, islot)) == 0 then
--			local aa=band(desc.in_use, lshift(15, islot * 4))
--			desc.in_use = bor(desc.in_use, lshift(1, islot))

			-- On the first time, and after every 16th slice has been alloted, add a new
			-- block; otherwise, continue to use the newest block. In either case, get the
			-- sub-range corresponding to the current bin.
			self.cur_bin = band(self.cur_bin, 15)

			local block, index

			if self.cur_bin == 0 then
				block = Blocks.PopCache() or Block()
				index = Blocks.AddToStore(self.id, block)
			else
				block, index = Blocks.GetLastItem(self.id)
			end

			-- Prepare the slice for use.
			desc.info[rshift(islot, 2)] = lshift(index, 4) + self.cur_bin

			ffi.fill(block.used + self.cur_bin, 16)

			self.cur_bin = self.cur_bin + 1
--end
		end
desc.in_use = bor(desc.in_use, lshift(1, islot))
		-- Assign the value and flag it as used.
		local ioffset = band(morton, 127) -- Bits 0-6: offset in data bin, in [0, 128)
		local uslot = band(islot, 3)--rshift(ioffset, 5) -- Bits 5-6: Sub-offset in slice usage, in [0, 4)
		local block, bin = Blocks.GetItem(self.id, rshift(desc.info[rshift(islot, 2)], 4)), band(desc.info[rshift(islot, 2)], 15)

		block.used[bin][uslot] = bor(block.used[bin][uslot], lshift(1, band(morton, 31))) -- Bits 0-4: Offset into slice usage, in [0, 31)
		block.values[--[[lshift(bin, 7) + ]]bin][ioffset] = value -- bin * 128 + offset
	end
end

-- --
local DeferredCorners = ffi.typeof[[
	struct {
		struct {
			int32_t offset; // Offset in data bin, in [0, 128)
			int32_t ci; // Cell corner index, in [1, 8)
			uint32_t block; // Block index, q.v. Descriptor
			uint32_t bin; // Bin index, likewise
			uint32_t o;
		} corner[7];
		int32_t n; // Number of deferred corners
	}
]]

-- Assigns a corner value, if convenient, deferring it otherwise
local function TrySetCellCorner (mcp, cell, cur, dc, ci, i, j, k, index)
	local ioffset, value = band(index, 127)

	-- If the corner is already in the current data bin, grab its value directly.
	if rshift(index - cur.base, 7) == 0 then
		local uslot, uindex = band(ioffset, 3)--[[rshift(ioffset, 5)]], band(ioffset, 31)

		value = band(cur.bbb.used[cur.bin][uslot]--[[cur.used_arr[uslot]], lshift(1, uindex)) ~= 0 and cur.bbb.values[cur.bin][ioffset]

	-- Otherwise, if the bin even exists, defer the assignment.
	else
		local desc = mcp.descriptors[rshift(index, 12)]
		local islot = band(rshift(index, 7), 31)

		if desc ~= nil and band(desc.in_use, lshift(1, islot)) ~= 0 then
			dc.corner[dc.n].offset = ioffset
			dc.corner[dc.n].ci = ci
dc.corner[dc.n].o = band(islot, 3)
islot = rshift(islot, 2)
			dc.corner[dc.n].block = rshift(desc.info[islot], 4)
			dc.corner[dc.n].bin = band(desc.info[islot], 15)

			dc.n = dc.n + 1
		end
	end

	-- Assign the value (using "none", if it was missing) along with some extra state. Any
	-- deferred value is taken as missing; if this turns out to be a false assumption, only
	-- its value needs to be patched.
	SetCellCorner(cell, ci, i, j, k, value or mcp.none)
end

--- DOCME
function MarchingCubes_MortonIndexedSmall:SetCell (cell, cur)
	local offset = lshift(cur.iii--[[used_index - 1]], 5) + cur.offset
	local index = cur.base + offset
	local i, j, k = MortonTriple(index)

	-- Mark the lowest-indexed corner, which is assumed to exist.
	SetCellCorner(cell, 0, i, j, k, cur.bbb.values[cur.bin][offset])

	-- The other corners require some extra effort, since they cannot be assumed to exist,
	-- and even then, they may be in a non-local data bin.
	local i2, j2, k2 = min(i + 1, self.ex), min(j + 1, self.ey), min(k + 1, self.ez)
	local di = Morton3(i2, j, k) - index
	local dj = Morton3(i, j2, k) - index
	local dk = Morton3(i, j, k2) - index
	local dc = DeferredCorners()

	TrySetCellCorner(self, cell, cur, dc, 1, i2, j, k, index + di)
	TrySetCellCorner(self, cell, cur, dc, 2, i2, j, k2, (index + di) + dk)
	TrySetCellCorner(self, cell, cur, dc, 3, i, j, k2, index + dk)
	TrySetCellCorner(self, cell, cur, dc, 4, i, j2, k, index + dj)
	TrySetCellCorner(self, cell, cur, dc, 5, i2, j2, k, (index + di) + dj)
	TrySetCellCorner(self, cell, cur, dc, 6, i2, j2, k2, (index + di) + (dj + dk))
	TrySetCellCorner(self, cell, cur, dc, 7, i, j2, k2, index + (dj + dk))

	-- Do all (potentially) non-local corners.
	for i = 0, dc.n - 1 do
		local corner = dc.corner[i]
		local block = Blocks.GetItem(self.id, corner.block)
		local uslot, uindex = band(corner.offset, 3)--[[rshift(corner.offset, 5)]], band(corner.offset, 31)

		if band(block.used[corner.bin][--[[uslot]]corner.o], lshift(1, uindex)) ~= 0 then
			SetCellCornerValue(cell, corner.ci, block.values[--[[lshift(corner.bin, 7) + ]]corner.bin][corner.offset])
		end
	end
end

--
ffi.metatype(State, {
	-- --
	__new = function(ct, nx, ny, nz, none)
		-- TODO: Validate n*?

		local id = Blocks.NewStore()

		Descriptors.NewStore()

		return ffi.new(ct, nx - 1, ny - 1, nz - 1, id, none or 1)
	end,

	-- --
	__gc = function(mcp)
		Blocks.RemoveStore(mcp.id)
		Descriptors.RemoveStore(mcp.id)
	end,

	-- --
	__index = MarchingCubes_MortonIndexedSmall
})

-- Export the class.
return State