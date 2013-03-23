--- The basic marching cubes polygonizer.
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
local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local floor = math.floor
local rshift = bit.rshift

-- Modules --
local ffi = require("ffi")
local common = require("marching_cubes.common")

-- Imports --
local TriTable = common.TriTable
local VertexInterp = common.VertexInterp

-- Exports --
local M = {}

-- --
local Merge = ffi.new("int[12]", { 0, 0, 0, 4, 0, 0, 0, 12, 13, 15, 13, 11 })

--
local function GetVertex (cell, loader, indices, index, iso)
	if indices[index] == 0 then
		indices[index] = loader.nverts + 1

		loader:AddVertex(VertexInterp(cell, band(index, 7), bxor(index + 1, Merge[index]), iso))
	end

	loader:AddIndex(indices[index] - 1)
end

-- Which vertex does this [0, 12) index reference? --
local Indices = ffi.typeof("uint8_t[12]")

--- DOCME
-- Given a grid cell and an isolevel, calculate the triangular
-- facets required to represent the isosurface through the cell.
-- Return the number of triangular facets, the array "triangles"
-- will be loaded up with the vertices at most 5 triangular facets.
-- 0 will be returned if the grid cell is either totally above
-- of totally below the isolevel.
-- TODO: Investigate Graphics Gems 3 article... mentioned only generating new vertices for 3, 1, 8?
function M.DoCell (cell, loader, iso)
	-- Determine the index into the edge table which
	-- tells us which vertices are inside of the surface
	local cubeindex = rshift(floor(cell.val[0] - iso), 31)

	cubeindex = bor(cubeindex, band(rshift(floor(cell.val[1] - iso), 30), 0x02))
	cubeindex = bor(cubeindex, band(rshift(floor(cell.val[2] - iso), 29), 0x04))
	cubeindex = bor(cubeindex, band(rshift(floor(cell.val[3] - iso), 28), 0x08))
	cubeindex = bor(cubeindex, band(rshift(floor(cell.val[4] - iso), 27), 0x10))
	cubeindex = bor(cubeindex, band(rshift(floor(cell.val[5] - iso), 26), 0x20))
	cubeindex = bor(cubeindex, band(rshift(floor(cell.val[6] - iso), 25), 0x40))
	cubeindex = bor(cubeindex, band(rshift(floor(cell.val[7] - iso), 24), 0x80))

	-- Create the triangle
	local indices, index = Indices(), 0

	while TriTable[cubeindex][index] ~= -1 do
		GetVertex(cell, loader, indices, TriTable[cubeindex][index + 0], iso)
		GetVertex(cell, loader, indices, TriTable[cubeindex][index + 1], iso)
		GetVertex(cell, loader, indices, TriTable[cubeindex][index + 2], iso)

		index = index + 3
	end
end

--- DOCME
function M.MaxAdded ()
	return 12, 15
end

-- Export the module.
return M