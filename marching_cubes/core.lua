--- This module implements the marching cubes algorithm.
--
-- See also: http://paulbourke.net/geometry/polygonise/

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
local max = math.max

-- Modules --
local ffi = require("ffi")
local common = require("marching_cubes.common")
local morton_indexed = require("marching_cubes.morton_indexed")

-- Imports --
local Cell = common.Cell

-- Exports --
local M = {}

--- DOCME
-- TODO: "Embarrassingly parallel"... threads?
function M.BuildIsoSurface (walker, loader, polygonize, func, iso)
	iso = iso or 0

    local cell, cur = Cell(), walker:Begin()

	while walker:Next(cur) do
		walker:SetCell(cell, cur)
		loader:Reset()

		polygonize(cell, loader, iso)
		func(loader)
	end
end

--- DOCME
-- TODO: Move this to some helper module
function M.Init (nx, ny, nz)
	if max(nx, ny, nz) <= 1024 then
		return morton_indexed(nx, ny, nz) -- Try 2-D version too?
	else
		-- "Naive" way?
	end
end

-- Export the module.
return M