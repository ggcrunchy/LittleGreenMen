--- Some utilities common to data structures.

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
local min = math.min
local remove = table.remove

-- Exports --
local M = {}

--- DOCME
function M.NewStoreGroup (ncache)
	ncache = ncache or 0

	local group, cache, free = {}, ncache > 0 and {} or "", false
	local StoreGroup = {}

	--- DOCME
	function StoreGroup.AddToStore (id, item)
		local store = group[id]
		local count = #store

		store[count + 1] = item

		return count
	end

	--- DOCME
	function StoreGroup.ClearStore (id)
		local store = group[id]

		-- Put as many items as possible back in the cache...
		for _ = 1, min(#store, ncache - #cache) do
			cache[#cache + 1] = remove(store)
		end

		-- ...and dump the rest.
		for i = #store, 1, -1 do
			store[i] = nil
		end
	end

	--- DOCME
	function StoreGroup.GetItem (id, index)
		local store = group[id]

		if index == true then
			local count = #store

			return store[count], count - 1
		else
			return store[index]
		end
	end

	--- DOCME
	function StoreGroup.NewStore ()
		local id

		if free then
			id, free = free, group[free]
		else
			id = #group + 1
		end

		group[id] = {}

		return id
	end

	--
	if ncache > 0 then
		--- DOCME
		function StoreGroup.PopCache ()
			return remove(cache)
		end
	end

	--
	local ClearStore = StoreGroup.ClearStore

	--- DOCME
	function StoreGroup.RemoveStore (id)
		ClearStore(id)

		if #group > id then
			group[id], free = free, id
		else
			group[id] = nil
		end
	end

	--- DOCME
	function StoreGroup.Wipe (keep_cache)
		group, free = {}, false

		if not keep_cache and ncache > 0 then
			cache = {}
		end
	end

	--
	return StoreGroup
end

-- Export the module.
return M