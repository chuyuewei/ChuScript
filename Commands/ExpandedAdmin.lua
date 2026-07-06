--[[
  Module: ExpandedAdminCommands
  Description: 进一步扩展的管理员命令，覆盖工具、传送和状态控制。
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local function getHumanoid(player)
  local character = player and player.Character
  if not character then
    return nil
  end

  return character:FindFirstChildOfClass("Humanoid")
end

local function getRoot(player)
  local character = player and player.Character
  if not character then
    return nil
  end

  return character:FindFirstChild("HumanoidRootPart")
end

return function(cs)
  local playerService = cs.players

  local function applyToTargets(selector, callback)
    local targets = playerService:getTargets(selector or "me")
    if #targets == 0 then
      return false, "No valid targets found."
    end

    for _, player in ipairs(targets) do
      callback(player)
    end

    return true, string.format("Applied to %d player(s).", #targets)
  end

  cs:registerCommand("tool", {"giveweapon", "giveitem"}, "给目标玩家一个工具", function(args)
    local targets = playerService:getTargets(args[1] or "me")
    if #targets == 0 then
      return false, "No valid targets found."
    end

    local toolName = args[2]
    if not toolName or toolName == "" then
      return false, "Usage: tool <player> <toolName>"
    end

    local tool = ReplicatedStorage:FindFirstChild(toolName) or Workspace:FindFirstChild(toolName)
    if not tool then
      return false, string.format("Tool '%s' not found.", toolName)
    end

    for _, player in ipairs(targets) do
      local character = player.Character
      if character then
        local clone = tool:Clone()
        clone.Parent = character
      end
    end

    return true, string.format("Gave '%s' to %d player(s).", toolName, #targets)
  end)

  cs:registerCommand("removeTool", {"rmtool"}, "移除目标玩家身上的工具", function(args)
    local targets = playerService:getTargets(args[1] or "me")
    if #targets == 0 then
      return false, "No valid targets found."
    end

    local toolName = args[2]
    if not toolName or toolName == "" then
      return false, "Usage: removeTool <player> <toolName>"
    end

    for _, player in ipairs(targets) do
      local character = player.Character
      if character then
        local tool = character:FindFirstChild(toolName)
        if tool then
          tool:Destroy()
        end
      end
    end

    return true, string.format("Removed tool '%s' from %d player(s).", toolName, #targets)
  end)

  cs:registerCommand("tpall", {"bringall"}, "把所有玩家传送到你这里", function(args)
    local localRoot = getRoot(Players.LocalPlayer)
    if not localRoot then
      return false, "Local character not found."
    end

    for _, player in ipairs(Players:GetPlayers()) do
      if player ~= Players.LocalPlayer then
        local targetRoot = getRoot(player)
        if targetRoot then
          targetRoot.CFrame = localRoot.CFrame * CFrame.new(0, 0, -3)
        end
      end
    end

    return true, "Brought all players to you."
  end)

  cs:registerCommand("spin", {}, "让目标角色旋转", function(args)
    return applyToTargets(args[1] or "me", function(player)
      local root = getRoot(player)
      if not root then
        return
      end

      local connection
      connection = game:GetService("RunService").RenderStepped:Connect(function()
        if root and root.Parent then
          root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(15), 0)
        else
          connection:Disconnect()
        end
      end)
    end)
  end)

  cs:registerCommand("ragdoll", {}, "让目标角色进入摔倒状态", function(args)
    return applyToTargets(args[1] or "me", function(player)
      local humanoid = getHumanoid(player)
      if humanoid then
        humanoid.PlatformStand = true
        humanoid.WalkSpeed = 0
      end
    end)
  end)

  cs:registerCommand("unragdoll", {}, "解除摔倒状态", function(args)
    return applyToTargets(args[1] or "me", function(player)
      local humanoid = getHumanoid(player)
      if humanoid then
        humanoid.PlatformStand = false
        humanoid.WalkSpeed = 16
      end
    end)
  end)

  cs:registerCommand("sethealth", {"health"}, "设置目标生命值", function(args)
    local targets = playerService:getTargets(args[1] or "me")
    if #targets == 0 then
      return false, "No valid targets found."
    end

    local health = tonumber(args[2]) or 100
    for _, player in ipairs(targets) do
      local humanoid = getHumanoid(player)
      if humanoid then
        humanoid.Health = health
        humanoid.MaxHealth = math.max(health, humanoid.MaxHealth)
      end
    end

    return true, string.format("Set health to %d for %d player(s).", health, #targets)
  end)
end
