--[[
  Module: MovementCommands
  Description: 移动与角色相关命令集。
  Part of: ChuScript
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

return function(cs)
  local playerService = cs.players
  local utilityService = cs.utility

  -- 1. Fly 命令
  cs:registerCommand("fly", {"f"}, "开启/关闭本地飞行", function(args)
    local targets = playerService:getTargets(args[1] or "me")
    local speed = tonumber(args[2]) or 50

    if #targets == 0 then return false, "No valid targets found." end

    for _, p in ipairs(targets) do
      if utilityService._flyConnections[p] then
        utilityService:stopFly(p)
      else
        utilityService:startFly(p, speed)
      end
    end
    return true, "Toggled fly for " .. #targets .. " player(s)."
  end)

  -- 2. Noclip 命令
  cs:registerCommand("noclip", {"nc"}, "开启/关闭本地穿墙", function(args)
    local targets = playerService:getTargets(args[1] or "me")

    for _, p in ipairs(targets) do
      if utilityService._noclipConnections[p] then
        utilityService:stopNoclip(p)
      else
        utilityService:startNoclip(p)
      end
    end
    return true, "Toggled noclip for " .. #targets .. " player(s)."
  end)

  -- 3. WalkSpeed 命令
  cs:registerCommand("walkspeed", {"ws", "speed"}, "修改本地移动速度", function(args)
    local targets = playerService:getTargets(args[1] or "me")
    local speed = tonumber(args[2]) or 16

    for _, p in ipairs(targets) do
      local char = p.Character
      local hum = char and char:FindFirstChildOfClass("Humanoid")
      if hum then
        hum.WalkSpeed = speed
      end
    end
    return true, string.format("Set WalkSpeed to %d for %d player(s).", speed, #targets)
  end)

  -- 4. JumpPower 命令
  cs:registerCommand("jumppower", {"jp"}, "修改本地跳跃力", function(args)
    local targets = playerService:getTargets(args[1] or "me")
    local power = tonumber(args[2]) or 50

    for _, p in ipairs(targets) do
      local char = p.Character
      local hum = char and char:FindFirstChildOfClass("Humanoid")
      if hum then
        hum.UseJumpPower = true
        hum.JumpPower = power
      end
    end
    return true, string.format("Set JumpPower to %d for %d player(s).", power, #targets)
  end)

  -- 5. Goto 命令 (传送到某人身边)
  cs:registerCommand("goto", {"to"}, "传送到指定玩家身边", function(args)
    local targets = playerService:getTargets(args[1] or "")
    if #targets == 0 then return false, "No target found to goto." end

    local targetChar = targets[1].Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    local localRoot = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    if targetRoot and localRoot then
      localRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
      return true, "Teleported to " .. targets[1].Name
    end
    return false, "Failed to get HumanoidRootPart."
  end)

  -- 6. TP 命令 (传送至坐标)
  cs:registerCommand("teleport", {"tp"}, "传送到指定坐标 (x y z)", function(args)
    local x = tonumber(args[1])
    local y = tonumber(args[2])
    local z = tonumber(args[3])

    if not x or not y or not z then return false, "Invalid coordinates. Usage: tp <x> <y> <z>" end

    local localRoot = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if localRoot then
      localRoot.CFrame = CFrame.new(x, y, z)
      return true, string.format("Teleported to %d, %d, %d", x, y, z)
    end
    return false, "Local character not found."
  end)
end