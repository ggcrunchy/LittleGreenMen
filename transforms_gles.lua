--- Utility class for generating transforms.

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
local abs = math.abs
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

--- DOCME
function M.MultVec3 (matrix, out, x, y, z, w)
	out[0] = matrix[0][0] * x + matrix[1][0] * y + matrix[2][0] * z + matrix[3][0] * w
	out[1] = matrix[0][1] * x + matrix[1][1] * y + matrix[2][1] * z + matrix[3][1] * w
	out[2] = matrix[0][2] * x + matrix[1][2] * y + matrix[2][2] * z + matrix[3][2] * w
end

--- DOCME
function M.MultVec3_W1 (matrix, out, x, y, z)
	out[0] = matrix[0][0] * x + matrix[1][0] * y + matrix[2][0] * z + matrix[3][0]
	out[1] = matrix[0][1] * x + matrix[1][1] * y + matrix[2][1] * z + matrix[3][1]
	out[2] = matrix[0][2] * x + matrix[1][2] * y + matrix[2][2] * z + matrix[3][2]
end

--- DOCME
function M.MultVec4 (matrix, out, x, y, z, w)
	M.MultVec3(matrix, out, x, y, z, w)

	out[3] = matrix[0][3] * x + matrix[1][3] * y + matrix[2][3] * z + matrix[3][3] * w
end

--- DOCME
function M.MultVec4_W1 (matrix, out, x, y, z)
	M.MultVec3_W1(matrix, out, x, y, z)

	out[3] = matrix[0][3] * x + matrix[1][3] * y + matrix[2][3] * z + matrix[3][3]
end

--[[
http://www.opengl.org/wiki/GluProject_and_gluUnProject_code
]]

--
local function AuxProject (ftemp, viewport, wc, w)
	w = 1 / w

	-- Window coordinates
	-- Map x, y to range 0-1
	wc[0] = (.5 * ftemp[0] * w + .5) * viewport[2] + viewport[0]
	wc[1] = (.5 * ftemp[1] * w + .5) * viewport[3] + viewport[1]

	-- This is only correct when glDepthRange(0.0, 1.0)
	wc[2] = (1 + ftemp[2] * w) * .5  -- Between 0 and 1

	return true
end

--- DOCME
function M.Project (objx, objy, objz, mv, proj, viewport, wc)
	local ftemp = ffi.new("double[4]")

	M.MultVec4_W1(mv, ftemp, objx, objy, objz)

	local w = -ftemp[2]

	if w == 0 then
		return false
	end

	M.MultVec3(proj, ftemp, ftemp[0], ftemp[1], ftemp[2], ftemp[3])

	return AuxProject(ftemp, viewport, wc, w)
end

--- DOCME
function M.Project_MVP (objx, objy, objz, mvp, viewport, wc)
	local ftemp = ffi.new("double[4]")

	M.MultVec4_W1(mvp, ftemp, objx, objy, objz)

	return ftemp[3] ~= 0 and AuxProject(ftemp, viewport, wc, ftemp[3])
end

--- DOCME
function M.Unproject (winx, winy, winz, mv, proj, viewport, oc)
	local mvp = M.New()

	M.MatrixMultiply(mvp, mv, proj)

	return M.Unproject_MVP(winx, winy, winz, mvp, viewport, oc)
end

--- DOCME
function M.Unproject_MVP (winx, winy, winz, mvp, viewport, oc)
	local inv = M.New()

	return M.Invert(mvp, inv) and M.Unproject_InverseMVP(winx, winy, winz, inv, viewport, oc)
end

--- DOCME
function M.Unproject_InverseMVP (winx, winy, winz, mvpi, viewport, oc)
	local inx = (winx - viewport[0]) / viewport[2] * 2 - 1
	local iny = (winy - viewport[1]) / viewport[3] * 2 - 1
	local inz = 2 * winz - 1

	local out = ffi.new("double[4]")

	M.MultVec4_W1(mvpi, out, inx, iny, inz)

	if out[3] == 0 then
		return false
	end

	local s = 1 / out[3]

	oc[0] = out[0] * s
	oc[1] = out[1] * s
	oc[2] = out[2] * s

	return true
end

-- Matrix inversion --
do
	--
	local function ScaleDiff (r, r2, s, m)
		for i = 4, 7 do
			r[i] = s * (r[i] - r2[i] * m)
		end
	end

	--
	local function SubScaled (r, r2, s, i0)
		for i = i0, 7 do
			r[i] = r[i] - r2[i] * s
		end
	end

	--- DOCME
	function M.Invert (matrix, out)
		local wtemp = ffi.new("double[4][8]")
		local r0, r1, r2, r3 = wtemp[0], wtemp[1], wtemp[2], wtemp[3]

		r0[0], r0[1], r0[2], r0[3], r0[4] = matrix[0][0], matrix[0][1], matrix[0][2], matrix[0][3], 1
		r1[0], r1[1], r1[2], r1[3], r1[5] = matrix[1][0], matrix[1][1], matrix[1][2], matrix[1][3], 1
		r2[0], r2[1], r2[2], r2[3], r2[6] = matrix[2][0], matrix[2][1], matrix[2][2], matrix[2][3], 1
		r3[0], r3[1], r3[2], r3[3], r3[7] = matrix[3][0], matrix[3][1], matrix[3][2], matrix[3][3], 1

		-- choose pivot - or die
		if abs(r3[0]) > abs(r2[0]) then
			r3, r2 = r2, r3
		end

		if abs(r2[0]) > abs(r1[0]) then
			r2, r1 = r1, r2
		end

		if abs(r1[0]) > abs(r0[0]) then
			r1, r0 = r0, r1
		end

		if r0[0] == 0 then
			return false
		end

		-- eliminate first variable
		local m1 = r1[0] / r0[0]
		local m2 = r2[0] / r0[0]
		local m3 = r3[0] / r0[0]

		for i = 1, 3 do
			local s = r0[i]

			r1[i] = r1[i] - m1 * s
			r2[i] = r2[i] - m2 * s
			r3[i] = r3[i] - m3 * s
		end

		for i = 4, 7 do
			local s = r0[i]

			if s ~= 0 then
			  r1[i] = r1[i] - m1 * s
			  r2[i] = r2[i] - m2 * s
			  r3[i] = r3[i] - m3 * s
			end
		end

		-- choose pivot - or die
		if abs(r3[1]) > abs(r2[1]) then
			r3, r2 = r2, r3
		end

		if abs(r2[1]) > abs(r1[1]) then
			r2, r1 = r1, r2
		end

		if r1[1] == 0 then
			return false
		end

		-- eliminate second variable
		m2 = r2[1] / r1[1]
		m3 = r3[1] / r1[1]

		r2[2] = r2[2] - m2 * r1[2]
		r3[2] = r3[2] - m3 * r1[2]
		r2[3] = r2[3] - m2 * r1[3]
		r3[3] = r3[3] - m3 * r1[3]

		for i = 4, 7 do
			local s = r1[i]

			if s ~= 0 then
				r2[i] = r2[i] - m2 * s
				r3[i] = r3[i] - m3 * s
			end
		end

		-- choose pivot - or die
		if abs(r3[2]) > abs(r2[2]) then
			r3, r2 = r2, r3
		end

		if r2[2] == 0 then
			return false
		end

		-- eliminate third variable
		SubScaled(r3, r2, r3[2] / r2[2], 3)

		-- last check
		if r3[3] == 0 then
			return false
		end

		-- now back substitute row 3
		local s = 1 / r3[3]

		for i = 4, 7 do
			r3[i] = r3[i] * s
		end

		-- now back substitute row 2
		ScaleDiff(r2, r3, 1 / r2[2], r2[3])
		SubScaled(r1, r3, r1[3], 4)
		SubScaled(r0, r3, r0[3], 4)

		-- now back substitute row 1
		ScaleDiff(r1, r2, 1 / r1[1], r1[2])
		SubScaled(r0, r2, r0[2], 4)

		-- now back substitute row 0
		ScaleDiff(r0, r1, 1 / r0[0], r0[1])

		for i = 0, 3 do
			out[0][i] = r0[4 + i]
			out[1][i] = r1[4 + i]
			out[2][i] = r2[4 + i]
			out[3][i] = r3[4 + i]
		end

		return true
	end
end

-- Export the module.
return M