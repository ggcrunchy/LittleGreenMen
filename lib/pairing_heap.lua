-- Standard library imports --
local remove = table.remove

-- Modules --
local heap_utils = require("heap_utils")

-- Cached module references --
local _Delete_
local _Insert_UserNode_

--[[
--- This module implements a pairing heap data structure.
module "pairing_heap"
]]
local _M = {}

-- Helper to detach node from neighbors or front of parent's children list
local function Detach (node)
	local lnode = node.left
	local rnode = node.right

	if lnode.child == node then
		lnode.child = rnode
	else
		lnode.right = rnode
	end

	node.left = nil

	if rnode ~= nil then
		rnode.left = lnode
		node.right = nil
	end
end

-- Helper to meld two sub-heaps
local function Meld (n1, n2)
	if n2 == nil then
		return n1
	elseif n1 == nil then
		return n2
	elseif n2.key < n1.key then
		n1, n2 = n2, n1
	end

	local cnode = n1.child

	n1.child = n2
	n2.left = n1
	n2.right = cnode

	if cnode ~= nil then
		cnode.left = n2
	end

	return n1
end

-- Special case where one sub-heap is the main heap (may replace root)
local function MeldToRoot (H, node)
	H.root = Meld(H.root, node)
end

---
-- @param H Heap.
-- @param node Node with key to decrease, which must be in <i>H</i>.
-- @param new Input used to produce new key, such that result &le current key.
-- @see New
function _M.DecreaseKey (H, node, new)
	H:update(node, new)

	if node ~= H.root then
		Detach(node)
		MeldToRoot(H, node)
	end
end

-- Intermediate merged pairs, used to reconstruct heap after a delete --
local Pairs = {}

--- Removes a node in the heap.
-- @param H Heap.
-- @param node Node, which must be in <i>H</i>.
function _M.Delete (H, node)
	-- If the node is the root, invalidate the root reference.
	if node == H.root then
		H.root = nil

	-- Otherwise, detach neighbors (the root has none).
	else
		Detach(node)		
	end

	-- Break the children off into separate heaps.
	local child, top = node.child

	while child ~= nil do
		local next = child.right

		child.left = nil
		child.right = nil

		-- Merge children in pairs from left to right. If there are an odd number of
		-- children, the last one will be the initial heap in the next step.
		if top ~= nil then
			Pairs[#Pairs + 1], top = Meld(top, child)
		else
			top = child
		end

		child = next
	end

	node.child = nil

	-- Merge the heaps built up in the last step into a new heap, from right to left.
	-- Merge the result back into the main heap.
	while #Pairs > 0 do
		top = Meld(top, remove(Pairs))
	end

	MeldToRoot(H, top)
end

--- If the heap is not empty, deletes the minimum-key node.
-- @param H Heap.
-- @see Delete
function _M.DeleteMin (H)
	if H.root ~= nil then
		_Delete_(H, H.root)
	end
end

--- Finds the heap's minimum-key node.
-- @class function
-- @name FindMin
-- @param H Heap.
-- @return Node with minimum key, or <b>nil</b> if the heap is empty.
-- @return If the heap is not empty, the key in the minimum node.
_M.FindMin = heap_utils.Root

--- Utility to supply neighbor information about a node.
-- @param node Node.
-- @return Left neighbor, or <b>nil</b> if absent.
-- @return Right neighbor, or <b>nil</b> if absent.
function _M.GetNeighbors (node)
	local lnode = node.left

	if lnode ~= nil and lnode.child == node then
		lnode = nil
	end

	return lnode, node.right
end

--- Adds a key to the heap.
-- @param H Heap.
-- @param init Input used to produce initial key.
-- @return New node.
function _M.Insert (H, init)
	local node = {}

	_Insert_UserNode_(H, init, node)

	return node
end

--- Variant of <b>Insert</b> that takes a user-supplied node.<br><br>
-- Conforming nodes have at least the following fields, to be treated as read-only:<br><br>
-- &nbsp&nbsp<b>- key:</b> cf. <i>update</i> in <b>heap_utils.New</b> (read-write inside <i>update</i>).<br>
-- &nbsp&nbsp<b>- child:</b> A link to another conforming node; may be set to <b>nil</b>.<br>
-- &nbsp&nbsp<b>- right:</b> As per <b>child</b>.<br><br>
-- Note that the default implementation assumes strong references to nodes are held by the
-- heap's <b>root</b> and nodes' <b>child</b> and <b>right</b> keys. Custom nodes must take
-- this into account.
-- @param H Heap.
-- @param init Input used to produce initial key.
-- @param node Node to be inserted.
-- @see Insert
-- @see ~heap_utils.New
function _M.Insert_UserNode (H, init, node)
	node.child = nil
	node.left = nil
	node.right = nil

	H:update(node, init)

	MeldToRoot(H, node)
end

---
-- @class function
-- @name IsEmpty
-- @param H Heap.
-- @return If true, the heap is empty.
_M.IsEmpty = heap_utils.IsEmpty_NilRoot

--- Builds a new pairing heap.
-- @class function
-- @name New
-- @param update Key update function.
-- @return New heap.
-- @see ~heap_utils.New
_M.New = heap_utils.New

-- Cache module members.
_Delete_ = _M.Delete
_Insert_UserNode_ = _M.Insert_UserNode

-- Export the module.
return _M