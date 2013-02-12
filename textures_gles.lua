-- Modules --
local ffi = require("ffi")
local gl  = require("ffi/OpenGLES2")
local sdl = require("ffi/sdl")
local shader_helper = require("lib.shader_helper")
local xforms = require("transforms_gles")

-- Exports --
local M = {}

-- --
local Proj = xforms.New()

-- --
local SP = shader_helper.NewShader{
	vs = [[
		attribute mediump vec2 position;
		attribute mediump vec2 texcoord;
		uniform mediump mat4 proj;

		varying highp vec2 uv;
		
		void main ()
		{
			gl_Position = proj * vec4(position, 0, 1);

			uv = texcoord;
		}
	]],

	fs = [[
		varying highp vec2 uv;

		uniform sampler2D tex;

		void main ()
		{
			gl_FragColor = texture2D(tex, uv);
		}
	]],

	on_done = function()
		gl.glDisable(gl.GL_TEXTURE_2D)
	end,

	on_use = function()
		gl.glDisable(gl.GL_DEPTH_TEST)
		gl.glDisable(gl.GL_CULL_FACE)
		gl.glEnable(gl.GL_TEXTURE_2D)

		local screen = sdl.SDL_GetVideoSurface()

		gl.glViewport(0, 0, screen.w, screen.h)

		xforms.MatrixLoadIdentity(Proj)
		xforms.Ortho(Proj, 0, screen.w, screen.h, 0, 0, 1)

		gl.glActiveTexture(gl.GL_TEXTURE0)
	end
}

local loc_proj = SP:GetUniformByName("proj")
local loc_pos = SP:GetAttributeByName("position")
local loc_tex = SP:GetAttributeByName("texcoord")

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
local bbb
function M.Draw (name, x, y, w, h, u1, v1, u2, v2, aaa)
if aaa then
	if not bbb then
SP = shader_helper.NewShader{
	vs = [[
		attribute mediump vec2 position;
		attribute mediump vec2 texcoord;
		uniform mediump mat4 proj;

		varying highp vec2 uv;
		
		void main ()
		{
			gl_Position = proj * vec4(position, 0, 1);

			uv = texcoord;
		}
	]],

	fs = [[
		varying highp vec2 uv;

		uniform sampler2D tex;

		void main ()
		{
			gl_FragColor = texture2D(tex, uv);
		}
	]],

	on_done = function()
		gl.glDisable(gl.GL_TEXTURE_2D)
	end,

	on_use = function()
		gl.glDisable(gl.GL_DEPTH_TEST)
		gl.glDisable(gl.GL_CULL_FACE)
		gl.glEnable(gl.GL_TEXTURE_2D)

		local screen = sdl.SDL_GetVideoSurface()

		gl.glViewport(0, 0, screen.w, screen.h)

		xforms.MatrixLoadIdentity(Proj)
		xforms.Ortho(Proj, 0, screen.w, screen.h, 0, 0, 1)

		gl.glActiveTexture(gl.GL_TEXTURE0)
	end
}

loc_proj = SP:GetUniformByName("proj")
loc_pos = SP:GetAttributeByName("position")
loc_tex = SP:GetAttributeByName("texcoord")
		bbb = true
	end
end
	SP:Use()

	gl.glBindTexture(gl.GL_TEXTURE_2D, name)

	local tex = ffi.new("float[8]",
		u1, v1,
		u2, v1,
		u1, v2,
		u2, v2
	)

	local ver = ffi.new("float[8]",
		x, y,
		x + w, y,
		x, y + h,
		x + w, y + h
	)
-- TODO: batching...
	SP:BindUniformMatrix(loc_proj, Proj[0])
	SP:BindAttributeStream(loc_pos, ver, 2)
	SP:BindAttributeStream(loc_tex, tex, 2)

	SP:DrawArrays(gl.GL_TRIANGLE_STRIP, 4)
end

--
local function PowerOf2 (input)
	local value = 1

	while value < input do
		value = value + value
	end

	return value
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

	sdl.SDL_FreeSurface(image)

	return texture[0], 0, 0, 1, 1
end

-- Export the module.
return M