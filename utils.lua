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

-- Imports --
local bor = bit.bor
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

--- DOCME
function M.Sort2 (x, y)
	local min_xy = min(x, y)

	return min_xy, x + y - min_xy
end

-- Export the module.
return M