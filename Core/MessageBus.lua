--[[
  Module: MessageBus
  Description: 异步消息总线，支持微服务间发布-订阅通信。
]]

local MessageBus = {}
MessageBus.__index = MessageBus

--- 创建新的消息总线实例。
-- @return MessageBus
function MessageBus.new()
  local self = setmetatable({}, MessageBus)
  self._subscribers = {}
  return self
end

--- 订阅特定事件类型。
-- @param eventType string 事件类型标识符
-- @param callback function 回调函数，接收 data 参数
-- @return function 取消订阅函数
function MessageBus:subscribe(eventType, callback)
  if not self._subscribers[eventType] then
    self._subscribers[eventType] = {}
  end

  local list = self._subscribers[eventType]
  table.insert(list, callback)
  local index = #list

  return function()
    list[index] = nil
  end
end

--- 发布事件到所有订阅者。
-- @param eventType string 事件类型
-- @param data table 事件数据负载
function MessageBus:publish(eventType, data)
  local listeners = self._subscribers[eventType]
  if not listeners then return end

  for _, callback in ipairs(listeners) do
    if callback then
      task.spawn(function()
        local ok, err = pcall(callback, data)
        if not ok then
          warn(string.format("[MessageBus] Subscriber error for '%s': %s", eventType, err))
        end
      end)
    end
  end
end

return MessageBus