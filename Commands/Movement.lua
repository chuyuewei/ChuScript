--[[
  Module: MovementCommands
  Description: 移动与角色相关命令集。
  Part of: ChuScript
]]

local Players = game:GetService("Players")

local function parseNumber(value, fallback)
  if value == nil or value == "" then
    return fallback
  end

  local number = tonumber(value)
  return number or nil
end

local function parseToggle(value)
  if value == nil or value == "" then
    return nil
  end

  local normalized = string.lower(value)
  if normalized == "on" or normalized == "true" or normalized == "1" then
    return true
  elseif normalized == "off" or normalized == "false" or normalized == "0" then
    return false
  end

  return nil
end

return function(cs)
  local playerService = cs.players
  local utilityService = cs.utility

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

  cs:registerCommand("fly", {"f"}, "开启/关闭或设置飞行速度", function(args)
    local targets = playerService:getTargets(args[1] or "me")
    if #targets == 0 then
      return false, "No valid targets found."
    end

    local speedArg = args[2]
    local speed = parseNumber(speedArg, 50)
    local toggle = parseToggle(speedArg)

    for _, target in ipairs(targets) do
      if toggle == false then
        utilityService:stopFly(target)
      elseif toggle == true then
        utilityService:startFly(target, speed or 50)
      elseif utilityService._flyConnections[target] then
        utilityService:stopFly(target)
      else
        utilityService:startFly(target, speed or 50)
      end
    end

    return true, "Toggled fly for " .. #targets .. " player(s)."
  end)

  cs:registerCommand("noclip", {"nc"}, "开启/关闭穿墙", function(args)
    local targets = playerService:getTargets(args[1] or "me")
    if #targets == 0 then
      return false, "No valid targets found."
    end

    for _, target in ipairs(targets) do
      if utilityService._noclipConnections[target] then
        utilityService:stopNoclip(target)
      else
        utilityService:startNoclip(target)
      end
    end

    return true, "Toggled noclip for " .. #targets .. " player(s)."
  end)

  cs:registerCommand("walkspeed", {"ws", "speed"}, "修改移动速度", function(args)
    local targets = playerService:getTargets(args[1] or "me")
    if #targets == 0 then
      return false, "No valid targets found."
    end

    local speed = parseNumber(args[2], 16)
    if speed == nil then
      return false, "Invalid speed value."
    end

    for _, target in ipairs(targets) do
      local character = target.Character
      local humanoid = character and character:FindFirstChildOfClass("Humanoid")
      if humanoid then
        humanoid.WalkSpeed = speed
      end
    end

    return true, string.format("Set WalkSpeed to %d for %d player(s).", speed, #targets)
  end)

  cs:registerCommand("jumppower", {"jp"}, "修改跳跃力", function(args)
    local targets = playerService:getTargets(args[1] or "me")
    if #targets == 0 then
      return false, "No valid targets found."
    end

    local power = parseNumber(args[2], 50)
    if power == nil then
      return false, "Invalid jump power value."
    end

    for _, target in ipairs(targets) do
      local character = target.Character
      local humanoid = character and character:FindFirstChildOfClass("Humanoid")
      if humanoid then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = power
      end
    end

    return true, string.format("Set JumpPower to %d for %d player(s).", power, #targets)
  end)

  cs:registerCommand("goto", {"to"}, "传送到指定玩家身边", function(args)
    local targets = playerService:getTargets(args[1] or "")
    if #targets == 0 then
      return false, "No target found to goto."
    end

    local targetCharacter = targets[1].Character
    local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
    local localRoot = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    if targetRoot and localRoot then
      localRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
      return true, "Teleported to " .. targets[1].Name
    end

    return false, "Failed to get HumanoidRootPart."
  end)

  cs:registerCommand("teleport", {"tp"}, "传送到指定坐标 (x y z)", function(args)
    local x = parseNumber(args[1], nil)
    local y = parseNumber(args[2], nil)
    local z = parseNumber(args[3], nil)

    if not x or not y or not z then
      return false, "Invalid coordinates. Usage: tp <x> <y> <z>"
    end

    local localRoot = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if localRoot then
      localRoot.CFrame = CFrame.new(x, y, z)
      return true, string.format("Teleported to %d, %d, %d", x, y, z)
    end

    return false, "Local character not found."
  end)
end