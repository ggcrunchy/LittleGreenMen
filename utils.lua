--- MIRMAL!

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

-- Standard library imports --
local min = math.min

-- Modules --
local bit = require("bit")
local ffi = require("ffi")

-- Imports --
local band = bit.band
local bor = bit.bor
local lshift = bit.lshift
local rshift = bit.rshift

-- Exports --
local M = {}

--- DOCME
function M.CLP2 (x)
	x = x - 1

	x = bor(x, rshift(x, 1))
	x = bor(x, rshift(x, 2))
	x = bor(x, rshift(x, 4))
	x = bor(x, rshift(x, 8))
	x = bor(x, rshift(x, 16))

	return x + 1
end

--- DOCME
function M.CubeCorners (x, y, z, ext)
	local xmin, ymin, zmin = x - ext, y - ext, z - ext
	local xmax, ymax, zmax = x + ext, y + ext, z + ext

	return xmin, ymin, zmin, xmax, ymax, zmax
end

do
	-- --
	local LgUnion = ffi.new[[
		union {
			int32_t i[2];
			double d;
		}
	]]

	-- --
	local LE = ffi.abi("le") and 1 or 0

	--- DOCME
	function M.Lg_PowerOf2 (n)
		LgUnion.i[LE] = 0x43300000
		LgUnion.i[1 - LE] = n

		LgUnion.d = LgUnion.d - 4503599627370496

		return rshift(LgUnion.i[LE], 20) - 0x3FF
	end
--[[
	Compare above to:
static const int MultiplyDeBruijnBitPosition2[32] = 
{
  0, 1, 28, 2, 29, 14, 24, 3, 30, 22, 20, 15, 25, 17, 4, 8, 
  31, 27, 13, 23, 21, 19, 16, 7, 26, 12, 18, 6, 11, 5, 10, 9
};
r = MultiplyDeBruijnBitPosition2[(uint32_t)(v * 0x077CB531U) >> 27];
]]

end

--[[
TODO: Put in ome unit testing area?

local function MortonNaive (x, y, z)
	local result = 0

	for i = 0, 9 do
		local mask = lshift(1, i)
		local xm = band(x, mask)
		local ym = band(y, mask)
		local zm = band(z, mask)

		-- i(x) = i * 3 + 0
		-- i(y) = i * 3 + 1
		-- i(z) = i * 3 + 2
		-- shift(flag) = i * 3 + K - i = i * (3 - 1) + K = i * 2 + K
		local i0 = i * 2

		result = bor(result, lshift(xm, i0), lshift(ym, i0 + 1), lshift(zm, i0 + 2))
	end

	return result
end
]]

--
local function AuxTriple (mnum)
	mnum = band(0x24924924, mnum)
	mnum = band(0x2190C321, bor(mnum, rshift(mnum, 2)))
	mnum = band(0x03818703, bor(mnum, rshift(mnum, 4)))
	mnum = band(0x000F801F, bor(mnum, rshift(mnum, 6)))
	mnum = band(0x000003FF, bor(mnum, rshift(mnum, 10)))

	return mnum
end

--- DOCME
function M.MortonTriple (mnum)
	return AuxTriple(lshift(mnum, 2)), AuxTriple(lshift(mnum, 1)), AuxTriple(mnum)
end

--
local function AuxMorton (x)
	x = band(0x000F801F, bor(x, lshift(x, 10))) -- 000 000 000 011 111 000 000 000 011 111
	x = band(0x03818703, bor(x, lshift(x, 6)))  -- 000 011 100 000 011 000 011 100 000 011
	x = band(0x2190C321, bor(x, lshift(x, 4)))  -- 100 001 100 100 001 100 001 100 100 001
	x = band(0x24924924, bor(x, lshift(x, 2)))  -- 100 100 100 100 100 100 100 100 100 100

	return x
end

--- DOCME
function M.Morton3 (x, y, z)
	return rshift(AuxMorton(x), 2) + rshift(AuxMorton(y), 1) + AuxMorton(z)
end

--- DOCME
function M.Sort2 (x, y)
	local min_xy = min(x, y)

	return min_xy, x + y - min_xy
end

-- Export the module.
return M