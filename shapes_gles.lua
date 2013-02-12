--- Utility class for generating shapes.

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

-- Standard library imports --
local cos = math.cos
local sin = math.sin

-- Modules --
local ffi = require("ffi")

-- Exports --
local M = {}

--
local function Out (out, vertices, normals, tex_coords, indices, num_indices)
	out = out or {}

	out.vertices = vertices
	out.normals = normals
	out.tex_coords = tex_coords
	out.indices = indices
	out.num_indices = num_indices

	return out
end

--- DOCME
-- @param num_slices
-- @param radius
-- @param out
-- @return
function M.GenSphere (num_slices, radius, out)
	local num_parallels = num_slices / 2
	local num_vertices = (num_parallels + 1) * (num_slices + 1)

	local angle_step = 2 * math.pi / num_slices

	local vertices = ffi.new("float[?]", num_vertices * 3)
	local normals = ffi.new("float[?]", num_vertices * 3)
	local tex_coords = ffi.new("float[?]", num_vertices * 2)

	for i = 0, num_parallels do
		for j = 0, num_slices do
			local vertex = (i * (num_slices + 1) + j) * 3

			local cosi, sini = cos(angle_step * i), sin(angle_step * i)
			local cosj, sinj = cos(angle_step * j), sin(angle_step * j)

			vertices[vertex + 0] = radius * sini * sinj
			vertices[vertex + 1] = radius * cosi
			vertices[vertex + 2] = radius * sini * cosj

			for k = vertex, vertex + 2 do
				normals[k] = vertices[k] / radius
			end

			local tex_index = (i * (num_slices + 1) + j) * 2

			tex_coords[tex_index + 0] = j / num_slices
			tex_coords[tex_index + 1] = (1 - i) / (num_parallels - 1)
		end
	end

	local index, num_indices = 0, num_parallels * num_slices * 6

	local indices = ffi.new("unsigned short[?]", num_indices * 2)

	for i = 0, num_parallels - 1 do
		for j = 0, num_slices - 1 do
			indices[index + 0] = i * (num_slices + 1) + j
			indices[index + 1] = (i + 1) * (num_slices + 1) + j
			indices[index + 2] = (i + 1) * (num_slices + 1) + (j + 1)
			indices[index + 3] = i * (num_slices + 1) + j
			indices[index + 4] = (i + 1) * (num_slices + 1) + (j + 1)
			indices[index + 5] = i * (num_slices + 1) + (j + 1)

			index = index + 6
		end
	end

	return Out(out, vertices, normals, tex_coords, indices, num_indices)
end

--- DOCME
-- @param scale
-- @param out
-- @return
function M.GenCube (scale, out)
	local num_vertices = 24
	local num_indices = 36

	local vertices = ffi.new("float[?]", num_vertices * 3, {
		-0.5, -0.5, -0.5, -0.5, -0.5, 0.5, 0.5,
		-0.5, 0.5, 0.5, -0.5, -0.5, -0.5, 0.5, -0.5, -0.5,
		0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, -0.5, -0.5, -0.5,
		-0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5, -0.5,
		-0.5, -0.5, -0.5, 0.5, -0.5, 0.5, 0.5, 0.5, 0.5, 0.5,
		0.5, -0.5, 0.5, -0.5, -0.5, -0.5, -0.5, -0.5, 0.5,
		-0.5, 0.5, 0.5, -0.5, 0.5, -0.5, 0.5, -0.5, -0.5,
		0.5, -0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, -0.5
	})

	local normals = ffi.new("float[?]", num_vertices * 3, {
		0.0, -1.0, 0.0, 0.0, -1.0, 0.0, 0.0,
		-1.0, 0.0, 0.0, -1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0,
		0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0,
		0.0, 0.0, -1.0, 0.0, 0.0, -1.0, 0.0, 0.0, -1.0, 0.0,
		0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0,
		1.0, -1.0, 0.0, 0.0, -1.0, 0.0, 0.0, -1.0, 0.0, 0.0,
		-1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0,
		0.0, 0.0, 1.0, 0.0, 0.0
	})

	local tex_coords = ffi.new("float[?]", num_vertices * 2, {
		0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0,
		1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0,
		0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0,
		1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0,
		1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0
	})
	
	for i = 0, num_vertices * 3 - 1 do
		vertices[i] = vertices[i] * scale
	end

	local indices = ffi.new("unsigned short[?]", num_indices, {
		0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7, 8, 9, 10,
		8, 10, 11, 12, 15, 14, 12, 14, 13, 16, 17, 18, 16, 18, 19, 20,
        23, 22, 20, 22, 21
	})

	return Out(out, vertices, normals, tex_coords, indices, num_indices)
end

-- Export the module.
return M