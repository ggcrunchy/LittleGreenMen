-- Standard library imports --
local assert = assert

-- Modules --
local bit = require("bit")
local ffi = require("ffi")
local heap_utils = require("heap_utils")

-- Imports --
local band = bit.band
local cast = ffi.cast
local lshift = bit.lshift

-- Cached module references --
local _DecreaseKey_
local _DeleteMin_
local _Insert_UserNode_

--[[
--- This module implements a Fibonacci heap data structure.
module "fibonacci_heap"
--]]
local _M = {}

-- Helper to add a node to a cycle
local function AddToCycle (root, node)
	node.marked = false

	local lnode = root.left

	node.left = lnode
	node.right = root

	lnode.right = node
	root.left = node
end

-- Helper to link two nodes on one side
local function LinkLR (lnode, rnode)
	rnode.left = lnode
	lnode.right = rnode
end

-- Helper to detach a node from its neighbors
local function Detach (node)
	-- Link neighbors together.
	local rnode = node.right

	LinkLR(node.left, rnode)

	-- Make node into a singleton.
	node.left = node
	node.right = node
	node.marked = false

	-- Return another node (or nil, if none was available) for use as a cycle root.
	if rnode ~= node then
		return rnode
	end
end

-- A decreased key violated the heap condition: spread "damage" up through the heap
local function CascadingCut (root, node, parent)
	repeat
		-- Remove the node from its parent's children list and stitch it into the root
		-- cycle, then update the root of the children cycle (even if the root was not
		-- removed, this is harmless, so forgo the check). 
		parent.child = Detach(node)
		parent.degree = parent.degree - 1

		AddToCycle(root, node)

		-- If the parent was unmarked, mark it and quit. Otherwise, move up the heap:
		-- unmark the parent, then repeat the removal process with it as the node and its
		-- own parent as the new parent (quitting if it has no parent, i.e. a node in the
		-- root cycle).
		local was_unmarked = not parent.marked

		parent.marked = was_unmarked

		node = parent
		parent = parent.pparent
	until parent == nil or was_unmarked
end

-- Helper to establish a node as the minimum, if possible
local function UpdateMin (H, node)
	local root = H.root

	if root ~= node and node.key < root.key then
		H.root = node
	end
end

---
-- @param H Heap.
-- @param node Node with key to decrease, which must be in <i>H</i>.
-- @param new Input used to produce new key, such that result &le current key.
-- @see New
function _M.DecreaseKey (H, node, new)
	H:update(node, new)

	local parent = node.pparent

	if parent ~= nil and node.key < parent.key then
		CascadingCut(H.root, node, parent)
	end

	UpdateMin(H, node)
end

--- Removes a node in the heap.
-- @param H Heap.
-- @param node Node, which must be in <i>H</i>.
function _M.Delete (H, node)
	if H.root ~= node then
		_DecreaseKey_(H, node, -1 / 0)
	end

	_DeleteMin_(H)
end

-- Helper to merge two cycles
local function Merge (r1, r2)
	local r2r = r2.right

	LinkLR(r2, r1.right)
	LinkLR(r1, r2r)
end

-- Helper to link two nodes while building up a binomial heap
local function Link (parent, child)
	-- Resolve which nodes will be parent and child.
	if child.key < parent.key then
		parent, child = child, parent
	end

	-- Remove the child-to-be from its neighbors. No root updating is needed since linking
	-- is only done on nodes in the root cycle.
	Detach(child)

	-- Add the child to the parent's children cycle. 
	child.pparent = parent

	if parent.child ~= nil then
		AddToCycle(parent.child, child)
	else
		parent.child = child
	end

	parent.degree = parent.degree + 1

	-- Return the resolved parent.
	return parent
end

-- Scratch buffer used to ensure binomial heaps are all of differing degree --
local Roots = ffi.new("void * [32]")

-- Helper to combine root into a binomial heap
local function CombineRoots (root, bits)
	local degree = root.degree
	local mask = lshift(1, degree)

	while band(bits, mask) ~= 0 do
		root = Link(root, cast(root, Roots[degree]))

		bits = bits - mask
		mask = mask + mask
		degree = degree + 1
	end

	Roots[degree] = root

	bits = bits + mask

	return bits
end

-- --
local Indices = ffi.new("int[59]")

for i = 0, 54 do
	Indices[2^i % 59] = i
end

--
local function NextRoot (cur, bits)
	local flag = band(bits, -bits)

	return bits - flag, cast(cur, Roots[Indices[flag % 59]])
end

--- If the heap is not empty, deletes the minimum-key node.
-- @param H Heap.
-- @see Delete
function _M.DeleteMin (H)
	local min = H.root

	if min ~= nil then
		-- Separate any children from the minimum node, then detach it.
		local children = min.child
		local cur = Detach(min)

		min.child = nil

		if children ~= nil then
			children.pparent = nil

			-- Merge any children into the root cycle.
			if cur ~= nil then
				Merge(cur, children)
			else
				cur = children
			end
		end

		-- If the heap is not empty, structure the nodes in the root cycle into binomial
		-- heaps, no two with the same degree.
		if cur ~= nil then
			local last = cur.right
			local bits = 0

			repeat
				local done = cur == last
				local next = cur.left

				bits = CombineRoots(cur, bits)
				cur = next
			until done

			-- There is at least one root, so start with that as the initial best. Compare
			-- against any other roots, replacing it with anything better.
			local bits, best = NextRoot(cur, bits)

			while bits ~= 0 do
				bits, last = NextRoot(cur, bits)

				if last.key < best.key then
					best = last
				end
			end

			-- Choose the best binomial heap root as the new minimum.
			H.root = best

		-- Otherwise, flag the heap as empty.
		else
			H.root = nil
		end
	end
end

--- Finds the heap's minimum-key node.
-- @class function
-- @name FindMin
-- @param H Heap.
-- @return Node with minimum key, or <b>nil</b> if the heap is empty.
-- @return If the heap is not empty, the key in the minimum node.
_M.FindMin = heap_utils.Root

--- Utility to supply neighbor information about a node.<br><br>
-- A singleton will return itself as its neighbors.
-- @param node Node.
-- @return Left neighbor.
-- @return Right neighbor.
function _M.GetNeighbors (node)
	return node.left, node.right
end

--- Adds a key to the heap.
-- @param H Heap.
-- @param init Input used to produce initial key.
-- @return New node.
-- @see Insert_UserNode
function _M.Insert (H, init)
	local node = {}

	_Insert_UserNode_(H, init, node)

	return node
end

--- Variant of <b>Insert</b> that takes a user-supplied node.<br><br>
-- Conforming nodes have at least the following fields, to be treated as read-only:<br><br>
-- &nbsp&nbsp<b>- key:</b> cf. <i>update</i> in <b>heap_utils.New</b>  (read-write inside <i>update</i>).<br>
-- &nbsp&nbsp<b>- degree:</b> An integer.<br>
-- &nbsp&nbsp<b>- child:</b> A link to another conforming node; may be set to <b>nil</b>.<br>
-- &nbsp&nbsp<b>- right:</b> As per <b>child</b>.<br>
-- &nbsp&nbsp<b>- marked:</b> A boolean.<br><br>
-- Note that the default implementation assumes strong references to nodes are held by the
-- heap's <b>root</b> and nodes' <b>child</b> and <b>right</b> keys. Custom nodes must take
-- this into account.
-- @param H Heap.
-- @param init Input used to produce initial key.
-- @param node Node to be inserted.
-- @see Insert
-- @see ~heap_utils.New
function _M.Insert_UserNode (H, init, node)
	-- Initialize node fields.
	node.degree = 0
	node.child = nil
	node.pparent = nil
	node.left = node
	node.right = node
	node.marked = false

	H:update(node, init)

	-- Stitch node into the root cycle.
	local root = H.root

	if root ~= nil then
		AddToCycle(root, node)
		UpdateMin(H, node)
	else
		H.root = node
	end
end

---
-- @class function
-- @name IsEmpty
-- @param H Heap.
-- @return If true, the heap is empty.
_M.IsEmpty = heap_utils.IsEmpty_NilRoot

--- Builds a new Fibonacci heap.
-- @class function
-- @name New
-- @param update Key update function.
-- @return New heap.
-- @see ~heap_utils.New
_M.New = heap_utils.New

--- Produces the union of two Fibonacci heaps.<br><br>
-- This operation is destructive: <i>h1</i> and <i>h2</i> may both be destroyed; only the
-- return value should be trusted.<br><br>
-- The heaps must be compatible, i.e. share the same update function.
-- @param H1 Heap #1.
-- @param H2 Heap #2.
-- @return New heap.
-- @see New
function _M.Union (H1, H2)
	-- If the first heap is empty, reuse the second heap.
	if H1.root == nil then
		return H2
	end

	-- If neither heap is empty, merge them together and return the result. Otherwise,
	-- this means the second heap is empty, so reuse the first heap.
	local root2 = H2.root

	if root2 ~= nil then
		assert(H1.update == H2.update, "Incompatible set functions")

		Merge(H1.root, root2)
		UpdateMin(H1, root2)
	end

	return H1
end

-- Cache module members.
_DecreaseKey_ = _M.DecreaseKey
_DeleteMin_ = _M.DeleteMin
_Insert_UserNode_ = _M.Insert_UserNode

-- Export the module.
return _M