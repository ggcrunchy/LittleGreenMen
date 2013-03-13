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
local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min

-- Modules --
local ffi = require("ffi")
local morton_indexed = require("marching_cubes.morton_indexed")
local v3math = require("lib.v3math")

-- Imports --
local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local lshift = bit.lshift
local rshift = bit.rshift

-- Exports --
local M = {}

-- --
local TriTable = ffi.new("int[256][16]", require("marching_cubes.lut"))

-- --
local dvector = v3math.new
local dvector_array = ffi.typeof("$[?]", dvector)

-- Linearly interpolate the position where an isosurface cuts
-- an edge between two vertices, each with their own scalar value
local function VertexInterp (cell, i1, i2, iso)
	local p1, valp1 = cell.p[i1], cell.val[i1]
	local p2, valp2 = cell.p[i2], cell.val[i2]

	if abs(iso - valp1) < 0.00001 then
		return p1
	end

	if abs(iso - valp2) < 0.00001 then
		return p2
	end

	if abs(valp1 - valp2) < 0.00001 then
		return p1
	end

	local mu = (iso - valp1) / (valp2 - valp1)

	return v3math.addscalednew(p1, v3math.subnew(p2, p1), mu)
end

-- --
local Merge = ffi.new("int[12]", { 0, 0, 0, 4, 0, 0, 0, 12, 13, 15, 13, 11 })

-- --
local VertList = dvector_array(12)

--
local function GetVertex (cell, index, computed, iso)
	local mask = lshift(1, index)

	if band(computed, mask) == 0 then
		computed = bor(computed, mask)

		VertList[index] = VertexInterp(cell, band(index, 7), bxor(index + 1, Merge[index]), iso)
	end

	return VertList[index], computed
end

-- Given a grid cell and an isolevel, calculate the triangular
-- facets required to represent the isosurface through the cell.
-- Return the number of triangular facets, the array "triangles"
-- will be loaded up with the vertices at most 5 triangular facets.
-- 0 will be returned if the grid cell is either totally above
-- of totally below the isolevel.
-- TODO: Investigate Graphics Gems 3 article... mentioned only generating new vertices for 3, 1, 8?
local function Polygonise (cell, triangles, iso)
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
	local computed, index, ntri = 0, 0, 0

	while TriTable[cubeindex][index] ~= -1 do
		triangles[ntri].p[0], computed = GetVertex(cell, TriTable[cubeindex][index + 0], computed, iso)
		triangles[ntri].p[1], computed = GetVertex(cell, TriTable[cubeindex][index + 1], computed, iso)
		triangles[ntri].p[2], computed = GetVertex(cell, TriTable[cubeindex][index + 2], computed, iso)

		ntri, index = ntri + 1, index + 3
	end

	return ntri
end

--
local function BuildTriangle (tri, cell, a1, a2, b1, b2, c1, c2, iso)
	tri.p[0] = VertexInterp(cell, a1, a2, iso)
	tri.p[1] = VertexInterp(cell, b1, b2, iso)
	tri.p[2] = VertexInterp(cell, c1, c2, iso)
end

--
local function BuildAndJoin (tri, cell, a1, a2, prev, pi1, pi2, iso)
	tri.p[0] = prev.p[pi1]
	tri.p[1] = VertexInterp(cell, a1, a2, iso)
	tri.p[2] = prev.p[pi2]
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
local function PolygoniseTri (cell, triangles, v0, v1, v2, v3, ntri, iso)
	-- Determine which of the 16 cases we have given which vertices
	-- are above or below the isosurface
	local tindex = rshift(floor(cell.val[v0] - iso), 31)

	tindex = bor(tindex, band(rshift(floor(cell.val[v1] - iso), 30), 2))
	tindex = bor(tindex, band(rshift(floor(cell.val[v2] - iso), 29), 4))
	tindex = bor(tindex, band(rshift(floor(cell.val[v3] - iso), 28), 8))

	-- Form the vertices of the triangles for each case	
	local cur = triangles[ntri]

	tindex = min(tindex, 0xF - tindex)

	if tindex == 0 then
		return ntri
	elseif tindex == 1 then
		BuildTriangle(cur, cell, v0, v1, v0, v2, v0, v3, iso)
	elseif tindex == 2 then
		BuildTriangle(cur, cell, v1, v0, v1, v3, v1, v2, iso)
	elseif tindex == 3 then
		BuildTriangle(cur, cell, v0, v3, v0, v2, v1, v3, iso)

		ntri = ntri + 1

		BuildAndJoin(triangles[ntri], cell, v1, v2, cur, 2, 1, iso)
	elseif tindex == 4 then
		BuildTriangle(cur, cell, v2, v0, v2, v1, v2, v3, iso)
	elseif tindex == 5 then
		BuildTriangle(cur, cell, v0, v1, v2, v3, v0, v3, iso)

		ntri = ntri + 1

		BuildAndJoin(triangles[ntri], cell, v1, v2, cur, 0, 1, iso)
	elseif tindex == 6 then
		BuildTriangle(cur, cell, v0, v1, v1, v3, v2, v3, iso)

		ntri = ntri + 1

		BuildAndJoin(triangles[ntri], cell, v0, v2, cur, 0, 2, iso)
	elseif tindex == 7 then
		BuildTriangle(cur, cell, v3, v0, v3, v2, v3, v1, iso)
	end

	return ntri + 1
end

local function PolygoniseTetra (cell, triangles, iso)
	local ntri = 0

	ntri = PolygoniseTri(cell, triangles, 0, 2, 3, 7, ntri, iso)
	ntri = PolygoniseTri(cell, triangles, 0, 2, 6, 7, ntri, iso)
	ntri = PolygoniseTri(cell, triangles, 0, 4, 6, 7, ntri, iso)
	ntri = PolygoniseTri(cell, triangles, 0, 6, 1, 2, ntri, iso)
	ntri = PolygoniseTri(cell, triangles, 0, 6, 1, 4, ntri, iso)
	ntri = PolygoniseTri(cell, triangles, 5, 6, 1, 4, ntri, iso)

	return ntri
end

--
local GridCell = ffi.typeof([[
	struct {
		$ p[8];
		double val[8];
	}
]], dvector)

--
local Triangle = ffi.typeof([[
	struct {
		$ p[3];
	}[?]
]], dvector)

-- --
local sTri = Triangle(12)

--- DOCME
-- TODO: "Embarrassingly parallel"... threads?
-- TODO: feed triangles (and indices) elsewhere, e.g. to func
function M.BuildIsoSurface (walker, func, options)
	local polygonise, iso

	if options then
		polygonise = options.polygonise
		iso = options.iso
	end

	polygonise = polygonise or Polygonise -- TODO: How?
	iso = iso or 0

    local cell = GridCell()

	walker:Begin()

	while walker:Next() do
		walker:SetCell(cell)

		local ntri = polygonise(cell, sTri, iso)

		for i = 0, ntri - 1 do
			func(sTri[i].p[0], sTri[i].p[1], sTri[i].p[2])
		end
		-- verts, indices
	end
end

--- DOCME
function M.Init (nx, ny, nz)
	if max(nx, ny, nz) <= 1024 then
		return morton_indexed(nx, ny, nz) -- Try 2-D version too?
	else
		-- "Naive" way?
	end
end

-- Export the module.
return M