local ffi = require("ffi")
local bit = require("bit")
local egl = require( "ffi/EGL" )
local gl  = require( "ffi/OpenGLES2" )
local sdl = require( "ffi/sdl" )
local window = require("window")
   
local ww, wh = 512, 512

-- --
local function NoOp () end

local Funcs = setmetatable({}, {
	__index = function() return NoOp end
})

-- --
local IsDrawing

-- Use SDL for windowing and events
local function InitSDL()
	window.SetMode_SDL(ww, wh)

	IsDrawing = true

	local event = ffi.new( "SDL_Event" )
	local prev_time, curr_time, fps = 0, 0, 0

	return {
		update = function() 
			-- Calculate the frame rate
			prev_time, curr_time = curr_time, os.clock()

			local diff = curr_time - prev_time + 0.00001
			local real_fps = 1/diff

			if math.abs( fps - real_fps ) * 10 > real_fps then
				fps = real_fps
			end

			fps = fps*0.99 + 0.01*real_fps

			-- Update the window caption with statistics
			--		  sdl.SDL_WM_SetCaption( string.format("%d %s %dx%d | %.2f fps | %.2f mps", ticks_base, tostring(bounce_mode), screen.w, screen.h, fps, fps * (screen.w * screen.h) / (1024*1024)), nil )
			Funcs.pre_update(curr_time - prev_time)

			while sdl.SDL_PollEvent( event ) ~= 0 do
				if event.type == sdl.SDL_QUIT then
					return false
				end

				if event.type == sdl.SDL_KEYUP and event.key.keysym.sym == sdl.SDLK_ESCAPE then
					event.type = sdl.SDL_QUIT

					sdl.SDL_PushEvent(event)
				elseif event.type == sdl.SDL_KEYUP or event.type == sdl.SDL_KEYDOWN then
					Funcs.key(event.key, event.type == sdl.SDL_KEYDOWN)
				elseif event.type == sdl.SDL_MOUSEBUTTONDOWN or event.type == sdl.SDL_MOUSEBUTTONUP then
					Funcs.mouse_button(event.button, event.type == sdl.SDL_MOUSEBUTTONDOWN)
				elseif event.type == sdl.SDL_MOUSEWHEEL then
					Funcs.mouse_wheel(event.wheel)
				elseif event.type == sdl.SDL_MOUSEMOTION then
					Funcs.mouse_motion(event.motion)
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

local function validate_shader( shader )
   local int = ffi.new( "GLint[1]" )
   gl.glGetShaderiv( shader, gl.GL_INFO_LOG_LENGTH, int )
   local length = int[0]
   if length <= 0 then
      return
   end
   gl.glGetShaderiv( shader, gl.GL_COMPILE_STATUS, int )
   local success = int[0]
   if success == gl.GL_TRUE then
      return
   end
   local buffer = ffi.new( "char[?]", length )
   gl.glGetShaderInfoLog( shader, length, int, buffer )
--   assert( int[0] == length )
   error( ffi.string(buffer) )
end
 
local function load_shader( src, type )
   local shader = gl.glCreateShader( type )
   if shader == 0 then
      error( "glGetError: " .. tonumber( gl.glGetError()) )
   end
   local src = ffi.new( "char[?]", #src, src )
   local srcs = ffi.new( "const char*[1]", src )
   gl.glShaderSource( shader, 1, srcs, nil )
   gl.glCompileShader ( shader )
   validate_shader( shader )
   return shader
end

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
	end

	WasDrawing = IsDrawing
end

wm:exit()