--- JJJJ

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
local sdl = require("ffi/sdl")

-- Exports --
local M = {}

-- COLLISION --

-- Ufff... broad sweep...
-- Sphere thing

-- WALKING THE SPACE --

-- Rays?
-- Octree...

-- PAINT BEAM --

-- Cylinder collision, then curve

-- VACUUM BEAM --

-- Cone collision, then curve?

-- TODO LIST --
--[[
1: Floor, walls, some stuff in middle generating and displaying
2: Ray collisions
3: Movement
4: Reticle
5: Paint
6: Vacuum
7: Tweakables
8: ???
]]

--- DOCME
-- @ptable funcs
function M.Start (funcs, ww, wh)

local textures = require("textures_gles")

local LOGO_FILE = "icon.bmp"

local cursor_texture = ffi.new("GLuint[1]")

local minx, miny, maxx, maxy, iw, ih

local function DrawLogoCursor (x, y)
	if cursor_texture[0] == 0 then
		local file = sdl.SDL_RWFromFile(LOGO_FILE, "rb")
		local image = sdl.SDL_LoadBMP_RW(file, 1)

		if image ~= nil then
			iw = image.w
			ih = image.h

			cursor_texture[0], minx, miny, maxx, maxy = textures.LoadTexture(image)

			sdl.SDL_FreeSurface(image)
		end

		if cursor_texture[0] == 0 then
			return
		end
	end

	textures.Draw(cursor_texture[0], x, y, iw, ih, minx, miny, maxx, maxy)

	textures.Draw(cursor_texture[0], x + 145, y + 22, iw, ih, minx, miny, maxx, maxy)
end

local color = ffi.new("GLfloat[960]", {
	1.0, 1.0, 0.0, 1.0,  -- 0
	1.0, 0.0, 0.0, 1.0, -- 1
	0.0, 1.0, 0.0, 1.0,  -- 3
	0.0, 0.0, 0.0, 1.0, -- 2

	0.0, 1.0, 0.0, 1.0,  -- 3
	0.0, 1.0, 1.0, 1.0, -- 4
	0.0, 0.0, 0.0, 1.0,  -- 2
	0.0, 0.0, 1.0, 1.0,  -- 7

	1.0, 1.0, 0.0, 1.0,  -- 0
	1.0, 1.0, 1.0, 1.0,  -- 5
	1.0, 0.0, 0.0, 1.0,  -- 1
	1.0, 0.0, 1.0, 1.0,  -- 6

	1.0, 1.0, 1.0, 1.0,  -- 5
	0.0, 1.0, 1.0, 1.0,  -- 4
	1.0, 0.0, 1.0, 1.0,  -- 6
	0.0, 0.0, 1.0, 1.0,  -- 7

	1.0, 1.0, 1.0, 1.0,  -- 5
	1.0, 1.0, 0.0, 1.0,  -- 0
	0.0, 1.0, 1.0, 1.0,  -- 4
	0.0, 1.0, 0.0, 1.0,  -- 3

	1.0, 0.0, 1.0, 1.0,  -- 6
	1.0, 0.0, 0.0, 1.0,  -- 1
	0.0, 0.0, 1.0, 1.0,  -- 7
	0.0, 0.0, 0.0, 1.0,  -- 2
})
for i = 1, 9 do
	for j = 0, 95 do
	color[i * 96 + j] = color[j]
	end
end

local shader_helper = require("lib.shader_helper")
local shapes = require("shapes_gles")
local xforms = require("transforms_gles")
local render_state = require("render_state_gles")

local matrix = xforms.New()

xforms.MatrixLoadIdentity(matrix)
xforms.Perspective(matrix, 70, ww / wh, .1, 1000)

render_state.SetProjectionMatrix(matrix)
local oo=matrix
local mvp = render_state.NewLazyMatrix()

gl.glViewport( 0, 0, ww, wh )
local Diff
local loc_mvp

local CUBE = shapes.GenCube(1)

local state
local SP = shader_helper.NewShader{
	vs = [[
		attribute lowp vec4 color;
		attribute mediump vec3 position;
		varying lowp vec3 col;
		uniform mediump mat4 mvp;
		uniform mediump float bb;

		void main ()
		{
			gl_Position = mvp * vec4(position, 1);

			col = color.rgb + bb * 1e-9;
		}
	]],

	fs = [[
		varying lowp vec3 col;

		void main ()
		{
			gl_FragColor = vec4(col, 1);
		}
	]],

	on_draw = function(sp)
		if render_state.GetModelViewProjection_Lazy(mvp) then
			sp:BindUniformMatrix(loc_mvp, mvp)
		end
	end,

	on_init = function(sp)
		loc_mvp = sp:GetUniformByName("mvp")

		state = sp:SetupBuffers{
			{ data = color, loc = "color", attr_size = 4 },
			{ data = CUBE.vertices, loc = "position", attr_size = 3 },
			indices = { data = CUBE.indices }
		}
	end,

	on_use = function()
		gl.glViewport(0, 0, ww, wh)

		gl.glEnable(gl.GL_DEPTH_TEST)
		gl.glEnable(gl.GL_CULL_FACE)
	end
}

local mc = require("mouse_camera")
local v3math = require("lib.v3math")

mc.Init(v3math.new(0, 1.5, -2), v3math.new(0, 0, 1), v3math.new(0, 1, 0))

local keys = {}

local function CalcMove (a, b, n)
	local move = 0

	if keys[a] then
		move = move - n
	end

	if keys[b] then
		move = move + n
	end

	return move * Diff
end

local PX, PY, PZ = -.75, 0, 1.5
local P = ffi.new("double[3]", PX - .1, PY, PZ)
local Q = ffi.new("double[3]", PX + .1, PY, PZ)
local UsingP = true

local function Corner (x, y, z, ext)
	local xmin, ymin, zmin = x - ext, y - ext, z - ext
	local xmax, ymax, zmax = x + ext, y + ext, z + ext

	return xmin, ymin, zmin, xmax, ymax, zmax
end

local rs = require("ray_slopes")

local Box = rs.MakeAABox(Corner(PX, PY, PZ, .1))
local HitColor, BoxColor = { 0, 1, 0 }

function KeyHandler (key, is_down)
	local sym = key.keysym.sym

	if sym == sdl.SDLK_LEFT then
		keys.left = is_down
	elseif sym == sdl.SDLK_RIGHT then
		keys.right = is_down
	end

	if is_down then
		local pt = UsingP and P or Q

		if sym == sdl.SDLK_a then
			pt[0] = pt[0] - .1
		elseif sym == sdl.SDLK_d then
			pt[0] = pt[0] + .1
		elseif sym == sdl.SDLK_w then
			pt[1] = pt[1] - .1
		elseif sym == sdl.SDLK_s then
			pt[1] = pt[1] + .1
		elseif sym == sdl.SDLK_j then
			pt[2] = pt[2] - .1
		elseif sym == sdl.SDLK_k then
			pt[2] = pt[2] + .1
		elseif sym == sdl.SDLK_SPACE then
			UsingP = not UsingP
		else
			return
		end

		if sym ~= sdl.SDLK_SPACE then
			local ray = rs.MakeRay(P[0], P[1], P[2], Q[0], Q[1], Q[2])

			local hit, when = rs.SlopeInt(ray, Box)
			if hit then
			print("HIT AT", when)
				BoxColor = HitColor
			else
				BoxColor = nil
			end
		end
	end
end

local N, D = 1, .5

local function VisitCube (func)
	local index = 1

	for i = -N, N, D do
		for j = -N, N, D do
			for k = -N, N, D do
				func(i, j, k, D, index)

				index = index + 1
			end
		end
	end
end

local MC = require("marching_cubes.core")

local Dim = N / D * 2 + 1
local DD = 5
local mcw = MC.Init(Dim * DD, Dim * DD, Dim * DD)

local MMM

local function mc_func (p0, p1, p2)
	local a, b, c = ffi.new("double[3]"), ffi.new("double[3]"), ffi.new("double[3]")

	for i = 0, 2 do
		a[i] = -N + (p0[i] - D * (DD - 1)) * D / DD -- ???
		b[i] = -N + (p1[i] - D * (DD - 1)) * D / DD
		c[i] = -N + (p2[i] - D * (DD - 1)) * D / DD
	end

	MMM[#MMM + 1] = {a, b, c}
end

local is_held
local LLL

function MouseButtonHandler (button, is_down)
	if button.button == 1 then
		is_held = is_down
	end
	if button.button == 3 then
		if is_down then
		local mvpi = xforms.New()
		local viewport = ffi.new("int[4]")

		render_state.GetModelViewProjection(mvpi)
		gl.glGetIntegerv(gl.GL_VIEWPORT, viewport)
		xforms.Invert(mvpi, mvpi)

		local oc = ffi.new("double[3]")

		xforms.Unproject_InverseMVP(button.x, viewport[3] - button.y, 0, mvpi, viewport, oc)

		local x, y, z = oc[0], oc[1], oc[2]

		xforms.Unproject_InverseMVP(button.x, viewport[3] - button.y + 2, 1, mvpi, viewport, oc)

		LLL = {}
		MMM = {}
		local ray = rs.MakeRayTo(x, y, z, oc[0], oc[1], oc[2])
		mcw:Reset()
		VisitCube(function(i, j, k, d, index)
			local box = rs.MakeAABox(Corner(i, j, k, d / 2--[[ * .8]]))

			LLL[index] = rs.SlopeInt(ray, box)
			if LLL[index] then
				local ii, jj, kk = (i + N) / D, (j + N) / D, (k + N) / D
				local ci, cj, ck = (DD - 1) / 2, (DD - 1) / 2, (DD - 1) / 2
				local len = ci * ci + cj * cj + ck * ck

				for io = 0, DD - 1 do
					local id = (io - ci) * (io - ci)
					for jo = 0, DD - 1 do
						local jd = (jo - cj) * (jo - cj)
						for ko = 0, DD - 1 do
							local kd = (ko - ck) * (ko - ck)
							local v = -len / 2 + (id + jd + kd)
local xx = i + io * D / DD
local yy = j + jo * D / DD
local zz = k + ko * D / DD
local a = (xx - ray.x) * ray.i + (yy - ray.y) * ray.j + (zz - ray.z) * ray.k
if a < 0 then
	v = 1
else
	local x2, y2, z2 = ray.x + ray.i * a, ray.y + ray.j * a, ray.z + ray.k * a
	v = math.sqrt((xx - x2)^2 + (yy - y2)^2 + (zz - z2)^2) - .25 * D
end
							mcw:Set(ii * DD + io, jj * DD + jo, kk * DD + ko, v)
						end
					end
				end
			end
		end)
		MC.BuildIsoSurface(mcw, mc_func)
		else
--			LLL = nil
		end
	end
end

local mx, my = 0, 0

local function Clamp (x)
	return math.min(math.max(x, -10), 10)
end
--sdl.SDL_ShowCursor(0)
function MouseMotionHandler (motion)
	if is_held then
		mx, my = Clamp(motion.xrel) * 8 * Diff, Clamp(motion.yrel) * 8 * Diff
--sdl.SDL_WarpMouseInWindow(sdl.SDL_GetMouseFocus(), 255, 255)
	end
end

local dwheel = 0

function MouseWheelHandler (wheel)
	dwheel = wheel.y / 120
end

local x, dx = 0, 1

local lines = require("lines_gles")

local function Quit ()
	if cursor_texture[0] ~= 0 then
		gl.glDeleteTextures(1, cursor_texture)
	end
end

local function DrawBoxAt (x, y, z, ext, color)
	local xmin, ymin, zmin, xmax, ymax, zmax = Corner(x, y, z, ext)

	lines.Draw(xmin, ymin, zmin, xmax, ymin, zmin, color)
	lines.DrawTo(xmax, ymax, zmin)
	lines.DrawTo(xmax, ymax, zmax)
	lines.DrawTo(xmin, ymax, zmax)
	lines.DrawTo(xmin, ymax, zmin)
	lines.DrawTo(xmin, ymin, zmin)
	lines.DrawTo(xmin, ymin, zmax)
	lines.DrawTo(xmax, ymin, zmax)
	lines.DrawTo(xmax, ymax, zmax)

	lines.Draw(xmin, ymax, zmin, xmax, ymax, zmin, color)
	lines.Draw(xmin, ymin, zmax, xmin, ymax, zmax, color)
	lines.Draw(xmax, ymin, zmin, xmax, ymin, zmax, color)
end

local function Test ()
	local ddir = dwheel * .2
	local dside = CalcMove("left", "right", .2)

	dwheel = 0

	mc.Update(ddir, dside, -mx, my)

	mx, my, dwheel = 0, 0, 0

	local pos = v3math.new()
	local dir = v3math.new()
	local side = v3math.new()
	local up = v3math.new()

	mc.GetVectors(pos, dir, side, up)

	xforms.MatrixLoadIdentity(matrix)

	local target = v3math.addnew(pos, dir)

	xforms.LookAt(matrix, pos[0], pos[1], pos[2], target[0], target[1], target[2], up[0], up[1], up[2])

	render_state.SetModelViewMatrix(matrix)

	SP:Use()
	SP:DrawBufferedElements(gl.GL_TRIANGLES, state)

	DrawLogoCursor(100 + x, 100)

--lines.Draw(pos[0] + 200, pos[1], pos[2] + 100, target[0], target[1], target[2], {0,1,0}, {1,0,0})
	VisitCube(function(i, j, k, D, index)
		DrawBoxAt(i, j, k, D / 2--[[ * .8]], (LLL and LLL[index]) and HitColor or nil)
	end)
DrawBoxAt(P[0], P[1], P[2], .025, { 0, 0, 1 })
DrawBoxAt(PX, PY, PZ, .1, BoxColor)
lines.Draw(P[0], P[1], P[2], Q[0], Q[1], Q[2], { 0, 1, 0 })
if MMM then
	for _, t in ipairs(MMM) do
		local a, b, c = t[1], t[2], t[3]
		lines.Draw(a[0], a[1], a[2], b[0], b[1], b[2], { 0, 0, 1 })
		lines.DrawTo(c[0], c[1], c[2])
		lines.DrawTo(a[0], a[1], a[2])
	end
end
	if x > 200 then
		dx = -1
	elseif x < -200 then
		dx = 1
	end
	x = x + dx
--	sdl.SDL_Delay(200)
if LLL then
if not DD then
	DD = true
end
--	lines.Draw(unpack(LLL))
end
end





	funcs.key = KeyHandler
	funcs.mouse_button = MouseButtonHandler
	funcs.mouse_motion = MouseMotionHandler
	funcs.mouse_wheel = MouseWheelHandler
	funcs.pre_update = function(dt)
		Diff = dt
	end
	funcs.quit = Quit
	funcs.update = Test
end

-- Export the module.
return M