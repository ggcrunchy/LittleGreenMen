--- Mechanics for a camera that tracks the mouse.

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
local atan2 = math.atan2
local cos = math.cos
local max = math.max
local min = math.min
local sin = math.sin
local sqrt = math.sqrt

-- Modules --
local v3math = require("lib.v3math")

-- Exports --
local M = {}

-- --
local Pos
local Dir = v3math.new()
local Side = v3math.new()
local Up = v3math.new()

--- DOCME
-- @tparam vec3 pos
-- @tparam vec3 dir
-- @tparam vec3 side
-- @tparam vec3 up
function M.GetVectors (pos, dir, side, up)
	for i = 0, 2 do
		pos[i] = Pos[i]
		dir[i] = Dir[i]
		side[i] = Side[i]
		up[i] = Up[i]
	end
end

-- --
local AngleHorz

-- --
local AngleVert

--- DOCME
-- @tparam vec3 pos
-- @tparam vec3 dir
-- @tparam vec3 up
function M.Init (pos, dir, up)
	Pos = v3math.scalenew(pos, 1)

	AngleHorz = atan2(dir[0], dir[2])
	AngleVert = atan2(sqrt(up[0] * up[0] + up[2] * up[2]), up[1])
end

--
local function ClampIn (n, range)
	return min(max(n, -range), range)
end

--
local function CosSin (angle)
	return cos(angle), sin(angle)
end

--
local function AddScaledTo (out, a, b, k)
	local temp = v3math.new()

	v3math.scale(temp, b, k)
	v3math.add(out, a, temp)
end

--
local function UpVector (dist)
	return v3math.new(0, dist, 0)
end

-- --
local HorzRange = math.pi / 6

-- --
local VertRange = math.pi * .375

--- DOCME
-- @number ddir
-- @number dside
-- @number dx
-- @number dy
function M.Update (ddir, dside, dx, dy)
	AngleHorz = AngleHorz + ClampIn(dx * .035, HorzRange)
	AngleVert = ClampIn(AngleVert + dy * .035, VertRange)

	local cosh, sinh = CosSin(AngleHorz)
	local cosv, sinv = CosSin(AngleVert)
	local planev = v3math.new(sinh, 0, cosh)

	AddScaledTo(Dir, UpVector(sinv), planev, cosv)
	AddScaledTo(Up, UpVector(cosv), planev, -sinv)

	v3math.normself(Dir)
	v3math.normself(Up)
	v3math.cross(Side, Up, Dir)

	AddScaledTo(Pos, Pos, Dir, ddir)
	AddScaledTo(Pos, Pos, Side, dside)
end

-- Export the module.
return M