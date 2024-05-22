local pendingCallbacks = {}
local cbEvent = '__ox_cb_%s'
local callbackTimeout = GetConvarInt('ox:callbackTimeout', 300000)

RegisterNetEvent(cbEvent:format(cache.resource), function(key, ...)
	local cb = pendingCallbacks[key]
    pendingCallbacks[key] = nil

	return cb and cb(...)
end)

---@param _ any
---@param event string
---@param playerId number
---@param cb function|false
---@param ... any
---@return ...
local function triggerClientCallback(_, event, playerId, cb, ...)
	local key

	repeat
		key = ('%s:%s:%s'):format(event, math.random(0, 100000), playerId)
	until not pendingCallbacks[key]

	TriggerClientEvent(cbEvent:format(event), playerId, cache.resource, key, ...)

	---@type promise | false
	local promise = not cb and promise.new()

	pendingCallbacks[key] = function(response, ...)
        response = { response, ... }

		if promise then
			return promise:resolve(response)
		end

        if cb then
            cb(table.unpack(response))
        end
	end

	if promise then
        if callbackTimeout > 0 then
            SetTimeout(callbackTimeout, function() promise:reject(("callback event '%s' timed out"):format(key)) end)
        end

		return table.unpack(Citizen.Await(promise))
	end
end

---@overload fun(event: string, playerId: number, cb: function, ...)
lib.callback = setmetatable({}, {
	__call = triggerClientCallback
})

---@param event string
---@param playerId number
--- Sends an event to a client and halts the current thread until a response is returned.
function lib.callback.await(event, playerId, ...)
	return triggerClientCallback(nil, event, playerId, false, ...)
end

local function callbackResponse(success, result, ...)
	if not success then
		if result then
			return print(('^1SCRIPT ERROR: %s^0\n%s'):format(result , Citizen.InvokeNative(`FORMAT_STACK_TRACE` & 0xFFFFFFFF, nil, 0, Citizen.ResultAsString()) or ''))
		end

		return false
	end

	return result, ...
end

local pcall = pcall

---@param name string
---@param cb function
--- Registers an event handler and callback function to respond to client requests.
function lib.callback.register(name, cb)
	RegisterNetEvent(cbEvent:format(name), function(resource, key, ...)
		TriggerClientEvent(cbEvent:format(resource), source, key, callbackResponse(pcall(cb, source, ...)))
	end)
end

return lib.callback


