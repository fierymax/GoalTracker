--[[
    GoalTracker / 目标追踪
    Core.lua - 数据层、账号金币统计、目标计算、里程碑播报
]]--

local ADDON_NAME, ns = ...
local L = ns.L

ns.ADDON_NAME = ADDON_NAME
ns.VERSION    = "1.0.0"

----------------------------------------------------------------------
-- 默认值（账号全局：TOC 中使用 SavedVariables，非 PerCharacter）
----------------------------------------------------------------------
local DEFAULTS = {
    version = 2,

    -- 位置
    point    = "CENTER",
    relPoint = "CENTER",
    x        = 0,
    y        = 150,
    locked   = false,
    clickThrough = false,
    rightClickOptions = false,   -- 右键点进度文字打开设置（默认关）
    scale    = 1,
    strata   = "MEDIUM",

    -- 目标（战网账号共用）
    goalType    = "money",
    label       = "",
    textFormat  = "{name}  {cur} / {goal}  ({pct})",

    -- 外观
    font        = nil,
    fontSize    = 20,
    fontOutline = "OUTLINE",
    useShadow   = true,
    shadowColor = { 0, 0, 0, 1 },
    color          = { 1, 0.82, 0, 1 },
    useCompleteColor = true,
    completeColor  = { 0.1, 1, 0.2, 1 },

    -- 金币
    moneyGoal   = 7000000,
    moneyScope  = "account",

    -- 其它类型参数
    itemID      = nil,
    itemGoal    = 1,
    includeBank = true,
    questID     = nil,
    factionID   = nil,
    factionGoal = 8,
    currencyID  = nil,
    currencyGoal = 0,
    currencyUseMax = false,
    customCurrent = 0,
    customTarget  = 100,

    -- 账号金币统计
    characters = {},          -- ["名字-服务器"] = { money, time, class, level }
    warband    = { money = 0, time = 0 },

    -- 里程碑播报
    notifyEnabled  = true,
    notifyStep     = 0.01,
    notifyFormat   = nil,
    notifySize     = 36,
    notifyColor    = { 1, 0.85, 0.2, 1 },
    notifyDuration = 3,
    notifyOffsetY  = 120,
    notifySound    = false,

    -- 大里程碑（10/25/33/50/75/90%）
    bigStepEnabled = true,
    bigColor       = { 1, 0.92, 0.35, 1 },

    -- 花钱时的惋惜提示
    regretEnabled  = true,
    regretStep     = 0.01,                  -- 花掉目标金额的百分之多少才提示
    regretColor    = { 1, 0.55, 0.55, 1 },
    regretFormat   = nil,
    regretSound    = false,

    -- 直播 / 外部读取
    liveEnabled      = false,   -- 总开关
    liveFrameEnabled = true,    -- 游戏内直播框（OBS 游戏捕获，实时）
    liveSaveEnabled  = true,    -- 写进存档（配合外部脚本导出成 txt）
    liveFormat       = nil,     -- 默认 {cur} / {goal} ({pct})
    liveSize         = 28,
    liveColor        = { 1, 0.82, 0, 1 },
    liveBg           = 0.5,     -- 背景不透明度，0 = 全透明
    liveWidth        = 280,
    livePoint        = "BOTTOM",
    liveRelPoint     = "BOTTOM",
    liveX            = 0,
    liveY            = 120,
    live             = nil,     -- 最新快照 { text, cur, goal, pct, remain, name, time }
    praiseList     = nil,
    lastStep       = nil,
    lastTotal      = nil,
    lastPraise     = nil,

    -- 聊天命令（v2.1：自动避开与其它插件冲突）
    chatCommand    = nil,     -- 自定义主命令，例如 "gtx"（不含斜杠）
    forceGT        = false,   -- true = 即使 /gt 已被其它插件占用也强行接管
}

local function ApplyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = {}
                ApplyDefaults(dst[k], v)
            else
                dst[k] = v
            end
        elseif type(v) == "table" and type(dst[k]) == "table" then
            ApplyDefaults(dst[k], v)
        end
    end
end

----------------------------------------------------------------------
-- 工具
----------------------------------------------------------------------
local function Clamp(v, lo, hi)
    if not v then return lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
ns.Clamp = Clamp

function ns.FormatNumber(n)
    if not n then return "0" end
    n = tonumber(n) or 0
    local neg = n < 0
    n = math.abs(math.floor(n + 0.5))
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    if neg then out = "-" .. out end
    return out
end

local function ShortNum(n)
    n = tonumber(n) or 0
    local loc = GetLocale()
    if loc == "zhCN" or loc == "zhTW" then
        if math.abs(n) >= 100000000 then
            return string.format("%.2f亿", n / 100000000)
        elseif math.abs(n) >= 10000 then
            return string.format("%.1f万", n / 10000)
        end
    else
        if math.abs(n) >= 1000000 then
            return string.format("%.2fM", n / 1000000)
        elseif math.abs(n) >= 10000 then
            return string.format("%.1fK", n / 1000)
        end
    end
    return ns.FormatNumber(n)
end
ns.ShortNum = ShortNum

local function SafeCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(func, ...)
    if ok then return a, b, c, d, e end
    return nil
end
ns.SafeCall = SafeCall

----------------------------------------------------------------------
-- 音效：拾取金币声
----------------------------------------------------------------------
local COIN_KITS = nil

function ns:PlayCoinSound()
    if not COIN_KITS then
        COIN_KITS = {}
        -- 按优先级取第一个客户端支持的音效
        local names = {
            "LOOT_WINDOW_COIN_SOUND",   -- 拾取窗口金币声（首选）
            "IG_BACKPACK_COIN_OPEN",    -- 打开钱袋
            "IG_BACKPACK_COIN_SELECT",  -- 选中金币
            "IG_BACKPACK_COIN_CLOSE",
        }
        if type(SOUNDKIT) == "table" then
            for _, n in ipairs(names) do
                if SOUNDKIT[n] then table.insert(COIN_KITS, SOUNDKIT[n]) end
            end
        end
        table.insert(COIN_KITS, 120)    -- 兜底：经典金币音效 ID
    end
    for _, kit in ipairs(COIN_KITS) do
        local played = SafeCall(PlaySound, kit, "SFX")
        if played then return true end
    end
    return false
end

----------------------------------------------------------------------
-- 字体
----------------------------------------------------------------------
local LSM = nil
if LibStub then
    LSM = SafeCall(LibStub, "LibSharedMedia-3.0", true)
end

local function GetDefaultFont()
    local f = SafeCall(function() return select(1, GameFontHighlight:GetFont()) end)
    if f and f ~= "" then return f end
    local loc = GetLocale()
    if loc == "zhCN" or loc == "zhTW" then return "Fonts\\ARKai_T.ttf" end
    return "Fonts\\FRIZQT__.ttf"
end
ns.GetDefaultFont = GetDefaultFont

function ns:GetFontList()
    if self.fontList then return self.fontList end
    local list, seen = {}, {}
    local fonts = SafeCall(GetFonts)
    if type(fonts) == "table" then
        for _, path in pairs(fonts) do
            if type(path) == "string" and not seen[path] then
                seen[path] = true
                local name = path:match("\\?([^\\]+)%.[tT][tT][fF]$") or path
                table.insert(list, { value = path, text = name })
            end
        end
    end
    if LSM and LSM.HashTable and LSM.HashTable.font then
        for name, path in pairs(LSM.HashTable.font) do
            local key = "LSM:" .. tostring(name)
            if not seen[key] then
                seen[key] = true
                table.insert(list, { value = key, text = "|cff88ff88" .. tostring(name) .. "|r (SharedMedia)" })
            end
        end
    end
    table.sort(list, function(a, b) return tostring(a.text) < tostring(b.text) end)
    if #list == 0 then
        list = {
            { value = "Fonts\\FRIZQT__.ttf", text = "FRIZQT" },
            { value = "Fonts\\ARKai_T.ttf",  text = "ARKai_T" },
            { value = "Fonts\\MORPHEUS.ttf", text = "MORPHEUS" },
        }
    end
    self.fontList = list
    return list
end

function ns:ResolveFont(value)
    if not value or value == "" then return GetDefaultFont() end
    if value:sub(1, 4) == "LSM:" and LSM then
        local path = SafeCall(LSM.Fetch, LSM, "font", value:sub(5))
        if path then return path end
    end
    return value
end

----------------------------------------------------------------------
-- 目标类型查询
----------------------------------------------------------------------
function ns:GetItemName(itemID)
    if not itemID then return nil end
    local name = SafeCall(function() return C_Item.GetItemInfo(itemID) end)
    if not name then name = SafeCall(function() return GetItemInfo(itemID) end) end
    return name
end

function ns:GetItemCount(itemID, includeBank)
    if not itemID then return 0 end
    local n = SafeCall(function() return C_Item.GetItemCount(itemID, includeBank, false, includeBank, includeBank) end)
    if n == nil then n = SafeCall(function() return GetItemCount(itemID, includeBank) end) end
    return tonumber(n) or 0
end

function ns:GetQuestTitle(questID)
    if not questID then return nil end
    local title = SafeCall(function() return C_QuestLog.GetTitleForQuestID(questID) end)
    if not title then title = SafeCall(function() return QuestUtils_GetQuestName(questID) end) end
    return title
end

function ns:IsQuestComplete(questID)
    if not questID then return false end
    local done = SafeCall(function() return C_QuestLog.IsQuestFlaggedCompleted(questID) end)
    if done == nil then done = SafeCall(function() return IsQuestFlaggedCompleted(questID) end) end
    return done and true or false
end

function ns:GetFactionData(factionID)
    if not factionID then return nil end
    return SafeCall(function() return C_Reputation.GetFactionDataByID(factionID) end)
end

function ns:GetStandingLabel(index)
    local v = _G["FACTION_STANDING_LABEL" .. tostring(index)]
    if v then return v end
    local fallback = { "仇恨", "敌对", "冷淡", "中立", "友善", "尊敬", "崇敬", "崇拜" }
    return fallback[index] or tostring(index)
end

function ns:GetCurrencyInfo(currencyID)
    if not currencyID then return nil end
    local info = SafeCall(function() return C_CurrencyInfo.GetCurrencyInfo(currencyID) end)
    if type(info) == "table" then return info end
    return nil
end

function ns:GetCurrencyList()
    local out = {}
    local size = SafeCall(function() return C_CurrencyInfo.GetCurrencyListSize() end) or 0
    for i = 1, size do
        local info = SafeCall(function() return C_CurrencyInfo.GetCurrencyListInfo(i) end)
        if type(info) == "table" and info.name and info.currencyID then
            table.insert(out, { value = info.currencyID, text = info.name })
        end
    end
    table.sort(out, function(a, b) return a.text < b.text end)
    return out
end

function ns:GetFactionList()
    local out = {}
    local n = SafeCall(GetNumFactions) or 0
    for i = 1, n do
        local data = SafeCall(function() return C_Reputation.GetFactionDataByIndex(i) end)
        if type(data) == "table" and data.name and data.factionID and data.isHeader ~= true then
            table.insert(out, { value = data.factionID, text = data.name })
        end
    end
    table.sort(out, function(a, b) return a.text < b.text end)
    return out
end

----------------------------------------------------------------------
-- 账号金币统计
----------------------------------------------------------------------
function ns:GetPlayerKey()
    local name = UnitName("player") or "?"
    local realm = GetRealmName() or ""
    return name .. "-" .. realm
end

-- 战团银行金币（铜）
local function FetchWarbandMoney()
    local v = SafeCall(function()
        if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType and Enum.BankType.Account then
            return C_Bank.FetchDepositedMoney(Enum.BankType.Account)
        end
    end)
    if type(v) == "number" then return v end

    local tabs = SafeCall(function()
        if C_Bank and C_Bank.FetchPurchasedBankTabData and Enum and Enum.BankType then
            return C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
        end
    end)
    if type(tabs) == "table" then
        local sum = 0
        for _, t in ipairs(tabs) do
            sum = sum + (tonumber(t.depositMoney) or 0)
        end
        return sum
    end
    return nil
end

function ns:RefreshWarbandMoney()
    local v = FetchWarbandMoney()
    if type(v) ~= "number" then return end
    -- 数据未加载时会返回 0，仅在值大于 0 或银行界面打开时采信
    if v > 0 or self.bankOpen then
        self.db.warband = self.db.warband or {}
        if self.db.warband.money ~= v then
            self.db.warband.money = v
            self.db.warband.time  = time()
            return true
        end
    end
    return false
end

function ns:UpdateCharacterSnapshot()
    local db = self.db
    db.characters = db.characters or {}
    local key = self:GetPlayerKey()
    local _, class = UnitClass("player")
    local money = tonumber(GetMoney()) or 0
    local old = db.characters[key]
    -- 登出瞬间 / 金币数据尚未加载时 GetMoney() 会返回 0，
    -- 不能用 0 覆盖已有的有效快照，否则这个角色的钱会从账号合计里消失。
    if money == 0 and old and (tonumber(old.money) or 0) > 0 then
        money = tonumber(old.money) or 0
    end
    db.characters[key] = {
        money = money,
        time  = time(),
        class = class or "",
        level = UnitLevel("player") or 0,
    }
    self.playerKey = key
end

-- 返回 total(铜), 明细列表, 战团银行(铜)
function ns:GetAccountGold()
    local db = self.db
    db.characters = db.characters or {}
    local key = self:GetPlayerKey()
    local current = tonumber(GetMoney()) or 0

    local list = {}
    local total = 0

    -- 当前角色：优先用实时值；若实时为 0 而 db 里还有快照（登出过程中 / 中断后刚开缓存），
    -- 就用快照兜底，避免在退出/换角色瞬间被误算成 0。
    local rec = db.characters[key]
    local useCurrent = current > 0 or not rec
    local shownMoney = useCurrent and current or (tonumber(rec.money) or 0)
    table.insert(list, {
        key = key,
        money = shownMoney,
        current = useCurrent,
        stale = not useCurrent,
        time = useCurrent and time() or (rec and rec.time) or 0,
        class = select(2, UnitClass("player")),
        level = UnitLevel("player"),
    })
    total = total + shownMoney

    -- 其它角色取快照
    for k, v in pairs(db.characters) do
        if k ~= key and type(v) == "table" then
            local m = tonumber(v.money) or 0
            total = total + m
            table.insert(list, { key = k, money = m, time = v.time or 0, class = v.class, level = v.level })
        end
    end
    table.sort(list, function(a, b)
        if a.current ~= b.current then return a.current end
        return (a.money or 0) > (b.money or 0)
    end)

    local warband = tonumber(db.warband and db.warband.money) or 0
    total = total + warband
    return total, list, warband
end

-- 调试：打印快照原表 + 当前 GetMoney + key，排查「登出后没记录」问题
function ns:DumpSnapshots()
    local db = self.db
    db.characters = db.characters or {}
    local key = self:GetPlayerKey()
    print("|cff00c0ffGoalTracker|r 当前 key: " .. tostring(key))
    print("|cff00c0ffGoalTracker|r 实时 GetMoney(): " .. tostring(GetMoney()))
    print("|cff00c0ffGoalTracker|r db.characters 快照 (" .. tostring(self:TallyKeys(db.characters)) .. " 条):")
    for k, v in pairs(db.characters) do
        local tag = (k == key) and "  <- 当前" or ""
        print(string.format("  %s%s  %s G  @ %s",
            tostring(k), tag,
            ns.FormatNumber((tonumber(v.money) or 0) / 10000),
            v.time and date("%Y-%m-%d %H:%M:%S", v.time) or "?"))
    end
end

function ns:TallyKeys(t)
    local n = 0; for _ in pairs(t) do n = n + 1 end; return n
end

function ns:PrintGoldBreakdown()
    local total, list, warband = self:GetAccountGold()
    print("|cff00c0ffGoalTracker|r " .. L["ACCOUNT_GOLD"] .. "：")
    for _, c in ipairs(list) do
        local g = (c.money or 0) / 10000
        local suffix = c.current and "" or L["GOLD_SNAPSHOT"]
        print(string.format("  |cffffffff%s|r  %s G%s", c.key, ns.FormatNumber(g), suffix))
    end
    print(string.format("  |cff00ff00%s|r  %s G", L["GOLD_WARBAND"], ns.FormatNumber(warband / 10000)))
    print(string.format("  |cffffd100%s|r  %s G", L["GOLD_TOTAL"], ns.FormatNumber(total / 10000)))
end

----------------------------------------------------------------------
-- 进度计算
----------------------------------------------------------------------
local function NewProgress()
    return {
        name = "", current = 0, goal = 0,
        curText = "0", goalText = "0", remainText = "0",
        pct = 0, pctText = "0%", completed = false, status = "",
    }
end

local function SetPct(p)
    if p.goal and p.goal > 0 then
        p.pct = Clamp(p.current / p.goal, 0, 1)
    else
        p.pct = p.completed and 1 or 0
    end
    p.pctText = string.format("%.2f%%", p.pct * 100)
    p.remainText = ns.FormatNumber(math.max((p.goal or 0) - (p.current or 0), 0))
    p.completed = ((p.goal and p.goal > 0 and p.current >= p.goal) == true)
    return p
end

function ns:ComputeProgress()
    local db = self.db
    local p = NewProgress()
    local t = db.goalType or "money"
    local label = db.label or ""

    if t == "money" then
        local copper
        if db.moneyScope == "character" then
            copper = tonumber(GetMoney()) or 0
        else
            copper = select(1, self:GetAccountGold()) or 0
        end
        p.current = copper / 10000
        p.goal    = tonumber(db.moneyGoal) or 0
        p.curText  = ns.FormatNumber(p.current)
        p.goalText = ns.FormatNumber(p.goal)
        p.name     = label ~= "" and label or L["MONEY_DEFAULT"]

    elseif t == "item" then
        local id = tonumber(db.itemID)
        p.current = self:GetItemCount(id, db.includeBank ~= false)
        p.goal    = tonumber(db.itemGoal) or 1
        p.curText  = ns.FormatNumber(p.current)
        p.goalText = ns.FormatNumber(p.goal)
        p.name = label ~= "" and label or (self:GetItemName(id) or L["ITEM_DEFAULT"])

    elseif t == "quest" then
        local qid = tonumber(db.questID)
        local done = self:IsQuestComplete(qid)
        local cur, req = (done and 1 or 0), 1
        if qid and SafeCall(function() return C_QuestLog.IsOnQuest(qid) end) then
            local objs = SafeCall(function() return C_QuestLog.GetQuestObjectives(qid) end)
            if type(objs) == "table" and #objs > 0 then
                cur, req = 0, 0
                for _, o in ipairs(objs) do
                    if o.numRequired and o.numRequired > 0 then
                        cur = cur + (o.numFulfilled or 0)
                        req = req + o.numRequired
                    end
                end
                if req == 0 then cur, req = (done and 1 or 0), 1 end
            end
        end
        if done then cur, req = 1, 1 end
        p.current, p.goal = cur, req
        p.curText, p.goalText = ns.FormatNumber(cur), ns.FormatNumber(req)
        p.status = done and L["STATUS_DONE"] or L["STATUS_NOTSTART"]
        p.name = label ~= "" and label or (self:GetQuestTitle(qid) or L["QUEST_DEFAULT"])

    elseif t == "reputation" then
        local data = self:GetFactionData(tonumber(db.factionID))
        local goalStanding = tonumber(db.factionGoal) or 8
        p.name = label ~= "" and label or (data and data.name or L["FACTION_UNKNOWN"])
        if data then
            local cur = data.currentStanding or 0
            local lo  = data.currentReactionThreshold or 0
            local hi  = data.nextReactionThreshold
            local reaction = data.reaction or 0
            if goalStanding <= reaction then
                p.current, p.goal = 1, 1
                p.curText, p.goalText = "1", "1"
                p.status = self:GetStandingLabel(reaction)
                p.completed = true
            else
                if hi and hi > lo then
                    p.current, p.goal = cur - lo, hi - lo
                else
                    p.current, p.goal = 0, 1
                end
                p.curText  = ns.FormatNumber(p.current)
                p.goalText = ns.FormatNumber(p.goal)
                p.status   = self:GetStandingLabel(reaction) .. " → " .. self:GetStandingLabel(goalStanding)
            end
        else
            p.current, p.goal = 0, 42000
            p.curText, p.goalText = "0", "42000"
        end

    elseif t == "currency" then
        local info = self:GetCurrencyInfo(tonumber(db.currencyID))
        p.name = label ~= "" and label or (info and info.name or L["CURRENCY_DEFAULT"])
        if info then
            p.current = tonumber(info.quantity) or 0
            p.goal = db.currencyUseMax and (tonumber(info.maxQuantity) or tonumber(db.currencyGoal) or 0)
                     or (tonumber(db.currencyGoal) or 0)
        else
            p.current = 0
            p.goal = tonumber(db.currencyGoal) or 0
        end
        p.curText, p.goalText = ns.FormatNumber(p.current), ns.FormatNumber(p.goal)

    else -- custom
        p.current = tonumber(db.customCurrent) or 0
        p.goal    = tonumber(db.customTarget) or 0
        p.curText, p.goalText = ns.FormatNumber(p.current), ns.FormatNumber(p.goal)
        p.name = label ~= "" and label or L["CUSTOM_DEFAULT"]
    end

    if t == "money" then
        p.remainText = ShortNum(math.max(p.goal - p.current, 0))
    end

    SetPct(p)
    if p.status == "" then
        p.status = p.completed and L["COMPLETED"] or L["STATUS_INPROG"]
    end
    return p
end

----------------------------------------------------------------------
-- 文本渲染
----------------------------------------------------------------------
function ns:FormatText(fmt, p)
    if not fmt or fmt == "" then fmt = DEFAULTS.textFormat end
    local map = {
        name   = p.name or "",
        cur    = p.curText or "",
        goal   = p.goalText or "",
        pct    = p.pctText or "",
        remain = p.remainText or "",
        status = p.status or "",
    }
    return fmt:gsub("{(%w+)}", function(k)
        if map[k] ~= nil then return tostring(map[k]) end
        return "{" .. k .. "}"
    end)
end

----------------------------------------------------------------------
-- 里程碑播报
----------------------------------------------------------------------
function ns:GetPraiseList()
    local custom = self.db.praiseList
    if custom and custom ~= "" then
        local list = {}
        for s in tostring(custom):gmatch("[^;；]+") do
            s = s:match("^%s*(.-)%s*$")
            if s ~= "" then table.insert(list, s) end
        end
        if #list > 0 then return list end
    end
    return ns.PRAISES or { L["COMPLETED"] }
end

function ns:RandomPraise()
    local list = self:GetPraiseList()
    if #list == 0 then return "" end
    if #list == 1 then return list[1] end
    local idx = math.random(1, #list)
    if self.db.lastPraise == list[idx] then
        idx = (idx % #list) + 1
    end
    self.db.lastPraise = list[idx]
    return list[idx]
end

----------------------------------------------------------------------
-- 大里程碑（10 / 25 / 33 / 50 / 75 / 90%）与惋惜提示
----------------------------------------------------------------------
local BIG_STEPS      = { 90, 75, 50, 33, 25, 10 }   -- 从高到低匹配
local BIG_REGRET_LV  = { 99, 50, 10, 1 }            -- 一次花掉持有金币的比例

local function Pick(list)
    if type(list) ~= "table" or #list == 0 then return nil end
    if #list == 1 then return list[1] end
    return list[math.random(1, #list)]
end

-- 本次是否跨过某个大里程碑（返回最高的那个）
local function BigStepCrossed(oldPct, newPct)
    for _, t in ipairs(BIG_STEPS) do
        if newPct >= t and oldPct < t then return t end
    end
    return nil
end

function ns:BigPraiseFor(threshold)
    local t = ns.BIG_PRAISES and ns.BIG_PRAISES[threshold]
    return Pick(t)
end

function ns:RandomRegret()
    return Pick(ns.REGRETS) or L["COMPLETED"]
end

-- pctHeld：本次花掉的钱占「花钱之前持有」的百分比
function ns:BigRegretFor(pctHeld)
    if type(pctHeld) ~= "number" or pctHeld <= 0 then return nil end
    for _, lv in ipairs(BIG_REGRET_LV) do
        if pctHeld + 0.0001 >= lv then
            local t = ns.BIG_REGRETS and ns.BIG_REGRETS[lv]
            local s = Pick(t)
            if s then return s, lv end
        end
    end
    return nil
end

function ns:CheckMilestone(p)
    local db = self.db
    if not p or not p.goal or p.goal <= 0 then return end

    local stepSize = tonumber(db.notifyStep) or 0.01
    if stepSize <= 0 then stepSize = 0.01 end

    local pct  = (p.pct or 0) * 100
    local step = math.floor(pct / stepSize + 0.000001)

    if db.lastStep == nil then
        db.lastStep     = step
        db.lastTotal    = p.current
        db.lastGainBase = p.current
        return
    end

    local prev = tonumber(db.lastTotal) or 0
    local cur  = p.current or 0

    ------------------------------------------------------------------
    -- 金额变少 = 花钱（不管有没有跨过里程碑档位都要检查，否则小额花费会被漏掉）
    ------------------------------------------------------------------
    if cur < prev then
        local spend   = prev - cur
        db.lastStep  = step
        db.lastTotal = cur

        if db.regretEnabled == false or spend <= 0 then return end

        local pctOfGoal = (spend / p.goal) * 100
        local pctHeld   = prev > 0 and (spend / prev) * 100 or 0

        local text, level = self:BigRegretFor(pctHeld)
        local isBig = (text ~= nil)
        if not text then
            -- 普通惋惜：达到「占目标」阈值，或一次花掉持有金币的 1% 以上
            local limit = tonumber(db.regretStep) or 0.01
            if limit <= 0 then limit = 0.01 end
            if pctOfGoal + 0.0001 < limit and pctHeld + 0.0001 < 1 then return end
            text = self:RandomRegret()
        end

        if ns.Display then
            ns.Display:Announce({
                kind   = "regret",
                big    = isBig and level or nil,
                praise = text,
                spend  = ns.FormatNumber(spend),
                remain = string.format("%.2f%%", math.max(100 - pct, 0)),
                pct    = string.format("%.2f%%", pct),
                cur    = p.curText,
                goal   = p.goalText,
                name   = p.name,
            })
        end
        return
    end

    ------------------------------------------------------------------
    -- 金额变多：只有跨过档位才播报
    ------------------------------------------------------------------
    if cur > prev then db.lastTotal = cur end     -- 随手更新基准，避免多笔收入后误判成巨额花费

    if step <= db.lastStep then return end

    local oldPct = (tonumber(db.lastStep) or 0) * stepSize
    if not db.notifyEnabled then
        db.lastStep     = step
        db.lastGainBase = cur
        return
    end

    local base = tonumber(db.lastGainBase)
    if base == nil then base = prev end
    local gain = cur - base
    if gain < 0 then gain = 0 end

    local big = (db.bigStepEnabled ~= false) and BigStepCrossed(oldPct, pct) or nil
    db.lastStep     = step
    db.lastGainBase = cur

    local remain = math.max(100 - pct, 0)
    if ns.Display then
        ns.Display:Announce({
            kind   = big and "big" or nil,
            praise = (big and self:BigPraiseFor(big)) or self:RandomPraise(),
            gain   = ns.FormatNumber(gain),
            remain = string.format("%.2f%%", remain),
            pct    = string.format("%.2f%%", pct),
            cur    = p.curText,
            goal   = p.goalText,
            name   = p.name,
        })
    end
end

----------------------------------------------------------------------
-- 直播输出：游戏内直播框（实时）+ 存档快照（供外部脚本导出成 txt）
----------------------------------------------------------------------
function ns:LiveText(p)
    local db = self.db
    local fmt = db.liveFormat
    if not fmt or fmt == "" then fmt = L["LIVE_DEFAULT_FORMAT"] end
    return ns:FormatText(fmt, p)
end

function ns:UpdateLive(p)
    local db = self.db
    if not db or not p then return end
    if not db.liveEnabled then
        if ns.Display then ns.Display:ShowLive(false) end
        return
    end

    local text = self:LiveText(p)

    if db.liveSaveEnabled ~= false then
        db.live = db.live or {}
        db.live.text   = text
        db.live.cur    = p.curText
        db.live.goal   = p.goalText
        db.live.pct    = p.pctText
        db.live.remain = p.remainText
        db.live.name   = p.name
        db.live.time   = time()
    end

    if ns.Display then
        ns.Display:ShowLive(db.liveFrameEnabled ~= false)
        if db.liveFrameEnabled ~= false then ns.Display:RenderLive(text) end
    end
end

----------------------------------------------------------------------
-- 更新调度
----------------------------------------------------------------------
local pending = false

local function DoUpdate()
    pending = false
    if not ns.db or not ns.Display then return end
    local p = ns:ComputeProgress()
    ns.Display:Render(p)
    ns:UpdateLive(p)
    ns:CheckMilestone(p)
end

function ns:Update(force)
    if pending and not force then return end
    pending = true
    C_Timer.After(0, DoUpdate)
end

----------------------------------------------------------------------
-- 事件
----------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventFrame:RegisterEvent("BANK_TABS_CHANGED")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("QUEST_ACCEPTED")
eventFrame:RegisterEvent("QUEST_REMOVED")
eventFrame:RegisterEvent("UPDATE_FACTION")
eventFrame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        GoalTrackerDB = GoalTrackerDB or {}
        ApplyDefaults(GoalTrackerDB, DEFAULTS)
        ns.db = GoalTrackerDB

        -- 旧版默认模板写的是 "{remain}%"，而 remain 本身已带 %，会显示成 99.99%%；这里修正一次
        if type(ns.db.notifyFormat) == "string" and ns.db.notifyFormat:find("{remain}%%") then
            ns.db.notifyFormat = ns.db.notifyFormat:gsub("{remain}%%", "{remain}")
        end

        ns:UpdateCharacterSnapshot()
        ns:RefreshWarbandMoney()

        if ns.Display then ns.Display:Init() end
        if ns.Options then ns.Options:Init() end
        ns:Update(true)

        -- 周期性刷新战团银行金币 + 角色快照（60 秒保险丝：
        -- 即使 12.0 把 PLAYER_LOGOUT 处理得不可靠，定时器也会兜底写入）
        local function tick()
            if not ns.db then return end
            ns:UpdateCharacterSnapshot()             -- 保险：定时强写一次快照
            if ns:RefreshWarbandMoney() then ns:Update() end
            C_Timer.After(60, tick)
        end
        C_Timer.After(60, tick)
        return
    end

    if not ns.db then return end

    if event == "PLAYER_LOGOUT" then
        -- 12.0 中 PLAYER_LOGOUT 的执行窗口被压缩、不可靠。
        -- 下面是 60 秒定时器 + BAG_UPDATE 在兜底，这里再写一次。
        ns:UpdateCharacterSnapshot()
        return
    end

    if event == "BANKFRAME_OPENED" then
        ns.bankOpen = true
        ns:RefreshWarbandMoney()
    elseif event == "BANKFRAME_CLOSED" then
        ns.bankOpen = false
    end

    -- 背包变化常常意味着金币变动（拾取/购买/卖物），
    -- 也补充触发一次快照，避免 PLAYER_MONEY 漏掉。
    if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        ns:UpdateCharacterSnapshot()
    end

    if event == "PLAYER_MONEY" or event == "PLAYER_ENTERING_WORLD" then
        ns:UpdateCharacterSnapshot()
    end

    ns:Update()
end)
