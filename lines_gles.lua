--- POOM

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
local type = type

-- Modules --
local ffi = require("ffi")
local gl  = require("ffi/OpenGLES2")
local render_state = require("render_state_gles")
local shader_helper = require("lib.shader_helper")
--local xforms = require("transforms_gles")

-- Exports --
local M = {}

-- Types --
local Float3 = ffi.typeof("float[3]")
local Float4 = ffi.typeof("float[4]")

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
local N, First, DrawBatch = 0, true

--
function ShaderParams.on_done ()
	if N > 0 then
		DrawBatch()
	end
end

-- --
local MaxN = 16

-- --
local Pos, LocPos = ffi.typeof("$[?]", Float3)(MaxN * 2)
local Color, LocColor = ffi.typeof("$[?]", Float4)(MaxN * 2)

--
function ShaderParams:on_use ()
	gl.glEnable(gl.GL_DEPTH_TEST)

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

	N = 0
end

--
local function GetColor (color)
	if ffi.istype(Float4, color) then
		return color
	end

	local out = Float4{1}

	if ffi.istype(Float3, color) then
		ffi.copy(out, color, ffi.sizeof(Float3))
	else
		assert(type(color) == "table" and #color == 3 or #color == 4, "Invalid color array")

		for i = 1, #color do
			out[i - 1] = color[i]
		end
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
	if color1 ~= nil then
		Color[N * 2 + 0] = GetColor(color1)
	else
		Color[N * 2 + 0] = Float4{1}
	end

	if color2 ~= nil then
		Color[N * 2 + 1] = GetColor(color2)
	else
		Color[N * 2 + 1] = Color[N * 2 + 0]
	end

	--
	N, First = N + 1

	if N == MaxN then
		DrawBatch()
	end
end

--- DOCME
-- @number x
-- @number y
-- @number z
-- @ptable color
function M.DrawTo (x, y, z, color)
	local prev_pos, prev_color

	if not First then
		local index = (N > 0 and N or MaxN) * 2 - 1

		prev_pos, prev_color = Pos[index], Color[index]
	else
		prev_pos, prev_color = Float3(), Float4{1}
	end

	M.Draw(prev_pos[0], prev_pos[1], prev_pos[2], x, y, z, prev_color, color)
end

-- Export the module.
return M