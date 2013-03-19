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
local tonumber = tonumber
local type = type

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
	local loc = assert(self:GetAttributeByName(name), "Invalid attribute name")

	gl.glVertexAttribPointer(loc, size, gl.GL_FLOAT, gl.GL_FALSE, 0, stream)
end

--- DOCME
function ShaderMT:BindAttributeStream (loc, stream, size)
	gl.glVertexAttribPointer(loc, size, gl.GL_FLOAT, gl.GL_FALSE, 0, stream)
end

-- --
local FloatPtr = ffi.typeof("GLfloat *")

--- DOCME
function ShaderMT:BindUniformMatrixByName (name, matrix)
	local loc = assert(self:GetUniformByName(name), "Invalid uniform name")

	gl.glUniformMatrix4fv(loc, 1, gl.GL_FALSE, ffi.cast(FloatPtr, matrix))
end

--- DOCME
function ShaderMT:BindUniformMatrix (loc, matrix)
	gl.glUniformMatrix4fv(loc, 1, gl.GL_FALSE, ffi.cast(FloatPtr, matrix))
end

-- --
local BoundLocs

--
local function Disable ()
-- TODO: Upload any cached uniforms?
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
local UniformLocs, UniformNames

-- --
local UsingBuffers

--
local function WipeBuffers ()
	gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0)
	gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, 0)
end

--
local function StopUsing ()
	if OnDone then
		OnDone()
	end

	if UsingBuffers then
		WipeBuffers()
	end

	Program, OnDone, UniformLocs, UniformNames, UsingBuffers = 0
end

--- DOCME
function ShaderMT:Disable ()
	if self._program == Program then
		StopUsing()
	end

	if self._alocs == BoundLocs then
		Disable()
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
-- TODO: Could do actual upload of uniforms here
	shader:_on_draw()
end

--- DOCME
function ShaderMT:DrawArrays (type, count, base)
	Draw(self)

	gl.glDrawArrays(type, base or 0, count)
end

-- --
local NullPtr = ffi.cast("const GLvoid *", 0)

--- DOCME
function ShaderMT:DrawBufferedElements (type, state, indices, num_indices)
	-- TODO: Is bound to this shader?

	--
	if state.num_indices then
		indices, num_indices = NullPtr, state.num_indices
	end

	--
	if not UsingBuffers then
		local attribs = state.attribs
		local buffers = state.buffers

		for i, v in ipairs(attribs) do
			gl.glBindBuffer(gl.GL_ARRAY_BUFFER, buffers[i - 1])

			self:BindAttributeStream(v.loc, NullPtr, v.size)
		end

		gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0)

		if state.num_indices then
			gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, buffers[#attribs])
		end

		UsingBuffers = true
	end

	Draw(self) -- TODO: Here??

	self:DrawElements(type, indices, num_indices)
end

--- DOCME
function ShaderMT:DrawElements (type, indices, num_indices)
	Draw(self)

	gl.glDrawElements(type, num_indices, gl.GL_UNSIGNED_SHORT, indices)
end

--
local function GetByName (names, locs, name)
	local data = names[name]

	return locs[data and data.index]	
end

--- DOCME
function ShaderMT:GetAttributeByName (name)
	return GetByName(self._anames, self._alocs, name)
end

--- DOCME
function ShaderMT:GetUniformByName (name)
	return GetByName(self._unames, self._ulocs, name)
end

--
local function SetupBuffer (type, info, buffer)
	local size = info.size or ffi.sizeof(info.data)
	local usage = info.usage or gl.GL_STATIC_DRAW

	gl.glBindBuffer(type, buffer)
	gl.glBufferData(type, size, info.data, usage)
end

--- DOCME
function ShaderMT:SetupBuffers (elements)
	assert(elements, "No elements to buffer")

	-- TODO: Tie state to shader?
	local n = #elements + (elements.indices and 1 or 0)
	local state = { attribs = {}, buffers = ffi.new("GLint[?]", n) }

	-- TODO: Validate?

	gl.glGenBuffers(n, state.buffers)

	for i, v in ipairs(elements) do
		SetupBuffer(gl.GL_ARRAY_BUFFER, v, state.buffers[i - 1])

		local loc = v.loc

		if type(loc) == "string" then
			loc = self:GetAttributeByName(loc)
		end

		state.attribs[#state.attribs + 1] = { loc = loc, size = v.attr_size, update = v.update }
	end

	if elements.indices then
		SetupBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, elements.indices, state.buffers[n - 1])

		if elements.num_indices then
			state.num_indices = elements.num_indices
		elseif elements.indices.data ~= nil then
			state.num_indices = ffi.sizeof(elements.indices.data) / 2 -- TODO: size of index...
		else
			state.num_indices = 0
		end
 
		state.update_indices = elements.indices.update
	end

	WipeBuffers()

	return state
end

--- DOCME
function ShaderMT:Use ()
	if self._program ~= Program then
		StopUsing()

		Program = self._program

		gl.glUseProgram(Program)

		OnDone = self._on_done
		UniformLocs = self._ulocs
		UniformNames = self._unames

		self:_on_use()
	end
end

--- DOCME
function M.Finish ()
	StopUsing()
	Disable()
end

-- --
local IntVar = ffi.new("GLint[1]")

--
local function Int (prog, enum)
	gl.glGetProgramiv(prog, enum, IntVar)

	return IntVar[0]
end

--
local NameType = ffi.typeof[[
	struct {
		int16_t index;
		int8_t type, offset;
	}
]]

-- --
local Types = { gl.GL_FLOAT_MAT2, gl.GL_BOOL, gl.GL_INT, gl.GL_INT_VEC2, gl.GL_FLOAT, gl.GL_FLOAT_VEC2 }

table.sort(Types)

--
-- TODO: GL_FLOAT, GL_INT...
local function ProcessType (type)
	if type ~= gl.GL_SAMPLER_2D and type ~= gl.GL_SAMPLER_CUBE then
		for i = #Types, 1, -1 do
			if type >= Types[i] then
				return i, type - Types[i]
			end
		end
	end

	return -1, 0
end

--
-- TODO: Pack uni. loc & type / size into _anames
local function EnumFeatures (prog, name, name_size, count_enum, get_active, get_loc)
	local evar = ffi.new("GLenum[1]")
	local locs, names = {}, {}

	for i = 1, Int(prog, count_enum) do
		gl[get_active](prog, i - 1, name_size, nil, IntVar, evar, name)

		local loc = gl[get_loc](prog, name)
		local str = ffi.string(name)
-- TODO: detect arrays (and structs???), add flag?

		if IntVar[0] > 1 then
			str = str:gsub("%b[]", "")
		end

		locs[i], names[str] = loc, NameType(i, ProcessType(evar[0]))
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

--
local function UpdateBuffer (state, k, index, update, arg)
	if update then
		local size, data, offset = update(arg)

		if size and size > 0 then
			gl.glBindBuffer(k, state.buffers[index])
			gl.glBufferSubData(k, offset or 0, size, data)

			return size
		end
	end
end

--- DOCME
-- @param state
-- @param arg
function M.UpdateBuffers (state, arg)
	local curb = ffi.new("GLint[1]")

	--
	gl.glGetIntegerv(gl.GL_ARRAY_BUFFER_BINDING, curb)

	for i, v in ipairs(state.attribs) do
		UpdateBuffer(state, gl.GL_ARRAY_BUFFER, i - 1, v.update, arg)
	end

	gl.glBindBuffer(gl.GL_ARRAY_BUFFER, curb[0])

	--
	gl.glGetIntegerv(gl.GL_ELEMENT_ARRAY_BUFFER_BINDING, curb)

	local size = UpdateBuffer(state, gl.GL_ELEMENT_ARRAY_BUFFER, #state.attribs, state.update_indices, arg)

	if size then
		state.num_indices = size / 2 -- TODO: size of index...

		gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, curb[0])
	end
end

--
local IndexType = {
	[gl.GL_FLOAT_MAT2] = function(n)
		-- new float[n * n]
	end,

	[gl.GL_BOOL] = function(n)
		-- new bool(int?)[n]
	end,

	[gl.GL_INT_VEC2] = function(n)
		-- new int[n]
	end,

	[gl.GL_FLOAT_VEC2] = function(n)
		-- new float[n]
	end
}

-- --
local SetUniform = {}

-- Matrix uniforms
do
	local Func = { gl.glUniformMatrix2fv, gl.glUniformMatrix3fv, gl.glUniformMatrix4fv }

	SetUniform[gl.GL_FLOAT_MAT2] = function(loc, n, v)
		assert(n <= 2, "Invalid uniform matrix")

		Func[n + 1](loc, 1, gl.GL_FALSE, ffi.cast(FloatPtr, v))
	end
end

-- Bool uniforms
do
	SetUniform[gl.GL_BOOL] = function(n, v)
		-- ??? Int?
	end
end

-- Int uniforms
do
	local Func = { gl.glUniform2iv, gl.glUniform3iv, gl.glUniform4iv }

	SetUniform[gl.GL_INT] = function(loc, _, v)
		gl.glUniform1i(tonumber(v) or v[0])
	end

	SetUniform[gl.GL_INT_VEC2] = function(n, v)
		assert(n <= 2, "Invalid uniform int tuple")

		Func[n + 1](loc, 1, ffi.cast("GLint *", v))
	end
end

-- Float uniforms
do
	local Func = { gl.glUniform2fv, gl.glUniform3fv, gl.glUniform4fv }

	SetUniform[gl.GL_FLOAT] = function(loc, _, v)
		gl.glUniform1f(tonumber(v) or v[0])
	end

	SetUniform[gl.GL_FLOAT_VEC2] = function(loc, n, v)
		assert(n <= 2, "Invalid uniform float tuple")

		Func[n + 1](loc, 1, ffi.cast(FloatPtr, v))
	end
end

-- --
local FloatArr = ffi.typeof("GLfloat[?]")
local IntArr = ffi.typeof("GLint[?]")

---
M.Uniforms = setmetatable({}, {
	__index = function(_, k)
		assert(Program ~= 0, "No program in use")

		local data = assert(UniformNames[k], "Uniform not found")
		local type = assert(Types[data.type], "Unsupported type")
		local cons, func, n = FloatArr, gl.glGetUniformfv, data.offset + 2

		if type == gl.GL_FLOAT_MAT2 then
			n = n * n
		elseif type == gl.GL_FLOAT or type == gl.GL_FLOAT_VEC2 then
			n = type == gl.GL_FLOAT and 1 or n
		elseif type == gl.GL_INT or type == gl.GL_INT_VEC2 then
			cons, func, n = IntArr, gl.glGetUniformiv, type == gl.GL_INT and 1 or n
		else
			return nil -- TODO: bools
		end

		--
		local var = cons(n) -- TODO: Always a tuple, even for int[1] and float[1]?

		func(Program, UniformLocs[data.index], var)

		return var
	end,
	__newindex = function(_, k, v)
		assert(Program ~= 0, "No program in use")

		local data = assert(UniformNames[k], "Uniform not found")
		local type = assert(Types[data.type], "Unsupported type")

		SetUniform[type](UniformLocs[data.index], data.offset, v)
	end,
	__metatable = true
})

-- Export the module.
return M