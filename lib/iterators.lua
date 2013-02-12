-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local min = math.min

-- Modules --
local cache_ops = require("cache_ops")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local CollectArgsInto = var_ops.CollectArgsInto
local IsCallable = var_preds.IsCallable
local IsPositiveInteger = var_preds.IsPositiveInteger
local SimpleCache = cache_ops.SimpleCache
local SwapField = var_ops.SwapField
local UnpackAndWipeRange = var_ops.UnpackAndWipeRange
local WipeRange = var_ops.WipeRange

--[[
--- This module defines some common iterators and supporting operations.
module "iterators"
]]
local _M = {}

--- Apparatus for building stateful iterators which recache themselves when iteration
-- terminates normally, of which multiple instances may be in use at once.
-- @param builder Function used to build a new iterator instance when none is available
-- in the cache. It must return the following functions, in order:<br><br>
-- &nbsp&nbsp- <i>body</i>: As with standard iterator functions, it takes the <i>state</i>
-- and <i>iterator variable</i> as arguments and its return values are placed in the loop
-- variables.<br><br>
-- &nbsp&nbsp- <i>done</i>: This takes the <i>state</i> and <i>iterator variable</i> as
-- arguments. If it returns a true result, the iterator terminates normally and <i>reclaim</i>
-- is called; otherwise the <i>body</i> logic is performed.<br><br>
-- &nbsp&nbsp&nbsp Any cleanup that relies on whether iteration terminated normally may also
-- be handled or configured here.<br><br>
-- &nbsp&nbsp- <i>setup</i>: This takes any iterator arguments and returns the <i>state</i>
-- and <i>iterator variable</i>. Any complex iterator state should be set up here.<br><br>
-- &nbsp&nbsp- <i>reclaim</i>: This takes one argument, which will be the <i>state</i> when
-- called after normal termination. Any complex iterator state should be cleaned up here.<br><br>
-- &nbsp&nbsp&nbsp Afterward this instance is put in the cache.<br><br>
-- This design encourages storing an instance's state in <i>builder</i>'s local variables,
-- which are then captured. Thus the above functions will typically be new closures.
-- @return Iterator generator function.<br><br>
-- Any arguments are passed to <i>setup</i>. If it is necessary to build an instance first,
-- <i>builder</i> will receive these arguments as well.<br><br>
-- In addition to the <i>iterator function</i>, <i>state</i>, and initial value for the <i>
-- iterator variable</i>, <i>reclaim</i> is returned. This can be used to manually recache
-- the iterator if the code needs to break or return mid-iteration, though if forgotten the
-- instance will just become garbage.
function _M.InstancedAutocacher (builder)
	local cache = SimpleCache()

	return function(...)
		local instance = cache("pull")

		if not instance then
			local body, done, setup, reclaim = builder(...)

			assert(IsCallable(body), "Uncallable body function")
			assert(IsCallable(done), "Uncallable done function")
			assert(IsCallable(setup), "Uncallable setup function")
			assert(IsCallable(reclaim), "Uncallable reclaim function")

			-- Build a reclaim function.
			local active

			local function reclaim_func (state)
				assert(active, "Iterator is not active")

				reclaim(state)

				cache(instance)

				active = false
			end

			-- Iterator function
			local function iter (s, i)
				assert(active, "Iterator is done")

				if done(s, i) then
					reclaim_func(s)
				else
					return body(s, i)
				end
			end

			-- Iterator instance
			function instance (...)
				assert(not active, "Iterator is already in use")

				active = true

				local state, var0 = setup(...)

				return iter, state, var0, reclaim_func
			end
		end

		return instance(...)
	end
end

--- Iterator over its arguments.
-- @class function
-- @name Args
-- @param ... Arguments.
-- @return Iterator instance which supplies index, value.
-- @see InstancedAutocacher
_M.Args = _M.InstancedAutocacher(function()
	local args, count

	-- Body --
	return function(_, i)
		return i + 1, SwapField(args, i + 1, false)
	end,

	-- Done --
	function(_, i)
		if i >= count then
			count = nil

			return true
		end
	end,

	-- Setup --
	function(...)
		count, args = CollectArgsInto(args, ...)

		return nil, 0
	end,

	-- Reclaim --
	function()
		WipeRange(args, 1, count or 0, false)

		count = nil
	end
end)


--- Variant of <b>Args</b> which, instead of the <i>i</i>th argument at each iteration,
-- supplies the <i>i</i>th <i>n</i>-sized batch.<br><br>
-- If the argument count is not a multiple of <i>n</i>, the unfilled loop variables will
-- be <b>nil</b>.<br><br>
-- For <i>n</i> = 1, behavior is equivalent to <b>Args</b>.
-- @class function
-- @name ArgsByN
-- @param n Number of arguments to examine per iteration.
-- @param ... Arguments.
-- @return Iterator instance which returns iteration index, <i>n</i> argument values.
-- @see Args
-- @see InstancedAutocacher
_M.ArgsByN = _M.InstancedAutocacher(function()
	local args, count

	-- Body --
	return function(n, i)
		local base = i * n

		return i + 1, UnpackAndWipeRange(args, base + 1, min(base + n, count), false)
	end,

	-- Done --
	function(n, i)
		if i * n >= count then
			count = nil

			return true
		end
	end,

	-- Setup --
	function(n, ...)
		assert(IsPositiveInteger(n), "Invalid n")

		count, args = CollectArgsInto(args, ...) 

		return n, 0
	end,

	-- Reclaim --
	function()
		WipeRange(args, 1, count or 0, false)

		count = nil
	end
end)

--- Iterator which traverses a table as per <b>ipairs</b>, then supplies some item on the
-- final iteration.
-- @class function
-- @name IpairsThenItem
-- @param t Table for array part.
-- @param item Post-table item.
-- @return Iterator which supplies index, value.<br><br>
-- On the last iteration, this returns <b>false</b>, <i>item</i>.
-- @see InstancedAutocacher
_M.IpairsThenItem = _M.InstancedAutocacher(function()
	local ivalue, value, aux, state, var

	-- Body --
	return function()
		if var then
			return var, value
		else
			return false, ivalue
		end
	end,

	-- Done --
	function()
		-- If ipairs is still going, grab another element. If it has completed, clear
		-- the table state and do the item.
		if var then
			var, value = aux(state, var)

			if not var then
				value, aux, state = nil
			end

		-- Quit after the item has been returned.
		else
			return true
		end
	end,

	-- Setup --
	function(t, item)
		aux, state, var = ipairs(t)

		ivalue = item
	end,

	-- Reclaim --
	function()
		ivalue, value, aux, state, var = nil
	end
end)

--- Iterator which supplies some item on the first iteration, then traverses a table as per
-- <b>ipairs</b>.
-- @class function
-- @name ItemThenIpairs
-- @param item Pre-table item.
-- @param t Table for array part.
-- @return Iterator which supplies index, value.<br><br>
-- On the first iteration, this returns <b>false</b>, <i>item</i>.
-- @see InstancedAutocacher
_M.ItemThenIpairs = _M.InstancedAutocacher(function()
	local value, aux, state, var

	-- Body --
	return function()
		-- After the first iteration, return the current result from ipairs.
		if var then
			return var, value

		-- Otherwise, prime ipairs and return the item.
		else
			aux, state, var = ipairs(state)

			return false, value
		end
	end,

	-- Done --
	function()
		-- After the first iteration, do one ipairs iteration per invocation.
		if var then
			var, value = aux(state, var)

			return not var
		end
	end,

	-- Setup --
	function(item, t)
		value = item
		state = t
	end,

	-- Reclaim --
	function()
		value, aux, state, var = nil
	end
end)

-- Export the module.
return _M