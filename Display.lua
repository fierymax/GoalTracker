--[[
    GoalTracker / 目标追踪
    Display.lua - 可拖动显示框体、外观渲染、里程碑播报
]]--

local ADDON_NAME, ns = ...
local L = ns.L

local Display = {}
ns.Display = Display

----------------------------------------------------------------------
-- 兼容层
-- 12.0 客户端对部分旧接口收紧（如 "HIGHEST" 层级已不再被接受），
-- 这里统一做保护：调用失败就降级，绝不让插件抛错中断。
----------------------------------------------------------------------
local function Safe(obj, method, ...)
    if not obj or not obj[method] then return false end
    return pcall(obj[method], obj, ...)
end

-- 同上，但返回创建出来的对象（失败返回 nil）
local function Try(obj, method, ...)
    if not obj or not obj[method] then return nil end
    local ok, ret = pcall(obj[method], obj, ...)
    if ok then return ret end
    return nil
end

-- 依次尝试层级名，返回第一个被客户端接受的
local function SetStrata(f, ...)
    for i = 1, select("#", ...) do
        local s = select(i, ...)
        if type(s) == "string" and Safe(f, "SetFrameStrata", s) then return s end
    end
    return nil
end

----------------------------------------------------------------------
-- 每日收入折线图
-- GameTooltip 只能加文字行，放不进真正的画布，所以这里做一个独立小框，
-- 用和提示框一样的底色/描边挂在提示框正下方，看起来就是提示框的一部分。
----------------------------------------------------------------------
local GRAPH_DAYS  = 10      -- 显示天数
local GRAPH_H     = 64      -- 图高
local GRAPH_PAD_L = 8
local GRAPH_PAD_R = 8
local GRAPH_PAD_B = 13      -- 底部留给日期
local GRAPH_PAD_T = 13      -- 顶部留给峰值
-- 线段用纹理旋转画；如果发现折线方向反了，把这里改成 -1 即可
local ROT_SIGN    = 1

function Display:EnsureGraph()
    if self.graph then return self.graph end

    local ok, g = pcall(CreateFrame, "Frame", "GoalTrackerGraphFrame", GameTooltip, "BackdropTemplate")
    if not ok or not g then
        g = CreateFrame("Frame", "GoalTrackerGraphFrame", GameTooltip)
    end
    self.graph = g
    g:SetHeight(GRAPH_H)
    Safe(g, "SetFrameStrata", "TOOLTIP")
    g:SetFrameLevel(250)
    Safe(g, "SetBackdrop", {
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    Safe(g, "SetBackdropColor", 0, 0, 0, 0.92)
    Safe(g, "SetBackdropBorderColor", 0.7, 0.7, 0.7, 0.7)
    g:Hide()

    local function Bar(layer, r, gg, b, a)
        local t = g:CreateTexture(nil, layer)
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        t:SetVertexColor(r, gg, b, a)
        return t
    end

    -- 网格：0 / 50% / 100% 三条
    g.grid = {}
    for i = 1, 3 do
        g.grid[i] = Bar("BORDER", 1, 1, 1, 0.09)
        g.grid[i]:SetHeight(1)
    end

    g.bars, g.lines, g.dots = {}, {}, {}
    for i = 1, GRAPH_DAYS do
        g.bars[i] = Bar("ARTWORK", 1, 0.76, 0.15, 0.22)          -- 面积柱
        local d = Bar("OVERLAY", 1, 0.85, 0.25, 1)               -- 数据点
        d:SetSize(5, 5)
        g.dots[i] = d
        if i < GRAPH_DAYS then
            g.lines[i] = Bar("ARTWORK", 1, 0.82, 0.2, 0.95)      -- 折线
        end
    end

    local function Label(justify)
        local fs = g:CreateFontString(nil, "OVERLAY")
        if fs.SetFontObject and GameTooltipTextSmall then
            fs:SetFontObject(GameTooltipTextSmall)
        end
        fs:SetJustifyH(justify)
        return fs
    end
    g.peakText  = Label("RIGHT")
    g.leftText  = Label("LEFT")
    g.rightText = Label("RIGHT")
    g.peakText:SetPoint("TOPRIGHT", g, "TOPRIGHT", -7, -4)
    g.leftText:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 7, 3)
    g.rightText:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", -7, 3)
    g.peakText:SetTextColor(1, 0.82, 0.2, 1)
    g.leftText:SetTextColor(0.7, 0.7, 0.7, 1)
    g.rightText:SetTextColor(0.7, 0.7, 0.7, 1)

    return g
end

function Display:DrawGraph()
    local g = self:EnsureGraph()
    local s = ns.GetDailyIncomeSummary and ns:GetDailyIncomeSummary(GRAPH_DAYS) or nil
    if not s or not s.series or #s.series == 0 then g:Hide(); return end

    local series = s.series
    local n = #series
    local maxV = s.peak or 0
    if maxV <= 0 then maxV = 1 end

    local plotH = GRAPH_H - GRAPH_PAD_B - GRAPH_PAD_T
    local plotW = (g:GetWidth() or 236) - GRAPH_PAD_L - GRAPH_PAD_R
    if plotW < 20 then plotW = 20 end
    local stepX = n > 1 and (plotW / (n - 1)) or 0

    local function PX(i) return GRAPH_PAD_L + (i - 1) * stepX end
    local function PY(v) return GRAPH_PAD_B + (v / maxV) * plotH end

    for i = 1, 3 do
        local t = g.grid[i]
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", GRAPH_PAD_L, GRAPH_PAD_B + plotH * (i - 1) / 2)
        t:SetWidth(plotW)
        t:Show()
    end

    for i = 1, GRAPH_DAYS do
        local d, bar, dot, line = series[i], g.bars[i], g.dots[i], g.lines[i]
        if d then
            local x, y = PX(i), PY(d.value)
            bar:ClearAllPoints()
            bar:SetPoint("BOTTOM", g, "BOTTOMLEFT", x, GRAPH_PAD_B)
            bar:SetWidth(math.max(stepX - 4, 3))
            bar:SetHeight(math.max(y - GRAPH_PAD_B, 1))
            bar:Show()
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", g, "BOTTOMLEFT", x, y)
            dot:Show()
        else
            bar:Hide(); dot:Hide()
        end
        if line then
            local a, b = series[i], series[i + 1]
            if a and b then
                local x1, y1 = PX(i), PY(a.value)
                local x2, y2 = PX(i + 1), PY(b.value)
                local dx, dy = x2 - x1, y2 - y1
                local len = math.sqrt(dx * dx + dy * dy)
                line:ClearAllPoints()
                line:SetSize(math.max(len, 0.01), 2)
                line:SetPoint("CENTER", g, "BOTTOMLEFT", (x1 + x2) / 2, (y1 + y2) / 2)
                if line.SetRotation then
                    line:SetRotation(ROT_SIGN * math.atan2(dy, dx))
                end
                line:Show()
            else
                line:Hide()
            end
        end
    end

    g.peakText:SetText(string.format("%s %s G", L["INCOME_PEAK"], ns.ShortNum(maxV)))
    g.leftText:SetText(series[1].label)
    g.rightText:SetText(series[n].label)

    g:ClearAllPoints()
    g:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 8, 3)
    g:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -8, 3)
    g:Show()
end

function Display:HideGraph()
    if self.graph then self.graph:Hide() end
end

----------------------------------------------------------------------
-- 主显示框体
----------------------------------------------------------------------
function Display:Init()
    if self.frame then
        self:ApplySettings()
        return
    end

    -- 部分新版客户端可能不再提供 BackdropTemplate，创建失败就退回无模板
    local ok, f = pcall(CreateFrame, "Frame", "GoalTrackerFrame", UIParent, "BackdropTemplate")
    if not ok or not f then
        f = CreateFrame("Frame", "GoalTrackerFrame", UIParent)
    end
    self.frame = f
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetSize(300, 40)
    Safe(f, "SetBackdrop", {
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    Safe(f, "SetBackdropColor", 0, 0, 0, 0.35)
    Safe(f, "SetBackdropBorderColor", 0.7, 0.7, 0.7, 0.7)

    local text = f:CreateFontString(nil, "OVERLAY")
    self.text = text
    text:SetPoint("CENTER", f, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetWordWrap(false)

    ------------------------------------------------------------------
    -- 拖动
    ------------------------------------------------------------------
    f:SetScript("OnDragStart", function(self)
        if ns.db.clickThrough then return end
        if ns.db.locked and not IsAltKeyDown() then return end
        self:StartMoving()
        self.isMoving = true
    end)

    f:SetScript("OnDragStop", function(self)
        if not self.isMoving then return end
        self:StopMovingOrSizing()
        self.isMoving = nil
        local point, _, relPoint, x, y = self:GetPoint(1)
        if point then
            ns.db.point    = point
            ns.db.relPoint = relPoint or point
            ns.db.x = x
            ns.db.y = y
        end
        Safe(self, "SetBackdropBorderColor", 0.7, 0.7, 0.7, 0.7)
    end)

    f:SetScript("OnMouseUp", function(_, button)
        if button ~= "RightButton" then return end
        -- 只有显式开启才弹设置；老存档里这个字段是 nil，也不会弹
        if ns.db.rightClickOptions ~= true then return end
        if ns.Options then ns.Options:Open() end
    end)

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        if not IsControlKeyDown() then return end
        ns.db.scale = ns.Clamp((ns.db.scale or 1) + delta * 0.05, 0.5, 3)
        Display:ApplySettings()
        ns:Update(true)
    end)

    -- 鼠标提示：账号金币明细 + 每日收入折线图
    f:SetScript("OnEnter", function(self)
        if ns.db.clickThrough then return end
        if ns.db.goalType ~= "money" or ns.db.moneyScope ~= "account" then
            Display:HideGraph()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cff00c0ff" .. L["ADDON_TITLE"] .. "|r")
            GameTooltip:AddLine(L["ACCOUNT_TIP"], 1, 1, 1, true)
            GameTooltip:Show()
            return
        end
        local total, list, warband = ns:GetAccountGold()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        -- 图挂在提示框下方，宽度要和图一致，否则会一宽一窄很难看
        Safe(GameTooltip, "SetMinimumWidth", 252)
        GameTooltip:AddLine("|cff00c0ff" .. L["ACCOUNT_GOLD"] .. "|r")
        GameTooltip:AddLine(" ")
        for _, c in ipairs(list) do
            local g = (c.money or 0) / 10000
            local suffix = c.current and "|cff88ff88" .. L["GOLD_CURRENT"] .. "|r" or L["GOLD_SNAPSHOT"]
            GameTooltip:AddDoubleLine(string.format("|cffffffff%s|r", c.key),
                string.format("|cffffd100%s|r G  %s", ns.FormatNumber(g), suffix))
        end
        GameTooltip:AddDoubleLine(L["GOLD_WARBAND"], string.format("|cffffd100%s|r G", ns.FormatNumber(warband / 10000)))
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L["GOLD_TOTAL"], string.format("|cff00ff00%s|r G", ns.FormatNumber(total / 10000)))
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["GOLD_HINT"], 0.7, 0.7, 0.7, true)

        -- 每日收入
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00c0ff" .. string.format(L["INCOME_TITLE"], GRAPH_DAYS) .. "|r")
        if ns.GetDailyIncomeSummary then
            local s = ns:GetDailyIncomeSummary(GRAPH_DAYS)
            if s.total <= 0 then
                GameTooltip:AddLine(L["INCOME_EMPTY"], 0.7, 0.7, 0.7, true)
            else
                GameTooltip:AddDoubleLine(L["INCOME_TODAY"],
                    string.format("|cffffd100%s|r G", ns.FormatNumber(s.today)))
                GameTooltip:AddDoubleLine(L["INCOME_AVG"],
                    string.format("|cffffd100%s|r G", ns.FormatNumber(s.avg)))
                GameTooltip:AddDoubleLine(L["INCOME_TOTAL"],
                    string.format("|cff00ff00%s|r G", ns.FormatNumber(s.total)))
            end
        end
        GameTooltip:Show()
        Display:DrawGraph()
    end)
    f:SetScript("OnLeave", function()
        GameTooltip:Hide()
        Display:HideGraph()
    end)

    self:ApplySettings()
    self:EnsureAnnounce()
end

----------------------------------------------------------------------
-- 应用设置
----------------------------------------------------------------------
function Display:ApplySettings()
    local db = ns.db
    local f = self.frame
    if not db or not f then return end

    f:SetScale(db.scale or 1)
    SetStrata(f, db.strata, "MEDIUM", "HIGH")   -- 存档里的旧层级若不被支持会自动降级
    f:SetFrameLevel(20)

    f:ClearAllPoints()
    f:SetPoint(db.point or "CENTER", UIParent, db.relPoint or "CENTER", db.x or 0, db.y or 150)

    self.text:SetFont(ns:ResolveFont(db.font), db.fontSize or 20, db.fontOutline or "OUTLINE")
    if db.useShadow then
        local sc = db.shadowColor or { 0, 0, 0, 1 }
        self.text:SetShadowColor(sc[1] or 0, sc[2] or 0, sc[3] or 0, sc[4] or 1)
        self.text:SetShadowOffset(1, -1)
    else
        self.text:SetShadowColor(0, 0, 0, 0)
        self.text:SetShadowOffset(0, 0)
    end

    if db.clickThrough then
        f:EnableMouse(false)
        Safe(f, "SetBackdropColor", 0, 0, 0, 0)
        Safe(f, "SetBackdropBorderColor", 1, 1, 1, 0)
    else
        f:EnableMouse(true)
        if db.locked then
            Safe(f, "SetBackdropColor", 0, 0, 0, 0)
            Safe(f, "SetBackdropBorderColor", 1, 1, 1, 0)
        else
            Safe(f, "SetBackdropColor", 0, 0, 0, 0.35)
            Safe(f, "SetBackdropBorderColor", 0.7, 0.7, 0.7, 0.7)
        end
    end

    self:ApplyAnnounceSettings()
    self:Layout()
    ns:Update(true)
end

----------------------------------------------------------------------
-- 布局
----------------------------------------------------------------------
function Display:Layout()
    if not self.frame or not ns.db then return end
    local w = (self.text:GetStringWidth() or 0) + 24
    local h = (ns.db.fontSize or 20) + 14
    self.frame:SetWidth(math.max(w, 40))
    self.frame:SetHeight(math.max(h, 24))
end

----------------------------------------------------------------------
-- 渲染
----------------------------------------------------------------------
function Display:Render(p)
    if not self.frame or not p then return end
    local db = ns.db

    self.text:SetText(ns:FormatText(db.textFormat, p))

    local c = (p.completed and db.useCompleteColor) and (db.completeColor or db.color) or (db.color or { 1, 0.82, 0, 1 })
    self.text:SetTextColor(c[1], c[2], c[3], c[4] or 1)

    self:Layout()
end

----------------------------------------------------------------------
-- 里程碑播报
----------------------------------------------------------------------
function Display:EnsureAnnounce()
    if self.announce then return end

    local f = CreateFrame("Frame", "GoalTrackerAnnounceFrame", UIParent)
    self.announce = f
    -- "HIGHEST" 在部分客户端已被移除，逐个尝试直到成功
    SetStrata(f, "HIGHEST", "FULLSCREEN_DIALOG", "DIALOG", "HIGH", "MEDIUM")
    f:SetFrameLevel(200)
    f:SetSize(1000, 80)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    f:SetAlpha(0)
    f:Hide()

    local text = f:CreateFontString(nil, "OVERLAY")
    self.announceText = text
    text:SetPoint("CENTER", f, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetWordWrap(false)

    -- 动画：任何一步不被客户端支持就跳过，不至于让播报功能整体失效
    local ag = Try(f, "CreateAnimationGroup")
    self.announceAnim = ag

    if ag then
        local fadeIn = Try(ag, "CreateAnimation", "Alpha")
        Safe(fadeIn, "SetFromAlpha", 0)
        Safe(fadeIn, "SetToAlpha", 1)
        Safe(fadeIn, "SetDuration", 0.3)
        Safe(fadeIn, "SetOrder", 1)

        local move = Try(ag, "CreateAnimation", "Translation")
        Safe(move, "SetOffset", 0, 60)
        Safe(move, "SetDuration", 3)
        Safe(move, "SetOrder", 1)
        Safe(move, "SetSmoothing", "OUT")
        self.announceMove = move

        local fadeOut = Try(ag, "CreateAnimation", "Alpha")
        Safe(fadeOut, "SetFromAlpha", 1)
        Safe(fadeOut, "SetToAlpha", 0)
        Safe(fadeOut, "SetDuration", 0.7)
        Safe(fadeOut, "SetOrder", 2)
        self.announceFadeOut = fadeOut

        Safe(ag, "SetScript", "OnFinished", function() f:Hide() end)
    end
end

-- 尺寸 / 颜色可覆盖（大里程碑、惋惜提示用不同样式）
function Display:ApplyAnnounceSettings(sizeOverride, colorOverride)
    self:EnsureAnnounce()
    local db = ns.db
    local f = self.announce
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, db.notifyOffsetY or 120)
    self.announceText:SetFont(ns:ResolveFont(db.font),
        sizeOverride or db.notifySize or 36, "THICKOUTLINE")
    local c = colorOverride or db.notifyColor or { 1, 0.85, 0.2, 1 }
    self.announceText:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    self.announceText:SetShadowColor(0, 0, 0, 1)
    self.announceText:SetShadowOffset(2, -2)
end

-- ctx: { kind, praise, gain, spend, remain, pct, cur, goal, name }
-- kind = nil/普通鼓励 | "big" 大里程碑 | "regret" 花钱惋惜
function Display:Announce(ctx)
    self:EnsureAnnounce()
    local db = ns.db
    local f = self.announce
    local kind = ctx.kind or "praise"

    local fmt, color, size
    if kind == "regret" then
        fmt   = db.regretFormat
        if not fmt or fmt == "" then fmt = L["REGRET_DEFAULT_FORMAT"] end
        color = db.regretColor or { 1, 0.55, 0.55, 1 }
        size  = db.notifySize or 36
    elseif kind == "big" then
        fmt   = db.notifyFormat
        if not fmt or fmt == "" then fmt = L["NOTIFY_DEFAULT_FORMAT"] end
        color = db.bigColor or { 1, 0.92, 0.35, 1 }
        size  = (db.notifySize or 36) * 1.25
    else
        fmt   = db.notifyFormat
        if not fmt or fmt == "" then fmt = L["NOTIFY_DEFAULT_FORMAT"] end
        color = db.notifyColor or { 1, 0.85, 0.2, 1 }
        size  = db.notifySize or 36
    end

    local map = {
        praise = ctx.praise or "",
        gain   = ctx.gain or "0",
        spend  = ctx.spend or "0",
        remain = ctx.remain or "0%",
        pct    = ctx.pct or "0%",
        cur    = ctx.cur or "",
        goal   = ctx.goal or "",
        name   = ctx.name or "",
    }
    local text = fmt:gsub("{(%w+)}", function(k)
        if map[k] ~= nil then return tostring(map[k]) end
        return "{" .. k .. "}"
    end)

    self:ApplyAnnounceSettings(size, color)
    self.announceText:SetText(text)

    local dur = tonumber(db.notifyDuration) or 3
    Safe(self.announceMove, "SetDuration", dur + 0.7)
    Safe(self.announceFadeOut, "SetStartDelay", dur)

    -- 惋惜提示默认不出声（避免花钱还响起金币声，太扎心）
    if kind ~= "regret" then
        if db.notifySound then ns:PlayCoinSound() end
    elseif db.regretSound then
        ns:PlayCoinSound()
    end

    f:StopAnimating()
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, db.notifyOffsetY or 120)
    f:SetAlpha(0)
    f:Show()
    if self.announceAnim then
        self.announceAnim:Stop()
        self.announceAnim:Play()
    else
        -- 动画不可用时至少把文字显示出来
        f:SetAlpha(1)
        if C_Timer and C_Timer.After then
            C_Timer.After(dur + 0.7, function() f:Hide() end)
        end
    end
end

----------------------------------------------------------------------
-- 直播框：独立小框体，给 OBS「游戏捕获 + 裁剪」用，零延迟
----------------------------------------------------------------------
function Display:EnsureLiveFrame()
    if self.liveFrame then return self.liveFrame end

    local ok, f = pcall(CreateFrame, "Frame", "GoalTrackerLiveFrame", UIParent, "BackdropTemplate")
    if not ok or not f then
        f = CreateFrame("Frame", "GoalTrackerLiveFrame", UIParent)
    end
    self.liveFrame = f
    SetStrata(f, "MEDIUM", "HIGH")
    f:SetFrameLevel(10)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    Safe(f, "SetBackdrop", {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = nil, tile = true, tileSize = 8,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    local text = f:CreateFontString(nil, "OVERLAY")
    self.liveText = text
    text:SetPoint("CENTER", f, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetWordWrap(false)

    f:SetScript("OnDragStart", function(s) s:StartMoving() end)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local point, _, relPoint, x, y = s:GetPoint(1)
        if point and ns.db then
            ns.db.livePoint, ns.db.liveRelPoint = point, relPoint or point
            ns.db.liveX, ns.db.liveY = x, y
        end
    end)

    return f
end

function Display:ApplyLiveSettings()
    if not self.liveFrame then return end
    local db = ns.db
    local f = self.liveFrame
    local text = self.liveText

    f:SetWidth(math.max(db.liveWidth or 280, 60))
    f:SetHeight(math.max((db.liveSize or 28) + 16, 24))
    f:ClearAllPoints()
    f:SetPoint(db.livePoint or "BOTTOM", UIParent, db.liveRelPoint or "BOTTOM",
               db.liveX or 0, db.liveY or 120)

    text:SetFont(ns:ResolveFont(db.font), db.liveSize or 28, db.fontOutline or "OUTLINE")
    local c = db.liveColor or { 1, 0.82, 0, 1 }
    text:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    if db.useShadow then
        local sc = db.shadowColor or { 0, 0, 0, 1 }
        text:SetShadowColor(sc[1] or 0, sc[2] or 0, sc[3] or 0, sc[4] or 1)
        text:SetShadowOffset(1, -1)
    end
    Safe(f, "SetBackdropColor", 0, 0, 0, tonumber(db.liveBg) or 0)
end

function Display:ShowLive(show)
    if show then
        self:EnsureLiveFrame()
        self:ApplyLiveSettings()
        self.liveFrame:Show()
    elseif self.liveFrame then
        self.liveFrame:Hide()
    end
end

function Display:RenderLive(text)
    self:EnsureLiveFrame()
    self:ApplyLiveSettings()
    if self.liveText and text then self.liveText:SetText(text) end
end

function Display:ResetLivePosition()
    local db = ns.db
    db.livePoint, db.liveRelPoint, db.liveX, db.liveY = "BOTTOM", "BOTTOM", 0, 120
    if self.liveFrame then
        self.liveFrame:ClearAllPoints()
        self.liveFrame:SetPoint(db.livePoint, UIParent, db.liveRelPoint, db.liveX, db.liveY)
    end
end

----------------------------------------------------------------------
-- 位置
----------------------------------------------------------------------
function Display:ResetPosition()
    local db = ns.db
    db.point, db.relPoint, db.x, db.y = "CENTER", "CENTER", 0, 150
    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    end
end

function Display:SetLocked(locked)
    ns.db.locked = locked and true or false
    self:ApplySettings()
end
