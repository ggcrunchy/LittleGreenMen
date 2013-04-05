--- Skip list data structure.

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
local assert = assert
local random = math.random
local type = type

-- Modules --
local ffi = require("ffi")

-- Imports --
local cast = ffi.cast

-- Exports --
local M = {}

--
local function FindMaxNodesLessThan (head, prev_nodes, value)
	local node = head

	for i = head.n - 1, 0, -1 do
		local next = cast(prev_nodes[0], node.next[i])

		--
        while next.data < value do
            node, next = next, cast(prev_nodes[0], next.next[i])
        end

		--
        prev_nodes[i] = cast(prev_nodes[0], node)
	end
end

--- DOCME
function M.NewType (inf, what)
	assert(inf ~= nil, "Type needs 'infinite' element")
	assert(type(inf) == "cdata" or type(what) == "string", "More info needed to build ct")

	--
	local ct = ffi.typeof([[
		struct {
			int n;
			$ data;
			void * next[?];
		}
	]], type(inf) == "cdata" and inf or ffi.typeof(what))

	-- --
	local SkipList = {}

	--
	local pct = ffi.typeof("$ *", ct)

	--- DOCME
	function SkipList:FindNode (value)
		local node = self

		for i = self.n - 1, 0, -1 do
			local next = cast(pct, node.next[i])

			--
			while next.data < value do
				node, next = next, cast(pct, next.next[i])
			end

			--
			if not (value < next.data) then
				return next
			end
		end

		return nil
	end

-- GetFirstNode: return self

	--- DOCME
	function SkipList:GetNextNode ()
		if cast(pct, self.next[0]).n ~= 0 then
			return cast(pct, self.next[0])
		else
			return nil
		end
	end

	--- DOCME
	function SkipList:GetNextNodeAt (h)
		if h < self.n and cast(pct, self.next[h]).n ~= 0 then
			return cast(pct, self.next[h])
		else
			return nil
		end
	end

	-- --
	local prev_nodes

	--
	local function AuxInsert (head, value)
		local n = random(head.n)
		local node = ct(n, n)

		node.data = value

		for i = 0, n - 1 do
			prev_nodes[i].next[i], node.next[i] = node, prev_nodes[i].next[i]
		end

		return node
	end

	--- DOCME
	function SkipList:InsertOrFindValue (value)
		FindMaxNodesLessThan(self, prev_nodes, value)

		if not (value < cast(pct, prev_nodes[0].next[0]).data) then
			return cast(pct, prev_nodes[0].next[0])
		else
			return AuxInsert(self, value)
		end
	end

	--- DOCME
	function SkipList:InsertValue (value)
		FindMaxNodesLessThan(self, prev_nodes, value)

		return AuxInsert(self, value)
	end

-- IsFinalNode -- return cast(pct, self.next[0]).n == 0
-- IsFinalNodeAt(h)-- return h >= self.n or cast(pct, self.next[h]).n == 0
-- TODO: h >= self.n returns false positives?

	--- DOCME
	-- N.B. node is assumed to exist! (could check that top level doesn't overrun...)
	function SkipList:RemoveNode (node)
		FindMaxNodesLessThan(self, prev_nodes, node.data)

		local pnode = cast(pct, node)

		for i = 0, node.n - 1 do
			local prev = prev_nodes[i]

			while cast(pct, prev.next[i]) ~= pnode do
				prev = cast(pct, prev.next[i])
			end

			prev.next[i] = node.next[i]
		end
	end

	--- DOCME
	function SkipList:RemoveValue (value)
		FindMaxNodesLessThan(self, prev_nodes, value)

		--
		local top, node = self.n, cast(pct, prev_nodes[0].next[0])

		if value < node.data then
			return nil
		end

		--
		for i = 0, node.n - 1 do
			prev_nodes[i].next[i] = node.next[i]
		end

		--
		return node
	end

	--
	ffi.metatype(ct, { __index = SkipList })

	-- --
	local pct_arr = ffi.typeof("$[?]", pct)

	-- --
	local inf_node = ct(1, 0, inf)

	-- --
	local prev_n = -1

	--- DOCME
	local function NewList (n)
		local head = ct(n, n)

		--
		for i = 0, n - 1 do
			head.next[i] = inf_node
		end

		--
		if prev_nodes == nil or prev_n < n then
			prev_nodes = pct_arr(n)
			prev_n = n
		end

		return head
	end

	return NewList
end

-- Export the module.
return M