--[[
  Module: PlayerService
  Description: 玩家目标选择器微服务。解析 "me", "all", 玩家名片段等为目标数组。
  Part of: ChuScript Microservices Architecture
]]

local Players = game:GetService("Players")

local PlayerService = {}
PlayerService.__index = PlayerService

function PlayerService.new()
  local self = setmetatable({}, PlayerService)
  return self
end

--- 解析目标字符串为数组。
-- @param selector string 目标字符串 (如 "me", "all", "others", "player1,player2")
-- @param excludeSelf boolean 当目标为 all 时是否排除自己
-- @return table Player 对象数组
function PlayerService:getTargets(selector, excludeSelf)
  local localPlayer = Players.LocalPlayer
  selector = string.lower(selector or "")
  local targets = {}
  local seen = {} -- 防止重复添加

  local function addPlayer(p)
    if p and not seen[p] then
      table.insert(targets, p)
      seen[p] = true
    end
  end

  -- 支持逗号分隔的多目标
  for part in string.gmatch(selector, "[^,]+") do
    part = string.gsub(part, "%s", "") -- 去除空格
    
    if part == "me" then
      if not excludeSelf then addPlayer(localPlayer) end
    elseif part == "all" then
      for _, p in ipairs(Players:GetPlayers()) do
        if not (excludeSelf and p == localPlayer) then addPlayer(p) end
      end
    elseif part == "others" then
      for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then addPlayer(p) end
      end
    elseif part == "random" then
      local available = excludeSelf and {} or Players:GetPlayers()
      if excludeSelf then
        for _, p in ipairs(Players:GetPlayers()) do
          if p ~= localPlayer then table.insert(available, p) end
        end
      end
      if #available > 0 then addPlayer(available[math.random(1, #available)]) end
    else
      -- 匹配具体玩家名/显示名片段
      for _, p in ipairs(Players:GetPlayers()) do
        if string.find(string.lower(p.Name), part, 1, true) or 
           string.find(string.lower(p.DisplayName), part, 1, true) then
          addPlayer(p)
        end
      end
    end
  end

  return targets
end

return PlayerService