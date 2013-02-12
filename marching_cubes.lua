--- This module implements the marching cubes algorithm.
--
-- See also: http://paulbourke.net/geometry/polygonise/

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
local abs = math.abs
local huge = math.huge
local max = math.max
local min = math.min

-- Modules --
local ffi = require("ffi")
local bit = require("bit")
local v3math = require("lib.v3math")

-- Imports --
local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local lshift = bit.lshift

-- Exports --
local M = {}

-- --
local TriTable = ffi.new("int[256][16]", require("marching_cubes_lut"))

-- --
local dvector = v3math.new
local dvector_array = ffi.typeof("$[?]", dvector)

-- private float mIsoLevel;

-- Linearly interpolate the position where an isosurface cuts
-- an edge between two vertices, each with their own scalar value
local function VertexInterp (grid, i1, i2)
	local p1, valp1 = grid.p[i1], grid.val[i1]
	local p2, valp2 = grid.p[i2], grid.val[i2]

	if abs(ISOLEVEL - valp1) < 0.00001 then
		return p1
	end

	if abs(ISOLEVEL - valp2) < 0.00001 then
		return p2
	end

	if abs(valp1 - valp2) < 0.00001 then
		return p1
	end

	local mu = (ISOLEVEL - valp1) / (valp2 - valp1)

	return v3math.addscalednew(p1, v3math.subnew(p2, p1), mu)
end

-- --
local Merge = ffi.new("int[12]", { 0, 0, 0, 4, 0, 0, 0, 12, 13, 15, 13, 11 })

-- --
local VertList = dvector_array(12)

--
local function GetVertex (grid, index, computed)
	local mask = lshift(1, index)

	if band(computed, mask) == 0 then
		computed = bor(computed, mask)

		VertList[index] = VertexInterp(grid, band(index, 7), bxor(index + 1, Merge[index]))
	end

	return VertList[index], computed
end

-- Given a grid cell and an isolevel, calculate the triangular
-- facets required to represent the isosurface through the cell.
-- Return the number of triangular facets, the array "triangles"
-- will be loaded up with the vertices at most 5 triangular facets.
-- 0 will be returned if the grid cell is either totally above
-- of totally below the isolevel.
local function Polygonise (grid, triangles)
	-- Determine the index into the edge table which
	-- tells us which vertices are inside of the surface
	local cubeindex = 0
	
	for i = 0, 7 do
		if grid.val[i] < ISOLEVEL then
			cubeindex = bor(cubeindex, lshift(1, i))
		end
	end

	-- Create the triangle
	local computed, index, ntri = 0, 0, 0

	while TriTable[cubeindex][index] ~= -1 do
		triangles[ntri].p[0], computed = GetVertex(grid, TriTable[cubeindex][index + 0], computed)
		triangles[ntri].p[1], computed = GetVertex(grid, TriTable[cubeindex][index + 1], computed)
		triangles[ntri].p[2], computed = GetVertex(grid, TriTable[cubeindex][index + 2], computed)

		ntri, index = ntri + 1, index + 3
	end

	return ntri
end

--
local function BuildTriangle (tri, grid, a1, a2, b1, b2, c1, c2)
	tri.p[0] = VertexInterp(grid, a1, a2)
	tri.p[1] = VertexInterp(grid, b1, b2)
	tri.p[2] = VertexInterp(grid, c1, c2)
end

--
local function BuildAndJoin (tri, grid, a1, a2, prev, pi1, pi2)
	tri.p[0] = prev.p[pi1]
	tri.p[1] = VertexInterp(grid, a1, a2)
	tri.p[2] = prev.p[pi2]
end

--[[
   Polygonise a tetrahedron given its vertices within a cube
   This is an alternative algorithm to polygonise grid.
   It results in a smoother surface but more triangular facets.

                      + 0
                     /|\
                    / | \
                   /  |  \
                  /   |   \
                 /    |    \
                /     |     \
               +-------------+ 1
              3 \     |     /
                 \    |    /
                  \   |   /
                   \  |  /
                    \ | /
                     \|/
                      + 2

   Its main purpose is still to polygonise a gridded dataset and
   would normally be called 6 times, one for each tetrahedron making
   up the grid cell.
]]
local function PolygoniseTri (cell, triangles, v0, v1, v2, v3, ntri)
	-- Determine which of the 16 cases we have given which vertices
	-- are above or below the isosurface
	local tindex = 0

	if cell.val[v0] < ISOLEVEL then
		tindex = bor(tindex, 1)
	end

	if cell.val[v1] < ISOLEVEL then
		tindex = bor(tindex, 2)
	end

	if cell.val[v2] < ISOLEVEL then
		tindex = bor(tindex, 4)
	end

	if cell.val[v3] < ISOLEVEL then
		tindex = bor(tindex, 8)
	end

	-- Form the vertices of the triangles for each case	
	local cur = triangles[ntri]

	tindex = min(tindex, 0xF - tindex)

	if tindex == 0 then
		return ntri
	elseif tindex == 1 then
		BuildTriangle(cur, cell, v0, v1, v0, v2, v0, v3)
	elseif tindex == 2 then
		BuildTriangle(cur, cell, v1, v0, v1, v3, v1, v2)
	elseif tindex == 3 then
		BuildTriangle(cur, cell, v0, v3, v0, v2, v1, v3)

		ntri = ntri + 1

		BuildAndJoin(triangles[ntri], cell, v1, v2, cur, 2, 1)
	elseif tindex == 4 then
		BuildTriangle(cur, cell, v2, v0, v2, v1, v2, v3)
	elseif tindex == 5 then
		BuildTriangle(cur, cell, v0, v1, v2, v3, v0, v3)

		ntri = ntri + 1

		BuildAndJoin(triangles[ntri], cell, v1, v2, cur, 0, 1)
	elseif tindex == 6 then
		BuildTriangle(cur, cell, v0, v1, v1, v3, v2, v3)

		ntri = ntri + 1

		BuildAndJoin(triangles[ntri], cell, v0, v2, cur, 0, 2)
	elseif tindex == 7 then
		BuildTriangle(cur, cell, v3, v0, v3, v2, v3, v1)
	end

	return ntri + 1
end

function M.PolygoniseTetra (cell, triangles)
	local ntri = 0

	ntri = PolygoniseTri(cell, triangles, 0, 2, 3, 7, ntri)
	ntri = PolygoniseTri(cell, triangles, 0, 2, 6, 7, ntri)
	ntri = PolygoniseTri(cell, triangles, 0, 4, 6, 7, ntri)
	ntri = PolygoniseTri(cell, triangles, 0, 6, 1, 2, ntri)
	ntri = PolygoniseTri(cell, triangles, 0, 6, 1, 4, ntri)
	ntri = PolygoniseTri(cell, triangles, 5, 6, 1, 4, ntri)

	return ntri
end

--[[
    private int[] mData;
    private int mMin, mMax;
    private float mDx, mDy, mDz;
    private int mNx, mNy, mNz;
    private int mRx, mRy, mRz;
    private int mResolution;
]]
-- Calculate the grid bounds
-- Set a default isolevel
-- Set an initial resolution
local function CalcBounds ()
	if DATA == nil then
		return
	end

	local NxNyNz, sum = NX * NY * NZ, 0

	-- Find the range
	MIN, MAX = huge, -huge

	for i = 0, NxNyNz - 1 do
		MAX = max(MAX, DATA[i])
		MIN = min(MIN, DATA[i])

		sum = sum + DATA[i]
	end

	if MIN >= MAX then
		MAX = MAX + 1
	end

	-- Reset the isolevel
	ISOLEVEL = sum / NxNyNz
	
	if ISOLEVEL < MIN or ISOLEVEL > MAX then
		ISOLEVEL = (MAX + MIN) / 2
	end

	-- Set an appropriate resolution
	RESOLUTION = min(max(NX, NY, NZ) / 20 + 1, 10)
end

--
local function SetCell (cell, ci, i, j, k, NxNy)
	cell.p[ci].x = i * DX
	cell.p[ci].y = j * DY
	cell.p[ci].z = k * DZ

    local index = k * NxNy + j * NX + i

    cell.val[ci] = DATA[index]
end

-- --
local MaxPolygons = 10000

--[[
    void CopyTo<T> (ref T[] arr, int extra)
    {
        T[] newa = new T[arr.Length + extra];

        Array.Copy(newa, arr, arr.Length);

        arr = newa;
    }

    void Trim<T> (ref T[] arr, int count)
    {
        if (arr.Length > count) Array.Resize(ref arr, count);
    }
]]

--
local GridCell = ffi.typeof([[
	struct {
		$ p[8];
		double val[8];
	}
]], dvector)

--
local Triangle = ffi.typeof([[
	struct {
		$ p[3];
	}[?]
]], dvector)

-- --
local sTri = Triangle(12)

-- Draw the isosurface facets
function M.DrawIsoSurface (mesh, pos)
    local cell = GridCell()

	local NxNy, npolygons, vi = NX * NY, 0, 0

	local VLen = 200 * 3
	
	local verts = dvector_array(VLen)
--	local uv = ffi.new(
--	local triangles = ffi.new(

	for i = 0, NX - 1, RX do
		local ii = min(i + RX, NX - 1)

		for j = 0, NY - 1, RY do
			local jj = min(j + RY, NY - 1)

			for k = 0, NZ - 1, RZ do
				local kk = min(k + RZ, NZ - 1)

				SetCell(cell, 0, i, j, k, NxNy)
				SetCell(cell, 1, ii, j, k, NxNy)
				SetCell(cell, 2, ii, j, kk, NxNy)
				SetCell(cell, 3, i, j, kk, NxNy)
				SetCell(cell, 4, i, jj, k, NxNy)
				SetCell(cell, 5, ii, jj, k, NxNy)
				SetCell(cell, 6, ii, jj, kk, NxNy)
				SetCell(cell, 7, i, jj, kk, NxNy)

                local ntri = M.Polygonise(cell, sTri)

                npolygons = npolygons + ntri

				for t = 0, ntri - 1 do
					if vi + 3 > VLen then
					    -- CopyTo(ref verts, 50 * 3);
                        -- CopyTo(ref uv, 50 * 3); // ?
                        -- CopyTo(ref triangles, 50 * 3); // More or less...
					end

					for v = 0, 2 do
						verts[vi] = pos + sTri[t].p[v]	-- * dx, dy, dz

						-- Triangles, uv
						vi = vi + 1
					end
				end
                    
                if npolygons > MaxPolygons then
					return
				end
			end
		end
	end

        -- REBASE INDICES?
--[[
        Trim(ref verts, vi);
        Trim(ref uv, vi); // ?
        Trim(ref triangles, vi); // *sigh*

        mesh.vertices = verts;
        mesh.uv = uv;
        mesh.triangles = triangles;
]]
end
--[[
	Bounds mCube;
	
	//
    public void Reset (Bounds cube)
    {
        mNx = mNy = mNz = 70;//50;
        mRx = mRy = mRz = 4;
        mDx = mDy = mDz = 1;
        mResolution = 2;
        mIsoLevel = 256;

		mData = new int[mNx * mNy * mNz];

		mCube = cube;
		
		mDx = cube.size.x / mNx;
		mDy = cube.size.y / mNy;
		mDz = cube.size.z / mNz;
	}

	float RaycastInsideCube (Bounds cube, Ray ray)
	{
		Vector3 target = ray.GetPoint(cube.size.magnitude + 1);
		
		Ray rev = new Ray(target, -ray.direction);
		
		// Determine when the ray will leave the "world".
        float endt;

        if (!cube.IntersectRay(rev, out endt)) return -1;

		return (rev.GetPoint(endt) - ray.origin).magnitude;
	}
	
    public void WalkRay (Bounds cube, Ray ray, int isov, float range)
    {
		// Determine when the ray will leave the "world".
        float endt = Math.Min(RaycastInsideCube(cube, ray), range);

        if (endt >= 0)
        {
            // Compute the size of a voxel.
            Vector3 size = cube.size;

            size.x /= mNx;
            size.y /= mNy;
            size.z /= mNz;

            Bounds voxel = new Bounds(Vector3.zero, size);
			
			int NxNy = mNx * mNy;
			
            // Walk until the ray leaves the world.
            float t = 0;

            while (t < endt)
            {
                // Get the voxel indices.
                Vector3 pos = ray.origin - cube.min;

                int i = Mathf.FloorToInt(pos.x / size.x);
                int j = Mathf.FloorToInt(pos.y / size.y);
                int k = Mathf.FloorToInt(pos.z / size.z);

                // Update the voxel isovalue.
				int index = k * NxNy + j * mNx + i;
				
				mData[index] = Math.Max(mData[index], isov);

                // Put a bounding cube at the voxel center.
                Vector3 center = cube.min;

                center.x += (.5f + i) * size.x;
                center.y += (.5f + j) * size.y;
                center.z += (.5f + k) * size.z;
				
				voxel.center = center;

                // Find where the ray leaves the voxel, step slightly past it (into the next
                // voxel), and accumulate the time spent.
                float hitt = RaycastInsideCube(voxel, ray);

                if (hitt < 0) return; // ????

                ray.origin = ray.GetPoint(hitt + .001f);

                t += hitt + .001f;
            }
        }
    }
}
]]


local function Swap (a, b)
	if a <= b then
		return a, b
	else
		return b, a
	end
end

local function STUFF ()
	-- Make a "world" cube that encloses all the sub-beams.
	local EXTRA = v3math(1,1,1)*(Radius + .001)
	local P = pos + BeginAt * dir
	local Q = P + max_range * dir

	P.x, Q.x = Swap(P.x, Q.x)
	P.y, Q.y = Swap(P.y, Q.y)
	P.z, Q.z = Swap(P.z, Q.z)

	local WORLD = Bounds(P - EXTRA, Q + EXTRA)

	MarchingCubes.Reset(WORLD)
	
	-- SOME MESH THING
	
	-- RESET MESH

	
	for i = 0, NDisps - 1 do
		local disp = Disps[i]

        ray.origin = pos + BeginAt * dir + (right * disp.x + transform.up * disp.y) * Radius

        MarchingCubes.WalkRay(world, ray, (int)(256 - disp.SqrMagnitude() * r2 * 32), min(RANGES[i], LEN))
	end

	MarchingCubes.CalcBounds()
	MarchingCubes.DrawIsoSurface(MESH, world.min)

	MESH.RecalculateNormals()
end

-- Export the module.
return M