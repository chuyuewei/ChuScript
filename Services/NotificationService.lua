--!strict
--[[
  Module: NotificationService
  Description: 通知聚合服务。把 CommandProcessed / SystemError 转为可视化通知。
]]

local Players = game:GetService("Players")
local MessageBus = require(script.Parent.Core.MessageBus)
local LoggerService = require(script.Parent.Services.LoggerService)
local NotificationUI = require(script.Parent.Parent.Packages.UI.Notification)

local NotificationService = {}
NotificationService.__index = NotificationService

export type NotificationType = "Info" | "Success" | "Warn" | "Error"

function NotificationService.new(messageBus: MessageBus.MessageBus, loggerService: LoggerService.LoggerService)
	assert(messageBus and loggerService, "Missing dependencies")

	local self = setmetatable({}, NotificationService)
	self._bus = messageBus
	self._logger = loggerService

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self._screenGui = Instance.new("ScreenGui")
	self._screenGui.Name = "ChuScriptNotifications"
	self._screenGui.ResetOnSpawn = false
	self._screenGui.DisplayOrder = 100
	self._screenGui.IgnoreGuiInset = true
	self._screenGui.Enabled = true
	self._screenGui.Parent = playerGui

	self._ui = NotificationUI.new(self._screenGui)
	self._bindings = {}

	self:_bindSystemEvents()
	self._logger:info("NotificationService initialized")
	return self
end

function NotificationService:_bindSystemEvents()
	self._bindings.command = self._bus:subscribe("CommandProcessed", function(data: { success: boolean, message: string })
		if type(data) ~= "table" then return end
		local title, kind, duration = "Command Executed", "Success", 3
		if not data.success then
			title, kind, duration = "Command Failed", "Error", 5
		end
		self:Send(title, tostring(data.message or ""), duration, kind)
	end)

	self._bindings.error = self._bus:subscribe("SystemError", function(data)
		if type(data) ~= "table" then return end
		local msg = if type(data.message) == "string" then data.message else "(no message)"
		self:Send("System Error", msg, 7, "Error")
	end)
end

function NotificationService:Send(title: string, message: string, duration: number?, notifType: NotificationType?)
	self._ui:Push(title, message, duration or 3, notifType or "Info")
end

function NotificationService:destroy()
	for _, token in pairs(self._bindings) do
		self._bus:unsubscribe(token)
	end
	if self._screenGui and self._screenGui.Parent then
		self._screenGui:Destroy()
	end
end

return table.freeze(NotificationService)
