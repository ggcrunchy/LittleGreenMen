-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min

-- Modules --
local func_ops = require("func_ops")
local iterators = require("iterators")

-- Imports --
local InstancedAutocacher = iterators.InstancedAutocacher
local NoOp = func_ops.NoOp

-- Cached module references --
local _BoxesIntersect_
local _CellToIndex_
local _DivRem_
local _SortPairs_
local _SwapIf_

--[[
--- An assortment of useful numeric operations.
module "numeric_ops"
]]
local _M = {}

---
-- @param x1 Box #1 x-coordinate.
-- @param y1 Box #1 y-coordinate.
-- @param w1 Box #1 width.
-- @param h1 Box #1 height.
-- @param x2 Box #2 x-coordinate.
-- @param y2 Box #2 y-coordinate.
-- @param w2 Box #2 width.
-- @param h2 Box #2 height.
-- @return If true, the boxes intersect.
function _M.BoxesIntersect (x1, y1, w1, h1, x2, y2, w2, h2)
	return not (x1 > x2 + w2 or x2 > x1 + w1 or y1 > y2 + h2 or y2 > y1 + h1)
end

--
-- @param bx Contained box x-coordinate.
-- @param by Contained box y-coordinate.
-- @param bw Contained box width.
-- @param bh Contained box height.
-- @param x Containing box x-coordinate.
-- @param y Containing box y-coordinate.
-- @param w Containing box width.
-- @param h Containing box height.
-- @return If true, the first box is contained by the second.
function _M.BoxInBox (bx, by, bw, bh, x, y, w, h)
	return not (bx < x or bx + bw > x + w or by < y or by + bh > y + h)
end

--- Variant of <b>BoxesIntersect</b> with intersection information.
-- @param x1 Box #1 x-coordinate.
-- @param y1 Box #1 y-coordinate.
-- @param w1 Box #1 width.
-- @param h1 Box #1 height.
-- @param x2 Box #2 x-coordinate.
-- @param y2 Box #2 y-coordinate.
-- @param w2 Box #2 width.
-- @param h2 Box #2 height.
-- @return If true, boxes intersect.
-- @return If the boxes intersect, the intersection x, y, w, h.
-- @see BoxesIntersect
function _M.BoxIntersection (x1, y1, w1, h1, x2, y2, w2, h2)
	if not _BoxesIntersect_(x1, y1, w1, h1, x2, y2, w2, h2) then
		return false
	end

	local sx, sy = max(x1, x2), max(y1, y2)

	return true, sx, sy, min(x1 + w1, x2 + w2) - sx, min(y1 + h1, y2 + h2) - sy
end

--- Clamps a number between two bounds.<br><br>
-- The bounds are swapped if out of order.
-- @param number Number to clamp.
-- @param minb Minimum bound.
-- @param maxb Maximum bound.
-- @return Clamped number.
function _M.ClampIn (number, minb, maxb)
	minb, maxb = _SwapIf_(minb > maxb, minb, maxb)

	return min(max(number, minb), maxb)
end

--- Returns the squared distance between two points in 2d.
--   @param x1
--   @param x2
--   @param y1
--   @param y2
-- @return Squared distance.
function _M.Distance2DSquared( x1, y1, x2, y2 )
	return ((x2 - x1)^2)  +	 ((y2 - y1)^2)
end

--- Breaks the result of <i>a</i> / <i>b</i> up into a count and remainder.
-- @param a Dividend.
-- @param b Divisor.
-- @return Integral number of times that <i>b</i> divides <i>a</i>.
-- @return Fractional part of <i>b</i> left over after the integer part is considered.
function _M.DivRem (a, b)
	local quot = floor(a / b)

	return quot, a - quot * b
end

--- Resolves a value to a slot in a uniform range.
-- @param value Value to resolve.
-- @param base Base value; values in [<i>base</i>, <i>base</i> + <i>dim</i>) fit to slot 1.
-- @param dim Slot size.
-- @return Slot index.
function _M.FitToSlot (value, base, dim)
	return floor((value - base) / dim) + 1
end

--- Gets the cell components of a flat array index when the array is considered as a grid.
-- @param index Array index.
-- @param w Grid row width.
-- @return Column index.
-- @return Row index.
-- @see CellToIndex
function _M.IndexToCell (index, w)
	local row, col = _DivRem_(index - 1, w)

	return col + 1, row + 1
end

--- Gets the index of a grid cell when that grid is considered as a flat array.
-- @param col Column index.
-- @param row Row index.
-- @param w Grid row width.
-- @return Index.
-- @see IndexToCell
function _M.CellToIndex (col, row, w)
	return (row - 1) * w + col
end

--- Iterator over a rectangular region on an array-based grid.
-- @class function
-- @name GridIter
-- @param c1 Column index #1.
-- @param r1 Row index #1.
-- @param c2 Column index #2.
-- @param r2 Row index #2.
-- @param dw Uniform cell width.
-- @param dh Uniform cell height.
-- @param ncols Number of columns in a grid row. If absent, this is assumed to be the
-- larger of <i>c1</i> and <i>c2</i>.
-- @return Instanced iterator, which returns the following, in order, at each iteration:<br><br>
-- &nbsp&nbsp- Current iteration index.<br>
-- &nbsp&nbsp- Array index, as per <b>CellToIndex</b>.<br>
-- &nbsp&nbsp- Column index.<br>
-- &nbsp&nbsp- Row index.<br>
-- &nbsp&nbsp- Cell corner x-coordinate, 0 at <i>c</i> = 1.<br>
-- &nbsp&nbsp- Cell corner y-coordinate, 0 at <i>r</i> = 1.
-- @see CellToIndex
-- @see ~iterators.InstancedAutocacher
_M.GridIter = InstancedAutocacher(function()
	local c1, r1, c2, r2, dw, dh, ncols, cw

	-- Body --
	return function(_, i)
		local dr, dc = _DivRem_(i, cw)

		dc = c2 < c1 and -dc or dc
		dr = r2 < r1 and -dr or dr

		local col = c1 + dc
		local row = r1 + dr

		return i + 1, _CellToIndex_(col, row, ncols), col, row, (col - 1) * dw, (row - 1) * dh
	end,

	-- Done --
	function(area, i)
		return i >= area
	end,

	-- Setup --
	function(...)
		c1, r1, c2, r2, dw, dh, ncols = ...
		ncols = ncols or max(c1, c2)
		cw = abs(c2 - c1) + 1

		return cw * (abs(r2 - r1) + 1), 0
	end,

	-- Reclaim --
	NoOp
end)

---
-- @param index Index to test.
-- @param size Size of range.
-- @param okay_after If true, the index may immediately follow the range.
-- @return If true, <i>index</i> is in the range.
function _M.IndexInRange (index, size, okay_after)
	return index > 0 and index <= size + (okay_after and 1 or 0)
end

---
-- @param px Point x-coordinate.
-- @param py Point y-coordinate.
-- @param x Box x-coordinate.
-- @param y Box y-coordinate.
-- @param w Box width.
-- @param h Box height.
-- @return If true, the point is contained by the box.
function _M.PointInBox (px, py, x, y, w, h)
	return px >= x and px < x + w and py >= y and py < y + h
end

--- Computes the overlap between an interval [<i>start</i>, <i>start</i> + <i>count</i>)
-- and a range [1, <i>size</i>].
-- @param start Starting index of interval.
-- @param count Count of items in interval.
-- @param size Length of range.
-- @return Size of intersection.
function _M.RangeOverlap (start, count, size)
	if start > size then
		return 0
	elseif start + count <= size + 1 then
		return count
	end

	return size - start + 1
end

--- Converts coordinate pairs into a rectangle.
-- @param x1 x-coordinate #1.
-- @param y1 y-coordinate #1.
-- @param x2 x-coordinate #2.
-- @param y2 y-coordinate #2.
-- @return Corner x-coordinate.
-- @return Corner y-coordinate.
-- @return Width.
-- @return Height.
-- @see SortPairs
function _M.Rect (x1, y1, x2, y2)
	x1, y1, x2, y2 = _SortPairs_(x1, y1, x2, y2)

	return x1, y1, x2 - x1, y2 - y1
end

--- Increments or decrements an index, rolling it around if it runs off the end of a range.
-- @param index Index to rotate.
-- @param size Size of range.
-- @param to_left If true, rotate left; otherwise, right.
-- @return Rotated index.
function _M.RotateIndex (index, size, to_left)
	if to_left then
		return index > 1 and index - 1 or size
	else
		return index < size and index + 1 or 1
	end
end

--- Sorts two pairs so the coordinates are ordered.
-- @param x1 x-coordinate #1.
-- @param y1 y-coordinate #1.
-- @param x2 x-coordinate #2.
-- @param y2 y-coordinate #2.
-- @return min(<i>x1</i>, <i>x2</i>)
-- @return min(<i>y1</i>, <i>y2</i>)
-- @return max(<i>x1</i>, <i>x2</i>)
-- @return max(<i>y1</i>, <i>y2</i>)
function _M.SortPairs (x1, y1, x2, y2)
	x1, x2 = _SwapIf_(x1 > x2, x1, x2)
	y1, y2 = _SwapIf_(y1 > y2, y1, y2)

	return x1, y1, x2, y2
end

--- Convenience function to return two values in a given order.
-- @param swap If true, swap <i>a</i> and <i>b</i>.
-- @param a Value #1.
-- @param b Value #2.
-- @return <i>a</i>, or <i>b</i> if <i>swap</i> was true.
-- @return <i>b</i>, or <i>a</i> if <i>swap</i> was true.
function _M.SwapIf (swap, a, b)
	if swap then
		return b, a
	end

	return a, b
end

--- Computes the height, at a given <i>x</i>, of a trapezoid whose parallel sides are
-- segments of the x-axis and y = 1.
-- @param x Distance along the x-axis.
-- @param grow_until Distance at which flat top begins.
-- @param flat_until Distance at which flat top ends.
-- @param drop_until Distance at which trapezoid ends.
-- @return Height at <i>x</i>, in [0, 1]; if <i>x</i> is less than 0 or greater than
-- <i>drop_until</i>, returns 0.
function _M.Trapezoid (x, grow_until, flat_until, drop_until)
	if x < 0 or x > drop_until then
		return
	elseif x <= grow_until then
		return x / grow_until
	elseif x <= flat_until then
		return 1
	else
		return 1 - (x - flat_until) / (drop_until - flat_until)
	end
end

--- Exclusive-ors two conditions.
-- @param b1 Condition #1.
-- @param b2 Condition #2.
-- @return If true, either <i>b1</b> or <i>b2</i> (but not both) is true.
function _M.XOR (b1, b2)
	return not b1 ~= not b2
end

-- Cache module members.
_BoxesIntersect_ = _M.BoxesIntersect
_CellToIndex_ = _M.CellToIndex
_DivRem_ = _M.DivRem
_SortPairs_ = _M.SortPairs
_SwapIf_ = _M.SwapIf

-- Export the module.
return _M