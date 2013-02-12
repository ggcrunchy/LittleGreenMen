-- Modules --
local ffi = require("ffi")
--local gl  = require("ffi/OpenGLES2")
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

	mat.counter = 1;

	return mat
end

-- --
local MVP = NewMatrix()

-- --
local MatrixSize = ffi.sizeof(MVP.matrix)

--
local function CopyMatrix (dst, src, inc)
	ffi.copy(dst, src, MatrixSize)

	if inc then
		dst.counter = dst.counter + 1
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

--- DOCME
function M.GetModelViewProjection (mvp)
	CopyMatrix(mvp, MVP)
end

--- DOCME
function M.GetModelViewProjection_Lazy (mvp)
	return CopyMatrix_Lazy(mvp, MVP)
end

-- --
local MV = NewMatrix()

--- DOCME
function M.GetModelView (mv)
	CopyMatrix(mv, MV)
end

function M.GetModelView_Lazy (mv)
	return CopyMatrix_Lazy(mv, MV)
end

-- --
local Proj = NewMatrix()

--- DOCME
function M.GetProjection (proj)
	CopyMatrix(proj, Proj)
end

function M.GetProjection_Lazy (proj)
	return CopyMatrix_Lazy(proj, Proj)
end

--
local function ComputeMVP ()
	xforms.MatrixMultiply(MVP.matrix, MV.matrix, Proj.matrix)

	MVP.counter = MVP.counter + 1
end

--- DOCME
-- @function NewLazyMatrix
-- @treturn LazyMatrix X
M.NewLazyMatrix = LazyMatrix

--- DOCME
-- @param mv
function M.SetModelViewMatrix (mv)
	CopyMatrix(MV, mv, true)
	ComputeMVP()
end

--- DOCME
-- @param proj
function M.SetProjectionMatrix (proj)
	CopyMatrix(Proj, proj, true)
	ComputeMVP()
end

-- Export the module.
return M