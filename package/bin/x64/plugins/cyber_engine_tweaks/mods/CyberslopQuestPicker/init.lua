-- Cyberslop Quest Picker 1.0.1 (2026-11-23)
-- 1.0.1: TRACK / UNTRACK pop their button colours before they call the game, so an error there can't leave
--        colours pushed on every CET window.
-- Pick the tracked quest from a CET window instead of the pause menu journal. Same lists as the 2.5 journal
-- (questLog.swift): tabs All / Quests (main + side) / Gigs (gigs, NCPD, cyberpsychos, apartments, courier) / Done,
-- search, sort by last update or by distance; a row shows the title, the first active objective and the nearest pin.
-- Click a row: its objectives and description (click an objective to track that one). Pin box or double-click:
-- track the quest (its first non-optional objective), pin box on the tracked quest: untrack.
-- Keep Tracked Quest (Cyberslop patch) counts every pick as the player's own: TrackEntry runs between its
-- BeginPlayerAction / EndPlayerAction, untrack is its ToggleByKey (HUD redraw, tracker stays empty, Numpad 9
-- brings the quest back). Without Keep Tracked Quest the journal is called directly.
-- Cost: no onUpdate, no hooks, no keys. onDraw returns at once while the CET overlay is closed. While it is open:
-- active quests re-read every 1.5 s, finished quests once per overlay open, texts cached per journal entry, only
-- the rows inside the scroll view are drawn.

local VERSION = "1.0.0"
local KTQ_SYS = "KeepTrackedQuest.KeepTrackedQuestSystem"
local CONFIG = "config.json"
local REFRESH = 1.5      -- s between quest reads while the overlay is open
local WIDE = 820         -- list content width from which the details sit beside the list
local CUT = 9            -- cut corner of rows and chips, px
local TITLE_SCALE = 1.1  -- row titles a bit larger, like the journal

-- categories, in the journal's sort order (QuestListItemType); OTHER = types the journal maps to Invalid
local C_MAIN, C_SIDE, C_GIG, C_PSYCHO, C_NCPD, C_APART, C_COURIER, C_OTHER, C_DONE = 0, 1, 2, 3, 4, 5, 6, 7, 8
local CAT_LABEL = { [0] = "MAIN JOB", "SIDE JOB", "GIG", "CYBERPSYCHO", "NCPD", "APARTMENT", "COURIER", "OTHER", "DONE" }
local TAB_ALL, TAB_QUESTS, TAB_GIGS, TAB_DONE = 1, 2, 3, 4
local TAB_ID = { "##cqp_t1", "##cqp_t2", "##cqp_t3", "##cqp_t4" }
local TAB_TIP = { "All active quests", "Main and side jobs", "Gigs, NCPD, cyberpsychos, apartments, courier",
    "Completed and failed" }

-- draw-list colours (ImU32 = 0xAABBGGRR), taken from the 2.5 journal screen
local function abgr(r, g, b, a)
    return math.floor((a or 1) * 255 + 0.5) * 16777216 + b * 65536 + g * 256 + r
end
local K = {
    rowBg = abgr(24, 18, 16, 0.92), rowBgHov = abgr(36, 27, 24, 0.95),
    rowLine = abgr(86, 66, 56, 0.9), rowLineHov = abgr(136, 108, 90, 1),
    trBg = abgr(46, 37, 12, 0.94), trLine = abgr(243, 206, 60, 1),
    sel = abgr(94, 246, 255, 0.7),
    title = abgr(98, 226, 240, 1), titleHov = abgr(150, 252, 255, 1),
    obj = abgr(196, 190, 182, 1), objHov = abgr(246, 243, 237, 1),
    dist = abgr(198, 236, 244, 1),
    yellow = abgr(250, 212, 30, 1), yellowDim = abgr(250, 212, 30, 0.45), pinDark = abgr(140, 14, 32, 1),
    ink = abgr(26, 16, 6, 1),
    green = abgr(62, 206, 120, 1), greenDim = abgr(62, 206, 120, 0.55),
    red = abgr(255, 78, 72, 1), redDim = abgr(150, 52, 48, 1),
    blue = abgr(90, 164, 255, 1), cyan = abgr(94, 246, 255, 1), cyanDim = abgr(94, 246, 255, 0.5),
    orange = abgr(255, 150, 60, 1), gray = abgr(150, 144, 136, 1),
    chipBg = abgr(30, 13, 12, 0.92), chipLine = abgr(100, 38, 34, 0.95),
    chipBgOn = abgr(8, 40, 44, 0.94), chipLineOn = abgr(94, 246, 255, 1),
}
local CAT_COL = { [C_SIDE] = K.yellow, [C_GIG] = K.green, [C_PSYCHO] = K.red, [C_NCPD] = K.blue,
    [C_APART] = K.cyan, [C_COURIER] = K.orange, [C_OTHER] = K.gray }
local TAB_COL = { K.cyan, K.yellow, K.green, K.red }

-- window palette (ImGui style colours, 0-255), pushed around this window only
local PAL = {
    { "Text", 215, 210, 200, 1 }, { "TextDisabled", 128, 116, 106, 1 },
    { "WindowBg", 13, 10, 9, 0.85 }, { "ChildBg", 0, 0, 0, 0 }, { "PopupBg", 16, 11, 10, 0.97 },
    { "Border", 112, 36, 32, 0.85 }, { "BorderShadow", 0, 0, 0, 0 },
    { "TitleBg", 28, 10, 9, 0.95 }, { "TitleBgActive", 96, 18, 16, 0.97 }, { "TitleBgCollapsed", 28, 10, 9, 0.8 },
    { "FrameBg", 22, 8, 8, 0.92 }, { "FrameBgHovered", 44, 14, 13, 0.95 }, { "FrameBgActive", 62, 18, 16, 1 },
    { "ScrollbarBg", 52, 12, 12, 0.55 }, { "ScrollbarGrab", 255, 75, 70, 0.95 },
    { "ScrollbarGrabHovered", 255, 112, 102, 1 }, { "ScrollbarGrabActive", 255, 140, 126, 1 },
    { "Button", 14, 44, 48, 0.92 }, { "ButtonHovered", 24, 72, 78, 0.96 }, { "ButtonActive", 38, 102, 110, 1 },
    { "Separator", 112, 36, 32, 0.7 }, { "CheckMark", 94, 246, 255, 1 },
    { "ResizeGrip", 255, 75, 70, 0.25 }, { "ResizeGripHovered", 255, 75, 70, 0.6 },
    { "ResizeGripActive", 255, 75, 70, 0.9 }, { "TextSelectedBg", 94, 246, 255, 0.3 },
}

local cfg = { tab = TAB_ALL, sort = 1 }  -- sort 1 = last updated, 2 = nearest

-- state (one table keeps the upvalue count of the draw functions low)
local S = {
    overlay = false, inGame = false, nextRefresh = 0, needFull = true, needDetails = false, errMsg = nil,
    lastErr = nil, active = {}, done = {}, activeBy = {}, doneBy = {}, counts = { 0, 0, 0, 0 },
    countStr = { "0", "0", "0", "0" }, view = {}, viewDirty = true, search = "", searchLower = "",
    selected = nil, det = nil, trackedQuest = 0, trackedObj = 0, hoverObj = 0, lastToggle = 0,
    txtDone = nil, txtFailed = nil, txtOptional = nil, tsMode = nil, sortW = nil, chipW = { 0, 0, 0, 0 },
    shown = true, pendingSel = nil, pendingAt = 0,
}
local textCache, optCache, counterCache, distCache, rowIds = {}, {}, {}, {}, {}
local F = nil       -- journal state filters, made on first use
local palFlat = nil -- resolved PAL

local function logLine(s)
    if spdlog and spdlog.info then spdlog.info("[CyberslopQuestPicker] " .. s) else print("[CyberslopQuestPicker] " .. s) end
end

local function u32(h)
    if h < 0 then return h + 4294967296 end
    return h
end

local function valid(x)
    return x ~= nil and IsDefined(x)
end

-- ---------------------------------------------------------------- config

local function loadCfg()
    local f = io.open(CONFIG, "r")
    if not f then return end
    local s = f:read("*a")
    f:close()
    local ok, t = pcall(json.decode, s)
    if ok and type(t) == "table" then
        if type(t.tab) == "number" and t.tab >= 1 and t.tab <= 4 then cfg.tab = math.floor(t.tab) end
        if t.sort == 1 or t.sort == 2 then cfg.sort = t.sort end
    end
end

local function saveCfg()
    local f = io.open(CONFIG, "w")
    if f then
        f:write(json.encode(cfg))
        f:close()
    end
end

-- ---------------------------------------------------------------- journal reads

local function filters()
    if F then return end
    F = {
        active = JournalRequestStateFilter.new({ active = true }),
        default = JournalRequestStateFilter.new({ active = true, inactive = true }),
        succ = JournalRequestStateFilter.new({ succeeded = true }),
        fail = JournalRequestStateFilter.new({ failed = true }),
        detail = JournalRequestStateFilter.new({ active = true, succeeded = true, failed = true }),
    }
end

local function getQuests(j, filter)
    local ctx = JournalRequestContext.new()
    ctx.stateFilter = filter
    return j:GetQuests(ctx) or {}
end

local function category(j, q)
    local t = j:GetQuestType(q)
    local T = gameJournalQuestType
    if t == T.MainQuest then return C_MAIN end
    if t == T.SideQuest or t == T.MinorQuest or t == T.CourierSideQuest then return C_SIDE end
    if t == T.StreetStory then return C_GIG end
    if t == T.CyberPsycho then return C_PSYCHO end
    if t == T.Contract then return C_NCPD end
    if t == T.ApartmentQuest then return C_APART end
    if t == T.CourierQuest then return C_COURIER end
    return C_OTHER
end

-- game seconds of an entry's last change (GameTime: .seconds field, else :GetSeconds(); 0 if neither works)
local function stamp(j, e)
    if S.tsMode == 0 then return 0 end
    local t = j:GetEntryTimestamp(e)
    if t == nil then return 0 end
    if S.tsMode == 1 then return t.seconds or 0 end
    if S.tsMode == 2 then return t:GetSeconds() or 0 end
    local ok1, s1 = pcall(function() return t.seconds end)
    if ok1 and type(s1) == "number" then S.tsMode = 1; return s1 end
    local ok2, s2 = pcall(function() return t:GetSeconds() end)
    if ok2 and type(s2) == "number" then S.tsMode = 2; return s2 end
    S.tsMode = 0
    return 0
end

local function isOptional(j, o, h)
    local v = optCache[h]
    if v == nil then
        v = j:GetIsObjectiveOptional(o) and true or false
        optCache[h] = v
    end
    return v
end

local function baseText(j, o, h)
    local s = textCache[h]
    if s == nil then
        s = GetLocalizedText(o:GetDescription()) or ""
        if isOptional(j, o, h) then s = s .. " [" .. S.txtOptional .. "]" end
        textCache[h] = s
    end
    return s
end

-- objective text with the journal's " [cur/total]" counter (left out if the text already carries it)
local function objText(j, o, h)
    local s = baseText(j, o, h)
    local total = j:GetObjectiveTotalCounter(o)
    if not total or total <= 0 then return s end
    local cur = j:GetObjectiveCurrentCounter(o) or 0
    local c = counterCache[h]
    if c and c[1] == cur and c[2] == total then return c[3] end
    local frag = cur .. "/" .. total
    local text = s:find(frag, 1, true) and s or (s .. " [" .. frag .. "]")
    counterCache[h] = { cur, total, text }
    return text
end

-- "857M" / "1.1KM" like the journal; nil for no pin
local function distLabel(d)
    if not d or d <= 0 then return nil, 0 end
    local key
    if d < 1000 then key = math.floor(d + 0.5) else key = 100000 + math.floor(d / 100 + 0.5) end
    local e = distCache[key]
    if not e then
        local s
        if key < 100000 then s = key .. "M" else s = string.format("%.1fKM", (key - 100000) / 10) end
        e = { s, (ImGui.CalcTextSize(s)) }
        distCache[key] = e
    end
    return e[1], e[2]
end

local function collectObjectives(j, entry, depth, out)
    local kids = j:GetChildren(entry, F.active)
    if not kids then return end
    for i = 1, #kids do
        local c = kids[i]
        if c:IsA("gameJournalQuestObjective") then
            out[#out + 1] = c
        elseif depth < 4 and c:IsA("gameJournalContainerEntry") then
            collectObjectives(j, c, depth + 1, out)
        end
    end
end

local function questOf(j, e)
    local n = 0
    while valid(e) and n < 8 do
        if e:IsA("gameJournalQuest") then return e end
        e = j:GetParentEntry(e)
        n = n + 1
    end
    return nil
end

local function readTracked(j)
    S.trackedQuest, S.trackedObj = 0, 0
    local t = j:GetTrackedEntry()
    if valid(t) then
        S.trackedObj = j:GetEntryHash(t)
        local q = questOf(j, t)
        if q then S.trackedQuest = j:GetEntryHash(q) end
    end
end

local function readActive(j, full)
    local list = getQuests(j, F.active)
    local out, seen = {}, {}
    for i = 1, #list do
        local q = list[i]
        local h = j:GetEntryHash(q)
        local r = S.activeBy[h]
        if not r then
            r = { hash = h }
            S.activeBy[h] = r
        end
        if full or not r.title then
            r.title = string.upper(GetLocalizedText(q:GetTitle(j)) or "")
            r.cat = category(j, q)
            r.key = nil
        end
        local objs = {}
        collectObjectives(j, q, 0, objs)
        local first, target, firstHash, best = nil, nil, nil, nil
        local ts = stamp(j, q)
        for k = 1, #objs do
            local o = objs[k]
            local oh = j:GetEntryHash(o)
            if k == 1 then first, firstHash = objText(j, o, oh), oh end
            if not target and not isOptional(j, o, oh) then target = oh end
            local d = j:GetDistanceToNearestMappin(o, F.default)
            if d and d > 0 and (not best or d < best) then best = d end
            local t = stamp(j, o)
            if t > ts then ts = t end
        end
        if r.obj ~= first then
            r.obj = first
            r.key = nil
        end
        r.target = target or firstHash
        r.dist = best or 0
        r.ts = ts
        r.distStr, r.distW = distLabel(best)
        out[#out + 1] = r
        seen[h] = true
    end
    for h in pairs(S.activeBy) do
        if not seen[h] then
            S.activeBy[h] = nil
            S.needFull = true -- a quest ended: re-read the finished list next time
        end
    end
    S.active = out
end

local function readDone(j)
    local out = {}
    for pass = 1, 2 do
        local list = getQuests(j, pass == 1 and F.succ or F.fail)
        for i = 1, #list do
            local q = list[i]
            local h = j:GetEntryHash(q)
            local r = S.doneBy[h]
            if not r or r.failed ~= (pass == 2) then
                r = { hash = h, title = string.upper(GetLocalizedText(q:GetTitle(j)) or ""), cat = C_DONE,
                    failed = pass == 2, ts = stamp(j, q), dist = 0 }
                r.obj = r.failed and S.txtFailed or S.txtDone
                S.doneBy[h] = r
            end
            out[#out + 1] = r
        end
    end
    S.done = out
end

local function recount()
    local q, g = 0, 0
    local a = S.active
    for i = 1, #a do
        local c = a[i].cat
        if c == C_MAIN or c == C_SIDE then q = q + 1 elseif c >= C_GIG and c <= C_COURIER then g = g + 1 end
    end
    local n = S.counts
    n[1], n[2], n[3], n[4] = #a, q, g, #S.done
    for t = 1, 4 do S.countStr[t] = tostring(n[t]) end
end

local function collectDetail(j, entry, depth, acts, fins, descs)
    local kids = j:GetChildren(entry, F.detail)
    if not kids then return end
    local ST = gameJournalEntryState
    for i = 1, #kids do
        local c = kids[i]
        if c:IsA("gameJournalQuestObjective") then
            local st = j:GetEntryState(c)
            if st == ST.Active then
                acts[#acts + 1] = c
            elseif st == ST.Succeeded or st == ST.Failed then
                fins[#fins + 1] = { c, st == ST.Failed }
            end
        elseif c:IsA("gameJournalQuestDescription") then
            descs[#descs + 1] = c
        elseif depth < 4 and c:IsA("gameJournalContainerEntry") then
            collectDetail(j, c, depth + 1, acts, fins, descs)
        end
    end
end

local function readDetails(j)
    S.needDetails = false
    S.det = nil
    local h = S.selected
    if not h then return end
    local q = j:GetEntry(u32(h))
    if not valid(q) then
        S.selected = nil
        return
    end
    local ST = gameJournalEntryState
    local st = j:GetEntryState(q)
    local r = S.activeBy[h] or S.doneBy[h]
    local d = { hash = h, act = {}, fin = {}, desc = nil }
    d.title = r and r.title or string.upper(GetLocalizedText(q:GetTitle(j)) or "")
    d.cat = r and r.cat or category(j, q)
    d.finished = st == ST.Succeeded or st == ST.Failed
    d.target = r and r.target
    local meta = d.finished and (st == ST.Failed and "FAILED" or "COMPLETED") or CAT_LABEL[d.cat]
    local okD, dn = pcall(function()
        local rec = j:GetDistrict(q)
        if rec then return GetLocalizedText(rec:LocalizedName()) end
    end)
    if okD and type(dn) == "string" and dn ~= "" and not dn:find("LocKey", 1, true) then
        meta = meta .. "  |  " .. string.upper(dn)
    end
    local okE, ep1 = pcall(function() return j:IsEp1Entry(q) end)
    if okE and ep1 then meta = meta .. "  |  PHANTOM LIBERTY" end
    d.meta = meta

    local acts, fins, descs = {}, {}, {}
    collectDetail(j, q, 0, acts, fins, descs)
    for k = 1, #acts do
        local o = acts[k]
        local oh = j:GetEntryHash(o)
        local label = objText(j, o, oh)
        local ds = distLabel(j:GetDistanceToNearestMappin(o, F.default))
        if ds then label = label .. "   " .. ds end
        d.act[#d.act + 1] = { hash = oh, label = label }
        if not d.target and not isOptional(j, o, oh) then d.target = oh end
    end
    if not d.target and d.act[1] then d.target = d.act[1].hash end
    for k = 1, #fins do
        local o = fins[k][1]
        d.fin[#d.fin + 1] = { label = baseText(j, o, j:GetEntryHash(o)), failed = fins[k][2] }
    end
    local parts, seen = {}, {}
    for k = 1, #descs do
        local dh = j:GetEntryHash(descs[k])
        local s = textCache[dh]
        if s == nil then
            s = GetLocalizedText(descs[k]:GetDescription()) or ""
            textCache[dh] = s
        end
        if s ~= "" and not seen[s] then
            seen[s] = true
            parts[#parts + 1] = s
        end
    end
    if #parts > 0 then d.desc = table.concat(parts, "\n\n") end
    S.det = d
end

local function refresh(now)
    S.nextRefresh = now + REFRESH
    local player = Game.GetPlayer()
    S.inGame = valid(player)
    if not S.inGame then
        S.active, S.done, S.det = {}, {}, nil
        S.counts[1], S.counts[2], S.counts[3], S.counts[4] = 0, 0, 0, 0
        for t = 1, 4 do S.countStr[t] = "0" end
        S.viewDirty = true
        return
    end
    local j = Game.GetJournalManager()
    if not valid(j) then
        S.inGame = false
        return
    end
    filters()
    if not S.txtDone then
        S.txtDone = GetLocalizedText("LocKey#27564") or "Completed"
        S.txtFailed = GetLocalizedText("LocKey#27566") or "Failed"
        local o = GetLocalizedText("UI-ScriptExports-Optional0")
        S.txtOptional = (o and o ~= "" and o ~= "UI-ScriptExports-Optional0") and o or "Optional"
    end
    local full = S.needFull
    S.needFull = false
    readTracked(j)
    readActive(j, full)
    if full then readDone(j) end
    recount()
    readDetails(j)
    S.viewDirty = true
    S.errMsg = nil
end

-- ---------------------------------------------------------------- tracking

local function sound(name)
    local p = Game.GetPlayer()
    if valid(p) then pcall(function() p:PlaySoundEvent(name) end) end
end

local function ktq()
    local sc = Game.GetScriptableSystemsContainer()
    if not sc then return nil end
    local s = sc:Get(KTQ_SYS)
    if valid(s) then return s end
    return nil
end

local function trackHash(h)
    if not h then return false end
    local j = Game.GetJournalManager()
    local e = j:GetEntry(u32(h))
    if not valid(e) or j:GetEntryState(e) ~= gameJournalEntryState.Active then return false end
    local sys = ktq()
    if sys then sys:BeginPlayerAction() end
    local ok, err = pcall(function() j:TrackEntry(e) end)
    if sys then sys:EndPlayerAction() end
    if not ok then error(err, 0) end
    sound("ui_menu_map_pin_created")
    S.nextRefresh = 0
    return true
end

local function untrack()
    local j = Game.GetJournalManager()
    if not valid(j:GetTrackedEntry()) then return end
    local sys = ktq()
    -- ToggleByKey exists only in a locally patched Keep Tracked Quest; if it is missing or fails, untrack through the journal
    if not (sys and pcall(function() sys:ToggleByKey() end)) then
        j:UntrackEntry()
        sound("ui_menu_map_pin_off")
    end
    S.nextRefresh = 0
end

local function toggleQuest(hash, target)
    if hash == S.trackedQuest then
        untrack()
    else
        trackHash(target)
    end
end

local function selectQuest(h)
    if S.selected == h then return end
    S.selected = h
    S.needDetails = true
end

-- ---------------------------------------------------------------- drawing helpers

local function rowId(i)
    local s = rowIds[i]
    if not s then
        s = "##cqpr" .. i
        rowIds[i] = s
    end
    return s
end

local function cutFill(dl, x1, y1, x2, y2, c, col)
    ImGui.ImDrawListAddRectFilled(dl, x1, y1, x2, y2 - c, col)
    ImGui.ImDrawListAddRectFilled(dl, x1, y2 - c, x2 - c, y2, col)
    ImGui.ImDrawListAddTriangleFilled(dl, x2 - c, y2 - c, x2, y2 - c, x2 - c, y2, col)
end

local function cutLine(dl, x1, y1, x2, y2, c, col, th)
    x1, y1, x2, y2 = x1 + 0.5, y1 + 0.5, x2 - 0.5, y2 - 0.5
    ImGui.ImDrawListAddLine(dl, x1, y1, x2, y1, col, th)
    ImGui.ImDrawListAddLine(dl, x2, y1, x2, y2 - c, col, th)
    ImGui.ImDrawListAddLine(dl, x2, y2 - c, x2 - c, y2, col, th)
    ImGui.ImDrawListAddLine(dl, x2 - c, y2, x1, y2, col, th)
    ImGui.ImDrawListAddLine(dl, x1, y2, x1, y1, col, th)
end

local function bang(dl, cx, cy, R, col)
    local th = R * 0.2
    if th < 1.6 then th = 1.6 end
    ImGui.ImDrawListAddLine(dl, cx, cy - R * 0.52, cx, cy + R * 0.12, col, th)
    ImGui.ImDrawListAddCircleFilled(dl, cx, cy + R * 0.42, th * 0.62, col, 8)
end

local function check(dl, cx, cy, R, col)
    local th = R * 0.18
    if th < 1.6 then th = 1.6 end
    ImGui.ImDrawListAddLine(dl, cx - R * 0.45, cy + R * 0.02, cx - R * 0.12, cy + R * 0.36, col, th)
    ImGui.ImDrawListAddLine(dl, cx - R * 0.12, cy + R * 0.36, cx + R * 0.5, cy - R * 0.36, col, th)
end

local function cross(dl, cx, cy, R, col)
    local a = R * 0.38
    ImGui.ImDrawListAddLine(dl, cx - a, cy - a, cx + a, cy + a, col, 1.8)
    ImGui.ImDrawListAddLine(dl, cx - a, cy + a, cx + a, cy - a, col, 1.8)
end

local function catIcon(dl, cat, failed, cx, cy, R)
    if cat == C_MAIN then
        ImGui.ImDrawListAddCircleFilled(dl, cx, cy, R, K.yellow, 24)
        bang(dl, cx, cy, R, K.ink)
    elseif cat == C_DONE then
        local col = failed and K.redDim or K.red
        ImGui.ImDrawListAddCircle(dl, cx, cy, R, col, 24, 1.8)
        if failed then cross(dl, cx, cy, R, col) else check(dl, cx, cy, R, col) end
    else
        local col = CAT_COL[cat] or K.gray
        ImGui.ImDrawListAddCircle(dl, cx, cy, R, col, 24, 1.8)
        bang(dl, cx, cy, R, col)
    end
end

local function tabIcon(dl, t, cx, cy, R)
    if t == TAB_ALL then
        for k = -1, 1 do
            local y = cy + k * R * 0.6
            ImGui.ImDrawListAddCircleFilled(dl, cx - R * 0.75, y, R * 0.14, K.cyan, 6)
            ImGui.ImDrawListAddLine(dl, cx - R * 0.4, y, cx + R * 0.85, y, K.cyan, 1.6)
        end
    elseif t == TAB_QUESTS then
        ImGui.ImDrawListAddCircleFilled(dl, cx, cy, R, K.yellow, 24)
        bang(dl, cx, cy, R, K.ink)
    elseif t == TAB_GIGS then
        ImGui.ImDrawListAddCircle(dl, cx, cy, R, K.green, 24, 1.8)
        local a, b = R * 0.39, R * 0.14 -- compass needle along the NE-SW diagonal
        ImGui.ImDrawListAddTriangleFilled(dl, cx + a, cy - a, cx + b, cy + b, cx - b, cy - b, K.green)
        ImGui.ImDrawListAddTriangleFilled(dl, cx - a, cy + a, cx - b, cy - b, cx + b, cy + b, K.greenDim)
    else
        ImGui.ImDrawListAddCircle(dl, cx, cy, R, K.red, 24, 1.8)
        check(dl, cx, cy, R, K.red)
    end
end

local function pinIcon(dl, cx, cy, R, col, hole)
    local hr = R * 0.52
    local hy = cy - R * 0.28
    ImGui.ImDrawListAddCircleFilled(dl, cx, hy, hr, col, 16)
    ImGui.ImDrawListAddTriangleFilled(dl, cx - hr * 0.92, hy + hr * 0.4, cx + hr * 0.92, hy + hr * 0.4, cx, cy + R * 0.66, col)
    ImGui.ImDrawListAddCircleFilled(dl, cx, hy, hr * 0.42, hole, 12)
end

local function diamond(dl, cx, cy, s, col, filled)
    if filled then
        ImGui.ImDrawListAddTriangleFilled(dl, cx, cy - s, cx + s, cy, cx - s, cy, col)
        ImGui.ImDrawListAddTriangleFilled(dl, cx - s, cy, cx + s, cy, cx, cy + s, col)
    else
        ImGui.ImDrawListAddLine(dl, cx, cy - s, cx + s, cy, col, 1.5)
        ImGui.ImDrawListAddLine(dl, cx + s, cy, cx, cy + s, col, 1.5)
        ImGui.ImDrawListAddLine(dl, cx, cy + s, cx - s, cy, col, 1.5)
        ImGui.ImDrawListAddLine(dl, cx - s, cy, cx, cy - s, col, 1.5)
    end
end

-- ---------------------------------------------------------------- view (tab + search + sort)

local function inTab(c, tab)
    if tab == TAB_ALL then return c ~= C_DONE end
    if tab == TAB_QUESTS then return c == C_MAIN or c == C_SIDE end
    if tab == TAB_GIGS then return c >= C_GIG and c <= C_COURIER end
    return c == C_DONE
end

local function keyOf(r)
    local k = r.key
    if not k then
        k = string.lower(r.title .. "\n" .. (r.obj or ""))
        r.key = k
    end
    return k
end

local function cmp(a, b)
    if a.cat ~= b.cat then return a.cat < b.cat end
    if cfg.sort == 2 and a.cat ~= C_DONE and a.dist ~= b.dist then
        if a.dist <= 0 then return false end
        if b.dist <= 0 then return true end
        return a.dist < b.dist
    end
    if a.ts ~= b.ts then return a.ts > b.ts end
    if a.title ~= b.title then return a.title < b.title end
    return a.hash < b.hash
end

local function buildView()
    S.viewDirty = false
    local v, tab, needle = {}, cfg.tab, S.searchLower
    local src = tab == TAB_DONE and S.done or S.active
    for i = 1, #src do
        local r = src[i]
        if inTab(r.cat, tab) and (needle == "" or keyOf(r):find(needle, 1, true)) then v[#v + 1] = r end
    end
    table.sort(v, cmp)
    S.view = v
end

-- ---------------------------------------------------------------- window parts

local function drawHeader(dl, lineH, chipH)
    local R = lineH * 0.42
    local widths, total = S.chipW, 0
    for t = 1, 4 do
        widths[t] = chipH + ImGui.CalcTextSize(S.countStr[t]) + 12
        total = total + widths[t] + 6
    end
    for t = 1, 4 do
        local w = widths[t]
        local x, y = ImGui.GetCursorScreenPos()
        if ImGui.InvisibleButton(TAB_ID[t], w, chipH) and cfg.tab ~= t then
            cfg.tab = t
            S.viewDirty = true
            saveCfg()
        end
        local hov = ImGui.IsItemHovered()
        if hov then ImGui.SetTooltip(TAB_TIP[t]) end
        local on = cfg.tab == t
        cutFill(dl, x, y, x + w, y + chipH, 6, on and K.chipBgOn or K.chipBg)
        cutLine(dl, x, y, x + w, y + chipH, 6, on and K.chipLineOn or (hov and K.rowLineHov or K.chipLine), on and 1.5 or 1)
        tabIcon(dl, t, x + chipH * 0.5 + 1, y + chipH * 0.5, R)
        ImGui.ImDrawListAddText(dl, x + chipH + 2, y + (chipH - lineH) * 0.5, TAB_COL[t], S.countStr[t])
        if t < 4 then ImGui.SameLine(0, 6) end
    end
    if not S.sortW then S.sortW = ImGui.CalcTextSize("NEAREST") + 22 end
    local availW = ImGui.GetContentRegionAvail()
    if availW - total >= 200 + S.sortW then
        ImGui.SameLine(0, 10)
        availW = availW - total - 4
    end
    local w = availW - S.sortW - 6
    if w < 80 then w = 80 end
    ImGui.SetNextItemWidth(w)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 8, (chipH - lineH) * 0.5)
    ImGui.PushStyleColor(ImGuiCol.TextDisabled, 0.66, 0.17, 0.15, 1)
    local txt, changed = ImGui.InputTextWithHint("##cqp_search", "SEARCH", S.search, 80)
    ImGui.PopStyleColor(1)
    if changed and type(txt) == "string" and txt ~= S.search then
        S.search = txt
        S.searchLower = string.lower(txt)
        S.viewDirty = true
    end
    ImGui.SameLine(0, 6)
    if ImGui.Button(cfg.sort == 2 and "NEAREST##cqp_sort" or "UPDATED##cqp_sort", S.sortW, chipH) then
        cfg.sort = 3 - cfg.sort
        S.viewDirty = true
        saveCfg()
    end
    ImGui.PopStyleVar(1)
    if ImGui.IsItemHovered() then ImGui.SetTooltip("Sort: last updated first / nearest first") end
end

local function drawRows()
    local view = S.view
    local n = #view
    if n == 0 then
        if not S.inGame then
            ImGui.TextDisabled("Load a save to see your quests.")
        elseif S.search ~= "" then
            ImGui.TextDisabled("No quest matches the search.")
        else
            ImGui.TextDisabled("Nothing here.")
        end
        return
    end
    local dl = ImGui.GetWindowDrawList()
    local lineH = ImGui.GetTextLineHeight()
    local rowH = math.floor(lineH * 2 + 22)
    local pitch = rowH + 6
    local pinW = math.floor(rowH * 0.95)
    local R = lineH * 0.62
    local w = ImGui.GetContentRegionAvail()
    if w < 60 then w = 60 end
    local scrollY = ImGui.GetScrollY()
    local _, winH = ImGui.GetWindowSize()
    local first = math.floor(scrollY / pitch)
    if first < 0 then first = 0 end
    local last = math.floor((scrollY + winH) / pitch)
    if last > n - 1 then last = n - 1 end
    local mx = ImGui.GetMousePos()
    local dbl = ImGui.IsMouseDoubleClicked ~= nil and ImGui.IsMouseDoubleClicked(0)
    local now = os.clock()
    for i = first, last do
        local r = view[i + 1]
        ImGui.SetCursorPosY(i * pitch)
        local x1, y1 = ImGui.GetCursorScreenPos()
        local clicked = ImGui.InvisibleButton(rowId(i), w, rowH)
        local hov = ImGui.IsItemHovered()
        local x2, y2 = x1 + w, y1 + rowH
        local live = r.cat ~= C_DONE
        local tracked = live and r.hash == S.trackedQuest
        local onPin = live and hov and mx >= x2 - pinW
        if clicked then
            if onPin then
                if now - S.lastToggle > 0.3 then
                    S.lastToggle = now
                    toggleQuest(r.hash, r.target)
                end
            else
                -- select after the double-click time, so a double-click (track) never re-lays out the window
                S.pendingSel, S.pendingAt = r.hash, now + 0.3
            end
        elseif hov and dbl and live and not onPin then
            S.pendingSel = nil
            if not tracked then trackHash(r.target) end
        end
        if onPin then ImGui.SetTooltip(tracked and "Untrack" or "Track") end

        local bg = tracked and K.trBg or (hov and K.rowBgHov or K.rowBg)
        cutFill(dl, x1, y1, x2, y2, CUT, bg)
        cutLine(dl, x1, y1, x2, y2, CUT, tracked and K.trLine or (hov and K.rowLineHov or K.rowLine), tracked and 1.5 or 1)
        if r.hash == S.selected and not tracked then cutLine(dl, x1 + 2, y1 + 2, x2 - 2, y2 - 2, CUT - 1, K.sel, 1) end
        catIcon(dl, r.cat, r.failed, x1 + 28, y1 + rowH * 0.5, R)

        local right = x2 - 14
        if tracked then
            local bx = x2 - pinW
            cutFill(dl, bx, y1 + 1, x2 - 1, y2 - 1, CUT - 1, K.yellow)
            pinIcon(dl, bx + pinW * 0.5, y1 + rowH * 0.5, R * 1.25, K.pinDark, K.yellow)
            right = bx - 12
        elseif live and hov then
            local bx = x2 - pinW
            cutLine(dl, bx, y1 + 4, x2 - 4, y2 - 4, CUT - 3, onPin and K.yellow or K.yellowDim, 1)
            pinIcon(dl, bx + (pinW - 4) * 0.5, y1 + rowH * 0.5, R * 1.25, onPin and K.yellow or K.yellowDim, bg)
            right = bx - 12
        end
        if r.distStr and not tracked then
            ImGui.ImDrawListAddText(dl, right - r.distW, y1 + (rowH - lineH) * 0.5, K.dist, r.distStr)
            right = right - r.distW - 14
        end
        local tx = x1 + 56
        local ty = y1 + (rowH - lineH * (1 + TITLE_SCALE) - 4) * 0.5
        ImGui.PushClipRect(tx, y1, right, y2, true)
        ImGui.SetWindowFontScale(TITLE_SCALE)
        ImGui.ImDrawListAddText(dl, tx, ty, hov and K.titleHov or K.title, r.title)
        ImGui.SetWindowFontScale(1)
        if r.obj and r.obj ~= "" then
            ImGui.ImDrawListAddText(dl, tx, ty + lineH * TITLE_SCALE + 4, hov and K.objHov or K.obj, r.obj)
        end
        ImGui.PopClipRect()
    end
    ImGui.SetCursorPosY(n * pitch)
    ImGui.Dummy(1, 1)
end

local function drawDetails()
    local d = S.det
    if not d then
        if S.selected then
            ImGui.TextDisabled("Reading the journal...")
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.47, 0.44, 1)
            ImGui.TextWrapped("Click a quest for its objectives and description. Pin box or double-click: track / untrack.")
            ImGui.PopStyleColor(1)
        end
        return
    end
    local dl = ImGui.GetWindowDrawList()
    local lineH = ImGui.GetTextLineHeight()
    ImGui.SetWindowFontScale(1.15)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.37, 0.96, 1, 1)
    ImGui.TextWrapped(d.title)
    ImGui.PopStyleColor(1)
    ImGui.SetWindowFontScale(1)
    ImGui.TextColored(0.86, 0.72, 0.25, 1, d.meta)
    ImGui.Spacing()

    local tracked = d.hash == S.trackedQuest
    if not d.finished then
        if tracked then
            ImGui.PushStyleColor(ImGuiCol.Button, 0.98, 0.83, 0.12, 1)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 1, 0.9, 0.35, 1)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.85, 0.7, 0.1, 1)
            ImGui.PushStyleColor(ImGuiCol.Text, 0.1, 0.06, 0.02, 1)
            local clicked = ImGui.Button("UNTRACK##cqp_dt")
            ImGui.PopStyleColor(4)
            if clicked then untrack() end
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 0.37, 0.96, 1, 1)
            local clicked = ImGui.Button("TRACK QUEST##cqp_dt")
            ImGui.PopStyleColor(1)
            if clicked then trackHash(d.target) end
        end
        ImGui.SameLine(0, 6)
    end
    if ImGui.Button("CLOSE##cqp_dc") then
        S.selected, S.det = nil, nil
        return
    end
    ImGui.Spacing()

    if #d.act > 0 then
        ImGui.TextColored(1, 0.33, 0.3, 1, "OBJECTIVES")
        local hoverNew = 0
        for k = 1, #d.act do
            local o = d.act[k]
            local x, y = ImGui.GetCursorScreenPos()
            local isTr = o.hash == S.trackedObj
            local hov = o.hash == S.hoverObj
            diamond(dl, x + 8, y + lineH * 0.5, lineH * 0.28, isTr and K.yellow or (hov and K.cyan or K.cyanDim), isTr)
            ImGui.Indent(22)
            if isTr then
                ImGui.PushStyleColor(ImGuiCol.Text, 0.98, 0.83, 0.12, 1)
            elseif hov then
                ImGui.PushStyleColor(ImGuiCol.Text, 0.97, 0.96, 0.93, 1)
            else
                ImGui.PushStyleColor(ImGuiCol.Text, 0.77, 0.75, 0.71, 1)
            end
            ImGui.TextWrapped(o.label)
            ImGui.PopStyleColor(1)
            ImGui.Unindent(22)
            if not d.finished and ImGui.IsItemHovered() then
                hoverNew = o.hash
                ImGui.SetTooltip(isTr and "Tracked" or "Click: track this objective")
                if not isTr and ImGui.IsItemClicked(0) then trackHash(o.hash) end
            end
        end
        S.hoverObj = hoverNew
        ImGui.Spacing()
    end

    if #d.fin > 0 then
        ImGui.TextColored(0.6, 0.55, 0.5, 1, "DONE")
        for k = 1, #d.fin do
            local o = d.fin[k]
            local x, y = ImGui.GetCursorScreenPos()
            if o.failed then
                cross(dl, x + 8, y + lineH * 0.5, lineH * 0.55, K.redDim)
            else
                check(dl, x + 8, y + lineH * 0.5, lineH * 0.55, K.gray)
            end
            ImGui.Indent(22)
            ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.47, 0.44, 1)
            ImGui.TextWrapped(o.label)
            ImGui.PopStyleColor(1)
            ImGui.Unindent(22)
        end
        ImGui.Spacing()
    end

    if d.desc then
        ImGui.TextColored(1, 0.33, 0.3, 1, "DESCRIPTION")
        ImGui.PushStyleColor(ImGuiCol.Text, 0.72, 0.7, 0.66, 1)
        ImGui.TextWrapped(d.desc)
        ImGui.PopStyleColor(1)
    end
end

local function reportError(where, err)
    local msg = tostring(err)
    S.errMsg = "Quest Picker " .. where .. ": " .. msg
    if S.lastErr ~= msg then
        S.lastErr = msg
        logLine(where .. " error: " .. msg)
    end
end

local function listChild(w, h)
    if ImGui.BeginChild("##cqp_list", w, h, false) then
        local ok, err = pcall(drawRows)
        if not ok then reportError("list", err) end
    end
    ImGui.EndChild()
end

local function detailsChild(w, h)
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.07, 0.05, 0.045, 0.9)
    if ImGui.BeginChild("##cqp_det", w, h, true) then
        local ok, err = pcall(drawDetails)
        if not ok then reportError("details", err) end
    end
    ImGui.EndChild()
    ImGui.PopStyleColor(1)
end

local function drawBody()
    local dl = ImGui.GetWindowDrawList()
    local lineH = ImGui.GetTextLineHeight()
    local chipH = math.floor(lineH + 14)
    drawHeader(dl, lineH, chipH)
    if S.errMsg then ImGui.TextColored(1, 0.35, 0.3, 1, S.errMsg) end
    if S.viewDirty then buildView() end
    ImGui.Spacing()
    local availW, availH = ImGui.GetContentRegionAvail()
    if availW >= WIDE then -- wide: details pane always there, so the list never changes width under the mouse
        local lw = math.floor(availW * 0.5)
        listChild(lw, availH)
        ImGui.SameLine(0, 10)
        detailsChild(0, availH)
    elseif S.selected then
        local dh = math.floor(availH * 0.45)
        listChild(0, availH - dh - 8)
        detailsChild(0, dh)
    else
        listChild(0, availH - lineH - 6)
        ImGui.TextDisabled("Click a quest for its objectives. Pin box or double-click: track / untrack.")
    end
end

local function pushPalette()
    if not palFlat then
        palFlat = {}
        for _, e in ipairs(PAL) do
            local idx = ImGuiCol[e[1]]
            if idx then
                palFlat[#palFlat + 1] = idx
                palFlat[#palFlat + 1] = e[2] / 255
                palFlat[#palFlat + 1] = e[3] / 255
                palFlat[#palFlat + 1] = e[4] / 255
                palFlat[#palFlat + 1] = e[5]
            end
        end
    end
    for i = 1, #palFlat, 5 do
        ImGui.PushStyleColor(palFlat[i], palFlat[i + 1], palFlat[i + 2], palFlat[i + 3], palFlat[i + 4])
    end
    ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 12, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 6, 6)
    return #palFlat / 5, 3
end

-- ---------------------------------------------------------------- events

registerForEvent("onInit", function()
    local ok, err = pcall(loadCfg)
    if not ok then logLine("config not read: " .. tostring(err)) end
    logLine("loaded " .. VERSION)
end)

registerForEvent("onOverlayOpen", function()
    S.overlay = true
    S.needFull = true
    S.nextRefresh = 0
end)

registerForEvent("onOverlayClose", function()
    S.overlay = false
end)

registerForEvent("onDraw", function()
    if not S.overlay then return end
    local now = os.clock()
    if S.pendingSel and now >= S.pendingAt then
        selectQuest(S.pendingSel)
        S.pendingSel = nil
    end
    if not S.shown then
        -- collapsed (or parked by CET Decluttered): no journal reads until it is open again
    elseif now >= S.nextRefresh then
        local ok, err = pcall(refresh, now)
        if not ok then
            reportError("refresh", err)
            S.nextRefresh = now + 5
        end
    elseif S.needDetails then
        local ok, err = pcall(function()
            filters()
            readDetails(Game.GetJournalManager())
        end)
        if not ok then
            S.needDetails = false
            reportError("details", err)
        end
    end
    local nCol, nVar = pushPalette()
    ImGui.SetNextWindowSize(580, 720, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSizeConstraints(360, 280, 6000, 4000)
    local shown = ImGui.Begin("Quest Picker##CyberslopQuestPicker", ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoScrollWithMouse)
    if shown and not S.shown then S.nextRefresh = 0 end -- just expanded: read the journal next frame
    S.shown = shown and true or false
    if shown then
        local ok, err = pcall(drawBody)
        if not ok then reportError("draw", err) end
    end
    ImGui.End()
    ImGui.PopStyleVar(nVar)
    ImGui.PopStyleColor(nCol)
end)
