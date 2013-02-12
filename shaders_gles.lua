--- Utility functions for loading shaders and creating program objects.

--[[
Source:

//
// Book:      OpenGL(R) ES 2.0 Programming Guide
// Authors:   Aaftab Munshi, Dan Ginsburg, Dave Shreiner
// ISBN-10:   0321502795
// ISBN-13:   9780321502797
// Publisher: Addison-Wesley Professional
// URLs:      http://safari.informit.com/9780321563835
//            http://www.opengles-book.com
//
]]

-- Modules --
local ffi = require("ffi")
local gl = require("ffi/OpenGLES2")

-- Exports --
local M = {}

--- Load a shader, checking for compile errors
-- @param type Type of shader (GL_VERTEX_SHADER or GL_FRAGMENT_SHADER)
-- @param source Shader source string
-- @return A new shader object on success, 0 on failure
-- @treturn string On failure, an error string
function M.LoadShader (type, source)
	-- Create the shader object
	local shader = gl.glCreateShader(type)

	if shader == 0 then
		return 0, "Could not create shader"
	end

	-- Load the shader source
	local src = ffi.new("char[?]", #source, source)
	local srcs = ffi.new("const char*[1]", src)
   
	gl.glShaderSource(shader, 1, srcs, nil)

	-- Compile the shader
	gl.glCompileShader(shader)

	-- Check the compile status
	local int = ffi.new("GLint[1]")

	gl.glGetShaderiv(shader, gl.GL_COMPILE_STATUS, int)

	local compiled = int[0]
	
	if compiled == 0 then
		gl.glGetShaderiv(shader, gl.GL_INFO_LOG_LENGTH, int)

		local length = int[0]
		local buffer = ffi.new("char[?]", length)

		gl.glGetShaderInfoLog(shader, length, int, buffer)
		gl.glDeleteShader(shader)

		return 0, ffi.string(buffer)
	end

	return shader
end

--- Load a vertex and fragment shader, create a program object, link program.
-- @param vert_src Vertex shader source code
-- @param frag_src Fragment shader source code
-- @return A new program object linked with the vertex/fragment shader pair, 0 on failure
-- @treturn string On failure, an error string
function M.LoadProgram (vert_src, frag_src)
	-- Load the vertex/fragment shaders
	local vert_shader, vs_err = M.LoadShader(gl.GL_VERTEX_SHADER, vert_src)

	if vert_shader == 0 then
		return 0, vs_err
	end

	local frag_shader, fs_err = M.LoadShader(gl.GL_FRAGMENT_SHADER, frag_src)

	if frag_shader == 0 then
		gl.glDeleteShader(vert_shader)

		return 0, fs_err
	end

	-- Create the program object
	local program_object = gl.glCreateProgram()

	if program_object == 0 then
		-- Should delete shaders, no? Error in original?

		return 0, "Could not create program"
	end

	gl.glAttachShader(program_object, vert_shader)
	gl.glAttachShader(program_object, frag_shader)

	-- Link the program
	gl.glLinkProgram(program_object)

	-- Check the link status
	local linked = ffi.new("int[1]")

	gl.glGetProgramiv(program_object, gl.GL_LINK_STATUS, linked)

	if linked[0] == 0 then
		local plog = gl.glGetProgramInfoLog(program_object)

		-- Shaders?

		gl.glDeleteProgram(program_object)

		return 0, "Error linking program: " .. plog
	end

	-- Free up no longer needed shader resources
	gl.glDeleteShader(vert_shader)
	gl.glDeleteShader(frag_shader)

	return program_object
end

-- Export the module.
return M