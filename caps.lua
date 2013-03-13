--- Functionality related to device capabilities.

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
local gl = require("ffi/OpenGLES2")

-- Exports --
local M = {}

-- --
local FloatVar, IntVar

-- --
local Values

--- DOCME
function M.Init ()
	FloatVar = ffi.new("GLfloat[1]") -- TODO: Grow if there are tuple caps
	IntVar = ffi.new("GLint[1]") -- TODO: Ditto (e.g. viewport...)
	Values = {}
end

--
-- TODO: account for tuples?
local function GetInt (enum)
	local iv = Values[enum]

	if iv then
		IntVar[0] = iv
	else
		gl.glGetIntegerv(enum, IntVar)

		Values[enum] = IntVar[0]
	end
end

-- TODO: Various minima, maxima
-- EGL stuff? SDL stuff?
-- Texture formats...
-- 2.x, 3.x? (might require using 3+... also ANGLE has to catch up?)
-- Instancing?

--- DOCME
function M.SupportsVertexTextures ()
	GetInt(gl.GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS)

	return IntVar[0] > 0, IntVar[0]
end

-- Export the module.
return M