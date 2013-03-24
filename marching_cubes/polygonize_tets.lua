--- The "marching tets" polygonizer.
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
local floor = math.floor
local lshift = bit.lshift
local min = math.min
local rshift = bit.rshift

-- Modules --
local ffi = require("ffi")
local common = require("marching_cubes.common")

-- Imports --
local VertexInterp = common.VertexInterp

-- Exports --
local M = {}

--
local function GetVertex (cell, loader, indices, i1, i2, iso)
	local index = lshift(i1, 3) + i2

	if indices[index] == 0 then
		indices[index] = loader:GetVertexCount() + 1

		loader:AddVertex(VertexInterp(cell, i1, i2, iso))
	end

	loader:AddIndex(indices[index] - 1)
end

--
local function BuildTriangle (cell, loader, indices, a1, a2, b1, b2, c1, c2, iso)
	GetVertex(cell, loader, indices, a1, a2, iso)
	GetVertex(cell, loader, indices, b1, b2, iso)
	GetVertex(cell, loader, indices, c1, c2, iso)
end

--
local function BuildAndJoin (cell, loader, indices, a1, a2, pi1, pi2, iso)
	local pbase = #loader - 3

	loader:AddIndex(loader:GetIndex(pbase + pi1))

	GetVertex(cell, loader, indices, a1, a2, iso)

	loader:AddIndex(loader:GetIndex(pbase + pi2))
end

--[[
   Polygonise a tetrahedron given its vertices within a cube
   This is an alternative algorithm to polygonise grid.
   It results in a smoother surface but more triangular facets.

                      + 0
                     /|\
                    / | \
                   /  |  \
                  /   |   \
                 /    |    \
                /     |     \
               +-------------+ 1
              3 \     |     /
                 \    |    /
                  \   |   /
                   \  |  /
                    \ | /
                     \|/
                      + 2

   Its main purpose is still to polygonise a gridded dataset and
   would normally be called 6 times, one for each tetrahedron making
   up the grid cell.
]]
-- TODO: Investigate Graphics Gems 3 article... mentioned only generating new vertices for 3, 1, 8?
local function DoTri (cell, loader, indices, v0, v1, v2, v3, iso)
	-- Determine which of the 16 cases we have given which vertices
	-- are above or below the isosurface
	local tindex = rshift(floor(cell.val[v0] - iso), 31)

	tindex = bor(tindex, band(rshift(floor(cell.val[v1] - iso), 30), 2))
	tindex = bor(tindex, band(rshift(floor(cell.val[v2] - iso), 29), 4))
	tindex = bor(tindex, band(rshift(floor(cell.val[v3] - iso), 28), 8))

	-- Form the vertices of the triangles for each case	
	tindex = min(tindex, 0xF - tindex)

	if tindex == 0 then
		return
	elseif tindex == 1 then
		BuildTriangle(cell, loader, indices, v0, v1, v0, v2, v0, v3, iso)
	elseif tindex == 2 then
		BuildTriangle(cell, loader, indices, v1, v0, v1, v3, v1, v2, iso)
	elseif tindex == 3 then
		BuildTriangle(cell, loader, indices, v0, v3, v0, v2, v1, v3, iso)
		BuildAndJoin(cell, loader, indices, v1, v2, 2, 1, iso)
	elseif tindex == 4 then
		BuildTriangle(cell, loader, indices, v2, v0, v2, v1, v2, v3, iso)
	elseif tindex == 5 then
		BuildTriangle(cell, loader, indices, v0, v1, v2, v3, v0, v3, iso)
		BuildAndJoin(cell, loader, indices, v1, v2, 0, 1, iso)
	elseif tindex == 6 then
		BuildTriangle(cell, loader, indices, v0, v1, v1, v3, v2, v3, iso)
		BuildAndJoin(cell, loader, indices, v0, v2, 0, 2, iso)
	elseif tindex == 7 then
		BuildTriangle(cell, loader, indices, v3, v0, v3, v2, v3, v1, iso)
	end
end

-- Which vertex does the [0, 8), [0, 8) index pair reference? --
local Indices = ffi.typeof("uint8_t[64]")

--- DOCME
function M.DoCell (cell, loader, iso)
	local indices = Indices()

	DoTri(cell, loader, indices, 0, 2, 3, 7, iso)
	DoTri(cell, loader, indices, 0, 2, 6, 7, iso)
	DoTri(cell, loader, indices, 0, 4, 6, 7, iso)
	DoTri(cell, loader, indices, 0, 6, 1, 2, iso)
	DoTri(cell, loader, indices, 0, 6, 1, 4, iso)
	DoTri(cell, loader, indices, 5, 6, 1, 4, iso)
end

--- DOCME
function M.MaxAdded ()
	return 24, 36
end

-- Export the module.
return M