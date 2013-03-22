--- Some common marching cubes utilities.

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
local min = math.min

-- Modules --
local ffi = require("ffi")
local v3math = require("lib.v3math")

-- Imports --
local addscalednew = v3math.addscalednew
local subnew = v3math.subnew

-- Exports --
local M = {}

--- DOCME
local dvector = v3math.new

--- DOCME
M.Cell = ffi.typeof([[
	struct {
		$ p[8];
		double val[8];
	}
]], dvector)

--- DOCME
function M.SetCellCorner (cell, ci, i, j, k, v)
	cell.p[ci][0] = i
	cell.p[ci][1] = j
	cell.p[ci][2] = k
    cell.val[ci] = v
end

--- DOCME
function M.SetCellCornerValue (cell, ci, v)
	cell.val[ci] = v
end

--- DOCME
M.Triangle = ffi.typeof([[
	struct {
		$ p[3];
	}[?]
]], dvector)

--- DOCME
M.TriTable = ffi.new("int[256][16]", require("marching_cubes.lut"))

--- DOCME
M.Vector = dvector

--- DOCME
M.VectorArray = ffi.typeof("$[?]", dvector)

--
local fvector = ffi.typeof("float[3]")

-- --
M.VertexLoaderBasic = ffi.typeof([[
	struct {
		$ * verts; // Stream of 3-float vertices...
		uint16_t * indices; // ...and (0-based) indices
		int16_t nverts; // Number of loaded vertices...
		int16_t nindices; // ...and indices
	}
]], fvector)

-- Methods --
local VertexLoaderBasic = {}

--- DOCME
function VertexLoaderBasic:AddIndex (index)
	self.indices[#self] = index

	self.nindices = #self + 1
end

--- DOCME
function VertexLoaderBasic:AddVertex (vertex)
	local pverts = self.verts[self.nverts]

	pverts[0], pverts[1], pverts[2] = vertex[0], vertex[1], vertex[2]

	self.nverts = self.nverts + 1
end

--- DOCME
function VertexLoaderBasic:GetIndex (pos)
	return self.indices[pos]
end

--- DOCME
function VertexLoaderBasic:Reset ()
	self.nverts, self.nindices = 0, 0
end

--
ffi.metatype(M.VertexLoaderBasic, {
	-- --
	__len = function(vlb)
		return vlb.nindices
	end,

	-- --
	__index = VertexLoaderBasic
})

--- DOCME
-- Linearly interpolate the position where an isosurface cuts
-- an edge between two vertices, each with their own scalar value
function M.VertexInterp (cell, i1, i2, iso)
	local p1, valp1 = cell.p[i1], cell.val[i1]
	local p2, valp2 = cell.p[i2], cell.val[i2]

	if abs(valp2 - valp1) < 0.00001 then
		return p1
	end

	local mu = (iso - valp1) / (valp2 - valp1)

	return addscalednew(p1, subnew(p2, p1), mu)
end

--- DOCME
function M.WithinGrid (walker, x, y, z)
	return min(x, walker.ex - x) >= 0 and min(y, walker.ey - y) >= 0 and min(z, walker.ez - z) >= 0
end

-- Export the module.
return M