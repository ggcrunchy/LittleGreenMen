--- Utility class for generating transforms.

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
local deg = math.deg
local rad = math.rad
local sin = math.sin
local sqrt = math.sqrt
local tan = math.tan

-- Modules --
local ffi = require("ffi")
local v3math = require("lib.v3math")

-- Exports --
local M = {}

--- DOCME
-- @function New
M.New = ffi.typeof("float[4][4]")

--- DOCME
-- @param matrix
-- @param sx
-- @param sy
-- @param sz
function M.Scale (matrix, sx, sy, sz)
	for i = 0, 2 do
		matrix[0][i] = matrix[0][i] * sx
		matrix[1][i] = matrix[1][i] * sy
		matrix[2][i] = matrix[2][i] * sz
	end
end

--- DOCME
-- @param matrix
-- @param tx
-- @param ty
-- @param tz
function M.Translate (matrix, tx, ty, tz)
	for i = 0, 3 do
		matrix[3][i] = matrix[3][i] + matrix[0][i] * tx + matrix[1][i] * ty + matrix[2][i] * tz
	end
end

--- DOCME
-- @param matrix
-- @param angle
-- @param x
-- @param y
-- @param z
function M.Rotate (matrix, angle, x, y, z)
	angle = deg(angle)

	local mag = sqrt(x * x + y * y + z * z)

	if mag > 0.0 then
		x = x / mag
		y = y / mag
		z = z / mag

		local xx = x * x
		local yy = y * y
		local zz = z * z
		local xy = x * y
		local yz = y * z
		local zx = z * x

		local sina = sin(angle)
		
		local xs = x * sina
		local ys = y * sina
		local zs = z * sina
		
		local cosa = cos(angle)
		local one_minus_cos = 1 - cosa

		local rot_mat = M.New()
		
		rot_mat[0][0] = (one_minus_cos * xx) + cosa
		rot_mat[0][1] = (one_minus_cos * xy) - zs
		rot_mat[0][2] = (one_minus_cos * zx) + ys

		rot_mat[1][0] = (one_minus_cos * xy) + zs
		rot_mat[1][1] = (one_minus_cos * yy) + cosa
		rot_mat[1][2] = (one_minus_cos * yz) - xs

		rot_mat[2][0] = (one_minus_cos * zx) - ys
		rot_mat[2][1] = (one_minus_cos * yz) + xs
		rot_mat[2][2] = (one_minus_cos * zz) + cosa

		rot_mat[3][3] = 1.0

		M.MatrixMultiply(matrix, rot_mat, matrix)
	end
end

--- DOCME
-- @param matrix
-- @param left
-- @param right
-- @param bottom
-- @param top
-- @param nearz
-- @param farz
function M.Frustum (matrix, left, right, bottom, top, nearz, farz)
	local dx = right - left
	local dy = top - bottom
	local dz = farz - nearz

	if dx <= 0 or dy <= 0 or dz <= 0 or nearz <= 0 or farz <= 0 then
		return
	end
	
	local frust = M.New()

	frust[0][0] = 2.0 * nearz / dx
	frust[1][1] = 2.0 * nearz / dy
	frust[2][0] = (right + left) / dx
	frust[2][1] = (top + bottom) / dy
	frust[2][2] = -(nearz + farz) / dz
	frust[2][3] = -1.0
	frust[3][2] = -2.0 * nearz * farz / dz

	M.MatrixMultiply(matrix, frust, matrix)
end

--- DOCME
-- @param matrix
-- @param fovy
-- @param aspect
-- @param nearz
-- @param farz
function M.Perspective (matrix, fovy, aspect, nearz, farz)
	local fh = tan(rad(fovy) / 2) * nearz
	local fw = fh * aspect

	M.Frustum(matrix, -fw, fw, -fh, fh, nearz, farz)
end

--- DOCME
-- @param matrix
-- @param left
-- @param right
-- @param bottom
-- @param top
-- @param nearz
-- @param farz
function M.Ortho (matrix, left, right, bottom, top, nearz, farz)
	local dx = right - left
	local dy = top - bottom
	local dz = farz - nearz

	if dx == 0 or dy == 0 or dz == 0 then
		return
	end
	
	local ortho_mat = M.New()

	ortho_mat[0][0] = 2.0 / dx
	ortho_mat[1][1] = 2.0 / dy
	ortho_mat[2][2] = -2.0 / dz
	ortho_mat[3][0] = -(right + left) / dx
	ortho_mat[3][1] = -(top + bottom) / dy
	ortho_mat[3][2] = -(nearz + farz) / dz
	ortho_mat[3][3] = 1

	M.MatrixMultiply(matrix, ortho_mat, matrix)
end

--- DOCME
-- @param matrix
-- @param src_a
-- @param src_b
function M.MatrixMultiply (matrix, src_a, src_b)
	local temp = M.New()

	for i = 0, 3 do
		temp[i][0] = src_a[i][0] * src_b[0][0] + src_a[i][1] * src_b[1][0] + src_a[i][2] * src_b[2][0] + src_a[i][3] * src_b[3][0]
		temp[i][1] = src_a[i][0] * src_b[0][1] + src_a[i][1] * src_b[1][1] + src_a[i][2] * src_b[2][1] + src_a[i][3] * src_b[3][1]
		temp[i][2] = src_a[i][0] * src_b[0][2] + src_a[i][1] * src_b[1][2] + src_a[i][2] * src_b[2][2] + src_a[i][3] * src_b[3][2]
		temp[i][3] = src_a[i][0] * src_b[0][3] + src_a[i][1] * src_b[1][3] + src_a[i][2] * src_b[2][3] + src_a[i][3] * src_b[3][3]
    end

	ffi.copy(matrix, temp, ffi.sizeof(matrix))
end

--- DOCME
-- @param matrix
function M.MatrixLoadIdentity (matrix)
	ffi.fill(matrix, ffi.sizeof(matrix))

	matrix[0][0] = 1.0
	matrix[1][1] = 1.0
	matrix[2][2] = 1.0
	matrix[3][3] = 1.0
end

--- DOCME
-- @param matrix
-- @param eyex
-- @param eyey
-- @param eyez
-- @param centerx
-- @param centery
-- @param centerz
-- @param upx
-- @param upy
-- @param upz
function M.LookAt (matrix, eyex, eyey, eyez, centerx, centery, centerz, upx, upy, upz)
	local f = v3math.normself(v3math.new(centerx - eyex, centery - eyey, centerz - eyez))
	local up = v3math.new(upx, upy, upz)

	local s = v3math.crossnew(f, v3math.new(upx, upy, upz))
	local u = v3math.crossnew(s, f)

	v3math.normself(s)
	v3math.normself(u)

	local lookat_mat = M.New()

	M.MatrixLoadIdentity(lookat_mat)

	for i = 0, 2 do
		lookat_mat[i][0] = s[i]
		lookat_mat[i][1] = u[i]
		lookat_mat[i][2] = -f[i]
	end

	M.Translate(lookat_mat, -eyex, -eyey, -eyez)
    M.MatrixMultiply(matrix, lookat_mat, matrix)
end

-- Export the module.
return M