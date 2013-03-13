--- Utilities for off-screen textures.

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

-- TODO: Not all that useful :P
local dr, fr, tt, good

	if good then
		textures.Draw(tt[0], y, x, iw, ih, minx, miny, maxx, maxy)
	end

-- TODO: Clean this up
if not dr then
	local max = ffi.new("GLint[1]")

	gl.glGetIntegerv(gl.GL_MAX_RENDERBUFFER_SIZE, max)

	dr, fr, tt = ffi.new("GLint[1]"), ffi.new("GLint[1]"), ffi.new("GLint[1]")

	-- check if GL_MAX_RENDERBUFFER_SIZE is >= texWidth and texHeight
	if max[0] >= ww and max[0] >= wh then
		-- cannot use framebuffer objects as we need to create
		-- a depth buffer as a renderbuffer object
		-- return with appropriate error
		-- ^ on failure

		-- generate the framebuffer, renderbuffer, and texture object names
		gl.glGenFramebuffers(1, fr)
		gl.glGenRenderbuffers(1, dr)
		gl.glGenTextures(1, tt)

		-- bind texture and load the texture mip-level 0
		-- texels are RGB565
		-- no texels need to be specified as we are going to draw into
		-- the texture
		gl.glBindTexture(gl.GL_TEXTURE_2D, tt[0])
		gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_RGB, ww, wh, 0, gl.GL_RGB, gl.GL_UNSIGNED_SHORT_5_6_5, nil)

		gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE)
		gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE)
		gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR)
		gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR)

		-- bind renderbuffer and create a 16-bit depth buffer
		-- width and height of renderbuffer = width and height of
		-- the texture
		gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, dr[0])
		gl.glRenderbufferStorage(gl.GL_RENDERBUFFER, gl.GL_DEPTH_COMPONENT16, ww, wh)

		-- bind the framebuffer
		gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, fr[0])

		-- specify texture as color attachment
		gl.glFramebufferTexture2D(gl.GL_FRAMEBUFFER, gl.GL_COLOR_ATTACHMENT0, gl.GL_TEXTURE_2D, tt[0], 0)

		-- specify depth_renderbufer as depth attachment
		gl.glFramebufferRenderbuffer(gl.GL_FRAMEBUFFER, gl.GL_DEPTH_ATTACHMENT, gl.GL_RENDERBUFFER, dr[0])

		-- check for framebuffer complete
		local status = gl.glCheckFramebufferStatus(gl.GL_FRAMEBUFFER)

		if status == gl.GL_FRAMEBUFFER_COMPLETE then
		   -- render to texture using FBO
		   -- clear color and depth buffer
		   gl.glClearColor(0, 0, 0, 1)
		   gl.glClear(bit.bor(gl.GL_COLOR_BUFFER_BIT, gl.GL_DEPTH_BUFFER_BIT))

		   good = true
		end

		-- render to window system provided framebuffer
		gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0)
	end
end

-- TODO: Add "capture screen" / "capture window" / etc. utilities
-- Caching?