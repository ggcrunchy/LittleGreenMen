--- This module implements some axis-aligned bounding box / ray collision algorithms.

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

-- Notice in the original:

--[===========================================================================[
  This source code accompanies the Journal of Graphics Tools paper:


  "Fast Ray / Axis-Aligned Bounding Box Overlap Tests using Ray Slopes" 
  by Martin Eisemann, Thorsten Grosch, Stefan Müller and Marcus Magnor
  Computer Graphics Lab, TU Braunschweig, Germany and
  University of Koblenz-Landau, Germany


  Parts of this code are taken from
  "Fast Ray-Axis Aligned Bounding Box Overlap Tests With Pluecker Coordinates" 
  by Jeffrey Mahovsky and Brian Wyvill
  Department of Computer Science, University of Calgary


  This source code is public domain, but please mention us if you use it.
]===========================================================================]

-- Standard library imports --
local band = bit.band
local bor = bit.bor
local floor = math.floor
local max = math.max
local rshift = bit.rshift
local sqrt = math.sqrt

-- Modules --
local ffi = require("ffi")
local utils = require("utils")

-- Exports --
local M = {}

ffi.cdef[[
	typedef union {
		struct {
			double x0, x1, y0, y1, z0, z1;
		};
		struct {
			double xx[2], yy[2], zz[2];
		};
	} AABox_t;

	enum CLASSIFICATION	{
		MMM, MMP, MPM, MPP, PMM, PMP, PPM, PPP,
		POO, MOO, OPO, OMO, OOP, OOM, OMM,
		OMP, OPM, OPP, MOM, MOP, POM, POP, MMO, MPO, PMO, PPO
	};

	typedef struct {
		double x, y, z; // ray origin   
		double i, j, k; // ray direction        
		double ii, ij, ik; // inverses of direction components

		// ray slope
		enum CLASSIFICATION classification;
		int32_t info;
		double ibyj, jbyi, kbyj, jbyk, ibyk, kbyi; // slope
		double c_xy, c_xz, c_yx, c_yz, c_zx, c_zy;       
	} Ray_t;
]]

-- TODO: turn CLASSIFICATION into the magic numbers
-- Include some notes about how to derive them
-- Put them in (commented-out) stuff in Slope

--- DOCME
-- @number x0
-- @number y0
-- @number z0
-- @number x1
-- @number y1
-- @number z1
-- @treturn AABox_t X
function M.MakeAABox (x0, y0, z0, x1, y1, z1)
	x0, x1 = utils.Sort2(x0, x1)
	y0, y1 = utils.Sort2(y0, y1)
	z0, z1 = utils.Sort2(z0, z1)

	return ffi.new("AABox_t", x0, x1, y0, y1, z0, z1)
end
-- TODO: Work these all out and just embed the constants
local function ls (magic, id)
	return magic + bit.lshift(id, 9)
end
--- DOCME
-- @number x
-- @number y
-- @number z
-- @number i
-- @number j
-- @number k
-- @treturn Ray_t X
function M.MakeRay (x, y, z, i, j, k)
	local ray = ffi.new("Ray_t", x, y, z, i, j, k, 1 / i, 1 / j, 1 / k)

	-- ray slope
	ray.ibyj = i * ray.ij
	ray.jbyi = j * ray.ii
	ray.jbyk = j * ray.ik
	ray.kbyj = k * ray.ij
	ray.ibyk = i * ray.ik
	ray.kbyi = k * ray.ii
	ray.c_xy = y - ray.jbyi * x
	ray.c_xz = z - ray.kbyi * x
	ray.c_yx = x - ray.ibyj * y
	ray.c_yz = z - ray.kbyj * y
	ray.c_zx = x - ray.ibyk * z
	ray.c_zy = y - ray.jbyk * z

	-- ray slope classification
	-- TODO: Is there a more elegant way?
	if i < 0 then
		if j < 0 then
			if k < 0 then
				ray.classification = "MMM"
				ray.info = ls(0x1F8, 1)
			elseif k > 0 then
				ray.classification = "MMP"
				ray.info = ls(0x13C, 1)
			else
				ray.classification = "MMO"
            end
		else -- j >= 0
			if k < 0 then
				ray.classification = j == 0 and "MOM" or "MPM"
				if j ~= 0 then
					ray.info = ls(0x1D2, 1)
				end
			else -- k >= 0
				if j == 0 and k == 0 then
					ray.classification = "MOO"
				elseif k == 0 then
					ray.classification = "MPO"
				elseif j == 0 then
					ray.classification = "MOP"
				else
					ray.classification = "MPP"
					ray.info = ls(0x116, 1)
				end
			end
		end
	else -- i >= 0
		if j < 0 then
			if k < 0 then
				ray.classification = i == 0 and "OMM" or "PMM"
				if i ~=0 then
					ray.info = ls(0x0E9, 1)
				end
			else -- k >= 0
				if i == 0 and k == 0 then
					ray.classification = "OMO"
				elseif k == 0 then
					ray.classification = "PMO"
				elseif i == 0 then
					ray.classification = "OMP"
				else
					ray.classification = "PMP"
					ray.info = ls(0x02D, 1)
				end
			end
        else -- j >= 0
			if k < 0 then
				if i == 0 and j == 0 then
					ray.classification = "OOM"
				elseif i == 0 then
					ray.classification = "OPM"
				elseif j == 0 then
					ray.classification = "POM"
				else
					ray.classification = "PPM"
					ray.info = ls(0x0C3, 1)
				end
			else -- k >= 0
				if i == 0 then
					if j == 0 then
						ray.classification = "OOP"
					elseif k == 0 then
						ray.classification = "OPO"
					else
						ray.classification = "OPP"
					end
				else
					if j == 0 and k == 0 then
						ray.classification = "POO"
                    elseif j == 0 then
						ray.classification = "POP"
					elseif k == 0 then
						ray.classification = "PPO"
					else
                        ray.classification = "PPP"
                        ray.info = ls(0x007, 1)
					end
				end
			end
		end
	end

	return ray
end

--- DOCME
-- @number x1
-- @number y1
-- @number z1
-- @number x2
-- @number y2
-- @number z2
-- @treturn Ray_t X
function M.MakeRayTo (x1, y1, z1, x2, y2, z2)
	local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
	local len = sqrt(dx * dx + dy * dy + dz * dz)

	return M.MakeRay(x1, y1, z1, dx / len, dy / len, dz / len)
end

-- --
local Pack = {
	-- 1: XYZ --
	function(ray, box)
		local ix = band(ray.info, 0x1)
		local iy = band(rshift(ray.info, 1), 0x1)
		local iz = band(rshift(ray.info, 2), 0x1)

		local x1 = box.xx[ix]
		local y1 = box.yy[iy]
		local z1 = box.zz[iz]

		local c1 = rshift(floor(ray.x - x1), 31)
		local c2 = band(rshift(floor(ray.y - y1), 30), 0x2)
		local c3 = band(rshift(floor(ray.z - z1), 29), 0x4)
		
		local x2 = box.xx[1 - ix]
		local y2 = box.yy[1 - iy]
		local z2 = box.zz[1 - iz]
		
		local c4 = band(rshift(floor(ray.jbyi * x1 - y2 + ray.c_xy), 28), 0x008)
		local c5 = band(rshift(floor(ray.ibyj * y1 - x2 + ray.c_yx), 27), 0x010)
		local c6 = band(rshift(floor(ray.jbyk * z1 - y2 + ray.c_zy), 26), 0x020)
		local c7 = band(rshift(floor(ray.kbyj * y1 - z2 + ray.c_yz), 25), 0x040)
		local c8 = band(rshift(floor(ray.kbyi * x1 - z2 + ray.c_xz), 24), 0x080)
		local c9 = band(rshift(floor(ray.ibyk * z1 - x2 + ray.c_zx), 23), 0x100)

		return bor(c1, c2, c3, c4, c5, c6, c7, c8, c9)
	end
}

--- DOCME
-- @tparam Ray_t ray
-- @tparam AABox_t box
-- @treturn boolean X
function M.Slope (ray, box)
    if ray.classification == "MMM" then
		if ray.x < box.x0 or ray.y < box.y0 or ray.z < box.z0 or
			ray.jbyi * box.x0 - box.y1 + ray.c_xy > 0 or
			ray.ibyj * box.y0 - box.x1 + ray.c_yx > 0 or
			ray.jbyk * box.z0 - box.y1 + ray.c_zy > 0 or
			ray.kbyj * box.y0 - box.z1 + ray.c_yz > 0 or
			ray.kbyi * box.x0 - box.z1 + ray.c_xz > 0 or
			ray.ibyk * box.z0 - box.x1 + ray.c_zx > 0 then
			return false
		end

	elseif ray.classification == "MMP" then
		if ray.x < box.x0 or ray.y < box.y0 or ray.z > box.z1 or
			ray.jbyi * box.x0 - box.y1 + ray.c_xy > 0 or
			ray.ibyj * box.y0 - box.x1 + ray.c_yx > 0 or
			ray.jbyk * box.z1 - box.y1 + ray.c_zy > 0 or
			ray.kbyj * box.y0 - box.z0 + ray.c_yz < 0 or
			ray.kbyi * box.x0 - box.z0 + ray.c_xz < 0 or
			ray.ibyk * box.z1 - box.x1 + ray.c_zx > 0 then
			return false
		end

	elseif ray.classification == "MPM" then
		if ray.x < box.x0 or ray.y > box.y1 or ray.z < box.z0 or
			ray.jbyi * box.x0 - box.y0 + ray.c_xy < 0 or
			ray.ibyj * box.y1 - box.x1 + ray.c_yx > 0 or
			ray.jbyk * box.z0 - box.y0 + ray.c_zy < 0 or
			ray.kbyj * box.y1 - box.z1 + ray.c_yz > 0 or
			ray.kbyi * box.x0 - box.z1 + ray.c_xz > 0 or
			ray.ibyk * box.z0 - box.x1 + ray.c_zx > 0 then
			return false
		end

	elseif ray.classification == "MPP" then
		if ray.x < box.x0 or ray.y > box.y1 or ray.z > box.z1 or
			ray.jbyi * box.x0 - box.y0 + ray.c_xy < 0 or
			ray.ibyj * box.y1 - box.x1 + ray.c_yx > 0 or
			ray.jbyk * box.z1 - box.y0 + ray.c_zy < 0 or
			ray.kbyj * box.y1 - box.z0 + ray.c_yz < 0 or
			ray.kbyi * box.x0 - box.z0 + ray.c_xz < 0 or
			ray.ibyk * box.z1 - box.x1 + ray.c_zx > 0 then
			return false
		end

	elseif ray.classification == "PMM" then
		if ray.x > box.x1 or ray.y < box.y0 or ray.z < box.z0 or
			ray.jbyi * box.x1 - box.y1 + ray.c_xy > 0 or
			ray.ibyj * box.y0 - box.x0 + ray.c_yx < 0 or
			ray.jbyk * box.z0 - box.y1 + ray.c_zy > 0 or
			ray.kbyj * box.y0 - box.z1 + ray.c_yz > 0 or
			ray.kbyi * box.x1 - box.z1 + ray.c_xz > 0 or
			ray.ibyk * box.z0 - box.x0 + ray.c_zx < 0 then
			return false
		end

	elseif ray.classification == "PMP" then
		if ray.x > box.x1 or ray.y < box.y0 or ray.z > box.z1 or
			ray.jbyi * box.x1 - box.y1 + ray.c_xy > 0 or
			ray.ibyj * box.y0 - box.x0 + ray.c_yx < 0 or
			ray.jbyk * box.z1 - box.y1 + ray.c_zy > 0 or
			ray.kbyj * box.y0 - box.z0 + ray.c_yz < 0 or
			ray.kbyi * box.x1 - box.z0 + ray.c_xz < 0 or
			ray.ibyk * box.z1 - box.x0 + ray.c_zx < 0 then
			return false
		end

	elseif ray.classification == "PPM" then
		if ray.x > box.x1 or ray.y > box.y1 or ray.z < box.z0 or
			ray.jbyi * box.x1 - box.y0 + ray.c_xy < 0 or
			ray.ibyj * box.y1 - box.x0 + ray.c_yx < 0 or
			ray.jbyk * box.z0 - box.y0 + ray.c_zy < 0 or
			ray.kbyj * box.y1 - box.z1 + ray.c_yz > 0 or
			ray.kbyi * box.x1 - box.z1 + ray.c_xz > 0 or
			ray.ibyk * box.z0 - box.x0 + ray.c_zx < 0 then
			return false
		end

	elseif ray.classification == "PPP" then
		if ray.x > box.x1 or ray.y > box.y1 or ray.z > box.z1 or
			ray.jbyi * box.x1 - box.y0 + ray.c_xy < 0 or
			ray.ibyj * box.y1 - box.x0 + ray.c_yx < 0 or
			ray.jbyk * box.z1 - box.y0 + ray.c_zy < 0 or
			ray.kbyj * box.y1 - box.z0 + ray.c_yz < 0 or
			ray.kbyi * box.x1 - box.z0 + ray.c_xz < 0 or
			ray.ibyk * box.z1 - box.x0 + ray.c_zx < 0 then
			return false
		end

	elseif ray.classification == "OMM" then
		if ray.x < box.x0 or ray.x > box.x1 or
			ray.y < box.y0 or ray.z < box.z0 or
			ray.jbyk * box.z0 - box.y1 + ray.c_zy > 0 or
			ray.kbyj * box.y0 - box.z1 + ray.c_yz > 0 then
			return false
		end

	elseif ray.classification == "OMP" then
		if ray.x < box.x0 or ray.x > box.x1 or
			ray.y < box.y0 or ray.z > box.z1 or
			ray.jbyk * box.z1 - box.y1 + ray.c_zy > 0 or
			ray.kbyj * box.y0 - box.z0 + ray.c_yz < 0 then
			return false
		end

	elseif ray.classification == "OPM" then
		if ray.x < box.x0 or ray.x > box.x1 or
			ray.y > box.y1 or ray.z < box.z0 or
			ray.jbyk * box.z0 - box.y0 + ray.c_zy < 0 or
			ray.kbyj * box.y1 - box.z1 + ray.c_yz > 0 then
			return false
		end

	elseif ray.classification == "OPP" then
		if ray.x < box.x0 or ray.x > box.x1 or
			ray.y > box.y1 or ray.z > box.z1 or
			ray.jbyk * box.z1 - box.y0 + ray.c_zy < 0 or
			ray.kbyj * box.y1 - box.z0 + ray.c_yz < 0 then
			return false
		end

	elseif ray.classification == "MOM" then
		if ray.y < box.y0 or ray.y > box.y1 or
			ray.x < box.x0 or ray.z < box.z0 or
			ray.kbyi * box.x0 - box.z1 + ray.c_xz > 0 or
			ray.ibyk * box.z0 - box.x1 + ray.c_zx > 0 then
			return false
		end

	elseif ray.classification == "MOP" then
		if ray.y < box.y0 or ray.y > box.y1 or
			ray.x < box.x0 or ray.z > box.z1 or
			ray.kbyi * box.x0 - box.z0 + ray.c_xz < 0 or
			ray.ibyk * box.z1 - box.x1 + ray.c_zx > 0 then
			return false
		end

	elseif ray.classification == "POM" then
		if ray.y < box.y0 or ray.y > box.y1 or
			ray.x > box.x1 or ray.z < box.z0 or
			ray.kbyi * box.x1 - box.z1 + ray.c_xz > 0 or
			ray.ibyk * box.z0 - box.x0 + ray.c_zx < 0 then
			return false
		end

	elseif ray.classification == "POP" then
		if ray.y < box.y0 or ray.y > box.y1 or
			ray.x > box.x1 or ray.z > box.z1 or
			ray.kbyi * box.x1 - box.z0 + ray.c_xz < 0 or
			ray.ibyk * box.z1 - box.x0 + ray.c_zx < 0 then
			return false
		end

	elseif ray.classification == "MMO" then
		if ray.z < box.z0 or ray.z > box.z1 or
			ray.x < box.x0 or ray.y < box.y0 or
			ray.jbyi * box.x0 - box.y1 + ray.c_xy > 0 or
			ray.ibyj * box.y0 - box.x1 + ray.c_yx > 0 then
			return false
		end

	elseif ray.classification == "MPO" then
		if ray.z < box.z0 or ray.z > box.z1 or
			ray.x < box.x0 or ray.y > box.y1 or
			ray.jbyi * box.x0 - box.y0 + ray.c_xy < 0 or
			ray.ibyj * box.y1 - box.x1 + ray.c_yx > 0 then
			return false
		end

	elseif ray.classification == "PMO" then
		if ray.z < box.z0 or ray.z > box.z1 or
			ray.x > box.x1 or ray.y < box.y0 or
			ray.jbyi * box.x1 - box.y1 + ray.c_xy > 0 or
			ray.ibyj * box.y0 - box.x0 + ray.c_yx < 0 then
			return false
		end

	elseif ray.classification == "PPO" then
		if ray.z < box.z0 or ray.z > box.z1 or
			ray.x > box.x1 or ray.y > box.y1 or
			ray.jbyi * box.x1 - box.y0 + ray.c_xy < 0 or
			ray.ibyj * box.y1 - box.x0 + ray.c_yx < 0 then
			return false
		end

	elseif ray.classification == "MOO" then
		if ray.x < box.x0 or
			ray.y < box.y0 or ray.y > box.y1 or
			ray.z < box.z0 or ray.z > box.z1 then
			return false
		end

	elseif ray.classification == "POO" then
		if ray.x > box.x1 or
			ray.y < box.y0 or ray.y > box.y1 or
			ray.z < box.z0 or ray.z > box.z1 then
			return false
		end

	elseif ray.classification == "OMO" then
		if ray.y < box.y0 or
			ray.x < box.x0 or ray.x > box.x1 or
			ray.z < box.z0 or ray.z > box.z1 then
			return false
		end

	elseif ray.classification == "OPO" then
		if ray.y > box.y1 or
			ray.x < box.x0 or ray.x > box.x1 or
			ray.z < box.z0 or ray.z > box.z1 then
            return false
		end

	elseif ray.classification == "OOM" then
		if ray.z < box.z0 or
			ray.x < box.x0 or ray.x > box.x1 or
			ray.y < box.y0 or ray.y > box.y1 then
            return false
		end

	elseif ray.classification == "OOP" then
		if ray.z > box.z1 or
			ray.x < box.x0 or ray.x > box.x1 or
			ray.y < box.y0 or ray.y > box.y1 then
			return false
		end
	end

	return true
--[[
	TODO: See notes in SlopeInt...
	local packet = Pack[rshift(ray.info, 9)](ray, box)

	return packet == band(ray.info, 0x1FF)
]]
end

-- --
local Intersect = {
	-- 1: XYZ --
	function(ray, box)
		local ix = band(ray.info, 0x1)
		local iy = band(rshift(ray.info, 1), 0x1)
		local iz = band(rshift(ray.info, 2), 0x1)

		return max((box.xx[1 - ix] - ray.x) * ray.ii, (box.yy[1 - iy] - ray.y) * ray.ij, (box.zz[1 - iz] - ray.z) * ray.ik)
	end
}

--- DOCME
-- @tparam Ray_t ray
-- @tparam AABox_t box
-- @treturn boolean X
-- @treturn number Y
function M.SlopeInt (ray, box)
	local t
--[=[
	-- XYZ (group 1):

    if ray.classification == "MMM" then -- 111 111 000 -> 0x1F8
		if ray.x < box.x0 or ray.y < box.y0 or ray.z < box.z0 or -- 000
			ray.jbyi * box.x0 - box.y1 + ray.c_xy > 0 or -- 1
			ray.ibyj * box.y0 - box.x1 + ray.c_yx > 0 or -- 1
			ray.jbyk * box.z0 - box.y1 + ray.c_zy > 0 or -- 1
			ray.kbyj * box.y0 - box.z1 + ray.c_yz > 0 or -- 1
			ray.kbyi * box.x0 - box.z1 + ray.c_xz > 0 or -- 1
			ray.ibyk * box.z0 - box.x1 + ray.c_zx > 0 then -- 1
			return false
		end

		t = max((box.x1 - ray.x) * ray.ii, (box.y1 - ray.y) * ray.ij, (box.z1 - ray.z) * ray.ik)

	elseif ray.classification == "MMP" then -- 100 111 100 -> 0x13C
		if ray.x < box.x0 or ray.y < box.y0 or ray.z > box.z1 or -- 001
			ray.jbyi * box.x0 - box.y1 + ray.c_xy > 0 or -- 1
			ray.ibyj * box.y0 - box.x1 + ray.c_yx > 0 or -- 1
			ray.jbyk * box.z1 - box.y1 + ray.c_zy > 0 or -- 1
			ray.kbyj * box.y0 - box.z0 + ray.c_yz < 0 or -- 0
			ray.kbyi * box.x0 - box.z0 + ray.c_xz < 0 or -- 0
			ray.ibyk * box.z1 - box.x1 + ray.c_zx > 0 then -- 1
			return false
		end

		t = max((box.x1 - ray.x) * ray.ii, (box.y1 - ray.y) * ray.ij, (box.z0 - ray.z) * ray.ik)

	elseif ray.classification == "MPM" then -- 111 010 010 -> 0x1D2
		if ray.x < box.x0 or ray.y > box.y1 or ray.z < box.z0 or -- 010
			ray.jbyi * box.x0 - box.y0 + ray.c_xy < 0 or -- 0
			ray.ibyj * box.y1 - box.x1 + ray.c_yx > 0 or -- 1
			ray.jbyk * box.z0 - box.y0 + ray.c_zy < 0 or -- 0
			ray.kbyj * box.y1 - box.z1 + ray.c_yz > 0 or -- 1
			ray.kbyi * box.x0 - box.z1 + ray.c_xz > 0 or -- 1
			ray.ibyk * box.z0 - box.x1 + ray.c_zx > 0 then -- 1
			return false
		end

		t = max((box.x1 - ray.x) * ray.ii, (box.y0 - ray.y) * ray.ij, (box.z1 - ray.z) * ray.ik)

	elseif ray.classification == "MPP" then -- 100 010 110 -> 0x116
		if ray.x < box.x0 or ray.y > box.y1 or ray.z > box.z1 or -- 011
			ray.jbyi * box.x0 - box.y0 + ray.c_xy < 0 or -- 0
			ray.ibyj * box.y1 - box.x1 + ray.c_yx > 0 or -- 1
			ray.jbyk * box.z1 - box.y0 + ray.c_zy < 0 or -- 0
			ray.kbyj * box.y1 - box.z0 + ray.c_yz < 0 or -- 0
			ray.kbyi * box.x0 - box.z0 + ray.c_xz < 0 or -- 0
			ray.ibyk * box.z1 - box.x1 + ray.c_zx > 0 then -- 1
			return false
		end

		t = max((box.x1 - ray.x) * ray.ii, (box.y0 - ray.y) * ray.ij, (box.z0 - ray.z) * ray.ik)

	elseif ray.classification == "PMM" then -- 011 101 001 -> 0x0E9
		if ray.x > box.x1 or ray.y < box.y0 or ray.z < box.z0 or -- 100
			ray.jbyi * box.x1 - box.y1 + ray.c_xy > 0 or -- 1
			ray.ibyj * box.y0 - box.x0 + ray.c_yx < 0 or -- 0
			ray.jbyk * box.z0 - box.y1 + ray.c_zy > 0 or -- 1
			ray.kbyj * box.y0 - box.z1 + ray.c_yz > 0 or -- 1
			ray.kbyi * box.x1 - box.z1 + ray.c_xz > 0 or -- 1
			ray.ibyk * box.z0 - box.x0 + ray.c_zx < 0 then -- 0
			return false
		end

		t = max((box.x0 - ray.x) * ray.ii, (box.y1 - ray.y) * ray.ij, (box.z1 - ray.z) * ray.ik)

	elseif ray.classification == "PMP" then -- 000 101 101 -> 0x02D
		if ray.x > box.x1 or ray.y < box.y0 or ray.z > box.z1 or -- 101
			ray.jbyi * box.x1 - box.y1 + ray.c_xy > 0 or -- 1
			ray.ibyj * box.y0 - box.x0 + ray.c_yx < 0 or -- 0
			ray.jbyk * box.z1 - box.y1 + ray.c_zy > 0 or -- 1
			ray.kbyj * box.y0 - box.z0 + ray.c_yz < 0 or -- 0
			ray.kbyi * box.x1 - box.z0 + ray.c_xz < 0 or -- 0
			ray.ibyk * box.z1 - box.x0 + ray.c_zx < 0 then -- 0
			return false
		end

		t = max((box.x0 - ray.x) * ray.ii, (box.y1 - ray.y) * ray.ij, (box.z0 - ray.z) * ray.ik)

	elseif ray.classification == "PPM" then -- 011 000 011 -> 0x0C3
		if ray.x > box.x1 or ray.y > box.y1 or ray.z < box.z0 or -- 110
			ray.jbyi * box.x1 - box.y0 + ray.c_xy < 0 or -- 0
			ray.ibyj * box.y1 - box.x0 + ray.c_yx < 0 or -- 0
			ray.jbyk * box.z0 - box.y0 + ray.c_zy < 0 or -- 0
			ray.kbyj * box.y1 - box.z1 + ray.c_yz > 0 or -- 1
			ray.kbyi * box.x1 - box.z1 + ray.c_xz > 0 or -- 1
			ray.ibyk * box.z0 - box.x0 + ray.c_zx < 0 then -- 0
			return false
		end

		t = max((box.x0 - ray.x) * ray.ii, (box.y0 - ray.y) * ray.ij, (box.z1 - ray.z) * ray.ik)

	elseif ray.classification == "PPP" then -- 000 000 111 -> 0x007
		if ray.x > box.x1 or ray.y > box.y1 or ray.z > box.z1 or -- 111
			ray.jbyi * box.x1 - box.y0 + ray.c_xy < 0 or -- 0
			ray.ibyj * box.y1 - box.x0 + ray.c_yx < 0 or -- 0
			ray.jbyk * box.z1 - box.y0 + ray.c_zy < 0 or -- 0
			ray.kbyj * box.y1 - box.z0 + ray.c_yz < 0 or -- 0
			ray.kbyi * box.x1 - box.z0 + ray.c_xz < 0 or -- 0
			ray.ibyk * box.z1 - box.x0 + ray.c_zx < 0 then -- 0
			return false
		end

		t = max((box.x0 - ray.x) * ray.ii, (box.y0 - ray.y) * ray.ij, (box.z0 - ray.z) * ray.ik)
]=]
--[[
	TODO:
	local index = band(rshift(ray.info, 3), 0x7)
	local packet = Slope[index](ray, box, band(ray.info, 0x7))
	if packet ~= rshift(ray.info, 6) then
		return false
	else
		return true[, Intersection[index](ray, box, band(ray.info, 0x7)] -- in SlopeInt case
	end
]]

	if ray.info ~= 0 then -- 3 bits to distinguish 7 cases? (0-2 = indices, 3-5 = case, 6-n, n <= 31 = magic number)
-- TODO: Are indices always part of magic number? If so, then 0-8 = packet, 9-11 = case
		local index = rshift(ray.info, 9)
		local packet = Pack[index](ray, box)--, band(ray.info, 0x7))

		if packet ~= band(ray.info, 0x1FF) then
			return false
		else
			return true, Intersect[index](ray, box)--, band(ray.info, 0x7))
		end

-- begin YZ...
	elseif ray.classification == "OMM" then
		if ray.x < box.x0 or ray.x > box.x1 or
			ray.y < box.y0 or ray.z < box.z0 or
			ray.jbyk * box.z0 - box.y1 + ray.c_zy > 0 or
			ray.kbyj * box.y0 - box.z1 + ray.c_yz > 0 then
			return false
		end

		t = max((box.y1 - ray.y) * ray.ij, (box.z1 - ray.z) * ray.ik)

	elseif ray.classification == "OMP" then
		if ray.x < box.x0 or ray.x > box.x1 or
			ray.y < box.y0 or ray.z > box.z1 or
			ray.jbyk * box.z1 - box.y1 + ray.c_zy > 0 or
			ray.kbyj * box.y0 - box.z0 + ray.c_yz < 0 then
			return false
		end

		t = max((box.y1 - ray.y) * ray.ij, (box.z0 - ray.z) * ray.ik)

	elseif ray.classification == "OPM" then
		if ray.x < box.x0 or ray.x > box.x1 or
			ray.y > box.y1 or ray.z < box.z0 or
			ray.jbyk * box.z0 - box.y0 + ray.c_zy < 0 or
			ray.kbyj * box.y1 - box.z1 + ray.c_yz > 0 then
			return false
		end

		t = max((box.y0 - ray.y) * ray.ij, (box.z1 - ray.z) * ray.ik)

	elseif ray.classification == "OPP" then
		if ray.x < box.x0 or ray.x > box.x1 or
			ray.y > box.y1 or ray.z > box.z1 or
			ray.jbyk * box.z1 - box.y0 + ray.c_zy < 0 or
			ray.kbyj * box.y1 - box.z0 + ray.c_yz < 0 then
			return false
		end

		t = max((box.y0 - ray.y) * ray.ij, (box.z0 - ray.z) * ray.ik)
-- begin XZ...
	elseif ray.classification == "MOM" then
		if ray.y < box.y0 or ray.y > box.y1 or
			ray.x < box.x0 or ray.z < box.z0 or
			ray.kbyi * box.x0 - box.z1 + ray.c_xz > 0 or
			ray.ibyk * box.z0 - box.x1 + ray.c_zx > 0 then
			return false
		end

		t = max((box.x1 - ray.x) * ray.ii, (box.z1 - ray.z) * ray.ik)

	elseif ray.classification == "MOP" then
		if ray.y < box.y0 or ray.y > box.y1 or
			ray.x < box.x0 or ray.z > box.z1 or
			ray.kbyi * box.x0 - box.z0 + ray.c_xz < 0 or
			ray.ibyk * box.z1 - box.x1 + ray.c_zx > 0 then
			return false
		end

		t = max((box.x1 - ray.x) * ray.ii, (box.z0 - ray.z) * ray.ik)

	elseif ray.classification == "POM" then
		if ray.y < box.y0 or ray.y > box.y1 or
			ray.x > box.x1 or ray.z < box.z0 or
			ray.kbyi * box.x1 - box.z1 + ray.c_xz > 0 or
			ray.ibyk * box.z0 - box.x0 + ray.c_zx < 0 then
			return false
		end

		t = max((box.x0 - ray.x) * ray.ii, (box.z1 - ray.z) * ray.ik)

	elseif ray.classification == "POP" then
		if ray.y < box.y0 or ray.y > box.y1 or
			ray.x > box.x1 or ray.z > box.z1 or
			ray.kbyi * box.x1 - box.z0 + ray.c_xz < 0 or
			ray.ibyk * box.z1 - box.x0 + ray.c_zx < 0 then
			return false
		end

		t = max((box.x0 - ray.x) * ray.ii, (box.z0 - ray.z) * ray.ik)
-- begin XY...
	elseif ray.classification == "MMO" then
		if ray.z < box.z0 or ray.z > box.z1 or
			ray.x < box.x0 or ray.y < box.y0 or
			ray.jbyi * box.x0 - box.y1 + ray.c_xy > 0 or
			ray.ibyj * box.y0 - box.x1 + ray.c_yx > 0 then
			return false
		end

		t = max((box.x1 - ray.x) * ray.ii, (box.y1 - ray.y) * ray.ij)

	elseif ray.classification == "MPO" then
		if ray.z < box.z0 or ray.z > box.z1 or
			ray.x < box.x0 or ray.y > box.y1 or
			ray.jbyi * box.x0 - box.y0 + ray.c_xy < 0 or
			ray.ibyj * box.y1 - box.x1 + ray.c_yx > 0 then
			return false
		end

		t = max((box.x1 - ray.x) * ray.ii, (box.y0 - ray.y) * ray.ij)

	elseif ray.classification == "PMO" then
		if ray.z < box.z0 or ray.z > box.z1 or
			ray.x > box.x1 or ray.y < box.y0 or
			ray.jbyi * box.x1 - box.y1 + ray.c_xy > 0 or
			ray.ibyj * box.y0 - box.x0 + ray.c_yx < 0 then
			return false
		end

		t = max((box.x0 - ray.x) * ray.ii, (box.y1 - ray.y) * ray.ij)

	elseif ray.classification == "PPO" then
		if ray.z < box.z0 or ray.z > box.z1 or
			ray.x > box.x1 or ray.y > box.y1 or
			ray.jbyi * box.x1 - box.y0 + ray.c_xy < 0 or
			ray.ibyj * box.y1 - box.x0 + ray.c_yx < 0 then
			return false
		end

		t = max((box.x0 - ray.x) * ray.ii, (box.y0 - ray.y) * ray.ij)
-- begin X...
	elseif ray.classification == "MOO" then
		if ray.x < box.x0 or
			ray.y < box.y0 or ray.y > box.y1 or
			ray.z < box.z0 or ray.z > box.z1 then
			return false
		end

		t = (box.x1 - ray.x) * ray.ii

	elseif ray.classification == "POO" then
		if ray.x > box.x1 or
			ray.y < box.y0 or ray.y > box.y1 or
			ray.z < box.z0 or ray.z > box.z1 then
			return false
		end

		t = (box.x0 - ray.x) * ray.ii
-- begin Y...
	elseif ray.classification == "OMO" then
		if ray.y < box.y0 or
			ray.x < box.x0 or ray.x > box.x1 or
			ray.z < box.z0 or ray.z > box.z1 then
			return false
		end

		t = (box.y1 - ray.y) * ray.ij

	elseif ray.classification == "OPO" then
		if ray.y > box.y1 or
			ray.x < box.x0 or ray.x > box.x1 or
			ray.z < box.z0 or ray.z > box.z1 then
            return false
		end

		t = (box.y0 - ray.y) * ray.ij
-- begin Z...
	elseif ray.classification == "OOM" then
		if ray.z < box.z0 or
			ray.x < box.x0 or ray.x > box.x1 or
			ray.y < box.y0 or ray.y > box.y1 then
            return false
		end

		t = (box.z1 - ray.z) * ray.ik

	elseif ray.classification == "OOP" then
		if ray.z > box.z1 or
			ray.x < box.x0 or ray.x > box.x1 or
			ray.y < box.y0 or ray.y > box.y1 then
			return false
		end

		t = (box.z0 - ray.z) * ray.ik
	end

	return true, t
end

-- Export the module.
return M