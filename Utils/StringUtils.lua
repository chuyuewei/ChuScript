--!strict
--[[
  Module: StringUtils
  Description: 通用字符串处理工具,纯函数,无副作用。
]]

local StringUtils = {}

-- 预编译匹配模式(避免每次调用重新构造)
local SPACE_PATTERN = "%s+"
local QUOTE_PATTERN = '^"'

function StringUtils.trim(s: string): string
	return string.match(s, "^%s*(.-)%s*$") :: string
end

--- 引号感知分词:支持 "a b" 作为一个 token。
function StringUtils.tokenize(input: string): { string }
	local tokens: { string } = {}
	local inQuote = false
	local buf: { string } = {}
	local i = 1
	local len = #input

	local function flush()
		if #buf > 0 then
			local token = table.concat(buf)
			table.clear(buf)
			table.insert(tokens, token)
		end
	end

	while i <= len do
		local c = string.sub(input, i, i)
		if c == '"' then
			inQuote = not inQuote
		elseif c == " " and not inQuote then
			flush()
		else
			table.insert(buf, c)
		end
		i += 1
	end
	flush()

	-- 去掉可能残留的首尾双引号
	for idx, t in ipairs(tokens) do
		if string.sub(t, 1, 1) == '"' and string.sub(t, -1) == '"' then
			tokens[idx] = string.sub(t, 2, -2)
		end
	end

	return tokens
end

--- Levenshtein 相似度,范围 0..1(1 表示完全相同)。
function StringUtils.calculateSimilarity(a: string, b: string): number
	if a == b then return 1 end
	local lenA = #a
	local lenB = #b
	if lenA == 0 then return lenB == 0 and 1 or 0 end
	if lenB == 0 then return 0 end

	-- 公共前缀优化
	local prefix = 0
	local maxPrefix = math.min(lenA, lenB)
	while prefix < maxPrefix do
		if string.byte(a, prefix + 1) ~= string.byte(b, prefix + 1) then break end
		prefix += 1
	end
	if prefix == maxPrefix then
		return (lenA == lenB) and 1 or (1 - math.abs(lenA - lenB) / math.max(lenA, lenB))
	end

	-- 单行 DP(空间 O(min(lenA,lenB)))
	if lenA < lenB then a, b = b, a; lenA, lenB = lenB, lenA end
	local prev: { number } = table.create(lenB, 0)
	local curr: { number } = table.create(lenB, 0)

	for j = 1, lenB do prev[j] = j end

	for i = 1, lenA do
		curr[1] = i
		local ca = string.byte(a, i)
		for j = 2, lenB do
			local cost = if ca == string.byte(b, j) then 0 else 1
			curr[j] = math.min(
				(curr[j - 1] :: number) + 1,
				(prev[j] :: number) + 1,
				(prev[j - 1] :: number) + cost
			)
		end
		prev, curr = curr, prev
	end

	local distance = prev[lenB]
	return 1 - distance / math.max(lenA, lenB)
end

function StringUtils.startsWith(s: string, prefix: string): boolean
	return string.sub(s, 1, #prefix) == prefix
end

function StringUtils.split(s: string, sep: string?): { string }
	sep = sep or ","
	local result: { string } = {}
	if sep == "" then
		for i = 1, #s do
			table.insert(result, string.sub(s, i, i))
		end
		return result
	end
	for piece in string.gmatch(s, "([^" .. sep .. "]+)") do
		table.insert(result, piece)
	end
	return result
end

return table.freeze(StringUtils)
