--[[
  Module: UtilityService
  Description: 物理、循环与状态管理微服务。
  Part of: ChuScript Microservices Architecture
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UtilityService = {}
UtilityService.__index = UtilityService

function UtilityService.new()
  local self = setmetatable({}, UtilityService)
  self._flyConnections = {}
  self._noclipConnections = {}
  self._flyStates = {} -- 记录玩家飞行速度
  return self
end

--- 开启本地飞行。
-- @param player Player 目标玩家
-- @param speed number 飞行速度
function UtilityService:startFly(player, speed)
  self:stopFly(player) -- 确保不重复绑定
  self._flyStates[player] = speed

  local char = player.Character
  if not char then return end
  local root = char:FindFirstChild("HumanoidRootPart")
  local hum = char:FindFirstChildOfClass("Humanoid")
  if not root or not hum then return end

  hum.PlatformStand = true

  local bc = RunService.RenderStepped:Connect(function(dt)
    if not char.Parent or not root.Parent or hum.Health <= 0 then
      self:stopFly(player)
      return
    end
    local cam = workspace.CurrentCamera
    local dir = cam.CFrame.LookVector
    local move = Vector3.new(0, 0, 0)

    -- 获取玩家按键状态 (本地玩家有效)
    if player == Players.LocalPlayer then
      local ui = game:GetService("UserInputService")
      if ui:IsKeyDown(Enum.KeyCode.W) then move = move + dir end
      if ui:IsKeyDown(Enum.KeyCode.S) then move = move - dir end
      if ui:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
      if ui:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
      if ui:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
      if ui:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end
    end

    if move.Magnitude > 0 then
      root.Velocity = move.Unit * speed
    else
      root.Velocity = Vector3.new(0, 0, 0) -- 悬停
    end
  end)

  self._flyConnections[player] = bc
end

--- 关闭本地飞行。
function UtilityService:stopFly(player)
  if self._flyConnections[player] then
    self._flyConnections[player]:Disconnect()
    self._flyConnections[player] = nil
  end
  self._flyStates[player] = nil

  local char = player.Character
  if char then
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if hum then hum.PlatformStand = false end
    if root then root.Velocity = Vector3.new(0, 0, 0) end
  end
end

--- 开启本地穿墙。
function UtilityService:startNoclip(player)
  self:stopNoclip(player)
  
  local bc = RunService.Stepped:Connect(function()
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
      if part:IsA("BasePart") and part.CanCollide then
        part.CanCollide = false
      end
    end
  end)
  self._noclipConnections[player] = bc
end

--- 关闭本地穿墙。
function UtilityService:stopNoclip(player)
  if self._noclipConnections[player] then
    self._noclipConnections[player]:Disconnect()
    self._noclipConnections[player] = nil
  end
end

return UtilityService