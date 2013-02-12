-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local remove = table.remove

-- Modules --
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local IsCallableOrNil = var_preds.IsCallableOrNil
local IsTable = var_preds.IsTable
local UnpackAndWipe = var_ops.UnpackAndWipe
local WipeRange = var_ops.WipeRange

--[[
--- This module defines some common caching operations.
module "cache_ops"
]]
local _M = {}

--- Builds a simple cache.
-- @return Cache function.<br><br>
-- If the argument is <b>"pull"</b>, an item in the cache is removed and returned.<br><br>
-- If the argument is <b>"peek"</b>, that item is returned, but without being removed.<br><br>
-- In either of these cases, if the cache is empty, <b>nil</b> is returned.<br><br>
-- Otherwise, the value passed as argument is added to the cache.
function _M.SimpleCache ()
	local cache = {}

	return function(elem_)
		if elem_ == "pull" then
			return remove(cache)
		elseif elem_ == "peek" then
			return cache[#cache]
		else
			cache[#cache + 1] = elem_
		end
	end
end

--- Wipes an array and puts it into a cache, returning the cleared values.
-- @param cache Cache of used arrays.
-- @param array Array to clear.
-- @param count Size of array; by default, #<i>array</i>.
-- @param wipe Value used to wipe cleared entries.
-- @return Array values (number of return values = count).
-- @see ~var_ops.UnpackAndWipe
function _M.UnpackWipeAndRecache (cache, array, count, wipe)
	cache[#cache + 1] = array

	return UnpackAndWipe(array, count, wipe)
end

--- Wipes an array and puts it into a cache.
-- @param cache Cache of used arrays.
-- @param array Array to clear.
-- @param count Size of array; by default, #<i>array</i>.
-- @param wipe Value used to wipe cleared entries.
-- @return Array.
-- @see ~var_ops.WipeRange
function _M.WipeAndRecache (cache, array, count, wipe)
	cache[#cache + 1] = array

	return WipeRange(array, 1, count, wipe)
end

-- Table restore options --
local TableOptions = { unpack_and_wipe = _M.UnpackWipeAndRecache, wipe_range = _M.WipeAndRecache }

--- Builds a table-based cache.
-- @param on_restore Logic to call on returning the table to the cache; the table is its
-- first argument, followed by any other arguments passed to the cache function. If <b>nil
-- </b>, this is a no-op.<br><br>
-- If this is <b>"unpack_and_wipe"</b> or <b>"wipe_range"</b>, then that operation from
-- <b>var_ops</b> is used as the restore logic. In this case, the operation's results are
-- returned by the cache function.
-- @return Cache function.<br><br>
-- If the first argument is <b>"pull"</b>, a table is created or removed from the cache, and
-- returned to the caller.<br><br>
-- If instead the argument is <b>"peek"</b>, that table is returned, , but without being
-- removed. If the cache is empty, <b>nil</b> is returned.<br><br>
-- Otherwise, the first argument must be table (though it need not have belonged to the
-- cache). Any restore logic will be called, passing this table and any additional arguments.
-- The table will then be restored to the cache.
-- @see ~var_ops.UnpackAndWipe
-- @see ~var_ops.WipeRange
function _M.TableCache (on_restore)
	local option = TableOptions[on_restore]

	assert(option or IsCallableOrNil(on_restore), "Uncallable restore")

	local cache = {}

	return function(t_, ...)
		if t_ == "pull" then
			return remove(cache) or {}
		elseif t_ == "peek" then
			return cache[#cache]
		else
			assert(IsTable(t_), "Attempt to return non-table")

			if option then
				return option(cache, t_, ...)
			elseif on_restore then
				on_restore(t_, ...)
			end

			cache[#cache + 1] = t_
		end
	end
end

-- Export the module.
return _M