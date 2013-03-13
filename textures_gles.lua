--- BRBL

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

-- Modules --
local ffi = require("ffi")
local gl  = require("ffi/OpenGLES2")
local sdl = require("ffi/sdl")
local shader_helper = require("lib.shader_helper")
local xforms = require("transforms_gles")

-- Exports --
local M = {}

-- Types --
local Float2 = ffi.typeof("float[2]")

-- --
local ShaderParams = {}

-- --
local N, DrawBatch, Name = 0

--
function ShaderParams.on_done ()
	if N > 0 then
		DrawBatch()
	end

	Name = nil

	gl.glDisable(gl.GL_TEXTURE_2D)
end

-- --
local MaxN = 32

-- --
local Proj, LocProj = xforms.New()
local Pos, LocPos = ffi.typeof("$[?]", Float2)(MaxN * 4)--8)
local Tex, LocTex = ffi.typeof("$[?]", Float2)(MaxN * 4)--8)
-- ^^ TODO: 4 correct?
-- TODO: Buffer this stuff?
local Indices = ffi.new("GLushort[?]", MaxN * 6 - 2)

local index, curr = 0, -1

for i = 0, MaxN - 1 do
	if i > 0 then
		Indices[index + 0] = curr
		Indices[index + 1] = curr + 1

		index = index + 2
	end

	for j = 0, 3 do
		curr = curr + 1
		Indices[index] = curr
		index = index + 1
	end
end

--
function ShaderParams:on_init ()
	LocProj = self:GetUniformByName("proj")

	LocPos = self:GetAttributeByName("position")
	LocTex = self:GetAttributeByName("texcoord")
end

--
local Screen = ffi.new("int[4]")

--
function ShaderParams:on_use ()
	gl.glDisable(gl.GL_DEPTH_TEST)
	gl.glDisable(gl.GL_CULL_FACE)
	gl.glEnable(gl.GL_TEXTURE_2D)
	gl.glActiveTexture(gl.GL_TEXTURE0)

	self:BindAttributeStream(LocPos, Pos, 2)
	self:BindAttributeStream(LocTex, Tex, 2)

	local screen = ffi.new("int[4]")

	gl.glGetIntegerv(gl.GL_VIEWPORT, screen)

	if screen[0] ~= Screen[0] or screen[1] ~= Screen[1] or screen[2] ~= Screen[2] or screen[3] ~= Screen[3] then
		Screen = screen

		xforms.MatrixLoadIdentity(Proj)
		xforms.Ortho(Proj, screen[0], screen[0] + screen[2], screen[1] + screen[3], screen[1], 0, 1)

		self:BindUniformMatrix(LocProj, Proj)
	end
end

--
ShaderParams.vs = [[
	attribute mediump vec2 position;
	attribute mediump vec2 texcoord;
	uniform mediump mat4 proj;

	varying highp vec2 uv;
	
	void main ()
	{
		gl_Position = proj * vec4(position, 0, 1);

		uv = texcoord;
	}
]]

--
ShaderParams.fs = [[
	varying highp vec2 uv;

	uniform sampler2D tex;

	void main ()
	{
		gl_FragColor = texture2D(tex, uv);
	}
]]

-- --
local SP = shader_helper.NewShader(ShaderParams)

function DrawBatch ()
	SP:DrawElements(gl.GL_TRIANGLE_STRIP, Indices, N * 6 - 2)

	N = 0
end

--- DOCME
-- @param name
-- @param x
-- @param y
-- @param w
-- @param h
-- @param u1
-- @param v1
-- @param u2
-- @param v2
function M.Draw (name, x, y, w, h, u1, v1, u2, v2)
	SP:Use()

	--
	if name ~= Name then
		if N > 0 then
			DrawBatch()
		end

		gl.glBindTexture(gl.GL_TEXTURE_2D, name)

		Name = name
	end

	--
	Pos[N * 4 + 0] = Float2(x, y)
	Pos[N * 4 + 1] = Float2(x + w, y)
	Pos[N * 4 + 2] = Float2(x, y + h)
	Pos[N * 4 + 3] = Float2(x + w, y + h)
	Tex[N * 4 + 0] = Float2(u1, v1)
	Tex[N * 4 + 1] = Float2(u2, v1)
	Tex[N * 4 + 2] = Float2(u1, v2)
	Tex[N * 4 + 3] = Float2(u2, v2)

	--
	N = N + 1

	if N == MaxN then
		DrawBatch()
	end
end

--- DOCME
-- @param surface
-- @return
-- @return
-- @return
-- @return
-- @return
function M.LoadTexture (surface)
	local screen = sdl.SDL_GetVideoSurface()

	--
	local image = sdl.SDL_ConvertSurface(surface, screen.format, sdl.SDL_SWSURFACE)

	if image == nil then
		return 0
	end

	--
	local ncolors, format = image.format.BytesPerPixel

	if ncolors == 4 then
		format = gl.GL_RGBA
	elseif ncolors == 3 then
		format = gl.GL_RGB
	else
		-- ERROR! (check this in XP...)
	end

	-- No BGR / BGRA on ES: convert to RGB / RGBA.
	if image.format.Rmask ~= 0x000000ff then
		sdl.SDL_LockSurface(image)

		local pixels = ffi.cast("uint8_t *", image.pixels)

		for i = 0, image.w * image.h * ncolors - 1, ncolors do
			pixels[i], pixels[i + 2] = pixels[i + 2], pixels[i]
		end

		sdl.SDL_UnlockSurface(image)
	end

	--
	local texture = ffi.new("GLuint[1]")
	
	gl.glGenTextures(1, texture)
	gl.glBindTexture(gl.GL_TEXTURE_2D, texture[0])
	gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_NEAREST)
	gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_NEAREST)
	gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, format, image.w, image.h, 0, format, gl.GL_UNSIGNED_BYTE, image.pixels)
	gl.glBindTexture(gl.GL_TEXTURE_2D, 0)

	sdl.SDL_FreeSurface(image)

	return texture[0], 0, 0, 1, 1
end

-- Export the module.
return M