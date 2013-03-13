--- MOOP

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
local clock = os.clock

-- Modules --
local ffi = require("ffi")
local egl = require("ffi/EGL")
local gl = require("ffi/OpenGLES2")
local sdl = require("ffi/sdl")
local window = require("window")
   
local ww, wh = 512, 512

-- --
local function NoOp () end

local Funcs = setmetatable({}, {
	__index = function() return NoOp end
})
--[[
local tw = require("ffi/AntTweakBar")
tw.TwInit( tw.TW_OPENGL, nil ) -- ???
local bar      = tw.TwNewBar( "Blah" )
local var1data = ffi.new( "double[1]" )
local var1     = tw.TwAddVarRW( bar, "Var1", tw.TW_TYPE_DOUBLE, var1data, "min = 0, max = .99, step = .01")
local var2data = ffi.new( "int32_t[1]" )
local var2     = tw.TwAddVarRO( bar, "Var2", tw.TW_TYPE_INT32, var2data, nil)

local atw = require("AntTweakBar_ops")
]]
-- --
local IsDrawing

-- Use SDL for windowing and events
local function InitSDL()
	window.SetMode_SDL(ww, wh)

--	sdl.SDL_WM_GrabInput(sdl.SDL_GRAB_ON)

	IsDrawing = true

	local event = ffi.new("SDL_Event")
	local prev_time, curr_time = 0, 0

	return {
		update = function() 
			prev_time, curr_time = curr_time, clock()

			Funcs.pre_update(curr_time - prev_time)

			while sdl.SDL_PollEvent(event) ~= 0 do
				if event.type == sdl.SDL_QUIT then
					return false
				end
--local h = atw.TwEvent(event)
				-- --
				if event.type == sdl.SDL_KEYUP and event.key.keysym.sym == sdl.SDLK_ESCAPE then
					event.type = sdl.SDL_QUIT

					sdl.SDL_PushEvent(event)
--elseif h then
	--
				-- --
				elseif event.type == sdl.SDL_KEYUP or event.type == sdl.SDL_KEYDOWN then
					Funcs.key(event.key, event.type == sdl.SDL_KEYDOWN)

				-- --
				elseif event.type == sdl.SDL_MOUSEBUTTONDOWN or event.type == sdl.SDL_MOUSEBUTTONUP then
					Funcs.mouse_button(event.button, event.type == sdl.SDL_MOUSEBUTTONDOWN)

				-- --
				elseif event.type == sdl.SDL_MOUSEWHEEL then
					Funcs.mouse_wheel(event.wheel)

				-- --
				elseif event.type == sdl.SDL_MOUSEMOTION then
					Funcs.mouse_motion(event.motion)

				-- --
				elseif event.type == sdl.SDL_WINDOWEVENT then
					if event.window.event == sdl.SDL_WINDOWEVENT_MINIMIZED then
						IsDrawing = false
					elseif event.window.event == sdl.SDL_WINDOWEVENT_RESTORED then
						IsDrawing = true
					end
				end
			end

			return true
		end,

		exit = function()
			window.Close()
			sdl.SDL_Quit() 
		end
	}
end

local wm = InitSDL()

require("driver").Start(Funcs, ww, wh)

gl.glEnable(gl.GL_DEPTH_TEST)
gl.glDepthFunc(gl.GL_LESS)

--
local WasDrawing = IsDrawing

while wm:update() do
	gl.glClear(bit.bor(gl.GL_COLOR_BUFFER_BIT, gl.GL_DEPTH_BUFFER_BIT))

	Funcs.update()

	if IsDrawing then
		window.SwapBuffers(WasDrawing)
--atw.Draw(ww, wh)
	end

	WasDrawing = IsDrawing
end

wm:exit()