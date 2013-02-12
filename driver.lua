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

	textures.Draw(cursor_texture[0], x, y, iw, ih, minx, miny, maxx, maxy, DDD)
end

local color = ffi.new("GLfloat[960]", {
	1.0,  1.0,  0.0, 1.0,  -- 0
	1.0,  0.0,  0.0,  1.0, -- 1
	0.0,  1.0,  0.0, 1.0,  -- 3
	0.0,  0.0,  0.0,  1.0, -- 2

	0.0,  1.0,  0.0, 1.0,  -- 3
	0.0,  1.0,  1.0,  1.0, -- 4
	0.0,  0.0,  0.0, 1.0,  -- 2
	0.0,  0.0,  1.0, 1.0,  -- 7

	1.0,  1.0,  0.0, 1.0,  -- 0
	1.0,  1.0,  1.0, 1.0,  -- 5
	1.0,  0.0,  0.0, 1.0,  -- 1
	1.0,  0.0,  1.0, 1.0,  -- 6

	1.0,  1.0,  1.0, 1.0,  -- 5
	0.0,  1.0,  1.0, 1.0,  -- 4
	1.0,  0.0,  1.0, 1.0,  -- 6
	0.0,  0.0,  1.0, 1.0,  -- 7

	1.0,  1.0,  1.0, 1.0,  -- 5
	1.0,  1.0,  0.0, 1.0,  -- 0
	0.0,  1.0,  1.0, 1.0,  -- 4
	0.0,  1.0,  0.0, 1.0,  -- 3

	1.0,  0.0,  1.0, 1.0,  -- 6
	1.0,  0.0,  0.0, 1.0,  -- 1
	0.0,  0.0,  1.0, 1.0,  -- 7
	0.0,  0.0,  0.0, 1.0,  -- 2
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
xforms.Perspective(matrix, 70, ww / wh, 1, 1000)

render_state.SetProjectionMatrix(matrix)

local mvp = render_state.NewLazyMatrix()

gl.glViewport( 0, 0, ww, wh )
local Diff
local loc_mvp

local SP = shader_helper.NewShader{
	vs = [[
		attribute lowp vec4 color;
		attribute mediump vec3 position;
		varying lowp vec3 col;
		uniform mediump mat4 mvp;

		void main ()
		{
			gl_Position = mvp * vec4(position, 1);

			col = color.rgb;
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
			sp:BindUniformMatrix(loc_mvp, mvp.matrix[0])
		end
	end,

	on_use = function()
		gl.glViewport(0, 0, ww, wh)

		gl.glEnable(gl.GL_DEPTH_TEST)
		gl.glEnable(gl.GL_CULL_FACE)
	end
}
require("marching_cubes")
local loc_color = SP:GetAttributeByName("color")
local loc_position = SP:GetAttributeByName("position")

loc_mvp = SP:GetUniformByName("mvp")

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

function KeyHandler (key, is_down)
	local sym = key.keysym.sym

	if sym == sdl.SDLK_LEFT then
		keys.left = is_down
	elseif sym == sdl.SDLK_RIGHT then
		keys.right = is_down
	end
end

local is_held

function MouseButtonHandler (button, is_down)
	if button.button == 1 then
		is_held = is_down
	end
end

local mx, my = 0, 0

local function Clamp (x)
	return math.min(math.max(x, -10), 10)
end

function MouseMotionHandler (motion)
	if is_held then
		mx, my = Clamp(motion.xrel) * 8 * Diff, Clamp(motion.yrel) * 8 * Diff
	end
end

local dwheel = 0

function MouseWheelHandler (wheel)
	dwheel = wheel.y / 120
end

local x, dx = 0, 1

local CUBE = shapes.GenCube(1)

local lines = require("lines_gles")

local function XYZ (pos, target, t)
	local s = 1 - t
	local x = s * pos[0] + t * target[0]
	local y = s * pos[1] + t * target[1]
	local z = s * (pos[2] + 800) + t * target[2]
	return x, y, z
end

local function Quit ()
	if cursor_texture[0] ~= 0 then
		gl.glDeleteTextures(1, cursor_texture)
	end
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

	SP:BindAttributeStream(loc_color, color, 4)
	SP:BindAttributeStream(loc_position, CUBE.vertices, 3)

	SP:DrawElements(gl.GL_TRIANGLES, CUBE.indices, CUBE.num_indices)

	DrawLogoCursor(100 + x, 100)
lines.Draw(pos[0] + 200, pos[1], pos[2] + 100, target[0], target[1], target[2], {0,1,0}, {1,0,0})
	if x > 200 then
		dx = -1
	elseif x < -200 then
		dx = 1
	end
	x = x + dx
--	sdl.SDL_Delay(200)
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