--[[
--- Some common utilities, used to implement heaps.
module "heap_utils"
--]]
local _M = {}

--- Empty heap test: <b>root</b> key is <b>nil</b>.
-- @param H Heap.
-- @return If true, the heap is empty.
function _M.IsEmpty_NilRoot (H)
	return H.root == nil
end

-- Default key update function
local function Update (_, node, new)
	node.key = new
end

--- Builds a new heap, with keys <b>root</b> (initially <b>nil</b>) and <b>update</b>.
-- @param update Key update function, called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>update(H, node, new)</b></i>,<br><br>
-- where <i>H</i> is the heap, <i>node</i> is the node that holds the key, and <i>new</i> is
-- the input used to produce the key. After being called, <i>node</i>.<b>key</b> must be
-- non-<b>nil</b> and comparable by operator <b>&lt</b>.<br><br>
-- If <i>update</i> is <b>nil</b>, a default function is supplied that simply assigns <i>new</i>
-- to <i>node</i>.<b>key</b>.
-- @return Heap.
function _M.New (update)
	return { update = update or Update, root = nil }
end

--- Gets the node at the heap's <b>root</b> key.
-- @param H Heap.
-- @return Node, or <b>nil</b> if the heap is empty.
-- @return If the heap is not empty, the key in the root node.
function _M.Root (H)
	local root = H.root

	if root ~= nil then
		return root, root.key
	else
		return nil
	end
end

-- Export the module.
return _M