-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local error = error
local pcall = pcall
local rawset = rawset
local setmetatable = setmetatable

-- Modules --
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local AssertArg_Pred = var_ops.AssertArg_Pred
local IsCallable = var_preds.IsCallable
local IsCallableOrNil = var_preds.IsCallableOrNil

-- Cached module references --
local _NoOp_
local _StoreTraceback_

--[[
--- This module defines some basic function primitives.
module "func_ops"
]]
local _M = {}

--- Calls a function.
-- @param func Function to call.
-- @param arg Argument.
-- @return Call results.
function _M.Call (func, arg)
	return func(arg)
end

--- Multiple-argument variant of <b>Call</b>.
-- @param func Function to call.
-- @param ... Arguments.
-- @return Call results.
-- @see Call
function _M.Call_Multi (func, ...)
	return func(...)
end

--- Calls a method.
-- @param owner Method owner.
-- @param name Method name.
-- @param arg Argument.
-- @return Call results.
function _M.CallMethod (owner, name, arg)
	return owner[name](owner, arg)
end

--- Multiple-argument variant of <b>CallMethod</b>.
-- @param owner Method owner.
-- @param name Method name.
-- @param ... Arguments.
-- @return Call results.
-- @see CallMethod
function _M.CallMethod_Multi (owner, name, ...)
	return owner[name](owner, ...)
end

--- If the value is callable, it is called and its value returned. Otherwise, returns it.
-- @param value Value to call or get.
-- @param arg Call argument.
-- @return Call results or value.
function _M.CallOrGet (value, arg)
	if IsCallable(value) then
		return value(arg)
	end

	return value
end

--- Multiple-argument variant of <b>CallOrGet</b>.
-- @param value Value to call or get.
-- @param ... Call arguments.
-- @return Call results or value.
-- @see CallOrGet
function _M.CallOrGet_Multi (value, ...)
	if IsCallable(value) then
		return value(...)
	end

	return value
end

---
-- @return <b>""</b>.
function _M.EmptyString ()
	return ""
end

---
-- @return <b>false</b>.
function _M.False ()
	return false
end

--- Builds a function that appends new functions into a table, validating its input.
-- @param key Table key, in object.
-- @param message Error message on invalid function input.
-- @param allow_nil If true, <b>nil</b> insertions are permitted, though they are no-ops;
-- otherwise, they must be stricly callable.
-- @return Function with signature<br><br>
-- &nbsp&nbsp&nbsp<i><b>appender(O, func)</b></i>,<br><br>
-- where <i>O</i> is some object and <i>func</i> is the function being appended.<br><br>
-- Typically, this will be set as a member function on some object or class.
function _M.FuncAppender (key, message, allow_nil)
	local pred = allow_nil and IsCallableOrNil or IsCallable

	return function(O, func)
		assert(pred(func), message)

		local t = O[key]

		t[#t + 1] = func
	end
end

--- Builds a function that sets a function at a given key, validating its input.
-- @param key Function key, in object.
-- @param message Error message on invalid function input.
-- @param allow_nil If true, the function may be <b>nil</b>, in which case the member is
-- cleared; otherwise, it must be strictly callable.
-- @return Function with signature<br><br>
-- &nbsp&nbsp&nbsp<i><b>setter(O, func)</b></i>,<br><br>
-- where <i>O</i> is some object and <i>func</i> is the function being assigned.<br><br>
-- Typically, this will be set as a member function of some object or class.
function _M.FuncSetter (key, message, allow_nil)
	local pred = allow_nil and IsCallableOrNil or IsCallable

	return function(O, func)
		assert(pred(func), message)

		O[key] = func
	end
end

--- Returns its argument.
-- @param arg Argument.
-- @return <i>arg</i>.
function _M.Identity (arg)
	return arg
end

--- Returns its arguments, minus the first.
-- @param _ Unused.
-- @param ... Arguments #2 and up.
-- @return Arguments #2 and up.
function _M.Identity_AllButFirst (_, ...)
	return ...
end

--- Multiple-argument variant of <b>Identity</b>.
-- @param ... Arguments.
-- @return Arguments.
-- @see Identity
function _M.Identity_Multi (...)
	return ...
end

--- Builds a function that passes its input to <i>func</i>. If it returns a true result,
-- this function returns <b>false</b>, and <b>true</b> otherwise.
-- @param func Function to negate, which is passed one argument.
-- @return Negated function.
function _M.Negater (func)
	return function(arg)
		return not func(arg)
	end
end

--- Multiple-argument variant of <b>Negater</b>.
-- @param func Function to negate, which is passed multiple arguments.
-- @return Negated function.
-- @see Negater
function _M.Negater_Multi (func)
	return function(...)
		return not func(...)
	end
end

---
-- @return New empty table.
function _M.NewTable ()
	return {}
end

--- No operation.
function _M.NoOp () end

---
-- @return 1.
function _M.One ()
	return 1
end

---
-- @return <b>true</b>.
function _M.True ()
	return true
end

---
-- @return 0.
function _M.Zero ()
	return 0
end

--- Builds a proxy allowing for get / set overrides, e.g. as <b>__index</b> / <b>__newindex
-- </b> metamethods for a table.<br><br>
-- This return a binder function, with signature<br><br>
-- &nbsp&nbsp&nbsp<i><b>binder(key, getter, setter)</b></i>,<br><br>
-- where <i>key</i> is the key to bind, <i>getter</i> is a function which takes no
-- arguments and returns a value for the key, and <i>setter</i> is a function which takes
-- the value to set as an argument and does something with it. Either <i>getter</i> or
-- <i>setter</i> may be <b>nil</b>: in the case of <i>getter</i>, <b>nil</b> will be
-- returned for the key; the response to <i>setter</i> being <b>nil</b> is explained below.
-- @param on_no_setter Behavior when no setter is available.<br><br>
-- If this is <b>"error"</b>, it is an error.<br><br>
-- If this is <b>"rawset"</b>, the object is assumed to be a table and the value will be
-- set at the key.<br><br>
-- Otherwise, the set is ignored.
-- @return <b>__index</b> function.
-- @return <b>__newindex</b> function.
-- @return Binder function.
function _M.Proxy (on_no_setter)
	local get = {}
	local set = {}

	return function(_, key)
		return (get[key] or _NoOp_)()
	end, function(object, key, value)
		local func = set[key]

		if func ~= nil then
			func(value)
		elseif on_no_setter == "error" then
			error("Unhandled set")
		elseif on_no_setter == "rawset" then
			rawset(object, key, value)
		end
	end, function(key, getter, setter)
		assert(IsCallableOrNil(getter), "Uncallable getter")
		assert(IsCallableOrNil(setter), "Uncallable setter")

		get[key] = getter
		set[key] = setter
	end
end

-- Protected calls with cleanup --
do
	--- Performs a call and cleans up afterward. If an error occurs during the call, the
	-- cleanup is still performed, and the error propagated.<br><br>
	-- It is assumed that the cleanup logic cannot itself trigger an error.
	-- @param func Call to protect, which takes <i>resource</i>, <i>arg1</i>, and <i>
	-- arg2</i> as arguments.
	-- @param finally Cleanup logic, which takes <i>resource</i> as argument.
	-- @param resource Arbitrary resource.
	-- @param arg1 Additional argument #1.
	-- @param arg2 Additional argument #2.
	function _M.Try (func, finally, resource, arg1, arg2)
		local success, message = pcall(func, resource, arg1, arg2)

		finally(resource)

		-- Propagate any usage error.
		if not success then
			_StoreTraceback_()

			error(message, 2)
		end
	end

	--- Multiple-argument variant of <b>Try</b>.
	-- @param func Call to protect.
	-- @param finally Cleanup logic.
	-- @param resource Arbitrary resource.
	-- @param ... Additional arguments.
	-- @see Try
	function _M.Try_Multi (func, finally, resource, ...)
		local success, message = pcall(func, resource, ...)

		finally(resource)

		-- Propagate any usage error.
		if not success then
			_StoreTraceback_()

			error(message, 2)
		end
	end
end

-- Time lapse handling --
do
	-- Time function metatable --
	local TimeMeta = {}

	function TimeMeta.__index (t)
		return t[TimeMeta]
	end

	-- Time lapse routines --
	local TimeLapse = setmetatable({ [TimeMeta] = Zero }, TimeMeta)

	-- Deduct routines --
	local Deduct = setmetatable({ [TimeMeta] = NoOp }, TimeMeta)

	--- Gets the time lapse function for a given category, along with its deduct function.<br><br>
	-- If no function is assigned for a given category, the default function is returned.
	-- The original default is a dummy that always returns 0; the default deduct is a no-op.
	-- @param name Category name, or <b>nil</b> for default.
	-- @return Time lapse function.
	-- @return Deduct function.
	-- @see SetTimeLapseFunc
	function _M.GetTimeLapseFunc (name)
		return TimeLapse[name], Deduct[name]
	end

	--- Sets the time lapse function for a given category or the default.
	-- @param name Category name, or <b>nil</b> for default.
	-- @param func Function to assign, or <b>nil</b> to clear the function (if not setting
	-- the default). The function must return a non-negative time lapse when called and
	-- should have no side effects.
	-- @param deduct Deduct function to assign, or <b>nil</b> to use the default. The
	-- function should, given a non-negative amount, deduct that amount of time from what
	-- <i>func</i> returns, e.g. for sequential events that should be given a diminishing
	-- slice of time as the sequence progresses.
	-- @see GetTimeLapseFunc
	function _M.SetTimeLapseFunc (name, func, deduct)
		assert(IsCallableOrNil(deduct), "Uncallable deduct function")

		if name == nil then
			TimeLapse[TimeMeta] = AssertArg_Pred(IsCallable, func, "SetTimeLapseFunc: Uncallable default time lapse function")
			Deduct[TimeMeta] = deduct or _NoOp_
		else
			TimeLapse[name] = AssertArg_Pred(IsCallableOrNil, func, "Uncallable time lapse function")
			Deduct[name] = deduct
		end
	end
end

-- Tracebacks --
do
	-- Last traceback --
	local LastTraceback

	-- Traceback function --
	local TracebackFunc

	--- Gets the last stored traceback.
	-- @param clear If true, clear the traceback after retrieval.
	-- @return Traceback string, or <b>nil</b> if absent.
	function _M.GetLastTraceback (clear)
		local traceback = LastTraceback

		if clear then
			LastTraceback = nil
		end

		return traceback
	end

	--- Sets the traceback function.
	-- @param func Function to assign, or <b>nil</b> for default.<br><br>
	-- The function should return either the traceback string or <b>nil</b>.
	function _M.SetTracebackFunc (func)
		TracebackFunc = AssertArg_Pred(IsCallableOrNil, func, "Uncallable traceback function")
	end

	--- Stores the current traceback.
	-- @param ... Arguments to traceback function.
	-- @see GetLastTraceback
	function _M.StoreTraceback (...)
		LastTraceback = (TracebackFunc ~= nil and TracebackFunc or _NoOp_)(...)
	end
end

-- Cache module members.
_NoOp_ = _M.NoOp
_StoreTraceback_ = _M.StoreTraceback

-- Export the module.
return _M