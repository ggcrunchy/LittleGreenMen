--- DOOBL

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

-- Modules --
local ffi = require("ffi")
local xforms = require("transforms_gles")

-- Exports --
local M = {}

--
local LazyMatrix = ffi.typeof[[
	struct {
		float matrix[4][4];
		int32_t counter;
	}
]]

--
local function NewMatrix ()
	local mat = LazyMatrix()

	xforms.MatrixLoadIdentity(mat.matrix)

	mat.counter = 1

	return mat
end

-- --
local MVP, MV, Proj = NewMatrix()

-- --
local MatrixSize = ffi.sizeof(MVP.matrix)

--
local function CopyMatrix (dst, src)
	ffi.copy(dst, src, MatrixSize)

	if src.counter < 0 then
		src.counter = 1 - src.counter
	end
end

--
local function CopyMatrix_Lazy (dst, src)
	local diff = src.counter ~= dst.counter

	if diff then
		CopyMatrix(dst, src)

		dst.counter = src.counter
	end

	return diff
end

--
local function ComputeMVP ()
	if MVP.counter < 0 then
		xforms.MatrixMultiply(MVP.matrix, MV.matrix, Proj.matrix)
	end
end

--- DOCME
function M.GetModelViewProjection (mvp)
	ComputeMVP()
	CopyMatrix(mvp, MVP)
end

--- DOCME
function M.GetModelViewProjection_Lazy (mvp)
	ComputeMVP()

	return CopyMatrix_Lazy(mvp, MVP)
end

-- --
MV = NewMatrix()

--- DOCME
function M.GetModelView (mv)
	CopyMatrix(mv, MV)
end

--- DOCME
function M.GetModelView_Lazy (mv)
	return CopyMatrix_Lazy(mv, MV)
end

-- --
Proj = NewMatrix()

--- DOCME
function M.GetProjection (proj)
	CopyMatrix(proj, Proj)
end

--- DOCME
function M.GetProjection_Lazy (proj)
	return CopyMatrix_Lazy(proj, Proj)
end

--- DOCME
-- @function NewLazyMatrix
-- @treturn LazyMatrix X
M.NewLazyMatrix = LazyMatrix

--
local function Dirty (matrix)
	matrix.counter = -abs(matrix.counter)
end

--- DOCME
-- @param mv
function M.SetModelViewMatrix (mv)
	ffi.copy(MV, mv, MatrixSize)

	Dirty(MV)
	Dirty(MVP)
end

--- DOCME
-- @param proj
function M.SetProjectionMatrix (proj)
	ffi.copy(Proj, proj, MatrixSize)

	Dirty(Proj)
	Dirty(MVP)
end

-- Export the module.
return M