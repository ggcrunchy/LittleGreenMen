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
-- Given the above, we can assign a descriptor to each 2K swath of elements (2^15 elements
-- = 8 descriptors in all). This is further divvied up into 128-element chunks. Since there
-- are 2K / 128 = 32 of these, it is easy to flag which ones are in use. The elements are
-- stored in the blocks, of course; the descriptor just holds an 8-bit info packet for each
-- chunk, which tells us where (block and bin) to look.

-- TODO: Implementation is somewhat more complex than necessary because of lack of 64-bit bit ops
-- Namely, the `int32_t used[16][4]` could become `int64_t used[16]` (extending `in_use` and `info`
-- to 64-bit/-element as well in the descriptor)... iteration would simplify likewise
-- These are supposed to be on the horizon for LuaJIT, so until then...

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
local cast = ffi.cast
local Lg_PowerOf2 = utils.Lg_PowerOf2
local lshift = bit.lshift
local min = math.min
local MortonTriple = utils.MortonTriple
local Morton3 = utils.Morton3
local SetCell = common.SetCell
local rshift = bit.rshift

-- --
local Descriptor = ffi.typeof[[
	struct {
		int32_t in_use; // Which elements of info are valid?
		struct {
			int8_t block : 4; // Block index, in [0, 15)
			int8_t bin : 4; // Bin index, in [0, 15)
		} info[32]; // Where to look for each 128-element slice owned by this descriptor
	}
]]

-- --
local Block = ffi.typeof[[
	struct {
		double values[2048]; // Raw values, divvied up in 16 128-element slices
		int32_t used[16][4]; // Which values are in valid? (4 int32's per slice)
	}
]]

-- --
local Cur = ffi.typeof([[
	struct {
		int32_t base, offset; // Base index (multiple of 2K) of current descriptor; sub-slice offset (multiple of 32) from base
		int32_t in_use, used; // Next value of descriptor and slice usage flags
		int32_t desc_index; // Index of next descriptor to iterate, in [0, 8)
		int32_t used_index; // Index of next element of used_arr to iterate, in [0, 4)
		$ * desc; // Currently iterated descriptor
		int32_t * used_arr; // Currently iterated "using which values in slice?" flags
		double * values; // Current values sub-slice
	}
]], Descriptor)

-- --
local State = ffi.typeof([[
	int32_t nx, ny, nz; // Dimensions of volume
	int32_t id; // ID used to maintain GC resources
	int32_t cur_bin; // Current bin, which will be alloted from the newest block
	double none; // "Missing" value
	$ cur; // Iteration state
	$ * descriptors[8]; // Descriptors for each 2K range of Morton numbers
]], Cur, Descriptor)

-- --
local MarchingCubes_MortonIndexedSmall = {}

--- DOCME
function MarchingCubes_MortonIndexedSmall:Begin ()
	self.cur.desc_index = 0
	self.cur.used_index = 4
	self.cur.in_use = 0
	self.cur.used = 0
end

-- --
local BlockStore = data_structure_ops.NewStoreGroup(10)

--- DOCME
function MarchingCubes_MortonIndexedSmall:Next ()
-- TODO: Need another offset? (one for descriptor, one for block?)
	repeat
		-- Does the sub-slice have elements?
		if self.cur.used ~= 0 then
			local flag = band(self.cur.used, -self.cur.used)

			self.cur.offset = Lg_PowerOf2(flag)
			self.cur.used = self.cur.used - flag

			return true

		-- ...does the rest of the slice?
		elseif self.cur.used_index < 4 then
			repeat
				self.cur.used = self.cur.used_arr[self.cur.used_index]
				self.cur.used_index = self.cur.used_index + 1
				self.cur.base = self.cur.base + 32
				self.cur.values = self.cur.values + 32
			until self.cur.used ~= 0 or self.cur.used_index == 4

		-- ...does the descriptor?
		elseif self.cur.in_use ~= 0 then
			local flag = band(self.cur.in_use, -self.cur.in_use)
			local offset = Lg_PowerOf2(flag)
			local info = self.cur.desc.info[offset]
			local block = BlockStore.GetItem(self.id, info.block)
			local to_slice = lshift(info.bin, 7)

			self.cur.base = lshift(self.cur.desc_index - 1, 12) + lshift(offset, 7)
			self.cur.in_use = self.cur.in_use - flag
			self.cur.used_arr = block.used[info.bin]
			self.cur.used = self.cur.used_arr[0]
			self.cur.used_index = 1
			self.cur.values = block.values + to_slice

		-- ...do the rest of the descriptors?
		elseif self.cur.desc_index < 8 then
			repeat
				self.cur.desc = self.descriptors[self.cur.desc_index]
				self.cur.desc_index = self.cur.desc_index + 1
			until (self.cur.desc ~= nil) or self.cur.desc_index == 8

			if self.cur.desc ~= nil then
				self.cur.in_use = self.cur.desc.in_use
			end

		-- Iteration complete.
		else
			return false
		end
	until false
end

-- --
local DescriptorStore = data_structure_ops.NewStoreGroup(10)

--- DOCME
function MarchingCubes_MortonIndexedSmall:Reset ()
	self.cur_bin = 0

	for i = 0, 7 do
		self.descriptors[i] = nil
	end

	BlockStore.ClearStore(self.id)
	DescriptorStore.ClearStore(self.id)
end

--- DOCME
function MarchingCubes_MortonIndexedSmall:Set (x, y, z, value)
	if x >= 0 and x < self.nx and y >= 0 and y < self.ny and z >= 0 and z < self.nz then
		local morton = Morton3(x, y, z) -- In [0, 2^15)
		local dslot = rshift(morton, 12) -- Bits 12-14: descriptor slot, in [0, 8)

		-- Get the descriptor (adding one, if necessary) for the 2K range in which the index resides.
		local desc = self.descriptors[dslot]

		if desc == nil then
			desc = DescriptorStore.PopCache() or Descriptor()

			self.descriptors[dslot], desc.in_use = desc, 0

			DescriptorStore.AddToStore(self.id, desc)
		end

		-- The index's 192-element sub-range may already have been alloted. In this case,
		-- refer directly to the block and slice usage flags.
		local islot, ioffset = band(rshift(morton, 7), 31), band(morton, 127) -- Bits 7-11: slot in info table, in [0, 31); bits 0-6: offset in data bin, in [0, 128)
		local iflag, info, block, used = lshift(1, islot), desc.info[islot]

		if band(desc.in_use, iflag) ~= 0 then
			block = BlockStore.GetItem(self.id, info.block)
			used = block.used[info.bin]

		-- Otherwise, allot a new sub-range.
		else
			desc.in_use = bor(desc.in_use, iflag)

			-- On the first time, and after every 16th slice has been alloted, add a new
			-- block; otherwise, continue to use the newest block. In either case, get the
			-- sub-range corresponding to the current bin.
			self.cur_bin = band(self.cur_bin, 15)

			if self.cur_bin == 0 then
				block = BlockStore.PopCache() or Block()
				info.block = BlockStore.AddToStore(self.id, block)
			else
				block, info.block = BlockStore.GetItem(self.id, true)
			end

			info.bin = self.cur_bin

			self.cur_bin = self.cur_bin + 1

			-- Prepare the slice for use.
			used = block.used[info.bin]

			used[0], used[1], used[2], used[3] = 0, 0, 0, 0
		end

		-- Assign the value and flag it as used.
		local uslot = rshift(ioffset, 5) -- Bits 5-6: Sub-offset in slice usage, in [0, 4)

		used[uslot] = bor(used[uslot], lshift(1, band(ioffset, 31))) -- Bits 0-4: Offset into slice usage, in [0, 31)
		block.values[lshift(info.bin, 7) + ioffset] = value -- bin * 128 + offset
	end
end

--
local function AssignValue (mcp, cell, ci, i, j, k, data, offset)
	local hindex, lindex = BinOffset(offset)
	local value = mcp.none

	if band(data.in_use, lshift(1, hindex)) ~= 0 and band(data.used[hindex], lshift(1, lindex)) ~= 0 then
		value = data.values[offset]
	end

	SetCell(cell, ci, i, j, k, value)
end

-- --
local DeferredCorners = ffi.new[[
	struct {
		struct {
			int32_t base, index;
			int16_t ci, i, j, k;
		} corner[7];
		int32_t n;
	}
]]

--
local function TrySetCell (mcp, cell, ci, i, j, k, index)
	local offset = band(index, 1023)

	--
	if index - offset == mcp.cur.data.base then
		AssignValue(mcp, cell, ci, i, j, k, mcp.cur.data, offset)

	--
	else
		local corner = DeferredCorners.corner[DeferredCorners.n]

		corner.base = index - offset
		corner.index, corner.ci = index, ci
		corner.i, corner.j, corner.k = i, j, k

		DeferredCorners.n = DeferredCorners.n + 1
	end
end

--- DOCME
function MarchingCubes_MortonIndexedSmall:SetCell (cell)
-- TODO!
	local index = self.cur.base + self.cur.offset
	local i, j, k = MortonTriple(index)

	--
	SetCell(cell, 0, i, j, k, self.cur.values[self.cur.offset])

	--
	DeferredCorners.n = 0

	local i2, j2, k2 = min(i + 1, self.nx - 1), min(j + 1, self.ny - 1), min(k + 1, self.nz - 1)
	local di = Morton3(i2, j, k) - index
	local dj = Morton3(i, j2, k) - index
	local dk = Morton3(i, j, k2) - index

	TrySetCell(self, cell, 1, i2, j, k, index + di)
	TrySetCell(self, cell, 2, i2, j, k2, (index + di) + dk)
	TrySetCell(self, cell, 3, i, j, k2, index + dk)
	TrySetCell(self, cell, 4, i, j2, k, index + dj)
	TrySetCell(self, cell, 5, i2, j2, k, (index + di) + dj)
	TrySetCell(self, cell, 6, i2, j2, k2, (index + di) + (dj + dk))
	TrySetCell(self, cell, 7, i, j2, k2, index + (dj + dk))

	--
	for i = 0, DeferredCorners.n - 1 do
		local corner = DeferredCorners.corner[i]
		local data = FindBlock(self, corner.base)

		if data ~= nil then
			AssignValue(self, cell, corner.ci, corner.i, corner.j, corner.k, data, corner.index - corner.base)
		else
			SetCell(cell, corner.ci, corner.i, corner.j, corner.k, self.none)
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

		return ffi.new(ct, nx, ny, nz, id, none or 1)
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