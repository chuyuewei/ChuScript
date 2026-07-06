--[[
  Module: AdministrationCommands
  Description: 基础管理员命令集合。
]]

local Players = game:GetService("Players")

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

  cs:registerCommand("kill", {"slay"}, "让目标角色失去生命", function(args)
    return applyToTargets(args[1] or "me", function(player)
      local humanoid = getHumanoid(player)
      if humanoid then
        humanoid.Health = 0
      end
    end)
  end)

  cs:registerCommand("heal", {"hp"}, "恢复目标生命值", function(args)
    return applyToTargets(args[1] or "me", function(player)
      local humanoid = getHumanoid(player)
      if humanoid then
        humanoid.Health = humanoid.MaxHealth
      end
    end)
  end)

  cs:registerCommand("respawn", {"re"}, "重生目标玩家", function(args)
    return applyToTargets(args[1] or "me", function(player)
      if player and player.Parent then
        player:LoadCharacter()
      end
    end)
  end)

  cs:registerCommand("freeze", {"ff"}, "冻结目标移动", function(args)
    return applyToTargets(args[1] or "me", function(player)
      local humanoid = getHumanoid(player)
      if humanoid then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.PlatformStand = true
      end
    end)
  end)

  cs:registerCommand("unfreeze", {"uf"}, "解除冻结", function(args)
    return applyToTargets(args[1] or "me", function(player)
      local humanoid = getHumanoid(player)
      if humanoid then
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
        humanoid.PlatformStand = false
      end
    end)
  end)

  cs:registerCommand("sit", {}, "让目标角色坐下", function(args)
    return applyToTargets(args[1] or "me", function(player)
      local humanoid = getHumanoid(player)
      if humanoid then
        humanoid.Sit = true
      end
    end)
  end)

  cs:registerCommand("stand", {}, "让目标角色站起", function(args)
    return applyToTargets(args[1] or "me", function(player)
      local humanoid = getHumanoid(player)
      if humanoid then
        humanoid.Sit = false
      end
    end)
  end)

  cs:registerCommand("bring", {"gethere"}, "将目标拉到你身边", function(args)
    local targets = playerService:getTargets(args[1] or "me")
    if #targets == 0 then
      return false, "No valid targets found."
    end

    local localRoot = getRoot(Players.LocalPlayer)
    if not localRoot then
      return false, "Local character not found."
    end

    for _, target in ipairs(targets) do
      local targetRoot = getRoot(target)
      if targetRoot then
        targetRoot.CFrame = localRoot.CFrame * CFrame.new(0, 0, -3)
      end
    end

    return true, string.format("Brought %d player(s) to you.", #targets)
  end)
end
