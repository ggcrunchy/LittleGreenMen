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
local max = math.max

-- Modules --
local ffi = require("ffi")

-- Exports --
local M = {}

ffi.cdef[[
	typedef struct {
		double x0, y0, z0, x1, y1, z1;
	} AABox_t;

	enum CLASSIFICATION	{
		MMM, MMP, MPM, MPP, PMM, PMP, PPM, PPP,
		POO, MOO, OPO, OMO, OOP, OOM, OMM,
		OMP, OPM, OPP, MOM, MOP, POM, POP, MMO, MPO, PMO, PPO
	};

	typedef struct {       
		//common variables
		double x, y, z;          // ray origin   
		double i, j, k;          // ray direction        
		double ii, ij, ik;       // inverses of direction components

		// ray slope
		enum CLASSIFICATION classification;
		double ibyj, jbyi, kbyj, jbyk, ibyk, kbyi; // slope
		double c_xy, c_xz, c_yx, c_yz, c_zx, c_zy;       
	} Ray_t;
]]

--- DOCME
-- @number x0
-- @number y0
-- @number z0
-- @number x1
-- @number y1
-- @number z1
-- @treturn AABox_t X
function M.MakeAABox (x0, y0, z0, x1, y1, z1)
	if x0 > x1 then
		x0, x1 = x1, x0
	end

	if y0 > y1 then
		y0, y1 = y1, y0
	end

	if z0 > z1 then
		z0, z1 = z1, z0
	end

	return ffi.new("AABox_t", x0, y0, z0, x1, y1, z1)
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
	if i < 0 then
		if j < 0 then
			if k < 0 then
				ray.classification = "MMM"
			elseif k > 0 then
				ray.classification = "MMP"
			else -- k >= 0
				ray.classification = "MMO"
            end
		else -- j >= 0)
			if k < 0 then
				ray.classification = j == 0 and "MOM" or "MPM"
			else -- k >= 0
				if j == 0 and k == 0 then
					ray.classification = "MOO"
				elseif k == 0 then
					ray.classification = "MPO"
				elseif j == 0 then
					ray.classification = "MOP"
				else
					ray.classification = "MPP"
				end
			end
		end
	else -- i >= 0
		if j < 0 then
			if k < 0 then
				ray.classification = i == 0 and "OMM" or "PMM"
			else -- k >= 0
				if i == 0 and k == 0 then
					ray.classification = "OMO"
				elseif k == 0 then
					ray.classification = "PMO"
				elseif i == 0 then
					ray.classification = "OMP"
				else
					ray.classification = "PMP"
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
					end
				end
			end
		end
	end

	return ray
end

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
end

--- DOCME
-- @tparam Ray_t ray
-- @tparam AABox_t box
-- @treturn boolean X
-- @treturn number Y
function M.SlopeInt (ray, box)
	local t

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

		t = max((box.x1 - ray.x) * ray.ii, (box.y1 - ray.y) * ray.ij, (box.z1 - ray.z) * ray.ik)

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

		t = max((box.x1 - ray.x) * ray.ii, (box.y1 - ray.y) * ray.ij, (box.z0 - ray.z) * ray.ik)

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

		t = max((box.x1 - ray.x) * ray.ii, (box.y0 - ray.y) * ray.ij, (box.z1 - ray.z) * ray.ik)

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

		t = max((box.x1 - ray.x) * ray.ii, (box.y0 - ray.y) * ray.ij, (box.z0 - ray.z) * ray.ik)

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

		t = max((box.x0 - ray.x) * ray.ii, (box.y1 - ray.y) * ray.ij, (box.z1 - ray.z) * ray.ik)

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

		t = max((box.x0 - ray.x) * ray.ii, (box.y1 - ray.y) * ray.ij, (box.z0 - ray.z) * ray.ik)

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

		t = max((box.x0 - ray.x) * ray.ii, (box.y0 - ray.y) * ray.ij, (box.z1 - ray.z) * ray.ik)

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

		t = max((box.x0 - ray.x) * ray.ii, (box.y0 - ray.y) * ray.ij, (box.z0 - ray.z) * ray.ik)

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