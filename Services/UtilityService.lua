--!strict
--[[
  Module: UtilityService
  Description: 飞行、穿墙等持续性能力。统一管理 RBXScriptConnection 生命周期。
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UtilityService = {}
UtilityService.__index = UtilityService

type FlyState = {
	connection: RBXScriptConnection,
	speed: number,
}

type NoclipState = {
	connection: RBXScriptConnection,
	trackedParts: { BasePart },
}

function UtilityService.new()
	local self = setmetatable({}, UtilityService)
	self._flyStates = {} :: { [Player]: FlyState }
	self._noclipStates = {} :: { [Player]: NoclipState }
	return self
end

--- 从 Character 拿 humanoid 与 root,做空值保护。
local function getHumanoid(player: Player): Humanoid?
	local char = player and player.Character
	return if char then char:FindFirstChildOfClass("Humanoid") else nil
end

local function getRoot(player: Player): BasePart?
	local char = player and player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isAlive(player: Player): boolean
	local hum = getHumanoid(player)
	return hum ~= nil and hum.Health > 0
end

function UtilityService:startFly(player: Player, speed: number?)
	assert(player ~= nil, "player required")
	self:stopFly(player)

	local hum = getHumanoid(player)
	local root = getRoot(player)
	if not hum or not root then return end

	speed = tonumber(speed) or 50
	hum.PlatformStand = true

	local connection = RunService.RenderStepped:Connect(function(dt)
		-- 角色失效时自动断开,避免悬挂连接
		if not root.Parent or hum.Health <= 0 then
			self:stopFly(player)
			return
		end

		local cam = workspace.CurrentCamera
		local dir = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
		local right = cam and cam.CFrame.RightVector or Vector3.new(1, 0, 0)
		local move = Vector3.zero

		-- 仅本地玩家读取按键,降低不必要的服务调用
		if player == Players.LocalPlayer then
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += dir end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= dir end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.yAxis end
		end

		if move.Magnitude > 0 then
			root.Velocity = move.Unit * speed
		else
			root.Velocity = Vector3.zero
		end
	end)

	self._flyStates[player] = { connection = connection, speed = speed }
end

function UtilityService:stopFly(player: Player)
	local state = self._flyStates[player]
	if state then
		state.connection:Disconnect()
		self._flyStates[player] = nil
	end

	local hum = getHumanoid(player)
	local root = getRoot(player)
	if hum then hum.PlatformStand = false end
	if root then root.Velocity = Vector3.zero end
end

function UtilityService:isFlying(player: Player): boolean
	return self._flyStates[player] ~= nil
end

function UtilityService:startNoclip(player: Player)
	assert(player ~= nil, "player required")
	self:stopNoclip(player)

	-- 预扫描角色所有 BasePart,后续每帧仅切 CanCollide 即可。
	local char = player.Character
	if not char then return end
	local parts: { BasePart } = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(parts, d) end
	end

	local connection = RunService.Stepped:Connect(function()
		if not char.Parent then
			self:stopNoclip(player)
			return
		end
		for _, part in ipairs(parts) do
			if part.Parent and part.CanCollide then
				part.CanCollide = false
			end
		end
	end)

	self._noclipStates[player] = { connection = connection, trackedParts = parts }
end

function UtilityService:stopNoclip(player: Player)
	local state = self._noclipStates[player]
	if state then
		state.connection:Disconnect()
		-- 恢复碰撞状态(若角色仍存在)
		local char = player.Character
		if char then
			for _, part in ipairs(state.trackedParts) do
				if part.Parent then part.CanCollide = true end
			end
		end
		self._noclipStates[player] = nil
	end
end

function UtilityService:isNoclipping(player: Player): boolean
	return self._noclipStates[player] ~= nil
end

--- 关停所有绑定(脚本结束 / LocalePlayer 重生时建议调用)。
function UtilityService:shutdown()
	for player in pairs(self._flyStates) do
		self:stopFly(player)
	end
	for player in pairs(self._noclipStates) do
		self:stopNoclip(player)
	end
end

return table.freeze(UtilityService)
