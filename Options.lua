--[[
    GoalTracker / 目标追踪
    Options.lua - 原生设置面板（无依赖）
]]--

local ADDON_NAME, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

-- 命令状态：必须在文件顶部声明，否则 BuildContent 等前方函数里的引用
-- 会落到全局变量（nil）上。详见文件末尾的「聊天命令」小节。
local activeCmds = {}     -- 已生效（带斜杠）
local takenCmds  = {}     -- 因冲突放弃（带斜杠）
local warned     = false  -- 本次登录是否已提示过（不写进存档，每次登录提示一次）

----------------------------------------------------------------------
-- 设置快照（保存 / 关闭 用）
-- 修改是即时生效的（方便预览），点「关闭」或按 ESC 时回滚到打开时的状态。
-- 回滚采用「就地覆盖」，表引用不变，ns.db / self.db 都不需要重新指向。
----------------------------------------------------------------------
local function DeepCopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, val in pairs(v) do out[k] = DeepCopy(val) end
    return out
end

local function RestoreInto(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then return end
    for k in pairs(dst) do dst[k] = nil end
    for k, v in pairs(src) do dst[k] = DeepCopy(v) end
end

----------------------------------------------------------------------
-- 通用控件工具
----------------------------------------------------------------------
local function SafeCall(obj, method, ...)
    if not obj or not obj[method] then return false end
    return pcall(obj[method], obj, ...)
end

local function SafeCreate(kind, name, parent, template)
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and f then return f end
    return CreateFrame(kind, name, parent)
end

local function AddLabel(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetText(text)
    return label
end

local function CreateEditBox(parent, labelText, width, getValue, setValue, numeric, tip)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 200, 44)

    local label = AddLabel(f, labelText)
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    local box = SafeCreate("EditBox", nil, f, "InputBoxTemplate")
    box:SetSize((width or 200) - 6, 22)
    box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 4, -2)
    box:SetAutoFocus(false)
    box:SetTextInsets(4, 4, 0, 0)
    box:SetFontObject(ChatFontNormal)
    box:SetText(tostring(getValue() or ""))

    if tip then
        box:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local function Commit()
        local raw = box:GetText() or ""
        if numeric then
            local v = tonumber(raw)
            if v ~= nil then setValue(v) end
        else
            setValue(raw)
        end
        ns:Update(true)
    end

    box:SetScript("OnEnterPressed", function(self) Commit(); self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function() Commit() end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(getValue() or ""))
        self:ClearFocus()
    end)

    f.box = box
    return f
end

local function CreateSlider(parent, labelText, minV, maxV, step, getValue, setValue, decimals)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(220, 46)

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    local slider = SafeCreate("Slider", nil, f, "BackdropTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(200, 16)
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    pcall(function() slider:SetObeyStepOnDrag(true) end)

    SafeCall(slider, "SetBackdrop", {
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(22, 22)
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetThumbTexture(thumb)

    local function Format(v)
        if decimals and decimals > 0 then
            return string.format("%." .. decimals .. "f", v)
        end
        return tostring(math.floor(v + 0.5))
    end

    local function Refresh()
        local v = getValue() or minV
        slider:SetValue(v)
        label:SetText(labelText .. "：|cffffffff" .. Format(v) .. "|r")
    end

    slider:SetScript("OnValueChanged", function(_, value)
        label:SetText(labelText .. "：|cffffffff" .. Format(value) .. "|r")
        setValue(value)
        ns:Update(true)
    end)

    Refresh()
    f.Refresh = Refresh
    return f
end

local function CreateCheck(parent, labelText, getValue, setValue, tip)
    local b = SafeCreate("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetSize(24, 24)

    local text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", b, "RIGHT", 2, 0)
    text:SetText(labelText)

    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    function b:Refresh() self:SetChecked(getValue() and true or false) end
    b:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
        ns:Update(true)
        if ns.Display and ns.Display.frame then ns.Display:ApplySettings() end
    end)
    b:Refresh()
    return b
end

local function CreateButton(parent, text, width, onClick)
    local b = SafeCreate("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 120, 24)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local HAS_DROPDOWN = (UIDropDownMenu_Initialize ~= nil and UIDropDownMenu_SetWidth ~= nil)

local function CreateDropdown(parent, labelText, items, getValue, setValue, width, onSelect)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 220, 48)

    local label = AddLabel(f, labelText)
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    local function TextOf(v)
        for _, it in ipairs(items) do
            if it.value == v then return it.text end
        end
        return tostring(v or "")
    end

    if HAS_DROPDOWN then
        local dd = SafeCreate("Frame", nil, f, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -16, -2)
        UIDropDownMenu_SetWidth(dd, (width or 220) - 36)
        UIDropDownMenu_SetText(dd, TextOf(getValue()))
        UIDropDownMenu_Initialize(dd, function(_, level)
            for _, it in ipairs(items) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = it.text
                info.value = it.value
                info.checked = (it.value == getValue())
                info.func = function(self)
                    setValue(self.value)
                    UIDropDownMenu_SetText(dd, self:GetText())
                    if onSelect then onSelect(self.value) end
                    ns:Update(true)
                    if ns.Display then ns.Display:ApplySettings() end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        f.Refresh = function() UIDropDownMenu_SetText(dd, TextOf(getValue())) end
    else
        local b = CreateButton(f, TextOf(getValue()), (width or 220) - 30, function(self)
            local cur = getValue()
            local idx = 1
            for i, it in ipairs(items) do
                if it.value == cur then idx = i end
            end
            local nxt = items[(idx % #items) + 1]
            setValue(nxt.value)
            self:SetText(nxt.text)
            if onSelect then onSelect(nxt.value) end
            ns:Update(true)
            if ns.Display then ns.Display:ApplySettings() end
        end)
        b:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
        f.Refresh = function() b:SetText(TextOf(getValue())) end
    end
    return f
end

----------------------------------------------------------------------
-- 颜色选择
----------------------------------------------------------------------
local function OpenColorPicker(r, g, b, callback)
    if not ColorPickerFrame then return end
    ColorPickerFrame:Hide()
    if ColorPickerFrame.SetupColorPickerAndShow then
        local info = {
            r = r, g = g, b = b,
            hasOpacity = false,
            swatchFunc = function()
                local rr, gg, bb = ColorPickerFrame:GetColorRGB()
                callback(rr, gg, bb)
            end,
            cancelFunc = function() callback(r, g, b) end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    else
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame.func = function()
            local rr, gg, bb = ColorPickerFrame:GetColorRGB()
            callback(rr, gg, bb)
        end
        ColorPickerFrame.cancelFunc = function() callback(r, g, b) end
        ColorPickerFrame:Show()
    end
end

local PRESET_COLORS = {
    { 1, 0.82, 0 }, { 1, 1, 1 }, { 1, 0.2, 0.2 }, { 1, 0.5, 0.1 },
    { 1, 1, 0.3 },  { 0.3, 1, 0.3 }, { 0.2, 0.9, 1 }, { 0.4, 0.6, 1 },
    { 0.8, 0.4, 1 }, { 1, 0.4, 0.8 }, { 0.6, 0.6, 0.6 }, { 0, 0, 0 },
}

local function CreateColorRow(parent, labelText, getColor, setColor, withPresets)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(260, withPresets and 62 or 40)

    local label = AddLabel(f, labelText)
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    local swatch = CreateFrame("Button", nil, f, "BackdropTemplate")
    swatch:SetSize(34, 20)
    swatch:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    SafeCall(swatch, "SetBackdrop", {
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    function f:Refresh()
        local c = getColor()
        SafeCall(swatch, "SetBackdropColor", c[1], c[2], c[3], 1)
    end

    local function Open()
        local c = getColor()
        OpenColorPicker(c[1], c[2], c[3], function(r, g, b)
            local cc = getColor()
            cc[1], cc[2], cc[3] = r, g, b
            setColor(cc)
            f:Refresh()
            ns:Update(true)
        end)
    end

    swatch:SetScript("OnClick", Open)

    local pick = CreateButton(f, L["PICK_COLOR"], 76, Open)
    pick:SetPoint("LEFT", swatch, "RIGHT", 6, 0)

    if withPresets then
        for i, c in ipairs(PRESET_COLORS) do
            local b = CreateFrame("Button", nil, f, "BackdropTemplate")
            b:SetSize(15, 15)
            b:SetPoint("TOPLEFT", swatch, "BOTTOMLEFT", (i - 1) * 18, -6)
            SafeCall(b, "SetBackdrop", {
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 4, edgeSize = 6,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            SafeCall(b, "SetBackdropColor", c[1], c[2], c[3], 1)
            b:SetScript("OnClick", function()
                local cc = getColor()
                cc[1], cc[2], cc[3] = c[1], c[2], c[3]
                setColor(cc)
                f:Refresh()
                ns:Update(true)
            end)
        end
    end

    f:Refresh()
    return f
end

----------------------------------------------------------------------
-- 面板构建
----------------------------------------------------------------------
local COL_W = 300

local function NewSection(parent, title)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(620, 26)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("LEFT", f, "LEFT", 0, 0)
    t:SetText("|cff00c0ff" .. title .. "|r")
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", t, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    line:SetColorTexture(0.3, 0.5, 0.7, 0.6)
    return f
end

local function ParseItemID(s)
    if not s then return nil end
    local fromLink = tostring(s):match("|Hitem:(%d+)")
    if fromLink then return tonumber(fromLink) end
    local n = tostring(s):match("(%d+)")
    return n and tonumber(n) or nil
end

function Options:BuildContent(container)
    local y = { left = -10, right = -10 }

    local function Place(frame, column, height)
        local col = column or "left"
        local x = (col == "right") and (COL_W + 30) or 10
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", x, y[col])
        y[col] = y[col] - (height or frame:GetHeight() or 40) - 6
        return frame
    end

    local function Both(frame, height)
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", 10, math.min(y.left, y.right))
        frame:SetPoint("RIGHT", container, "RIGHT", -10, 0)
        y.left = math.min(y.left, y.right) - (height or 40) - 6
        y.right = y.left
        return frame
    end

    ------------------------------------------------------------------
    -- 目标
    ------------------------------------------------------------------
    Both(NewSection(container, L["GOAL_TYPE"]))

    local types = {
        { value = "money",      text = L["TYPE_MONEY"] },
        { value = "item",       text = L["TYPE_ITEM"] },
        { value = "quest",      text = L["TYPE_QUEST"] },
        { value = "reputation", text = L["TYPE_REPUTATION"] },
        { value = "currency",   text = L["TYPE_CURRENCY"] },
        { value = "custom",     text = L["TYPE_CUSTOM"] },
    }
    Place(CreateDropdown(container, L["GOAL_TYPE"], types,
        function() return ns.db.goalType end,
        function(v) ns.db.goalType = v end,
        240, function() Options:RebuildDynamic() end), "left", 48)

    Place(CreateEditBox(container, L["GOAL_NAME"], 240,
        function() return ns.db.label end,
        function(v) ns.db.label = v end, false, L["GOAL_NAME_TIP"]), "right", 44)

    Place(CreateEditBox(container, L["TEXT_FORMAT"], 280,
        function() return ns.db.textFormat end,
        function(v) ns.db.textFormat = v end, false, L["TEXT_FORMAT_TIP"]), "left", 44)

    -- 动态区域
    local dyn = CreateFrame("Frame", nil, container)
    dyn:SetSize(620, 200)
    Both(dyn, 200)
    self.dynamic = dyn

    ------------------------------------------------------------------
    -- 账号金币明细
    ------------------------------------------------------------------
    local gold = CreateFrame("Frame", nil, container)
    gold:SetSize(620, 230)
    Both(gold, 230)
    self.goldSection = gold

    local goldTitle = gold:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    goldTitle:SetPoint("TOPLEFT", gold, "TOPLEFT", 12, 0)
    goldTitle:SetText("|cff00c0ff" .. L["ACCOUNT_GOLD"] .. "|r")

    local goldText = gold:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    goldText:SetPoint("TOPLEFT", goldTitle, "BOTTOMLEFT", 0, -6)
    goldText:SetJustifyH("LEFT")
    goldText:SetJustifyV("TOP")
    goldText:SetWordWrap(true)
    goldText:SetWidth(590)
    self.goldText = goldText

    local hintText = gold:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hintText:SetPoint("TOPLEFT", goldText, "BOTTOMLEFT", 0, -8)
    hintText:SetJustifyH("LEFT")
    hintText:SetWordWrap(true)
    hintText:SetWidth(590)
    hintText:SetText(L["GOLD_HINT"])
    self.goldHint = hintText

    local refreshBtn = CreateButton(gold, L["GOLD_REFRESH"], 90, function()
        ns:UpdateCharacterSnapshot()
        ns:RefreshWarbandMoney()
        Options:UpdateGoldInfo()
        ns:Update(true)
    end)
    refreshBtn:SetPoint("BOTTOMLEFT", gold, "BOTTOMLEFT", 12, 0)

    local clearBtn = CreateButton(gold, L["GOLD_CLEAR"], 120, function()
        ns.db.characters = {}
        ns:UpdateCharacterSnapshot()
        Options:UpdateGoldInfo()
        ns:Update(true)
    end)
    clearBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 8, 0)

    ------------------------------------------------------------------
    -- 外观
    ------------------------------------------------------------------
    Both(NewSection(container, L["LOOK"]))

    Place(CreateDropdown(container, L["FONT"], ns:GetFontList(),
        function() return ns.db.font end,
        function(v) ns.db.font = v end, 240), "left", 48)

    Place(CreateSlider(container, L["FONT_SIZE"], 8, 64, 1,
        function() return ns.db.fontSize end,
        function(v) ns.db.fontSize = v; if ns.Display then ns.Display:ApplySettings() end end), "right", 46)

    local outlines = {
        { value = "",             text = L["OUTLINE_NONE"] },
        { value = "OUTLINE",      text = L["OUTLINE_THIN"] },
        { value = "THICKOUTLINE", text = L["OUTLINE_THICK"] },
    }
    Place(CreateDropdown(container, L["FONT_OUTLINE"], outlines,
        function() return ns.db.fontOutline end,
        function(v) ns.db.fontOutline = v end, 200), "left", 48)

    Place(CreateColorRow(container, L["TEXT_COLOR"],
        function() return ns.db.color end,
        function(c) ns.db.color = c end, true), "right", 62)

    Place(CreateColorRow(container, L["PICK_COMPLETE"],
        function() return ns.db.completeColor end,
        function(c) ns.db.completeColor = c end, true), "left", 62)

    Place(CreateCheck(container, L["COMPLETE_COLOR"],
        function() return ns.db.useCompleteColor end,
        function(v) ns.db.useCompleteColor = v end), "right", 26)

    Place(CreateCheck(container, L["SHADOW"],
        function() return ns.db.useShadow end,
        function(v) ns.db.useShadow = v end), "left", 26)

    ------------------------------------------------------------------
    -- 里程碑播报
    ------------------------------------------------------------------
    Both(NewSection(container, L["NOTIFY"]))

    Place(CreateCheck(container, L["NOTIFY_ENABLE"],
        function() return ns.db.notifyEnabled end,
        function(v) ns.db.notifyEnabled = v end), "left", 26)

    Place(CreateCheck(container, L["NOTIFY_SOUND"],
        function() return ns.db.notifySound end,
        function(v) ns.db.notifySound = v end), "right", 26)

    local steps = {
        { value = 0.01, text = "0.01%" },
        { value = 0.05, text = "0.05%" },
        { value = 0.1,  text = "0.1%" },
        { value = 0.5,  text = "0.5%" },
        { value = 1,    text = "1%" },
        { value = 5,    text = "5%" },
    }
    Place(CreateDropdown(container, L["NOTIFY_STEP"], steps,
        function() return ns.db.notifyStep end,
        function(v) ns.db.notifyStep = v end, 180, nil), "left", 48)

    Place(CreateSlider(container, L["NOTIFY_SIZE"], 16, 72, 1,
        function() return ns.db.notifySize end,
        function(v) ns.db.notifySize = v; if ns.Display then ns.Display:ApplyAnnounceSettings() end end), "right", 46)

    Place(CreateEditBox(container, L["NOTIFY_FORMAT"], 300,
        function() return ns.db.notifyFormat or "" end,
        function(v) ns.db.notifyFormat = (v ~= "" and v or nil) end, false, L["NOTIFY_FORMAT_TIP"]), "left", 44)

    Place(CreateColorRow(container, L["NOTIFY_COLOR"],
        function() return ns.db.notifyColor end,
        function(c) ns.db.notifyColor = c end, true), "right", 62)

    Place(CreateSlider(container, L["NOTIFY_DURATION"], 1, 10, 0.5,
        function() return ns.db.notifyDuration end,
        function(v) ns.db.notifyDuration = v end, 1), "left", 46)

    Place(CreateSlider(container, L["NOTIFY_OFFSET"], -300, 300, 5,
        function() return ns.db.notifyOffsetY end,
        function(v) ns.db.notifyOffsetY = v; if ns.Display then ns.Display:ApplyAnnounceSettings() end end), "right", 46)

    Place(CreateEditBox(container, L["NOTIFY_PRAISE"], 300,
        function() return ns.db.praiseList or "" end,
        function(v) ns.db.praiseList = (v ~= "" and v or nil) end, false), "left", 44)

    local testBtn = CreateButton(container, L["NOTIFY_TEST"], 110, function()
        if ns.Display then
            ns.Display:Announce({
                praise = ns:RandomPraise(),
                gain   = "700",
                remain = "99.99%",
                pct    = "0.01%",
                cur    = "700",
                goal   = ns.FormatNumber(ns.db.moneyGoal or 7000000),
                name   = ns.db.label ~= "" and ns.db.label or L["MONEY_DEFAULT"],
            })
        end
    end)
    Place(testBtn, "right", 24)

    ------------------------------------------------------------------
    -- 大里程碑
    ------------------------------------------------------------------
    Both(NewSection(container, L["BIGSTEP"]))

    Place(CreateCheck(container, L["BIGSTEP_ENABLE"],
        function() return ns.db.bigStepEnabled ~= false end,
        function(v) ns.db.bigStepEnabled = v end, L["BIGSTEP_TIP"]), "left", 26)

    Place(CreateColorRow(container, L["BIGSTEP_COLOR"],
        function() return ns.db.bigColor end,
        function(c) ns.db.bigColor = c end, true), "right", 62)

    Place(CreateButton(container, L["BIGSTEP_TEST"], 140, function()
        if ns.Display then
            ns.Display:Announce({
                kind   = "big",
                praise = ns:BigPraiseFor(50) or ns:RandomPraise(),
                gain   = "350000",
                remain = "50.00%",
                pct    = "50.00%",
                cur    = "3500000",
                goal   = ns.FormatNumber(ns.db.moneyGoal or 7000000),
                name   = ns.db.label ~= "" and ns.db.label or L["MONEY_DEFAULT"],
            })
        end
    end), "left", 24)

    ------------------------------------------------------------------
    -- 花钱惋惜提示
    ------------------------------------------------------------------
    Both(NewSection(container, L["REGRET"]))

    Place(CreateCheck(container, L["REGRET_ENABLE"],
        function() return ns.db.regretEnabled ~= false end,
        function(v) ns.db.regretEnabled = v end, L["REGRET_TIP"]), "left", 26)

    Place(CreateCheck(container, L["REGRET_SOUND"],
        function() return ns.db.regretSound end,
        function(v) ns.db.regretSound = v end), "right", 26)

    local regretSteps = {
        { value = 0.01, text = "0.01%" },
        { value = 0.05, text = "0.05%" },
        { value = 0.1,  text = "0.1%" },
        { value = 0.5,  text = "0.5%" },
        { value = 1,    text = "1%" },
        { value = 5,    text = "5%" },
    }
    Place(CreateDropdown(container, L["REGRET_STEP"], regretSteps,
        function() return ns.db.regretStep end,
        function(v) ns.db.regretStep = v end, 180, nil), "left", 48)

    Place(CreateColorRow(container, L["REGRET_COLOR"],
        function() return ns.db.regretColor end,
        function(c) ns.db.regretColor = c end, true), "right", 62)

    Place(CreateEditBox(container, L["REGRET_FORMAT"], 300,
        function() return ns.db.regretFormat or "" end,
        function(v) ns.db.regretFormat = (v ~= "" and v or nil) end, false, L["REGRET_FORMAT_TIP"]), "left", 44)

    Place(CreateButton(container, L["REGRET_TEST"], 140, function()
        if ns.Display then
            ns.Display:Announce({
                kind   = "regret",
                praise = ns:BigRegretFor(10) or ns:RandomRegret(),
                spend  = "70000",
                remain = "1.00%",
                pct    = "99.00%",
                cur    = "6930000",
                goal   = ns.FormatNumber(ns.db.moneyGoal or 7000000),
                name   = ns.db.label ~= "" and ns.db.label or L["MONEY_DEFAULT"],
            })
        end
    end), "right", 24)

    ------------------------------------------------------------------
    -- 直播 / 外部读取
    ------------------------------------------------------------------
    Both(NewSection(container, L["LIVE_SECTION"]))

    Place(CreateCheck(container, L["LIVE_ENABLE"],
        function() return ns.db.liveEnabled end,
        function(v)
            ns.db.liveEnabled = v
            if ns.Display then ns.Display:ShowLive(v and ns.db.liveFrameEnabled ~= false) end
            ns:Update(true)
        end, L["LIVE_TIP"]), "left", 26)

    Place(CreateCheck(container, L["LIVE_FRAME"],
        function() return ns.db.liveFrameEnabled ~= false end,
        function(v)
            ns.db.liveFrameEnabled = v
            if ns.Display then ns.Display:ShowLive(v and ns.db.liveEnabled) end
        end), "right", 26)

    Place(CreateCheck(container, L["LIVE_SAVE"],
        function() return ns.db.liveSaveEnabled ~= false end,
        function(v) ns.db.liveSaveEnabled = v end), "left", 26)

    Place(CreateEditBox(container, L["LIVE_FORMAT"], 300,
        function() return ns.db.liveFormat or "" end,
        function(v) ns.db.liveFormat = (v ~= "" and v or nil) end, false, L["LIVE_FORMAT_TIP"]), "right", 44)

    Place(CreateSlider(container, L["LIVE_SIZE"], 10, 72, 1,
        function() return ns.db.liveSize end,
        function(v) ns.db.liveSize = v; if ns.Display then ns.Display:ApplyLiveSettings() end end), "left", 46)

    Place(CreateColorRow(container, L["LIVE_COLOR"],
        function() return ns.db.liveColor end,
        function(c) ns.db.liveColor = c end, true), "right", 62)

    Place(CreateSlider(container, L["LIVE_BG"], 0, 1, 0.05,
        function() return ns.db.liveBg end,
        function(v) ns.db.liveBg = v; if ns.Display then ns.Display:ApplyLiveSettings() end end, 2), "left", 46)

    Place(CreateSlider(container, L["LIVE_WIDTH"], 80, 800, 10,
        function() return ns.db.liveWidth end,
        function(v) ns.db.liveWidth = v; if ns.Display then ns.Display:ApplyLiveSettings() end end), "right", 46)

    Place(CreateButton(container, L["LIVE_RESET"], 180, function()
        if ns.Display then ns.Display:ResetLivePosition() end
    end), "left", 24)

    Place(CreateButton(container, L["LIVE_TEST"], 140, function()
        local p = ns:ComputeProgress()
        local text = ns:LiveText(p)
        print("|cff00c0ffGoalTracker:|r " .. text)
        if ns.Display then ns.Display:RenderLive(text) end
    end), "right", 24)

    local liveHint = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    liveHint:SetPoint("TOPLEFT", container, "TOPLEFT", 12, math.min(y.left, y.right) + 6)
    liveHint:SetJustifyH("LEFT")
    liveHint:SetJustifyV("TOP")
    liveHint:SetWordWrap(true)
    liveHint:SetWidth(590)
    liveHint:SetText("|cffaaaaaa" .. L["LIVE_HINT"] .. "|r")
    local lh = math.ceil((liveHint:GetStringWidth() or 0) / 590) * 16 + 20
    y.left = math.min(y.left, y.right) - lh
    y.right = y.left

    ------------------------------------------------------------------
    -- 位置
    ------------------------------------------------------------------
    Both(NewSection(container, L["POSITION"]))

    Place(CreateCheck(container, L["LOCKED"],
        function() return ns.db.locked end,
        function(v) ns.db.locked = v end, L["LOCKED_TIP"]), "left", 26)

    Place(CreateCheck(container, L["CLICK_THROUGH"],
        function() return ns.db.clickThrough end,
        function(v) ns.db.clickThrough = v end), "right", 26)

    Place(CreateCheck(container, L["RIGHT_CLICK_OPTIONS"],
        function() return ns.db.rightClickOptions == true end,
        function(v) ns.db.rightClickOptions = v end, L["RIGHT_CLICK_OPTIONS_TIP"]), "left", 26)

    Place(CreateSlider(container, L["SCALE"], 0.5, 3, 0.05,
        function() return ns.db.scale end,
        function(v) ns.db.scale = v; if ns.Display then ns.Display:ApplySettings() end end, 2), "left", 46)

    local strata = {
        { value = "BACKGROUND", text = "BACKGROUND" },
        { value = "LOW",    text = "LOW" },
        { value = "MEDIUM", text = "MEDIUM" },
        { value = "HIGH",   text = "HIGH" },
        { value = "DIALOG", text = "DIALOG" },
    }
    Place(CreateDropdown(container, L["STRATA"], strata,
        function() return ns.db.strata end,
        function(v) ns.db.strata = v end, 200), "right", 48)

    Place(CreateButton(container, L["RESET_POS"], 160, function()
        if ns.Display then ns.Display:ResetPosition() end
        print("|cff00c0ffGoalTracker:|r " .. L["RESET_MSG"])
    end), "left", 24)

    ------------------------------------------------------------------
    -- 聊天命令
    ------------------------------------------------------------------
    Both(NewSection(container, L["CMD_SECTION"]))

    Place(CreateEditBox(container, L["CMD_CUSTOM"], 240,
        function() return ns.db.chatCommand or "" end,
        function(v)
            v = (v or ""):match("^%s*(.-)%s*$")
            if v == "" then
                if ns.db.chatCommand then self:ClearCustomCommand() end
            elseif v ~= ns.db.chatCommand then
                self:SetCustomCommand(v)
            end
        end, false, L["CMD_CUSTOM_TIP"]), "left", 44)

    Place(CreateCheck(container, L["CMD_FORCE_GT"],
        function() return ns.db.forceGT end,
        function(v) ns.db.forceGT = v end, L["CMD_FORCE_GT_TIP"]), "right", 26)

    local cmdInfo = CreateFrame("Frame", nil, container)
    cmdInfo:SetSize(320, 22)
    local cmdInfoText = cmdInfo:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cmdInfoText:SetPoint("LEFT", cmdInfo, "LEFT", 0, 0)
    cmdInfoText:SetJustifyH("LEFT")
    function cmdInfo:Refresh()
        -- 走方法而非直接引用 upvalue，避免以后调整代码顺序时再次踩到 nil
        local cmds = Options:GetActiveCommands() or {}
        cmdInfoText:SetText("|cff888888" .. string.format(L["CMD_ACTIVE"],
            table.concat(cmds, " ")) .. "|r")
    end
    cmdInfo:Refresh()
    Place(cmdInfo, "right", 22)

    ------------------------------------------------------------------
    -- 关于
    ------------------------------------------------------------------
    Both(NewSection(container, L["ABOUT"]))
    local about = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    about:SetPoint("TOPLEFT", container, "TOPLEFT", 12, math.min(y.left, y.right))
    about:SetJustifyH("LEFT")
    about:SetText(L["ABOUT_TEXT"] .. "  |cff888888" .. L["CMD_HELP"] .. "|r")
    y.left = math.min(y.left, y.right) - 30
    y.right = y.left

    container:SetHeight(math.max(600, math.abs(math.min(y.left, y.right)) + 40))

    self:RebuildDynamic()
end

----------------------------------------------------------------------
-- 账号金币明细文本
----------------------------------------------------------------------
function Options:UpdateGoldInfo()
    if not self.goldText then return end
    local total, list, warband = ns:GetAccountGold()
    local lines = {}
    local shown = 0

    for _, c in ipairs(list) do
        shown = shown + 1
        if shown > 14 then
            table.insert(lines, "…")
            break
        end
        local g = (c.money or 0) / 10000
        local tag = c.current and "|cff88ff88" .. L["GOLD_CURRENT"] .. "|r" or L["GOLD_SNAPSHOT"]
        table.insert(lines, string.format("|cffffffff%s|r   |cffffd100%s|r G   %s",
            c.key, ns.FormatNumber(g), tag))
    end
    if #list == 0 then
        table.insert(lines, L["GOLD_NONE"])
    end

    table.insert(lines, " ")
    table.insert(lines, string.format("|cff00ff00%s|r  |cffffd100%s|r G", L["GOLD_WARBAND"], ns.FormatNumber(warband / 10000)))
    table.insert(lines, string.format("|cff00c0ff%s|r  |cff00ff00%s|r G", L["GOLD_TOTAL"], ns.FormatNumber(total / 10000)))

    self.goldText:SetText(table.concat(lines, "\n"))
end

----------------------------------------------------------------------
-- 动态区域（随目标类型变化）
----------------------------------------------------------------------
function Options:RebuildDynamic()
    local dyn = self.dynamic
    if not dyn then return end
    local db = ns.db

    for _, child in ipairs({ dyn:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    local y = -4
    local function Add(frame, height)
        frame:SetPoint("TOPLEFT", dyn, "TOPLEFT", 10, y)
        y = y - (height or 44) - 6
        return frame
    end

    local t = db.goalType

    if t == "money" then
        Add(CreateEditBox(dyn, L["MONEY_GOAL"], 220,
            function() return db.moneyGoal end,
            function(v) db.moneyGoal = v; if Options.goldText then Options:UpdateGoldInfo() end end,
            true, L["MONEY_GOAL_TIP"]), 44)

        local scopes = {
            { value = "account",   text = L["SCOPE_ACCOUNT"] },
            { value = "character", text = L["SCOPE_CHAR"] },
        }
        Add(CreateDropdown(dyn, L["MONEY_SCOPE"], scopes,
            function() return db.moneyScope end,
            function(v) db.moneyScope = v end, 280), 48)

    elseif t == "item" then
        Add(CreateEditBox(dyn, L["ITEM_ID"], 260,
            function() return db.itemID or "" end,
            function(v) db.itemID = ParseItemID(v) end, false, L["ITEM_ID_TIP"]), 44)
        Add(CreateEditBox(dyn, L["ITEM_COUNT"], 160,
            function() return db.itemGoal end,
            function(v) db.itemGoal = v end, true), 44)
        Add(CreateCheck(dyn, L["ITEM_BANK"],
            function() return db.includeBank end,
            function(v) db.includeBank = v end), 26)

    elseif t == "quest" then
        Add(CreateEditBox(dyn, L["QUEST_ID"], 200,
            function() return db.questID or "" end,
            function(v) db.questID = tonumber(v) or nil end, false, L["QUEST_ID_TIP"]), 44)

    elseif t == "reputation" then
        local factions = ns:GetFactionList()
        if #factions > 0 then
            Add(CreateDropdown(dyn, L["FACTION_ID"], factions,
                function() return db.factionID end,
                function(v) db.factionID = v end, 280), 48)
        end
        Add(CreateEditBox(dyn, "Faction ID", 160,
            function() return db.factionID or "" end,
            function(v) db.factionID = tonumber(v) or nil end, true, L["FACTION_TIP"]), 44)

        local standings = {}
        for i = 8, 1, -1 do
            table.insert(standings, { value = i, text = ns:GetStandingLabel(i) })
        end
        Add(CreateDropdown(dyn, L["FACTION_GOAL"], standings,
            function() return db.factionGoal end,
            function(v) db.factionGoal = v end, 200), 48)

    elseif t == "currency" then
        local list = ns:GetCurrencyList()
        if #list > 0 then
            Add(CreateDropdown(dyn, L["CURRENCY_ID"], list,
                function() return db.currencyID end,
                function(v) db.currencyID = v end, 280), 48)
        end
        Add(CreateEditBox(dyn, "Currency ID", 160,
            function() return db.currencyID or "" end,
            function(v) db.currencyID = tonumber(v) or nil end, true), 44)
        Add(CreateEditBox(dyn, L["CURRENCY_GOAL"], 160,
            function() return db.currencyGoal end,
            function(v) db.currencyGoal = v end, true), 44)
        Add(CreateCheck(dyn, L["CURRENCY_USEMAX"],
            function() return db.currencyUseMax end,
            function(v) db.currencyUseMax = v end), 26)

    else -- custom
        Add(CreateEditBox(dyn, L["CUSTOM_CURRENT"], 160,
            function() return db.customCurrent end,
            function(v) db.customCurrent = v end, true, L["CUSTOM_TIP"]), 44)
        Add(CreateEditBox(dyn, L["CUSTOM_TARGET"], 160,
            function() return db.customTarget end,
            function(v) db.customTarget = v end, true, L["CUSTOM_TIP"]), 44)
    end

    dyn:SetHeight(math.max(120, math.abs(y) + 20))

    if self.goldSection then
        self.goldSection:SetShown(t == "money" and db.moneyScope ~= "character")
        self:UpdateGoldInfo()
    end

    ns:Update(true)
end

----------------------------------------------------------------------
-- 聊天命令（v2.1：自动避开与其它插件的冲突）
--   1. /gt、/goal 若已被其它插件占用，则自动跳过，改用 /goaltracker
--   2. 登录后再复查一次（有些插件在 PLAYER_ENTERING_WORLD 才注册）
--   3. 支持自定义命令，或用 /goaltracker cmd xxx 随时改
----------------------------------------------------------------------
local SLASH_ID     = "GOALTRACKER"
local BASE_COMMAND = "goaltracker"          -- 保底命令，永不放弃
-- 候选命令按顺序注册，第一个成功的就是主命令（默认 /gttx）
local CANDIDATES   = { "gttx", "gt", "goal", "gtrack", "goaltrack" }

local function NormCmd(s)
    s = tostring(s or ""):match("^%s*(.-)%s*$")
    s = s:gsub("^/+", "")
    if s == "" then return nil end
    if not s:match("^[%w_]+$") then return nil end
    return s
end

-- 检测某个命令是否已被别的插件占用（不检测本插件自己注册的）
local function IsCmdTaken(cmd)
    local key = "/" .. cmd:upper()

    if type(hash_SlashCmdList) == "table" then
        local owner = hash_SlashCmdList[key]
        if owner and owner ~= SLASH_ID then return true end
    end

    -- 兜底：扫描全局 SLASH_XXX1..n（hash 可能尚未建立）
    for g, v in pairs(_G) do
        if type(g) == "string" and type(v) == "string"
           and g:match("^SLASH_[%w_]+%d+$")
           and g:sub(1, #SLASH_ID + 6) ~= ("SLASH_" .. SLASH_ID) then
            if v:upper() == key then return true end
        end
    end
    return false
end

local slashIndex = 0
local function BindCommand(cmd, force)
    local name = NormCmd(cmd)
    if not name then return false end
    local full = "/" .. name

    for _, c in ipairs(activeCmds) do
        if c:upper() == full:upper() then return true end
    end

    if not force and IsCmdTaken(name) then
        local exists = false
        for _, c in ipairs(takenCmds) do if c:upper() == full:upper() then exists = true end end
        if not exists then table.insert(takenCmds, full) end
        return false
    end

    slashIndex = slashIndex + 1
    _G["SLASH_" .. SLASH_ID .. slashIndex] = full
    if type(hash_SlashCmdList) == "table" then
        hash_SlashCmdList[full:upper()] = SLASH_ID
    end
    table.insert(activeCmds, full)
    return true
end

-- 命令集合：自定义 > 候选（gttx 优先）> 保底
-- 保底放最后，这样列表第一位永远是主命令（默认 /gttx）
local function BuildCommandSet()
    local list = {}
    local db = ns.db or {}
    if db.chatCommand and db.chatCommand ~= "" then
        table.insert(list, { cmd = db.chatCommand, force = true })
    end
    if db.forceGT then
        table.insert(list, { cmd = "gt", force = true })       -- 用户要求强行接管
    end
    for _, c in ipairs(CANDIDATES) do
        table.insert(list, { cmd = c, force = false })
    end
    table.insert(list, { cmd = BASE_COMMAND, force = true })   -- 保底，永不放弃
    return list
end

-- 提示里只展示前几个命令 + 保底，避免刷屏；`/cmds` 才列全部
local function ShortCommandList()
    local t = {}
    for i = 1, math.min(#activeCmds, 3) do table.insert(t, activeCmds[i]) end
    local base = "/" .. BASE_COMMAND
    local has = false
    for _, c in ipairs(t) do if c == base then has = true end end
    if not has then table.insert(t, base) end
    return table.concat(t, " ")
end

function Options:RegisterSlashCommands(initial)
    SlashCmdList[SLASH_ID] = function(msg) Options:Command(msg) end

    for _, item in ipairs(BuildCommandSet()) do
        BindCommand(item.cmd, item.force)
    end

    -- 有些插件在进入世界后才注册命令，登录片刻后复查并补齐
    if initial and C_Timer and C_Timer.After then
        C_Timer.After(3, function()
            for _, item in ipairs(BuildCommandSet()) do
                BindCommand(item.cmd, item.force)
            end
            self:ReportCommands()
        end)
    end
end

-- 登录后提示一次冲突情况
function Options:ReportCommands()
    if #takenCmds == 0 or warned then return end
    local skipped = table.concat(takenCmds, " ")
    print("|cff00c0ffGoalTracker:|r " .. string.format(L["CMD_TAKEN"], skipped,
        ShortCommandList()))
    warned = true
end

-- 运行时新增/修改自定义命令（立即生效，无需重载）
function Options:SetCustomCommand(raw)
    local name = NormCmd(raw)
    if not name then
        print("|cff00c0ffGoalTracker:|r " .. L["CMD_INVALID"])
        return false
    end
    ns.db.chatCommand = name
    BindCommand(name, true)
    print("|cff00c0ffGoalTracker:|r " .. string.format(L["CMD_SET"], "/" .. name))
    return true
end

function Options:ClearCustomCommand()
    ns.db.chatCommand = nil
    print("|cff00c0ffGoalTracker:|r " .. L["CMD_CLEARED"])
end

function Options:GetActiveCommands()
    return activeCmds
end

----------------------------------------------------------------------
-- 原生窗体（UIPanelDialogTemplate：系统设置窗口外观，带标题栏与关闭按钮）
----------------------------------------------------------------------
local function MakeWindow()
    local name = "GoalTrackerOptionsWindow"
    local f
    -- 逐级回退：系统对话框模板 → 基础窗体模板 → 手动构造
    for _, tpl in ipairs({ "UIPanelDialogTemplate", "BasicFrameTemplate", "BasicFrameTemplateWithInset" }) do
        local ok, o = pcall(CreateFrame, "Frame", name, UIParent, tpl)
        if ok and o then f = o; break end
    end
    if not f then
        local ok, o = pcall(CreateFrame, "Frame", name, UIParent, "BackdropTemplate")
        f = (ok and o) or CreateFrame("Frame", name, UIParent)
        SafeCall(f, "SetBackdrop", {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end
    return f
end

function Options:BuildWindow()
    if self.window then return self.window end

    local w = MakeWindow()
    self.window = w
    w:SetSize(720, 660)
    w:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    SafeCall(w, "SetFrameStrata", "DIALOG")
    w:SetMovable(true)
    w:EnableMouse(true)
    w:Hide()

    -- 标题（模板没给就自己画一个）
    if w.TitleText then
        w.TitleText:SetText(L["ADDON_TITLE"])
    else
        local title = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", w, "TOP", 0, -10)
        title:SetText(L["ADDON_TITLE"])
        w.TitleText = title
    end

    -- 关闭按钮（模板自带则只接管行为）
    if not w.CloseButton then
        local ok, b = pcall(CreateFrame, "Button", nil, w, "UIPanelCloseButton")
        if ok and b then
            b:SetSize(24, 24)
            b:SetPoint("TOPRIGHT", w, "TOPRIGHT", -4, -4)
            w.CloseButton = b
        end
    end
    if w.CloseButton then
        w.CloseButton:SetScript("OnClick", function() w:Hide() end)
    end

    -- 拖动：优先标题栏区域，不行就整窗可拖
    local hasRegion = false
    if w.CreateTitleRegion then
        hasRegion = pcall(function()
            local region = w:CreateTitleRegion()
            region:SetPoint("TOPLEFT", w, "TOPLEFT", 0, 0)
            region:SetPoint("TOPRIGHT", w, "TOPRIGHT", 0, 0)
            region:SetHeight(34)
        end)
    end
    if not hasRegion then
        w:RegisterForDrag("LeftButton")
        w:SetScript("OnDragStart", function(s) s:StartMoving() end)
        w:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
    end

    -- ESC 可关
    if type(UISpecialFrames) == "table" then
        local exists = false
        for _, n in ipairs(UISpecialFrames) do if n == "GoalTrackerOptionsWindow" then exists = true end end
        if not exists then table.insert(UISpecialFrames, "GoalTrackerOptionsWindow") end
    end

    ------------------------------------------------------------------
    -- 内容区（滚动）
    ------------------------------------------------------------------
    local container
    pcall(function()
        local scroll = CreateFrame("ScrollFrame", "GoalTrackerOptionsScroll", w, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", w, "TOPLEFT", 12, -34)
        scroll:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -30, 46)
        local inner = CreateFrame("Frame", nil, scroll)
        inner:SetSize(640, 1600)
        scroll:SetScrollChild(inner)
        container = inner
        self.scroll = scroll
    end)
    if not container then
        container = CreateFrame("Frame", nil, w)
        container:SetPoint("TOPLEFT", w, "TOPLEFT", 12, -34)
        container:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -12, 46)
    end
    self.container = container

    self:BuildContent(container)

    ------------------------------------------------------------------
    -- 底部按钮：保存 / 关闭
    ------------------------------------------------------------------
    local saveBtn = CreateButton(w, L["SAVE"], 110, function() Options:SaveAndClose() end)
    saveBtn:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 16, 14)
    self.saveButton = saveBtn

    local closeBtn = CreateButton(w, L["CLOSE"], 110, function() w:Hide() end)
    closeBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
    self.closeButton = closeBtn

    local hint = w:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", closeBtn, "RIGHT", 12, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["SAVE_HINT"])
    self.hintText = hint

    -- 直接关闭（X / ESC）视为放弃未保存的修改
    w:SetScript("OnHide", function()
        if Options.snapshot then Options:Rollback(true) end
    end)

    return w
end

----------------------------------------------------------------------
-- 保存 / 关闭
----------------------------------------------------------------------
function Options:SaveAndClose()
    self.snapshot = nil
    if self.window then self.window:Hide() end
    if ns.Display then ns.Display:ApplySettings() end
    ns:Update(true)
    print("|cff00c0ffGoalTracker:|r " .. L["SAVED_MSG"])
end

-- quiet = 由 OnHide 触发，不重复隐藏
function Options:Rollback(quiet)
    if self.snapshot then
        RestoreInto(ns.db, self.snapshot)
        self.snapshot = nil
        if ns.Display then ns.Display:ApplySettings() end
        self:Refresh()
        if self.goldText then self:UpdateGoldInfo() end
        ns:Update(true)
        print("|cff00c0ffGoalTracker:|r " .. L["CANCEL_MSG"])
    end
    if not quiet and self.window then self.window:Hide() end
end

----------------------------------------------------------------------
-- 面板容器（插件列表里给一个入口按钮，真正的设置走原生窗体）
----------------------------------------------------------------------
function Options:Init()
    self:BuildWindow()

    local panel = CreateFrame("Frame", "GoalTrackerOptionsPanel", UIParent)
    self.panel = panel
    panel.name = L["ADDON_TITLE"]
    panel:SetSize(660, 120)

    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    text:SetJustifyH("LEFT")
    text:SetText(L["PANEL_ENTRY_TIP"])

    local openBtn = CreateButton(panel, L["OPEN_SETTINGS"], 200, function() Options:Open() end)
    openBtn:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)

    local registered = false
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok, category = pcall(function()
            local cat = Settings.RegisterCanvasLayoutCategory(panel, L["ADDON_TITLE"])
            cat.ID = L["ADDON_TITLE"]
            Settings.RegisterAddOnCategory(cat)
            return cat
        end)
        if ok and category then
            self.categoryID = category.ID
            registered = true
        end
    end
    if not registered and InterfaceOptions_AddCategory then
        pcall(InterfaceOptions_AddCategory, panel)
    end
    self.registered = registered

    self:RegisterSlashCommands(true)
end

function Options:Open()
    if not self.window then self:BuildWindow() end
    -- 打开时做快照：之后所有改动即时生效，关闭（X/ESC/关闭按钮）则回滚
    self.snapshot = DeepCopy(ns.db)
    self:Refresh()
    if self.goldText then self:UpdateGoldInfo() end
    self.window:Show()
end

function Options:Refresh()
    if not self.window then return end
    local function refreshChildren(parent)
        for _, child in ipairs({ parent:GetChildren() }) do
            if child.Refresh and type(child.Refresh) == "function" then
                pcall(child.Refresh, child)
            end
        end
    end
    refreshChildren(self.window)
    if self.container then refreshChildren(self.container) end
end

function Options:Command(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local cmd, arg = msg:match("^(%S*)%s*(.-)%s*$")
    local lower = (cmd or ""):lower()
    arg = (arg or ""):match("^%s*(.-)%s*$")

    if lower == "" or lower == "config" or lower == "options" or lower == "opt" then
        self:Open()
    elseif lower == "cmd" then
        if arg ~= "" then self:SetCustomCommand(arg) else self:PrintCommands() end
    elseif lower == "cmdreset" or lower == "cmddel" then
        self:ClearCustomCommand()
    elseif lower == "cmds" or lower == "commands" then
        self:PrintCommands()
    elseif lower == "dump" or lower == "snap" then
        ns:DumpSnapshots()
    elseif lower == "lock" or lower == "unlock" then
        if ns.Display then
            ns.Display:SetLocked(not ns.db.locked)
            print("|cff00c0ffGoalTracker:|r " .. (ns.db.locked and L["LOCKED_MSG"] or L["UNLOCKED_TIP"]))
        end
    elseif lower == "reset" then
        if ns.Display then
            ns.Display:ResetPosition()
            print("|cff00c0ffGoalTracker:|r " .. L["RESET_MSG"])
        end
    elseif lower == "gold" then
        ns:PrintGoldBreakdown()
    elseif lower == "test" then
        if ns.Display then
            local goal = ns.FormatNumber(ns.db.moneyGoal or 7000000)
            local name = ns.db.label ~= "" and ns.db.label or L["MONEY_DEFAULT"]
            local sub = (arg or ""):lower()
            if sub == "big" then
                ns.Display:Announce({
                    kind = "big", praise = ns:BigPraiseFor(50) or ns:RandomPraise(),
                    gain = "350000", remain = "50.00%", pct = "50.00%",
                    cur = "3500000", goal = goal, name = name,
                })
            elseif sub == "regret" then
                ns.Display:Announce({
                    kind = "regret", praise = ns:BigRegretFor(10) or ns:RandomRegret(),
                    spend = "70000", remain = "1.00%", pct = "99.00%",
                    cur = "6930000", goal = goal, name = name,
                })
            else
                ns.Display:Announce({
                    praise = ns:RandomPraise(),
                    gain = "700", remain = "99.99%", pct = "0.01%",
                    cur = "700", goal = goal, name = name,
                })
            end
        end
    elseif lower == "help" then
        self:PrintCommands(true)
    else
        self:Open()
    end
end

-- 打印当前真正可用的命令（冲突后 /gt 可能已让出，所以动态显示）
function Options:PrintCommands(full)
    print("|cff00c0ffGoalTracker:|r " .. string.format(L["CMD_ACTIVE"], ShortCommandList()))
    if #takenCmds > 0 then
        print("|cff00c0ffGoalTracker:|r " .. string.format(L["CMD_TAKEN_SHORT"],
            table.concat(takenCmds, " ")))
    end
    if full then
        print("|cff00c0ffGoalTracker:|r " .. L["CMD_USAGE"])
        print("|cff00c0ffGoalTracker:|r " .. L["CMD_ALL"] .. " " .. table.concat(activeCmds, " "))
    end
end
