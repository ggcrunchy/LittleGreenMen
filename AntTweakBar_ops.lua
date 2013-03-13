--- Utilities for using AntTweakBar

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
local sdl = require("ffi/sdl")
local tw = require("ffi/AntTweakBar")

-- Imports --
local band = bit.band
local bnot = bit.bnot
local lshift = bit.lshift

-- Exports --
local M = {}

--- DOCME
function M.Draw (w, h)
	tw.TwWindowSize(w, h)
	tw.TwDraw()
end

--
--[[
tw.TwInit( tw.TW_OPENGL, nil ) -- ???
local bar      = tw.TwNewBar( "Blah" )
local var1data = ffi.new( "double[1]" )
local var1     = tw.TwAddVarRW( bar, "Var1", tw.TW_TYPE_DOUBLE, var1data, "min = 0, max = .99, step = .01")
local var2data = ffi.new( "int32_t[1]" )
local var2     = tw.TwAddVarRO( bar, "Var2", tw.TW_TYPE_INT32, var2data, nil)
]]

--- @brief      Helper: 
---             translate and re-send mouse and keyboard events 
---             from SDL 1.3 event loop to AntTweakBar
--- 
--- @author     Philippe Decaudin - http://www.antisphere.com
--- @license    This file is part of the AntTweakBar library.
---             For conditions of distribution and use, see License.txt
local s_KeyMod = 0
local s_WheelPos = 0

local Keys = {
	[sdl.SDLK_UP] = tw.TW_KEY_UP,
	[sdl.SDLK_DOWN] = tw.TW_KEY_DOWN,
	[sdl.SDLK_RIGHT] = tw.TW_KEY_RIGHT,
	[sdl.SDLK_LEFT] = tw.TW_KEY_LEFT,
	[sdl.SDLK_INSERT] = tw.TW_KEY_INSERT,
	[sdl.SDLK_HOME] = tw.TW_KEY_HOME,
	[sdl.SDLK_END] = tw.TW_KEY_END,
	[sdl.SDLK_PAGEUP] = tw.TW_KEY_PAGE_UP,
	[sdl.SDLK_PAGEDOWN] = TW_KEY_PAGE_DOWN
}

--- DOCME
function M.TwEvent (event)
	--  The way SDL handles keyboard events has changed between version 1.2
	--  and 1.3. It is now more difficult to translate SDL keyboard events to 
	--  AntTweakBar events. The following code is an attempt to do so, but
	--  it is rather complex and not always accurate (eg, CTRL+1 is not handled).
	--  If someone knows a better and more robust way to do the keyboard events
	--  translation, please let me know.
	local handled = 0
	local etype = event.type

	-- Text input --
	if etype == sdl.SDL_TEXTINPUT then
		if event.text.text[0] ~= 0 and event.text.text[1] == 0 then
			if band(s_KeyMod, tw.TW_KMOD_CTRL) ~= 0 and event.text.text[0] < 32 then
				handled = tw.TwKeyPressed(event.text.text[0] + ("a"):byte() - 1, s_KeyMod)
			else
				if band(s_KeyMod, sdl.KMOD_RALT) ~= 0 then
					s_KeyMod = band(s_KeyMod, bnot(sdl.KMOD_CTRL))
				end

				handled = tw.TwKeyPressed(event.text.text[0], s_KeyMod)
			end
		end

		s_KeyMod = 0

	-- Key down --
	elseif etype == sdl.SDL_KEYDOWN then
		local sym = event.key.keysym.sym

		if band(sym, lshift(1, 30)) ~= 0 then -- 1 << 30 == SDLK_SCANCODE_MASK
			local key = Keys[sym]

			if not key and sym >= sdl.SDLK_F1 and sym <= sdl.SDLK_F12 then
				key = sym + tw.TW_KEY_F1 - sdl.SDLK_F1
			end

			if key then
				handled = tw.TwKeyPressed(key, event.key.keysym.mod)
			end

		elseif band(event.key.keysym.mod, tw.TW_KMOD_ALT) ~= 0 then
			handled = tw.TwKeyPressed(band(sym, 0xFF), event.key.keysym.mod);

		else
			s_KeyMod = event.key.keysym.mod
		end

	-- Key up --
	elseif etype == sdl.SDL_KEYUP then
		s_KeyMod = 0

	-- Mouse motion --
	elseif etype == sdl.SDL_MOUSEMOTION then
		handled = tw.TwMouseMotion(event.motion.x, event.motion.y)

	-- Mouse button --
	elseif etype == sdl.SDL_MOUSEBUTTONUP or etype == sdl.SDL_MOUSEBUTTONDOWN then
		if etype == sdl.SDL_MOUSEBUTTONDOWN and (event.button.button == 4 or event.button.button == 5) then  -- mouse wheel
			if event.button.button == 4 then
				s_WheelPos = s_WheelPos + 1
			else
				s_WheelPos = s_WheelPos - 1
			end

			handled = tw.TwMouseWheel(s_WheelPos)

		else
			handled = tw.TwMouseButton(etype == sdl.SDL_MOUSEBUTTONUP and tw.TW_MOUSE_RELEASED or tw.TW_MOUSE_PRESSED, event.button.button)
		end

	-- Video resize --
	elseif etype == sdl.SDL_VIDEORESIZE then
		tw.TwWindowSize(event.resize.w, event.resize.h);
	end

	return handled ~= 0
end

-- Export the module.
return M