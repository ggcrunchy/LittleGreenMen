-- Standard library imports --
local assert = assert
local type = type

-- Modules --
local ffi = require("ffi")
local gl  = require("ffi/OpenGLES2")
local render_state = require("render_state_gles")
local shader_helper = require("lib.shader_helper")
--local xforms = require("transforms_gles")

-- Imports --
local Float3 = ffi.typeof("float[3]")
local Float4 = ffi.typeof("float[4]")

-- Exports --
local M = {}

-- --
local ShaderParams = {}

-- --
local MVP, LocMVP = render_state.NewLazyMatrix()

--
function ShaderParams:on_draw ()
	if render_state.GetModelViewProjection_Lazy(MVP) then
		self:BindUniformMatrix(LocMVP, MVP.matrix[0])
	end
end

-- --
--local PrevPos = Float3() -- In case we want an "append"...

-- --
--local PrevColor = Float4()

-- --
local N, DrawBatch = 0

--
function ShaderParams.on_done ()
	if N > 0 then
		DrawBatch()
	end

	-- Invalidate prev?
end

-- --
local MaxN = 16

-- --
local Pos, LocPos = ffi.new("float[?][3]", MaxN * 2)
local Color, LocColor = ffi.new("float[?][4]", MaxN * 2)

--
function ShaderParams:on_use ()
	self:BindAttributeStream(LocPos, Pos, 3)
	self:BindAttributeStream(LocColor, Color, 4)
end

--
function ShaderParams:on_init ()
	LocMVP = self:GetUniformByName("mvp")

	LocPos = self:GetAttributeByName("position")
	LocColor = self:GetAttributeByName("color")
end

--
ShaderParams.vs = [[
	attribute mediump vec3 position;
	attribute mediump vec4 color;
	uniform mediump mat4 mvp;
	varying lowp vec4 lcolor;
	
	void main ()
	{
		lcolor = color;

		gl_Position = mvp * vec4(position, 1);
	}
]]

--
ShaderParams.fs = [[
	varying lowp vec4 lcolor;

	void main ()
	{
		gl_FragColor = lcolor;
	}
]]

-- --
local SP = shader_helper.NewShader(ShaderParams)

function DrawBatch ()
	SP:DrawArrays(gl.GL_LINES, N * 2)
	-- Prev = Batch[N]?

	N = 0
end

--
local function GetColor (color, def)
	if ffi.istype(Float4, color) then
		return color
	end

	local out = def

	if ffi.istype(Float3, color) or type(color) == "table" then
		out = Float4{1}

		if ffi.istype(Float3, color) then
			ffi.copy(out, color, ffi.sizeof(Float3))
		else
			assert(#color == 3 or #color == 4, "Invalid color array")

			for i = 1, #color do
				out[i - 1] = color[i]
			end
		end
	elseif def == nil then
		out = Float4{1}
	end

	return out
end

--- DOCME
-- @number x1
-- @number y1
-- @number z1
-- @number x2
-- @number y2
-- @number z2
-- @ptable color1
-- @ptable color2
function M.Draw (x1, y1, z1, x2, y2, z2, color1, color2)
	SP:Use()

	--
	Pos[N * 2 + 0] = Float3(x1, y1, z1)
	Pos[N * 2 + 1] = Float3(x2, y2, z2)

	--
	local cref = GetColor(color1)

	Color[N * 2 + 0] = cref
	Color[N * 2 + 1] = GetColor(color2, cref)

	--
	N = N + 1

	if N == MaxN then
		DrawBatch()
	end
end

-- Export the module.
return M