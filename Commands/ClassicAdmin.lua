--[[
  Module: ClassicAdminCommands
  Description: 参考 IY / CMD-X 风格扩展的常用管理员命令。
]]

local Players = game:GetService("Players")
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

  local godStates = {}
  local invisibilityStates = {}

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

  cs:registerCommand("god", {"godmode"}, "开启/关闭无敌模式", function(args)
    return applyToTargets(args[1] or "me", function(player)
      local humanoid = getHumanoid(player)
      if not humanoid then
        return
      end

      if godStates[player] then
        humanoid.MaxHealth = godStates[player].maxHealth
        humanoid.Health = godStates[player].health
        godStates[player] = nil
      else
        godStates[player] = {
          maxHealth = humanoid.MaxHealth,
          health = humanoid.Health,
        }
        humanoid.MaxHealth = 100000000
        humanoid.Health = 100000000
      end
    end)
  end)

  cs:registerCommand("invis", {"invisible", "ghost"}, "开启/关闭隐身", function(args)
    return applyToTargets(args[1] or "me", function(player)
      local character = player and player.Character
      if not character then
        return
      end

      if invisibilityStates[player] then
        for part, originalTransparency in pairs(invisibilityStates[player]) do
          if part and part.Parent then
            part.Transparency = originalTransparency
          end
        end
        invisibilityStates[player] = nil
      else
        local records = {}
        for _, descendant in ipairs(character:GetDescendants()) do
          if descendant:IsA("BasePart") then
            records[descendant] = descendant.Transparency
            descendant.Transparency = 1
          end
        end
        invisibilityStates[player] = records
      end
    end)
  end)

  cs:registerCommand("visible", {"vis"}, "解除隐身", function(args)
    return applyToTargets(args[1] or "me", function(player)
      local records = invisibilityStates[player]
      if not records then
        return
      end

      for part, originalTransparency in pairs(records) do
        if part and part.Parent then
          part.Transparency = originalTransparency
        end
      end
      invisibilityStates[player] = nil
    end)
  end)

  cs:registerCommand("explode", {"boom"}, "让目标角色爆炸", function(args)
    return applyToTargets(args[1] or "me", function(player)
      local root = getRoot(player)
      if not root then
        return
      end

      local explosion = Instance.new("Explosion")
      explosion.Position = root.Position
      explosion.BlastRadius = 8
      explosion.BlastPressure = 0
      explosion.DestroyJointRadiusPercent = 0
      explosion.Parent = Workspace
    end)
  end)

  cs:registerCommand("reset", {"rejoin"}, "重置目标角色", function(args)
    return applyToTargets(args[1] or "me", function(player)
      if player and player.Parent then
        player:LoadCharacter()
      end
    end)
  end)

  cs:registerCommand("kick", {}, "将目标踢出游戏", function(args)
    local targets = playerService:getTargets(args[1] or "me")
    if #targets == 0 then
      return false, "No valid targets found."
    end

    local reason = table.concat(args, " ", 2)
    if reason == "" then
      reason = "Kicked by admin"
    end

    for _, player in ipairs(targets) do
      if player ~= Players.LocalPlayer then
        player:Kick(reason)
      end
    end

    return true, string.format("Kicked %d player(s).", #targets)
  end)
end
