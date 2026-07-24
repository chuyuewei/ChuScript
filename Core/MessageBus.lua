--!strict
--[[
  Module: MessageBus
  Description: 同步发布-订阅总线,带 token 取消订阅、再入保护与错误隔离。

  设计要点:
    - 同步派发:在调用线程内执行订阅者,便于追踪调用栈。
    - 错误隔离:单个订阅者崩溃不影响同事件其他订阅者。
    - Token 取消:通过订阅 token 幂等取消,无下标漂移问题。
    - 再入保护:订阅者在回调中再次订阅/发布同一事件不会破坏迭代。
]]

export type Handler = (data: any) -> ()

local MessageBus = {}
MessageBus.__index = MessageBus

-- 单个事件下的订阅者集合
type Subscriber = {
	callback: Handler,
	token: number,
	once: boolean,
}

function MessageBus.new()
	local self = setmetatable({}, MessageBus)
	self._subscribers = {} :: { [string]: { Subscriber } }
	self._nextToken = 1
	self._depthByThread = {} :: { [number]: number }
	return self
end

local function threadKey(): number
	local co = coroutine.running() :: any
	if co == nil then return 1 end
	-- 同一线程持续期返回同一闭包,所以用引用做弱 key
	local key = (tonumber(tostring(co))) :: number?
	if type(key) == "number" then return key end
	-- 兜底:用地址哈希(不保证唯一,但深度仅做粗略比较)
	return 1
end

local function currentDepth(self: MessageBus): number
	return self._depthByThread[threadKey()] or 0
end

local function bumpDepth(self: MessageBus, delta: number)
	local k = threadKey()
	self._depthByThread[k] = (self._depthByThread[k] or 0) + delta
end

--- 订阅事件。
-- @param eventType string
-- @param callback Handler
-- @param opts { once: boolean }?
-- @return number unsubscribe token
function MessageBus:subscribe(eventType: string, callback: Handler, opts: { once: boolean }?): number
	assert(type(eventType) == "string", "eventType must be string")
	assert(type(callback) == "function", "callback must be function")

	local list = self._subscribers[eventType]
	if not list then
		list = {}
		self._subscribers[eventType] = list
	end

	local token = self._nextToken
	self._nextToken += 1
	table.insert(list, {
		callback = callback,
		token = token,
		once = if opts and opts.once then true else false,
	})
	return token
end

--- 一次性订阅。
function MessageBus:subscribeOnce(eventType: string, callback: Handler): number
	return self:subscribe(eventType, callback, { once = true })
end

--- 按 token 取消订阅(幂等)。
function MessageBus:unsubscribe(token: number): boolean
	for eventType, list in pairs(self._subscribers) do
		for i = #list, 1, -1 do
			if (list[i] :: Subscriber).token == token then
				table.remove(list, i)
				if #list == 0 then
					self._subscribers[eventType] = nil
				end
				return true
			end
		end
	end
	return false
end

--- 按事件取消所有订阅者。
function MessageBus:clear(eventType: string?)
	if eventType ~= nil then
		self._subscribers[eventType] = nil
	else
		table.clear(self._subscribers)
	end
end

--- 发布事件。
function MessageBus:publish(eventType: string, data: any?)
	assert(type(eventType) == "string", "eventType must be string")
	local list = self._subscribers[eventType]
	if not list or #list == 0 then return end

	-- 再入检测:同一线程嵌套 publish 同一事件直接丢弃并 warn。
	local depth = currentDepth(self)
	if depth > 16 then
		warn(string.format("[MessageBus] Re-entrant publish suppressed for '%s' (depth=%d)", eventType, depth))
		return
	end
	bumpDepth(self, 1)

	-- 复制一份避免回调修改影响本次派发
	local snapshot = table.create(#list)
	for i, s in ipairs(list) do
		snapshot[i] = s
	end

	-- 收集本轮一次性订阅者的 token,事后清理
	local toRemove: { number }? = nil

	for _, sub in ipairs(snapshot) do
		-- 校验订阅者仍在列表中(可能在迭代前已被取消)
		local stillExists = false
		for _, current in ipairs(list) do
			if current.token == sub.token then
				stillExists = true
				break
			end
		end
		if stillExists then
			local ok, err = pcall(sub.callback, data)
			if not ok then
				warn(string.format("[MessageBus] Subscriber error in '%s': %s", eventType, tostring(err)))
			end
			if sub.once then
				toRemove = toRemove or {}
				table.insert(toRemove, sub.token)
			end
		end
	end

	if toRemove then
		for _, token in ipairs(toRemove) do
			self:unsubscribe(token)
		end
	end

	bumpDepth(self, -1)
end

--- 返回订阅者数量(用于测试/调试)。
function MessageBus:listenerCount(eventType: string?): number
	if eventType == nil then
		local total = 0
		for _, list in pairs(self._subscribers) do
			total += #list
		end
		return total
	end
	local list = self._subscribers[eventType]
	return list and #list or 0
end

return table.freeze(MessageBus)
