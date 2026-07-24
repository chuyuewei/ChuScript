--!strict
--[[
  Module: PlayerService
  Description: 玩家目标选择器。"me", "all", "others", "random", 名称片段。
]]

local Players = game:GetService("Players")

local PlayerService = {}
PlayerService.__index = PlayerService

-- 缓存:玩家名/显示名的小写版本,避免每次匹配重复 lower()
local nameCache = {} :: { [number]: { lowerName: string, lowerDisplay: string } }

local function ensureCacheEntry(player)
	local cached = nameCache[player.UserId]
	if cached then return cached end
	local entry = {
		lowerName = string.lower(player.Name),
		lowerDisplay = string.lower(player.DisplayName),
	}
	nameCache[player.UserId] = entry
	return entry
end

-- 玩家增删时维护缓存
Players.PlayerAdded:Connect(function(p) ensureCacheEntry(p) end)
Players.PlayerRemoving:Connect(function(p) nameCache[p.UserId] = nil end)
for _, p in ipairs(Players:GetPlayers()) do ensureCacheEntry(p) end

function PlayerService.new()
	local self = setmetatable({}, PlayerService)
	return self
end

--- 主入口。
function PlayerService:getTargets(selector: string?, excludeSelf: boolean?): { Player }
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then return {} end

	selector = string.lower(string.match(selector or "", "^%s*(.-)%s*$") or "")
	local targets: { Player } = {}
	local seen: { [Player]: true } = {}

	local function add(p: Player?)
		if p and not seen[p] then
			seen[p] = true
			table.insert(targets, p)
		end
	end

	if selector == "" then
		add(string.lower("me") == "" and localPlayer or localPlayer) -- 兼容空字符串
	else
		for part in string.gmatch(selector, "[^,]+") do
			part = string.match(part, "^%s*(.-)%s*$") or ""
			if part == "me" then
				if not excludeSelf then add(localPlayer) end
			elseif part == "all" then
				for _, p in ipairs(Players:GetPlayers()) do
					if not (excludeSelf and p == localPlayer) then add(p) end
				end
			elseif part == "others" then
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= localPlayer then add(p) end
				end
			elseif part == "random" then
				local pool: { Player } = {}
				for _, p in ipairs(Players:GetPlayers()) do
					if not (excludeSelf and p == localPlayer) then table.insert(pool, p) end
				end
				if #pool > 0 then add(pool[math.random(1, #pool)]) end
			else
				-- 名称/显示名子串匹配
				for _, p in ipairs(Players:GetPlayers()) do
					local entry = ensureCacheEntry(p)
					if string.find(entry.lowerName, part, 1, true)
						or string.find(entry.lowerDisplay, part, 1, true) then
						add(p)
					end
				end
			end
		end
	end

	return targets
end

--- 通过用户名/显示名精确查找一个玩家。
function PlayerService:getPlayerByName(name: string?): Player?
	if not name or name == "" then return nil end
	local lower = string.lower(name)
	for _, p in ipairs(Players:GetPlayers()) do
		local entry = ensureCacheEntry(p)
		if entry.lowerName == lower or entry.lowerDisplay == lower then
			return p
		end
	end
	return nil
end

--- 模糊匹配玩家(供 Picker UI 使用)。
function PlayerService:searchPlayers(query: string?, limit: number?): { Player }
	query = string.lower(string.match(query or "", "^%s*(.-)%s*$") or "")
	limit = limit or 10
	if query == "" then
		local all = Players:GetPlayers()
		local out = table.create(math.min(limit, #all))
		for i = 1, math.min(limit, #all) do out[i] = all[i] end
		return out
	end

	local out: { Player } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local entry = ensureCacheEntry(p)
		if string.find(entry.lowerName, query, 1, true)
			or string.find(entry.lowerDisplay, query, 1, true) then
			table.insert(out, p)
			if #out >= limit then break end
		end
	end
	return out
end

return table.freeze(PlayerService)
