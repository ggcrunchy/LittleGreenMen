--- A marching cubes walker using Morton indices to handle grid sparsity.

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
local data_structure_ops = require("data_structure_ops")
local mi_small = require("marching_cubes.morton_indexed_small")
local utils = require("utils")

-- Imports --
local band = bit.band
local bor = bit.bor
local cast = ffi.cast
local Lg_PowerOf2 = utils.Lg_PowerOf2
local lshift = bit.lshift
local max = math.max
local min = math.min
local MortonTriple = utils.MortonTriple
local Morton3 = utils.Morton3
local rshift = bit.rshift

-- --
local PackedUsage = ffi.typeof[[
	struct {
		int32_t base;
		int32_t in_use;
		int32_t used[32];
		void * next;
		double values[1024];
	}
]]

--[[ DESCRIPTOR
	struct {
		int32_t base;
		int32_t in_use;
		void * next;
		struct {
			int32_t data : 20;
			int32_t bin : 5;
		} info[32];
	}
]]

-- In tiny case, just do a search?

--[[ BLOCK
	struct {
		double values[1024]; // or however...
		int32_t usage[32];
	}
]]

--[[ CUR
	struct {
		int32_t base, offset, in_use, used;
		double * values;
	}
]]

--[[ PACKED
	struct {
		int32_t nx, ny, nz;
		int32_t id;
		int32 bin;
		double none;
		Cur cur;
	}
]]

-- Blocks[id] = { block1, block2, ..., blockn }
-- Descriptors[id] = { [base1] = desc1, [base2] = desc2, ..., [basen] = descn }

--[[
	> Now:

	1024-double chunks scattered, iterated search
	32 bits -> 32 flags

	> Better?:

	4K chunks (could even be sub-allocated on demand and strung together)

	Chunk:
	  - 4K (32 * 128) doubles
	  - 128 int32s as usage flags

	Morton3 can go from 0 - 1024^3 -> 30 bits
	4K = 2^12 -> 2^30 / 2^12 = 2^18 -> 18 bits

	For 128 flags, we need 7 bits to reference it
	Also, 5 bits to isolate the flag bit
	30 - (7 + 5) = 18 bits left, as needed, for chunk lookup

	Descriptors:

	Keep most recent offset / descriptor pair cached

	Lookup by hashing on `morton - morton % 4096`

	Argh:

	Those flag bits are pointless?

	> Another go:

	Skip lists
	Keep power-of-2 size list of descriptor skip lists, up to some maximum power
	Use that maximum power to bin to a list

	Exchange time for space
	Lookup descriptor in bin's skip list
	Wipe data slice to `none` on acquire

	Not sure about chunk size / descriptor bits

	32 descriptors allows for a uint32 of flags, then each skip list covers 25 bits, or 32M
]]

-- --
local PackedUsagePtr = ffi.typeof([[ $ *]], PackedUsage)

-- --
local Packed = ffi.typeof([[
	struct {
		int32_t nx, ny, nz;
		int32_t id;
		double none;
		struct {
			int32_t base, offset, in_use, used;
			$ data;
			$ next;
		} cur;
		$ head;
	}
]], PackedUsagePtr, PackedUsagePtr, PackedUsagePtr)

-- --
local MarchingCubes_MortonIndexed = {}

--- DOCME
function MarchingCubes_MortonIndexed:Begin ()
	self.cur.in_use = 0
	self.cur.used = 0
	self.cur.next = self.head
end

--- DOCME
function MarchingCubes_MortonIndexed:Next ()
	repeat
		-- Does the sub-block have elements?
		if self.cur.used ~= 0 then
			local flag = band(self.cur.used, -self.cur.used)

			self.cur.offset = self.cur.base + Lg_PowerOf2(flag)
			self.cur.used = self.cur.used - flag

			return true

		-- ...does the block?
		elseif self.cur.in_use ~= 0 then
			local flag = band(self.cur.in_use, -self.cur.in_use)
			local offset = Lg_PowerOf2(flag)

			self.cur.base = lshift(offset, 5)
			self.cur.in_use = self.cur.in_use - flag
			self.cur.used = self.cur.data.used[offset]

		-- ...the list?
		elseif self.cur.next ~= nil then
			self.cur.data = cast(PackedUsagePtr, self.cur.next)
			self.cur.next = self.cur.data.next
			self.cur.in_use = self.cur.data.in_use

		-- Iteration complete.
		else
			return false
		end
	until false
end

-- --
local Blocks = data_structure_ops.NewStoreGroup(10)

--- DOCME
function MarchingCubes_MortonIndexed:Reset ()
	Blocks.ClearStore(self.id)

	self.head = nil
end

--
local function BinOffset (n)
	return rshift(n, 5), band(n, 31)
end

--
local function FindBlock (mcp, base)
	local data, prev = mcp.head

	while data ~= nil and data.base ~= base do
		data, prev = cast(PackedUsagePtr, data.next), data
	end

	return data, prev
end

--- DOCME
function MarchingCubes_MortonIndexed:Set (x, y, z, value)
	if x >= 0 and x < self.nx and y >= 0 and y < self.ny and z >= 0 and z < self.nz then
		local morton = Morton3(x, y, z)
		local offset = band(morton, 1023)
		local base = morton - offset

		--
		local data, prev = FindBlock(self, base)

		if data == nil then
			data = Blocks.PopCache() or PackedUsage()

			data.base = base
			data.next = self.head
			data.in_use = 0

			Blocks.AddToStore(self.id, data)

		--
		elseif prev ~= nil then
			prev.next = data.next
			data.next = self.head
		end

		--
		self.head = data

		--
		local sbin, soffset = BinOffset(offset)
		local flag, used = lshift(1, sbin), 0

		if band(data.in_use, flag) ~= 0 then
			used = data.used[sbin]
		end

		data.in_use = bor(data.in_use, flag)
		data.used[sbin] = bor(used, lshift(1, soffset))

		--
		data.values[offset] = value
	end
end

--
local function SetCell (cell, ci, i, j, k, v)
	cell.p[ci][0] = i
	cell.p[ci][1] = j
	cell.p[ci][2] = k
    cell.val[ci] = v
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
function MarchingCubes_MortonIndexed:SetCell (cell)
	local index = self.cur.data.base + self.cur.offset
	local i, j, k = MortonTriple(index)

	--
	SetCell(cell, 0, i, j, k, self.cur.data.values[self.cur.offset])

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
ffi.metatype(Packed, {
	-- --
	__new = function(ct, nx, ny, nz, none)
		if max(nx, ny, nz) <= 32 then
			return mi_small(nx, ny, nz, none)
		else
			-- TODO: Validate n*?

			local id = Blocks.NewStore()

			return ffi.new(ct, nx, ny, nz, id, none or 1)
		end
	end,

	-- --
	__gc = function(mcp)
		Blocks.RemoveStore(mcp.id)
	end,

	-- --
	__index = MarchingCubes_MortonIndexed
})

-- Export the class.
return Packed