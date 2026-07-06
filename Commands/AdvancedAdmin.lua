--[[
  Module: AdvancedAdminCommands
  Description: Further admin commands for bans, mutes, server lock, and announcements.
]]

local Players = game:GetService("Players")

return function(cs)
  local playerService = cs.players

  local bannedPlayers = {}
  local mutedPlayers = {}
  local serverLocked = false
  local allowedLockBypass = {}

  local function isAdmin(player)
    return player == Players.LocalPlayer
  end

  local function getPlayerByName(name)
    if not name or name == "" then
      return nil
    end

    for _, player in ipairs(Players:GetPlayers()) do
      if string.lower(player.Name) == string.lower(name) then
        return player
      end
    end

    return nil
  end

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

  cs:registerCommand("ban", {}, "封禁指定玩家", function(args)
    local target = getPlayerByName(args[1]) or playerService:getTargets(args[1] or "me")[1]
    if not target then
      return false, "Target not found."
    end

    local reason = table.concat(args, " ", 2)
    if reason == "" then
      reason = "Banned by admin"
    end

    bannedPlayers[target] = reason
    target:Kick("You were banned. Reason: " .. reason)
    return true, string.format("Banned %s.", target.Name)
  end)

  cs:registerCommand("unban", {}, "解除封禁", function(args)
    local target = getPlayerByName(args[1])
    if not target then
      return false, "Target not found."
    end

    bannedPlayers[target] = nil
    return true, string.format("Unbanned %s.", target.Name)
  end)

  cs:registerCommand("mute", {}, "禁言指定玩家", function(args)
    local target = getPlayerByName(args[1]) or playerService:getTargets(args[1] or "me")[1]
    if not target then
      return false, "Target not found."
    end

    mutedPlayers[target] = true
    return true, string.format("Muted %s.", target.Name)
  end)

  cs:registerCommand("unmute", {}, "解除禁言", function(args)
    local target = getPlayerByName(args[1]) or playerService:getTargets(args[1] or "me")[1]
    if not target then
      return false, "Target not found."
    end

    mutedPlayers[target] = nil
    return true, string.format("Unmuted %s.", target.Name)
  end)

  cs:registerCommand("serverlock", {"lockserver"}, "锁定服务器，禁止新玩家进入", function(args)
    serverLocked = true
    return true, "Server locked."
  end)

  cs:registerCommand("serverunlock", {"unlockserver"}, "解锁服务器", function(args)
    serverLocked = false
    return true, "Server unlocked."
  end)

  cs:registerCommand("announce", {"bc", "broadcast"}, "向所有玩家发送公告", function(args)
    local message = table.concat(args, " ")
    if message == "" then
      return false, "Usage: announce <message>"
    end

    for _, player in ipairs(Players:GetPlayers()) do
      if player and player.Parent then
        player:Kick("Announcement: " .. message)
      end
    end

    return true, "Broadcast sent."
  end)

  Players.PlayerAdded:Connect(function(player)
    if bannedPlayers[player] then
      player:Kick("You were banned. Reason: " .. bannedPlayers[player])
      return
    end

    if serverLocked and not isAdmin(player) and not allowedLockBypass[player] then
      player:Kick("Server is locked.")
    end
  end)
end
