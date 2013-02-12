--- A wrapper around common shader operations.

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
local assert = assert
local ipairs = ipairs
local max = math.max
local setmetatable = setmetatable

-- Modules --
local ffi = require("ffi")
local gl = require("ffi/OpenGLES2")
local shaders = require("shaders_gles")

-- Exports --
local M = {}

--
local ShaderMT = {}

ShaderMT.__index = ShaderMT

--- DOCME
function ShaderMT:BindAttributeStreamByName (name, stream, size)
	local loc = assert(self._anames[name], "Invalid attribute name")

	gl.glVertexAttribPointer(loc, size, gl.GL_FLOAT, gl.GL_FALSE, 0, stream)
end

--- DOCME
function ShaderMT:BindAttributeStream (loc, stream, size)
	gl.glVertexAttribPointer(loc, size, gl.GL_FLOAT, gl.GL_FALSE, 0, stream)
end

--- DOCME
function ShaderMT:BindUniformMatrixByName (name, matrix)
	local loc = assert(self._unames[name], "Invalid uniform name")

	gl.glUniformMatrix4fv(loc, 1, gl.GL_FALSE, matrix)
end

--- DOCME
function ShaderMT:BindUniformMatrix (loc, matrix)
	gl.glUniformMatrix4fv(loc, 1, gl.GL_FALSE, matrix)
end

-- --
local BoundLocs

--
local function Disable ()
	for i = 1, #(BoundLocs or "") do
		gl.glDisableVertexAttribArray(BoundLocs[i])
	end

	BoundLocs = nil
end

-- --
local OnDone

-- --
local Program = 0

-- --
local UniformNames

--
local function StopUsing ()
	if OnDone then
		OnDone()
	end

	Program, OnDone, UniformNames = 0
end

--- DOCME
function ShaderMT:Disable ()
	if self._alocs == BoundLocs then
		Disable()
	end

	if self._program == Program then
		StopUsing()
	end
end

--
local function Enable (shader)
	if shader._alocs ~= BoundLocs then
		Disable()

		for _, aloc in ipairs(shader._alocs) do
			gl.glEnableVertexAttribArray(aloc)
		end

		BoundLocs = shader._alocs
	end
end

--
local function Draw (shader)
	Enable(shader)

	shader:_on_draw()
end

--- DOCME
function ShaderMT:DrawArrays (type, count, base)
	Draw(self)

	gl.glDrawArrays(type, base or 0, count)
end

--- DOCME
function ShaderMT:DrawElements (type, indices, num_indices)
	Draw(self)

	gl.glDrawElements(type, num_indices, gl.GL_UNSIGNED_SHORT, indices)
end

--- DOCME
function ShaderMT:GetAttributeByName (name)
	return self._anames[name]
end

--- DOCME
function ShaderMT:GetUniformByName (name)
	return self._unames[name]
end

--- DOCME
function ShaderMT:Use ()
	if self._program ~= Program then
		StopUsing()

		Program = self._program

		gl.glUseProgram(Program)

		OnDone = self._on_done
		UniformNames = self._unames

		self:_on_use()
	end
end

--- DOCME
function M.Finish ()
	Disable()
	StopUsing()
end

-- --
local IntVar = ffi.new("GLint[1]")

--
local function Int (prog, enum)
	gl.glGetProgramiv(prog, enum, IntVar)

	return IntVar[0]
end

-- --
local EnumVar = ffi.new("GLenum[1]")

--
local function EnumFeatures (prog, name, name_size, count_enum, get_active, get_loc)
	local locs, names = {}, {}

	for i = 1, Int(prog, count_enum) do
		gl[get_active](prog, i - 1, name_size, nil, IntVar, EnumVar, name)

		local loc = gl[get_loc](prog, name)

		locs[#locs + 1], names[ffi.string(name)] = loc, loc
	end

	return locs, names
end

--
local function OnEventDef () end

--- DOCME
-- @ptable params
-- @treturn table X
-- @treturn string Y
function M.NewShader (params)
	local prog, err = shaders.LoadProgram(params.vs, params.fs)

	if prog ~= 0 then
		local len = max(Int(prog, gl.GL_ACTIVE_ATTRIBUTE_MAX_LENGTH), Int(prog, gl.GL_ACTIVE_UNIFORM_MAX_LENGTH))
		local buffer = ffi.new("GLchar[?]", len + 1)

		-- Enumerate attributes and uniforms.
		local alocs, anames = EnumFeatures(prog, buffer, len, gl.GL_ACTIVE_ATTRIBUTES, "glGetActiveAttrib", "glGetAttribLocation")
		local ulocs, unames = EnumFeatures(prog, buffer, len, gl.GL_ACTIVE_UNIFORMS, "glGetActiveUniform", "glGetUniformLocation")

		--
		local shader, on_draw, on_use = { _alocs = alocs, _anames = anames, _ulocs = ulocs, _unames = unames, _program = prog }

		shader._on_done = params.on_done
		shader._on_draw = params.on_draw or OnEventDef
		shader._on_use = params.on_use or OnEventDef

		setmetatable(shader, ShaderMT)

		;(params.on_init or OnEventDef)(shader)

		return shader
	else
		return nil, err
	end
end

-- --
local FloatVar = ffi.new("GLfloat[1]")

---
M.Uniforms = setmetatable({}, {
	__index = function(_, k)
		assert(Program ~= 0, "No program in use")

		local loc = assert(UniformNames[k], "Uniform not found")

		-- TODO: Discriminate ints, handle long arrays...
		local var = FloatVar

		gl.glGetUniformfv(Program, loc, var)

		return var[0]
	end,
	__newindex = function(_, k, v)
		assert(Program ~= 0, "No program in use")

		local loc = assert(UniformNames[k], "Uniform not found")

		-- TODO: Discriminate ints, handle panoply of sizes...
--		gl.glUniformTHIS_OR_THAT()...
	end
})

-- Export the module.
return M