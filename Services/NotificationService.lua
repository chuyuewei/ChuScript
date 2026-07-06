--[[
  Module: NotificationService
  Description: 通知管理服务。接管所有系统消息的 UI 展示。
  Part of: ChuScript Microservices Architecture
]]

local Players = game:GetService("Players")
local NotificationUI = require(script.Parent.Parent.Packages.UI.Notification)

local NotificationService = {}
NotificationService.__index = NotificationService

--- 构造函数（依赖注入）。
-- @param messageBus MessageBus
-- @param loggerService LoggerService
-- @return NotificationService
function NotificationService.new(messageBus, loggerService)
  local self = setmetatable({}, NotificationService)
  self._bus = messageBus
  self._logger = loggerService

  self._playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

  -- 独立创建一个 ScreenGui 容器，确保通知永远在最上层
  self._screenGui = Instance.new("ScreenGui")
  self._screenGui.Name = "ChuScriptNotifications"
  self._screenGui.ResetOnSpawn = false
  self._screenGui.DisplayOrder = 100 -- 高于主 UI
  self._screenGui.Parent = self._playerGui

  self._ui = NotificationUI.new(self._screenGui)

  self:_bindSystemEvents()
  self._logger:info("NotificationService initialized")
  return self
end

--- 绑定系统微服务事件，自动触发通知。
function NotificationService:_bindSystemEvents()
  -- 监听命令处理结果
  self._bus:subscribe("CommandProcessed", function(data)
    if data.success then
      self:Send("Command Executed", data.message, 3, "Success")
    else
      -- 错误消息可能包含建议，给予更长的显示时间
      self:Send("Command Failed", data.message, 5, "Error")
    end
  end)

  -- 监听系统级崩溃
  self._bus:subscribe("SystemError", function(data)
    self:Send("System Error", data.message, 7, "Error")
  end)
end

--- 公共 API：发送一条通知。
-- @param title string
-- @param message string
-- @param duration number
-- @param notifType string "Info", "Success", "Warn", "Error"
function NotificationService:Send(title, message, duration, notifType)
  self._ui:Push(title, message, duration, notifType)
end

return NotificationService