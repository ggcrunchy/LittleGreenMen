-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local lower = string.lower
local rawget = rawget
local tonumber = tonumber
local type = type

-- Pure Lua hacks --
local debug_getmetatable = debug.getmetatable

-- Cached module references --
local _HasMeta_
local _IsCallable_
local _IsCountable_
local _IsIndexableR_
local _IsInteger_
local _IsNonNegativeInteger_
local _IsNumber_

--[[
--- This module defines some common unary and binary predicates on variables.
module "var_preds"
]]
local _M = {}

---
-- @param var Variable to test, which must be callable or read-indexable.<br><br>
-- If <i>var</i> is callable, then from i = 1 to <i>count</i>, all <i>var</i>(i) calls must
-- return a true result.<br><br>
-- Otherwise, all <i>var</i>[i] lookups in that same range must be true.<br><br>
-- @param count Number of tests to perform; in the indexing case, this may be <b>nil</b>, in
-- which case #<i>var</i> is used.
-- @return If true, all tests passed.
-- @see IsCallable
-- @see IsIndexableR
function _M.All (var, count)
	assert(_IsNonNegativeInteger_(count) or _IsCountable_(var), "Invalid count")

	if _IsCallable_(var) then
		for i = 1, count do
			if not var(i) then
				return false
			end
		end
	else
		assert(_IsIndexableR_(var), "Un-indexable variable")

		for i = 1, count or #var do
			if not var[i] then
				return false
			end
		end
	end

	return true
end

---
-- @param var Variable to test, which must be callable or read-indexable.<br><br>
-- If <i>var</i> is callable, then from i = 1 to <i>count</i>, at least one <i>var</i>(i)
-- call must return a true result.<br><br>
-- Otherwise, any <i>var</i>[i] lookup in that same range must be true.<br><br>
-- @param count Number of tests to perform; in the indexing case, this may be <b>nil</b>, in
-- which case #<i>var</i> is used.
-- @return If true, some test passed.
-- @see IsCallable
-- @see IsIndexableR
function _M.Any (var, count)
	assert(_IsNonNegativeInteger_(count) or _IsCountable_(var), "Invalid count")

	if _IsCallable_(var) then
		for i = 1, count do
			if var(i) then
				return true
			end
		end
	else
		assert(_IsIndexableR_(var), "Un-indexable variable")

		for i = 1, count or #var do
			if var[i] then
				return true
			end
		end
	end

	return false
end

---
-- @param var Variable to test.
-- @param field Field to check.
-- @return If true, the field is set.
function _M.HasField (var, field)
	assert(_IsIndexableR_(var), "Un-indexable variable")

	return var[field] ~= nil
end

---
-- @param var Variable to test.
-- @param meta Metaproperty to lookup.
-- @return If true, variable supports the metaproperty.
function _M.HasMeta (var, meta)
	local mt = debug_getmetatable(var)

	return (mt and rawget(mt, meta)) ~= nil
end

-- Helper to build a predicate pair, where the second is an "or nil" version
local function Pair (name, base_func)
	_M[name] = base_func

	_M[name .. "OrNil"] = function(var)
		return var == nil or base_func(var)
	end
end

-- Helper to build the base and "or nil" variant for a given variable type
local function TypePair (suffix)
	local type_name = lower(suffix)

	Pair("Is" .. suffix, function(var)
		return type(var) == type_name
	end)
end

--- 
-- @class function
-- @name IsBoolean
-- @param var Variable to test.
-- @return If true, variable is a boolean.

--- 
-- @class function
-- @name IsBooleanOrNil
-- @param var Variable to test.
-- @return If true, variable is a boolean or <b>nil</b>.

TypePair("Boolean")

--- 
-- @class function
-- @name IsCallable
-- @param var Variable to test.
-- @return If true, variable is callable.

--- 
-- @class function
-- @name IsCallableOrNil
-- @param var Variable to test.
-- @return If true, variable is callable or <b>nil</b>.

Pair("IsCallable", function(var)
	return type(var) == "function" or _HasMeta_(var, "__call")
end)

---
-- @param var Variable to test.
-- @return If true, variable is countable.
function _M.IsCountable (var)
	local vtype = type(var)

	return vtype == "string" or vtype == "table" or _HasMeta_(var, "__len")
end

--- 
-- @class function
-- @name IsFunction
-- @param var Variable to test.
-- @return If true, variable is a function.

--- 
-- @class function
-- @name IsFunctionOrNil
-- @param var Variable to test.
-- @return If true, variable is a function or <b>nil</b>.

TypePair("Function")

-- Helper to build the base and "or nil" variant for two given variable types
local function TypeChoicePair (suffix1, suffix2)
	local type_name1, type_name2 = lower(suffix1), lower(suffix2)

	Pair("Is" .. suffix1 .. "Or" .. suffix2, function(var)
		local vtype = type(var)

		return vtype == type_name1 or vtype == type_name2
	end)
end

--- 
-- @class function
-- @name IsFunctionOrTable
-- @param var Variable to test.
-- @return If true, variable is a function or table.

--- 
-- @class function
-- @name IsFunctionOrTableOrNil
-- @param var Variable to test.
-- @return If true, variable is a function or table or <b>nil</b>.

TypeChoicePair("Function", "Table")

---
-- @param var Variable to test
-- @return If true, variable is read- and write-indexable.
function _M.IsIndexable (var)
	if type(var) == "table" then
		return true
	else
		local mt = debug_getmetatable(var)

		return (mt and rawget(mt, "__index") and rawget(mt, "__newindex")) ~= nil
	end
end

---
-- @param var Variable to test
-- @return If true, variable is read-indexable.
function _M.IsIndexableR (var)
	return type(var) == "table" or _HasMeta_(var, "__index")
end

---
-- @param var Variable to test
-- @return If true, variable is write-indexable.
function _M.IsIndexableW (var)
	return type(var) == "table" or _HasMeta_(var, "__newindex")
end

-- Helper to establish integer-ness
local function IsIntegral (n)
	return n % 1 == 0
end

-- Helper to get a number that can fail comparisons gracefully
local function ToNumber (var)
	return tonumber(var) or 0 / 0
end

-- Helper to get an integer that can fail comparisons gracefully
local function ToInteger (var)
	local n = ToNumber(var)

	return IsIntegral(n) and n or 0 / 0
end

---
-- @param var Variable to test.
-- @return If true, variable is an integer.
function _M.IsInteger (var)
	return IsIntegral(ToNumber(var))
end

--- Variant of <b>IsInteger</b>, requiring that <i>var</i> is a number.
-- @param var Variable to test.
-- @return If true, variable is an integer.
-- @see IsInteger
function _M.IsInteger_Number (var)
	return _IsNumber_(var) and IsIntegral(var)
end

---
-- @param var Variable to test.
-- @return If true, variable is a negative number.
function _M.IsNegative (var)
	return ToNumber(var) < 0
end

--- Variant of <b>IsNegative</b>, requiring that <i>var</i> is a number.
-- @param var Variable to test.
-- @return If true, variable is a negative number.
-- @see IsNegative
function _M.IsNegative_Number (var)
	return _IsNumber_(var) and var < 0
end

---
-- @param var Variable to test.
-- @return If true, variable is a negative integer.
-- @see IsInteger
function _M.IsNegativeInteger (var)
	return ToInteger(var) < 0
end

--- Variant of <b>IsNegativeInteger</b>, requiring that <i>var</i> is a number.
-- @param var Variable to test.
-- @return If true, variable is a negative integer.
-- @see IsNegativeInteger
function _M.IsNegativeInteger_Number (var)
	return _IsNumber_(var) and var < 0 and IsIntegral(var)
end

---
-- @param var Variable to test.
-- @return If true, variable is <b>nil</b>.
function _M.IsNil (var)
	return var == nil
end

---
-- @param var Variable to test.
-- @return If true, variable is 0 or a positive number.
function _M.IsNonNegative (var)
	return ToNumber(var) >= 0
end

--- Variant of <b>IsNonNegative</b>, requiring that <i>var</i> is a number.
-- @param var Variable to test.
-- @return If true, variable is 0 or a positive number.
-- @see IsNonNegative
function _M.IsNonNegative_Number (var)
	return _IsNumber_(var) and var >= 0
end

---
-- @param var Variable to test.
-- @return If true, variable is 0 or a positive integer.
-- @see IsInteger
function _M.IsNonNegativeInteger (var)
	return ToInteger(var) >= 0
end

--- Variant of <b>IsNonNegativeInteger</b>, requiring that <i>var</i> is a number.
-- @param var Variable to test.
-- @return If true, variable is 0 or a positive integer.
-- @see IsNonNegativeInteger
function _M.IsNonNegativeInteger_Number (var)
	return _IsNumber_(var) and var >= 0 and IsIntegral(var)
end

---
-- @param var Variable to test.
-- @return If true, variable is 0 or a negative number.
function _M.IsNonPositive (var)
	return ToNumber(var) <= 0
end

--- Variant of <b>IsNonPositive</b>, requiring that <i>var</i> is a number.
-- @param var Variable to test.
-- @return If true, variable is 0 or a negative number.
-- @see IsNonPositive
function _M.IsNonPositive_Number (var)
	return _IsNumber_(var) and var <= 0
end

---
-- @param var Variable to test.
-- @return If true, variable is 0 or a negative integer.
-- @see IsInteger
function _M.IsNonPositiveInteger (var)
	return ToInteger(var) <= 0
end

--- Variant of <b>IsNonPositiveInteger</b>, requiring that <i>var</i> is a number.
-- @param var Variable to test.
-- @return If true, variable is 0 or a negative integer.
-- @see IsNonPositiveInteger
function _M.IsNonPositiveInteger_Number (var)
	return _IsNumber_(var) and var <= 0 and IsIntegral(var)
end

--- 
-- @class function
-- @name IsNumber
-- @param var Variable to test.
-- @return If true, variable is a number.

--- 
-- @class function
-- @name IsNumberOrNil
-- @param var Variable to test.
-- @return If true, variable is a number or <b>nil</b>.

TypePair("Number")

---
-- @param var Variable to test.
-- @return If true, variable is a positive number.
function _M.IsPositive (var)
	return ToNumber(var) > 0
end

--- Variant of <b>IsPositive</b>, requiring that <i>var</i> is a number.
-- @param var Variable to test.
-- @return If true, variable is a positive number.
-- @see IsPositive
function _M.IsPositive_Number (var)
	return _IsNumber_(var) and var > 0
end

---
-- @param var Variable to test.
-- @return If true, variable is a positive integer.
-- @see IsInteger
function _M.IsPositiveInteger (var)
	return ToInteger(var) > 0
end

--- Variant of <b>IsPositiveInteger</b>, requiring that <i>var</i> is a number.
-- @param var Variable to test.
-- @return If true, variable is a positive integer.
-- @see IsPositiveInteger
function _M.IsPositiveInteger_Number (var)
	return _IsNumber_(var) and var > 0 and IsIntegral(var)
end

---
-- @param var Variable to test.
-- @return If true, variable is "not a number".
function _M.IsNaN (var)
	return var ~= var
end

--- 
-- @class function
-- @name IsString
-- @param var Variable to test.
-- @return If true, variable is a string.

--- 
-- @class function
-- @name IsStringOrNil
-- @param var Variable to test.
-- @return If true, variable is a string or <b>nil</b>.

TypePair("String")

--- 
-- @class function
-- @name IsTable
-- @param var Variable to test.
-- @return If true, variable is a table.

--- 
-- @class function
-- @name IsTableOrNil
-- @param var Variable to test.
-- @return If true, variable is a table or <b>nil</b>.

TypePair("Table")

--- 
-- @class function
-- @name IsTableOrUserdata
-- @param var Variable to test.
-- @return If true, variable is a table or userdata.

--- 
-- @class function
-- @name IsTableOrUserdataOrNil
-- @param var Variable to test.
-- @return If true, variable is a table or userdata or <b>nil</b>.

TypeChoicePair("Table", "Userdata")

--- 
-- @class function
-- @name IsThread
-- @param var Variable to test.
-- @return If true, variable is a thread.

--- 
-- @class function
-- @name IsThreadOrNil
-- @param var Variable to test.
-- @return If true, variable is a thread or <b>nil</b>.

TypePair("Thread")

--- 
-- @class function
-- @name IsUserdata
-- @param var Variable to test.
-- @return If true, variable is a userdata.

--- 
-- @class function
-- @name IsUserdataOrNil
-- @param var Variable to test.
-- @return If true, variable is a userdata or <b>nil</b>.

TypePair("Userdata")

-- Cache module members.
_HasMeta_ = _M.HasMeta
_IsCallable_ = _M.IsCallable
_IsCountable_ = _M.IsCountable
_IsIndexableR_ = _M.IsIndexableR
_IsInteger_ = _M.IsInteger
_IsNonNegativeInteger_ = _M.IsNonNegativeInteger
_IsNumber_ = _M.IsNumber

-- Export the module.
return _M