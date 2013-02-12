-- Standard library imports --
local tonumber = tonumber

-- Modules --
local ffi = require("ffi")
local bit = require("bit")
local egl = require("ffi/EGL")
local sdl = require("ffi/sdl")

-- Exports --
local M = {}

-- --
local ConfigAttr = ffi.new("EGLint[3]", egl.EGL_RENDERABLE_TYPE, egl.EGL_OPENGL_ES2_BIT, egl.EGL_NONE)
local ContextAttr = ffi.new("EGLint[3]", egl.EGL_CONTEXT_CLIENT_VERSION, 2, egl.EGL_NONE)

-- --
local Config = ffi.new("EGLConfig[1]")
local NumConfig = ffi.new("EGLint[1]")

-- --
local Context

-- --
local Display = 0

-- --
local Surface

-- --
local Window

-- --
local NoSurface = ffi.cast("EGLSurface", egl.EGL_NO_SURFACE)
local NoContext = ffi.cast("EGLContext", egl.EGL_NO_CONTEXT)

--- DOCME
function M.Close ()
	if Context then
		egl.eglDestroyContext(Display, Context)
	end

	if Surface then
		egl.eglDestroySurface(Display, Surface)
	end

	egl.eglMakeCurrent(Display, NoSurface, NoSurface, NoContext)
	egl.eglTerminate(Display)

	Display, Context, Surface, Window = 0
end

--- DOCME
function M.Reload ()
    Surface = egl.eglCreateWindowSurface(Display, Config[0], Window, nil)

	egl.eglMakeCurrent(Display, Surface, Surface, Context)
end

--- DOCME
-- @uint ww
-- @uint wh
function M.SetMode_SDL (ww, wh)
	local screen = sdl.SDL_SetVideoMode(ww, wh, 32, 0 * sdl.SDL_RESIZABLE)
	local wminfo = ffi.new("SDL_SysWMinfo")

	sdl.SDL_GetVersion(wminfo.version)
	sdl.SDL_GetWMInfo(wminfo)

	local systems = { "win", "x11", "dfb", "cocoa", "uikit" }
	local subsystem = tonumber(wminfo.subsystem)

	wminfo = wminfo.info[systems[subsystem]]

	Window = wminfo.window

	if systems[subsystem] == "x11" then
		Display = wminfo.display

		print('X11', Display, Window)
	else
		Display = egl.EGL_DEFAULT_DISPLAY
	end

	Display = egl.eglGetDisplay(ffi.cast("intptr_t", Display))

	local r = egl.eglInitialize(Display, nil, nil)

--	print('wm.display/dpy/r', wm.display, dpy, r)

	local r0 = egl.eglChooseConfig(Display, ConfigAttr, Config, 1, NumConfig)

	local c = Config[0]

	for i=0,10 do
	--    if c[i]==egl.EGL_FALSE then break end
	--    print(i,c[i])
	end

	Context = egl.eglCreateContext(Display, Config[0], nil, ContextAttr)

	M.Reload()
end

---
-- @bool prev
function M.SwapBuffers (prev)
	local result = prev and egl.eglSwapBuffers(Display, Surface)

	if result ~= egl.EGL_TRUE then
        local err = egl.eglGetError()

        --[[
			EXPLANATION:
			http://library.forum.nokia.com/index.jsp?topic=/Nokia_Symbian3_Developers_Library/GUID-894AB487-C127-532D-852B-37CB0DEA1440.html
			On the Symbian platform, EGL handles the window resize in the next
			call to eglSwapBuffers(), which resizes the surface to match the new
			window size. If the preserve buffer option is in use, this function
			also copies across all the pixels from the old surface that overlap
			the new surface, although the exact details depend on the
			implementation.If the surface resize fails, eglSwapBuffers() returns
			EGL_FALSE and an EGL_BAD_ALLOC error is raised. This may mean that
			the implementation does not support the resizing of a surface or that
			there is not enough memory available (on a platform with GPU, this
			would be GPU rather than system memory). Applications must always
			monitor whether eglSwapBuffers() fails after a window resize.
			When it does fail, the application should do the following:
			Call eglDestroySurface() to destroy the current EGL window surface.
			Call eglCreateWindowSurface() to recreate the EGL window surface.
			This may cause a noticeable flicker and so should be done only when
			necessary.
        ]]
        --qDebug() << "eglSwapbuffers failed with error: " << errval;
		
        if err == egl.EGL_BAD_ALLOC or err == egl.EGL_BAD_SURFACE then
        --    if (errval==EGL_BAD_ALLOC)
         --       //qDebug() << "Error was bad alloc, .. taking care of it.";
            egl.eglDestroySurface(Display, Surface)

			M.Reload()
        else
			-- FATAL...
		end
	end
end

-- Export the module.
return M