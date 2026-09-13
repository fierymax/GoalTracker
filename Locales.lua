--[[
    GoalTracker / 目标追踪
    Locales.lua - 多语言文本
]]--

local ADDON_NAME, ns = ...

local L = {}
ns.L = L

local loc = GetLocale()

if loc == "zhCN" or loc == "zhTW" then
    -- ============ 简体 / 繁体中文 ============
    L["ADDON_TITLE"]   = "目标追踪"
    L["ADDON_SUB"]     = "在屏幕上钉一个目标，随时看到自己离它还有多远。"

    -- 目标类型
    L["TYPE_MONEY"]      = "金币（战网账号合计）"
    L["TYPE_ITEM"]       = "物品 / 装备"
    L["TYPE_QUEST"]      = "任务"
    L["TYPE_REPUTATION"] = "声望"
    L["TYPE_CURRENCY"]   = "货币 / 点数"
    L["TYPE_CUSTOM"]     = "自定义数值"

    -- 通用
    L["GOAL_TYPE"]       = "目标类型"
    L["GOAL_NAME"]       = "目标名称"
    L["GOAL_NAME_TIP"]   = "显示在 {name} 位置的文字。留空则自动使用系统名称。"
    L["TEXT_FORMAT"]     = "显示文本格式"
    L["TEXT_FORMAT_TIP"] = "可用占位符：{name} 名称 / {cur} 当前 / {goal} 目标 / {pct} 百分比 / {remain} 还差 / {status} 状态"
    L["STATUS_DONE"]     = "已完成"
    L["STATUS_INPROG"]   = "进行中"
    L["STATUS_NOTSTART"] = "未开始"
    L["COMPLETED"]       = "已完成"

    -- 金币
    L["MONEY_GOAL"]      = "金币目标（单位：金）"
    L["MONEY_GOAL_TIP"]  = "战网账号共用同一个目标。默认 7,000,000 金。"
    L["MONEY_DEFAULT"]   = "战网金币"
    L["MONEY_SCOPE"]     = "统计范围"
    L["SCOPE_ACCOUNT"]   = "全部角色 + 战团银行"
    L["SCOPE_CHAR"]      = "仅当前角色"

    -- 账号金币统计
    L["ACCOUNT_GOLD"]    = "账号金币统计"
    L["ACCOUNT_TIP"]     = "鼠标移到显示框上可查看每个角色的明细。"
    L["GOLD_TOTAL"]      = "合计"
    L["GOLD_WARBAND"]    = "战团银行"
    L["GOLD_CHARS"]      = "角色"
    L["GOLD_CURRENT"]    = "当前角色（实时）"
    L["GOLD_SNAPSHOT"]   = "（上次登录时的记录）"
    L["GOLD_NONE"]       = "暂无记录，切换到其他角色登录一次就会自动记录。"
    L["GOLD_REFRESH"]    = "刷新"
    L["GOLD_CLEAR"]      = "清除角色记录"
    L["GOLD_UPDATED"]    = "更新于"
    L["GOLD_HINT"]       = "说明：只有登录过的角色才能被统计，未登录过的角色无法读取其金币（暴雪接口限制）。战团银行金币在打开战团银行时刷新。"

    -- 每日收入折线图
    L["INCOME_TITLE"]    = "每日收入（近 %d 天）"
    L["INCOME_TODAY"]    = "今日"
    L["INCOME_AVG"]      = "日均"
    L["INCOME_TOTAL"]    = "区间合计"
    L["INCOME_PEAK"]     = "峰值"
    L["INCOME_EMPTY"]    = "暂无数据，赚到第一笔钱后会自动记录。"
    L["INCOME_PRINT"]    = "每日收入（近 %d 天）"
    L["INCOME_ROW"]      = "  %s  %s G"
    L["INCOME_CLEARED"]  = "每日收入记录已清空。"

    -- 里程碑播报
    L["NOTIFY"]          = "里程碑播报"
    L["NOTIFY_ENABLE"]   = "启用播报"
    L["NOTIFY_STEP"]     = "播报间隔（进度百分比）"
    L["NOTIFY_STEP_TIP"] = "默认 0.01%，即每攒够 700 金（700 万 × 0.01%）播报一次。"
    L["NOTIFY_FORMAT"]   = "播报文本"
    L["NOTIFY_FORMAT_TIP"]= "占位符：{praise} 鼓励语 / {gain} 本次获得 / {remain} 离目标还剩（自带 %） / {pct} 当前（自带 %） / {cur} / {goal}"
    -- {remain} / {pct} 自身已带 %，模板里不要再写 %
    L["NOTIFY_DEFAULT_FORMAT"] = "{praise}，您获得了 {gain} 金币，您离目标还有 {remain}"
    L["NOTIFY_SIZE"]     = "播报字号"
    L["NOTIFY_COLOR"]    = "播报颜色"
    L["NOTIFY_DURATION"] = "停留时间（秒）"
    L["NOTIFY_OFFSET"]   = "垂直偏移"
    L["NOTIFY_PRAISE"]   = "自定义鼓励语（用 ; 分隔，留空用内置）"
    L["NOTIFY_TEST"]     = "测试播报"
    L["NOTIFY_SOUND"]    = "播报时播放音效"

    -- 大里程碑
    L["BIGSTEP"]         = "大里程碑（10% / 25% / 33% / 50% / 75% / 90%）"
    L["BIGSTEP_ENABLE"]  = "到这些节点时用专属鼓励语"
    L["BIGSTEP_TIP"]     = "跨过上面任一百分比时，播报专属文案并放大字号；没跨过就用普通鼓励语。"
    L["BIGSTEP_COLOR"]   = "大里程碑颜色"
    L["BIGSTEP_TEST"]    = "测试大里程碑"

    -- 花钱惋惜提示
    L["REGRET"]          = "花钱惋惜提示"
    L["REGRET_ENABLE"]   = "花钱时提示惋惜"
    L["REGRET_TIP"]      = "金币减少达到阈值时播报一句惋惜；一次花掉当前金币的 1% / 10% / 50% / 99% 会有更狠的专属文案。"
    L["REGRET_STEP"]     = "触发阈值（占目标百分比）"
    L["REGRET_STEP_TIP"] = "默认 0.01%，即一次花掉 700 金（700 万 × 0.01%）才提示；另外一次花掉持有金币 1% 以上也会提示。"
    L["REGRET_FORMAT"]   = "惋惜文本"
    L["REGRET_FORMAT_TIP"]= "占位符：{praise} 惋惜语 / {spend} 本次花费 / {pct} 当前（自带 %） / {remain} / {cur} / {goal}"
    L["REGRET_DEFAULT_FORMAT"] = "{praise}，本次花掉 {spend} 金币，进度回到 {pct}"
    L["REGRET_COLOR"]    = "惋惜颜色"
    L["REGRET_SOUND"]    = "惋惜时也播金币音效"
    L["REGRET_TEST"]     = "测试惋惜提示"

    -- 直播 / 外部读取
    L["LIVE_SECTION"]    = "直播 / 外部读取"
    L["LIVE_ENABLE"]     = "启用直播输出"
    L["LIVE_TIP"]        = "开后可同时：①屏幕上的直播小框（OBS 用游戏捕获，实时）；②把最新数值写进存档，配合 Live_Bridge.py 导出成 txt。"
    L["LIVE_FRAME"]      = "显示直播小框（OBS 游戏捕获）"
    L["LIVE_SAVE"]       = "写入存档（供外部脚本导出 txt）"
    L["LIVE_FORMAT"]     = "输出格式"
    L["LIVE_FORMAT_TIP"] = "占位符：{name} {cur} {goal} {pct} {remain} {status}（{pct}/{remain} 自带 %）"
    L["LIVE_DEFAULT_FORMAT"] = "{cur} / {goal} ({pct})"
    L["LIVE_SIZE"]       = "直播框字号"
    L["LIVE_COLOR"]      = "直播框颜色"
    L["LIVE_BG"]         = "背景不透明度"
    L["LIVE_BG_TIP"]     = "0 = 全透明（推荐，OBS 里再自己加背景）；1 = 纯黑底。"
    L["LIVE_WIDTH"]      = "直播框宽度"
    L["LIVE_RESET"]      = "直播框回到默认位置"
    L["LIVE_TEST"]       = "立即输出一次"
    L["LIVE_HINT"]       = "提示：暴雪不允许插件实时写文件，存档只在 /reload、退出或换角色时落盘。要「实时」就用上面的小框 + OBS 游戏捕获；要「文件」就开存档写入并运行 Live_Bridge.py。"

    -- 各类型
    L["ITEM_ID"]         = "物品 ID 或链接"
    L["ITEM_ID_TIP"]     = "可直接把物品链接粘贴进来，或填写数字 ID。"
    L["ITEM_COUNT"]      = "需要数量"
    L["ITEM_BANK"]       = "计入银行 / 战团银行"
    L["ITEM_DEFAULT"]    = "物品目标"

    L["QUEST_ID"]        = "任务 ID"
    L["QUEST_ID_TIP"]    = "填写任务 ID（可在 Wowhead 网址中查到）。"
    L["QUEST_DEFAULT"]   = "任务目标"

    L["FACTION_ID"]      = "声望阵营"
    L["FACTION_TIP"]     = "从列表选择，或手动填写阵营 ID。"
    L["FACTION_GOAL"]    = "目标声望等级"
    L["FACTION_DEFAULT"] = "声望目标"
    L["FACTION_UNKNOWN"] = "未选择阵营"

    L["CURRENCY_ID"]     = "货币"
    L["CURRENCY_GOAL"]   = "货币目标数量"
    L["CURRENCY_USEMAX"] = "以上限为目标"
    L["CURRENCY_DEFAULT"]= "货币目标"

    L["CUSTOM_CURRENT"]  = "当前进度"
    L["CUSTOM_TARGET"]   = "目标进度"
    L["CUSTOM_TIP"]      = "手动维护进度时使用。"
    L["CUSTOM_DEFAULT"]  = "自定义目标"

    -- 外观
    L["LOOK"]            = "外观"
    L["FONT"]            = "字体"
    L["FONT_SIZE"]       = "字号"
    L["FONT_OUTLINE"]    = "文字描边"
    L["OUTLINE_NONE"]    = "无"
    L["OUTLINE_THIN"]    = "细描边"
    L["OUTLINE_THICK"]   = "粗描边"
    L["TEXT_COLOR"]      = "文字颜色"
    L["PICK_COLOR"]      = "自定义…"
    L["COMPLETE_COLOR"]  = "完成时使用单独颜色"
    L["PICK_COMPLETE"]   = "完成颜色"
    L["SHADOW"]          = "文字阴影"

    -- 位置
    L["POSITION"]        = "位置与拖动"
    L["RIGHT_CLICK_OPTIONS"]   = "右键点进度文字打开设置"
    L["RIGHT_CLICK_OPTIONS_TIP"] = "默认关闭。打开后，右键点屏幕上的进度文字会弹出设置窗口。"
    L["LOCKED"]          = "锁定位置"
    L["LOCKED_TIP"]      = "锁定后不可拖动。按住 Alt 拖动可临时移动；如需完全穿透鼠标请勾选下一项。"
    L["CLICK_THROUGH"]   = "鼠标穿透（完全不响应鼠标）"
    L["SCALE"]           = "整体缩放"
    L["RESET_POS"]       = "重置位置到屏幕中央"
    L["STRATA"]          = "图层层级"

    -- 命令
    L["CMD_HELP"]        = "命令：/gttx 打开设置 | /gttx lock 锁定或解锁 | /gttx reset 重置位置 | /gttx gold 金币明细 | /gttx test 测试播报"
    L["UNLOCKED_TIP"]    = "已解锁：现在可以拖动这个框体。"
    L["LOCKED_MSG"]      = "已锁定：位置固定。"
    L["RESET_MSG"]       = "位置已重置。"

    -- 设置窗体（原生窗口 + 保存 / 关闭）
    L["SAVE"]            = "保存"
    L["CLOSE"]           = "关闭"
    L["SAVE_HINT"]       = "改动即时生效；点「保存」保留，点「关闭」或按 ESC 放弃本次修改。"
    L["SAVED_MSG"]       = "设置已保存。"
    L["CANCEL_MSG"]      = "已关闭，本次修改未保存。"
    L["OPEN_SETTINGS"]   = "打开 GoalTracker 设置"

    -- 命令（自动避开与其它插件冲突）
    L["CMD_SECTION"]      = "聊天命令"
    L["CMD_CUSTOM"]       = "自定义命令（不含 /）"
    L["CMD_CUSTOM_TIP"]   = "想换个更好记的命令就填一个，例如 gtx。留空=自动。也可聊天框输入 /goaltracker cmd gtx。"
    L["CMD_ACTIVE"]       = "当前可用：%s"
    L["CMD_TAKEN"]        = "%s 已被其它插件占用，已自动改用：%s（可在 设置→聊天命令 里自定义）"
    L["CMD_TAKEN_SHORT"]  = "已让出（被占用）：%s"
    L["CMD_SET"]          = "命令已设为 %s，立即生效。"
    L["CMD_CLEARED"]      = "已清除自定义命令，恢复默认。"
    L["CMD_INVALID"]      = "命令无效：只能包含字母、数字、下划线。"
    L["CMD_ALL"]          = "全部可用："
    L["CMD_USAGE"]        = "用法：<命令> 打开设置 | lock 锁定 | reset 复位 | gold 金币明细 | income 每日收入 | test 测试播报 | cmd xxx 改命令 | cmds 查看命令 | dump 调试快照"

    -- 关于
    L["ABOUT"]           = "关于"
    L["ABOUT_TEXT"]      = "版本 1.0.2 · 作者 fierymax · 无外部依赖，纯原生实现。所有设置按战网账号保存。"

    -- 内置鼓励语（前 25 条通用，后 25 条为口语梗 / 搞钱梗）
    ns.PRAISES = {
        "干得漂亮", "太强了", "继续保持", "稳扎稳打", "真有你的",
        "效率惊人", "财源广进", "势不可挡", "厉害了我的哥", "又近了一步",
        "手感火热", "节奏很好", "这波很赚", "坚持就是胜利", "你的努力看得见",
        "距离目标又短了一截", "金币在向你招手", "今天的你很棒", "一路高歌", "收成不错",
        "再接再厉", "状态拉满", "运气与实力并存", "目标终会达成", "了不起",

        -- 口语梗 / 搞钱梗（25 条）
        "来财，来财", "钱包鼓鼓，心情舒舒", "余额才是最佳表情包", "万事皆可期",
        "夯爆了，这波稳", "爱你老己，先奖励自己", "含人量拉满的一天", "慢慢来，反而快",
        "今天的你比昨天有钱", "搞钱这条路你从不孤单", "小妖怪也有大梦想", "金币会迟到但不缺席",
        "情绪价值已到账", "苦尽甘来，甘已经来了", "坚持本身就是天赋", "先别卷了，夸夸自己",
        "存款 +700，快乐 +N", "你攒钱的样子真好看", "暴富进度条 +1", "只进不出，这才对",
        "财神今天也上班", "离小目标又近一点点", "稳步上升比暴涨安心", "时间会奖励坚持的人",
        "这金币，比出橙装还香",
    }

    ------------------------------------------------------------------
    -- 大里程碑（10% / 25% / 33% / 50% / 75% / 90%）专属鼓励语
    ------------------------------------------------------------------
    ns.BIG_PRAISES = {
        [10] = { "开门红！已完成 10%，稳稳起步", "十分之一到手，节奏很不错" },
        [25] = { "四分之一达成，你已经跑赢大多数人", "25%！进度条肉眼可见地在动" },
        [33] = { "三分之一了，胜利在向你招手", "33%，只剩两个这样的自己了" },
        [50] = { "半程达成！说好的坚持你做到了", "50%！前半程收工，后半程继续" },
        [75] = { "四分之三！冲刺阶段来了", "75%，胜利的味道已经闻到了" },
        [90] = { "90%！最后一段路，稳住就赢了", "就差临门一脚，千万别松劲" },
    }

    ------------------------------------------------------------------
    -- 惋惜提示（花钱时）：20 条普通 + 10 条网络梗
    ------------------------------------------------------------------
    ns.REGRETS = {
        -- 普通（20）
        "金币少了，心疼三秒钟", "这笔花得有点疼", "钱包瘦身成功",
        "余额回落，请稳住心态", "看着数字变小，深呼吸", "开销有点大，下次注意",
        "刚才那笔，肉疼", "距离目标远了一点点", "花钱一时爽，进度往回走",
        "攒钱不易，且花且珍惜", "这次消费有点狠", "金币流走了一些",
        "进度条小幅回撤", "心在滴血，但生活要继续", "这笔钱本可以留着",
        "小金库缩水了", "买都买了，往前看", "进度退了一小步",
        "有点可惜，重新出发", "攒钱路上总有代价",
        -- 网络梗（10）
        "钱包：你清高，你了不起", "钱没了可以再赚，心态没了就真没了",
        "我的钱只是换了个方式陪我", "一秒回到解放前", "存款：我轻轻地走了",
        "这波属于钱包刺客", "含泪消费，笑着前行", "钱是赚出来的，不是省出来的……但我还是心疼",
        "余额：已读不回", "又是一次痛彻心扉的成长",
    }

    ------------------------------------------------------------------
    -- 特殊惋惜：一次花掉当前金币的 1% / 10% / 50% / 99%
    ------------------------------------------------------------------
    ns.BIG_REGRETS = {
        [1]  = { "一次花掉 1% 家底，小场面", "1% 而已，还扛得住" },
        [10] = { "十分之一没了，肉疼指数 +1", "10% 家底出走，需要缓一缓" },
        [50] = { "一半家当没了，这波有点狠", "50%！钱包直接腰斩" },
        [99] = { "几乎清空了……从头再来吧", "99% 的家底说没就没，佩服你的魄力" },
    }
else
    -- ============ English (default) ============
    L["ADDON_TITLE"]   = "Goal Tracker"
    L["ADDON_SUB"]     = "Pin one goal on your screen and watch how close you are."

    L["TYPE_MONEY"]      = "Gold (account total)"
    L["TYPE_ITEM"]       = "Item / Gear"
    L["TYPE_QUEST"]      = "Quest"
    L["TYPE_REPUTATION"] = "Reputation"
    L["TYPE_CURRENCY"]   = "Currency"
    L["TYPE_CUSTOM"]     = "Custom"

    L["GOAL_TYPE"]       = "Goal type"
    L["GOAL_NAME"]       = "Goal name"
    L["GOAL_NAME_TIP"]   = "Shown in place of {name}. Leave empty to use the in-game name."
    L["TEXT_FORMAT"]     = "Text format"
    L["TEXT_FORMAT_TIP"] = "Placeholders: {name} {cur} {goal} {pct} {remain} {status}"
    L["STATUS_DONE"]     = "Done"
    L["STATUS_INPROG"]   = "In progress"
    L["STATUS_NOTSTART"] = "Not started"
    L["COMPLETED"]       = "Completed"

    L["MONEY_GOAL"]      = "Gold goal (in gold)"
    L["MONEY_GOAL_TIP"]  = "Shared by the whole account. Default 7,000,000 gold."
    L["MONEY_DEFAULT"]   = "Account gold"
    L["MONEY_SCOPE"]     = "Counting scope"
    L["SCOPE_ACCOUNT"]   = "All characters + warband bank"
    L["SCOPE_CHAR"]      = "Current character only"

    L["ACCOUNT_GOLD"]    = "Account gold"
    L["ACCOUNT_TIP"]     = "Hover the display frame to see per-character details."
    L["GOLD_TOTAL"]      = "Total"
    L["GOLD_WARBAND"]    = "Warband bank"
    L["GOLD_CHARS"]      = "Characters"
    L["GOLD_CURRENT"]    = "Current character (live)"
    L["GOLD_SNAPSHOT"]   = " (last seen)"
    L["GOLD_NONE"]       = "No records yet. Log into other characters once to record them."
    L["GOLD_REFRESH"]    = "Refresh"
    L["GOLD_CLEAR"]      = "Clear records"
    L["GOLD_UPDATED"]    = "Updated"
    L["GOLD_HINT"]       = "Only characters you have logged in with are counted (Blizzard API limit). Warband bank gold refreshes when you open the warband bank."

    -- Daily income line chart
    L["INCOME_TITLE"]    = "Daily income (last %d days)"
    L["INCOME_TODAY"]    = "Today"
    L["INCOME_AVG"]      = "Daily avg"
    L["INCOME_TOTAL"]    = "Period total"
    L["INCOME_PEAK"]     = "Peak"
    L["INCOME_EMPTY"]    = "No data yet - it starts recording as soon as you earn gold."
    L["INCOME_PRINT"]    = "Daily income (last %d days)"
    L["INCOME_ROW"]      = "  %s  %s G"
    L["INCOME_CLEARED"]  = "Daily income history cleared."

    L["NOTIFY"]          = "Milestone announcement"
    L["NOTIFY_ENABLE"]   = "Enable announcement"
    L["NOTIFY_STEP"]     = "Announce every (percent)"
    L["NOTIFY_STEP_TIP"] = "Default 0.01%, i.e. every 700 gold of a 7,000,000 goal."
    L["NOTIFY_FORMAT"]   = "Announcement text"
    L["NOTIFY_FORMAT_TIP"]= "Placeholders: {praise} {gain} {remain} {pct} {cur} {goal} ({remain}/{pct} already include %)"
    L["NOTIFY_DEFAULT_FORMAT"] = "{praise}! You gained {gain} gold, {remain} left to your goal"
    L["NOTIFY_SIZE"]     = "Font size"
    L["NOTIFY_COLOR"]    = "Color"
    L["NOTIFY_DURATION"] = "Duration (sec)"
    L["NOTIFY_OFFSET"]   = "Vertical offset"
    L["NOTIFY_PRAISE"]   = "Custom praises (separate with ; )"
    L["NOTIFY_TEST"]     = "Test"
    L["NOTIFY_SOUND"]    = "Play a sound"

    L["BIGSTEP"]         = "Big milestones (10% / 25% / 33% / 50% / 75% / 90%)"
    L["BIGSTEP_ENABLE"]  = "Use special praises at these points"
    L["BIGSTEP_TIP"]     = "Crossing any of these shows a dedicated line in a bigger font; otherwise the normal praises are used."
    L["BIGSTEP_COLOR"]   = "Big milestone color"
    L["BIGSTEP_TEST"]    = "Test big milestone"

    L["REGRET"]          = "Spending regrets"
    L["REGRET_ENABLE"]   = "Show a regret when you spend"
    L["REGRET_TIP"]      = "Announces a regret when gold drops past the threshold; spending 1% / 10% / 50% / 99% of what you hold triggers harsher special lines."
    L["REGRET_STEP"]     = "Threshold (% of goal)"
    L["REGRET_STEP_TIP"] = "Default 0.01% (700 gold of a 7,000,000 goal). Spending over 1% of your current gold also triggers it."
    L["REGRET_FORMAT"]   = "Regret text"
    L["REGRET_FORMAT_TIP"]= "Placeholders: {praise} {spend} {pct} {remain} {cur} {goal} ({pct}/{remain} already include %)"
    L["REGRET_DEFAULT_FORMAT"] = "{praise} - spent {spend} gold, progress back to {pct}"
    L["REGRET_COLOR"]    = "Regret color"
    L["REGRET_SOUND"]    = "Play the coin sound here too"
    L["REGRET_TEST"]     = "Test regret"

    L["LIVE_SECTION"]    = "Streaming / external read"
    L["LIVE_ENABLE"]     = "Enable streaming output"
    L["LIVE_TIP"]        = "When on: 1) a small on-screen frame for OBS game capture (real time); 2) the latest values are written to saved variables for Live_Bridge.py to export as txt."
    L["LIVE_FRAME"]      = "Show the streaming frame (OBS game capture)"
    L["LIVE_SAVE"]       = "Write to saved variables (for export scripts)"
    L["LIVE_FORMAT"]     = "Output format"
    L["LIVE_FORMAT_TIP"] = "Placeholders: {name} {cur} {goal} {pct} {remain} {status}"
    L["LIVE_DEFAULT_FORMAT"] = "{cur} / {goal} ({pct})"
    L["LIVE_SIZE"]       = "Stream frame font size"
    L["LIVE_COLOR"]      = "Stream frame color"
    L["LIVE_BG"]         = "Background opacity"
    L["LIVE_BG_TIP"]     = "0 = fully transparent (recommended), 1 = solid black."
    L["LIVE_WIDTH"]      = "Stream frame width"
    L["LIVE_RESET"]      = "Reset stream frame position"
    L["LIVE_TEST"]       = "Output once now"
    L["LIVE_HINT"]       = "Note: addons cannot write files in real time - saved variables are flushed on /reload, logout or character switch. For real time use the frame + OBS game capture; for a file, enable saving and run Live_Bridge.py."

    L["ITEM_ID"]         = "Item ID or link"
    L["ITEM_ID_TIP"]     = "Paste an item link, or type a numeric ID."
    L["ITEM_COUNT"]      = "Required amount"
    L["ITEM_BANK"]       = "Count bank / warband bank"
    L["ITEM_DEFAULT"]    = "Item goal"

    L["QUEST_ID"]        = "Quest ID"
    L["QUEST_ID_TIP"]    = "Numeric quest ID (find it in the Wowhead URL)."
    L["QUEST_DEFAULT"]   = "Quest goal"

    L["FACTION_ID"]      = "Faction"
    L["FACTION_TIP"]     = "Pick from the list, or type a faction ID."
    L["FACTION_GOAL"]    = "Target standing"
    L["FACTION_DEFAULT"] = "Reputation goal"
    L["FACTION_UNKNOWN"] = "No faction selected"

    L["CURRENCY_ID"]     = "Currency"
    L["CURRENCY_GOAL"]   = "Currency goal"
    L["CURRENCY_USEMAX"] = "Use max as goal"
    L["CURRENCY_DEFAULT"]= "Currency goal"

    L["CUSTOM_CURRENT"]  = "Current value"
    L["CUSTOM_TARGET"]   = "Target value"
    L["CUSTOM_TIP"]      = "For manual tracking."
    L["CUSTOM_DEFAULT"]  = "Custom goal"

    L["LOOK"]            = "Appearance"
    L["FONT"]            = "Font"
    L["FONT_SIZE"]       = "Font size"
    L["FONT_OUTLINE"]    = "Outline"
    L["OUTLINE_NONE"]    = "None"
    L["OUTLINE_THIN"]    = "Thin"
    L["OUTLINE_THICK"]   = "Thick"
    L["TEXT_COLOR"]      = "Text color"
    L["PICK_COLOR"]      = "Pick…"
    L["COMPLETE_COLOR"]  = "Use a separate completed color"
    L["PICK_COMPLETE"]   = "Completed color"
    L["SHADOW"]          = "Text shadow"

    L["POSITION"]        = "Position"
    L["RIGHT_CLICK_OPTIONS"]   = "Right-click progress text opens settings"
    L["RIGHT_CLICK_OPTIONS_TIP"] = "Off by default."
    L["LOCKED"]          = "Lock position"
    L["LOCKED_TIP"]      = "When locked, hold Alt to drag."
    L["CLICK_THROUGH"]   = "Click through (ignore all mouse)"
    L["SCALE"]           = "Scale"
    L["RESET_POS"]       = "Reset position"
    L["STRATA"]          = "Frame strata"

    L["CMD_HELP"]        = "Commands: /gttx options | /gttx lock | /gttx reset | /gttx gold | /gttx test"
    L["UNLOCKED_TIP"]    = "Unlocked: drag the frame now."
    L["LOCKED_MSG"]      = "Locked."
    L["RESET_MSG"]       = "Position reset."

    L["SAVE"]            = "Save"
    L["CLOSE"]           = "Close"
    L["SAVE_HINT"]       = "Changes apply instantly; Save keeps them, Close or ESC discards them."
    L["SAVED_MSG"]       = "Settings saved."
    L["CANCEL_MSG"]      = "Closed without saving."
    L["OPEN_SETTINGS"]   = "Open GoalTracker settings"

    L["CMD_SECTION"]      = "Chat commands"
    L["CMD_CUSTOM"]       = "Custom command (without /)"
    L["CMD_CUSTOM_TIP"]   = "Pick a command you like, e.g. gtx. Leave empty for auto."
    L["CMD_ACTIVE"]       = "Active: %s"
    L["CMD_TAKEN"]        = "%s is already used by another addon; using %s instead (customize in Options > Chat commands)."
    L["CMD_TAKEN_SHORT"]  = "Skipped (taken): %s"
    L["CMD_SET"]          = "Command set to %s."
    L["CMD_CLEARED"]      = "Custom command cleared."
    L["CMD_INVALID"]      = "Invalid command: letters, digits and underscore only."
    L["CMD_ALL"]          = "All commands: "
    L["CMD_USAGE"]        = "Usage: <cmd> options | lock | reset | gold | income | test | cmd xxx | cmds | dump"

    L["ABOUT"]           = "About"
    L["ABOUT_TEXT"]      = "Version 1.0.2 · by fierymax · No dependencies. Settings are saved per Battle.net account."

    -- Built-in praises (first 25 generic, next 25 slang / money vibes)
    ns.PRAISES = {
        "Nice work", "Amazing", "Keep it up", "Steady progress", "Well played",
        "Fantastic", "Rich and getting richer", "Unstoppable", "Great job", "One step closer",
        "On fire", "Perfect pace", "Big gains", "Consistency wins", "Your grind is paying off",
        "The goal is getting closer", "Gold is flowing", "You are doing great", "Full steam ahead", "Solid haul",

        "Bags heavier, mood lighter",
        "W grind, no cap",
        "Look at you go",
        "Printing gold like a goblin",
        "Your wallet is glowing",
        "Small steps, big bags",
        "Rich era loading...",
        "Manifesting: completed",
        "You're him, you're that guy",
        "Zero notes, perfect run",
        "Gold gained, goals gained",
        "Certified money magnet",
        "Keep cooking",
        "Unbothered and wealthy",
        "This is the way",
        "Delulu is the solulu and it's working",
        "Main character energy",
        "Another day, another bag",
        "Stacks on stacks",
        "Patience pays dividends",
        "You're doing amazing, sweetie",
        "Compound interest is your friend",
        "Dungeon cleared: poverty",
        "Loot goblin approved",
        "Onwards to the next milestone",
    }

    -- Big milestones (10% / 25% / 33% / 50% / 75% / 90%)
    ns.BIG_PRAISES = {
        [10] = { "10% done - a solid start", "One tenth down, great pace" },
        [25] = { "A quarter done, you're ahead of most", "25%! The bar is visibly moving" },
        [33] = { "One third there, victory is waving at you", "33% - only two more of these to go" },
        [50] = { "Halfway! You kept your promise", "50%! First half done, on to the next" },
        [75] = { "Three quarters! Sprint time", "75% - you can almost taste it" },
        [90] = { "90%! Hold steady and it's yours", "One last push, don't let up now" },
    }

    -- Regrets (spending): 20 plain + 10 slang
    ns.REGRETS = {
        "Ouch, that one stung a little", "Your wallet just got lighter",
        "Balance dropped, stay calm", "Take a deep breath and carry on",
        "That was a big spend", "Progress slipped back a bit",
        "Spending is easy, saving is the grind", "A little farther from the goal now",
        "There goes some hard-earned gold", "The bar moved backwards",
        "Bleeding gold, but life goes on", "That gold could have stayed",
        "The stash shrank", "It's bought - look forward",
        "A small step back", "A bit of a shame, start again",
        "Every saver pays a price", "Gold out, lessons in",
        "Your coins found a new home", "Sadly, the bar went the wrong way",

        "Wallet: 'you do you, I guess'", "Money comes back, composure doesn't",
        "Your gold just changed form", "Back to square one, speedrun edition",
        "Savings: quietly left the chat", "Certified wallet assassin",
        "Spent with tears, moving on with a smile", "You make money, you don't save it... ouch",
        "Balance: left on read", "Another painful chapter of growth",
    }

    -- Special regrets: spent 1% / 10% / 50% / 99% of what you hold
    ns.BIG_REGRETS = {
        [1]  = { "1% of the stash gone - manageable", "Just 1%, you'll live" },
        [10] = { "A tenth of it, gone", "10% walked out the door" },
        [50] = { "Half your gold, just like that", "50%! Wallet cut in half" },
        [99] = { "Basically cleaned out... back to zero", "99% of it, gone - impressive, honestly" },
    }
end
