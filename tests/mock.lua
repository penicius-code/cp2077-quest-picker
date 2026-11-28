-- Mock test for Cyberslop Quest Picker 1.1.0 (run: luajit mock.lua <path to init.lua>, cwd = a temp dir)
local MOD = arg[1] or "mod/init.lua"

local pass, fail = 0, 0
local function ok(cond, name)
    if cond then pass = pass + 1 else fail = fail + 1; io.stdout:write("FAIL: " .. name .. "\n") end
end

-- ------------------------------------------------------------ CET globals
local handlers = {}
function registerForEvent(name, fn) handlers[name] = fn end
local logs = {}
spdlog = { info = function(s) logs[#logs + 1] = s end }
function print(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end logs[#logs + 1] = table.concat(t, " ") end
function IsDefined(x) return x ~= nil end
function GetLocalizedText(s)
    if s == "LocKey#27564" then return "Quest completed" end
    if s == "LocKey#27566" then return "Quest failed" end
    if s == "UI-ScriptExports-Optional0" then return "Optional" end
    return s
end
json = {
    encode = function(t)
        local parts = {}
        for k, v in pairs(t) do parts[#parts + 1] = string.format("%q:%s", k, tostring(v)) end
        table.sort(parts)
        return "{" .. table.concat(parts, ",") .. "}"
    end,
    decode = function(s)
        local t = {}
        for k, v in s:gmatch('"(%w+)":(%-?%d+)') do t[k] = tonumber(v) end
        return t
    end,
}
local NOW = 100
os.clock = function() return NOW end

local seq = 0
local function enumTable() return setmetatable({}, { __index = function(t, k) seq = seq + 1; rawset(t, k, seq); return seq end }) end
ImGuiCol = enumTable()
ImGuiStyleVar = enumTable()
ImGuiCond = { FirstUseEver = 4, Always = 1 }
ImGuiWindowFlags = { NoScrollbar = 8, NoScrollWithMouse = 16 }

gameJournalQuestType = { MainQuest = "MainQuest", SideQuest = "SideQuest", MinorQuest = "MinorQuest",
    StreetStory = "StreetStory", CyberPsycho = "CyberPsycho", Contract = "Contract", VehicleQuest = "VehicleQuest",
    ApartmentQuest = "ApartmentQuest", CourierQuest = "CourierQuest", CourierSideQuest = "CourierSideQuest" }
gameJournalEntryState = { Undefined = "Undefined", Inactive = "Inactive", Active = "Active", Succeeded = "Succeeded", Failed = "Failed" }

JournalRequestStateFilter = { new = function(t)
    t = t or {}
    return { active = t.active or false, inactive = t.inactive or false, succeeded = t.succeeded or false, failed = t.failed or false }
end }
JournalRequestContext = { new = function() return { stateFilter = JournalRequestStateFilter.new() } end }

-- ------------------------------------------------------------ fake journal
local CHAIN = {
    gameJournalQuest = { gameJournalQuest = 1, gameJournalFileEntry = 1, gameJournalContainerEntry = 1, gameJournalEntry = 1 },
    gameJournalQuestPhase = { gameJournalQuestPhase = 1, gameJournalContainerEntry = 1, gameJournalEntry = 1 },
    gameJournalQuestObjective = { gameJournalQuestObjective = 1, gameJournalQuestObjectiveBase = 1, gameJournalContainerEntry = 1, gameJournalEntry = 1 },
    gameJournalQuestDescription = { gameJournalQuestDescription = 1, gameJournalEntry = 1 },
}
local EntryMT = { __index = {
    IsA = function(self, name) return CHAIN[self.class][name] ~= nil end,
    GetTitle = function(self, j) assert(j, "GetTitle needs the journal"); return self.title end,
    GetDescription = function(self) return self.desc end,
    GetType = function(self) return self.qtype end,
} }
local byHash, top = {}, {}
local function u(h) if h < 0 then return h + 4294967296 end return h end
local function E(class, hash, parent, p)
    local e = setmetatable({ class = class, hash = hash, parent = parent, children = {}, state = "Active" }, EntryMT)
    for k, v in pairs(p or {}) do e[k] = v end
    if parent then table.insert(parent.children, e) else table.insert(top, e) end
    byHash[u(hash)] = e
    return e
end
local function quest(hash, title, qtype, ts, state) return E("gameJournalQuest", hash, nil, { title = title, qtype = qtype, ts = ts, state = state }) end
local function phase(hash, q, state) return E("gameJournalQuestPhase", hash, q, { state = state }) end
local function obj(hash, ph, desc, p) p = p or {}; p.desc = desc; return E("gameJournalQuestObjective", hash, ph, p) end

local Q1 = quest(101, "Light Candle for Johnny", "MainQuest", 500); local P1 = phase(1011, Q1)
obj(10111, P1, "Buy or find a candle", { ts = 510 })
local P1b = phase(1012, Q1, "Inactive"); obj(10121, P1b, "hidden objective")
local Q2 = quest(102, "Nocturne OP55N1", "MainQuest", 400); local P2 = phase(1021, Q2)
local O2 = obj(10211, P2, "Meet Hanako at Embers", { dist = 857 })
local Q3 = quest(103, "NC Courier Jobs", "CourierSideQuest", 300); local P3 = phase(1031, Q3)
obj(10311, P3, "Reach the current courier objective", { dist = 1100 })
local Q4 = quest(-12345, "Bad Company", "SideQuest", 350); local P4 = phase(-123451, Q4)
local O4a = obj(-1234511, P4, "Optional thing", { optional = true, dist = 50 })
local O4b = obj(-1234512, P4, "Return to your apartment", { dist = 1500 })
obj(-1234513, P4, "Talked to someone", { state = "Succeeded" })
E("gameJournalQuestDescription", -1234519, P4, { desc = "V has to go home." })
local Q5 = quest(105, "Spread the Word", "StreetStory", 200); obj(10511, phase(1051, Q5), "Perform a gig", { dist = 1120 })
local Q6 = quest(106, "Khooneye Ma", "SideQuest", 100); obj(10611, phase(1061, Q6), "Find all the meditation locations", { cur = 5, total = 40 })
local Q7 = quest(107, "Other Thing", "VehicleQuest", 50); obj(10711, phase(1071, Q7), "Drive")
local Q8 = quest(108, "Psycho Hunt", "CyberPsycho", 40); obj(10811, phase(1081, Q8), "Find the psycho")
local Q9 = quest(109, "Scanner Hustle", "Contract", 30); obj(10911, phase(1091, Q9), "Clear the area")
quest(201, "The Rescue", "MainQuest", 900, "Succeeded")
quest(202, "Lost Cause", "SideQuest", 950, "Failed")

local CALLS = {}
local STATEKEY = { Active = "active", Inactive = "inactive", Succeeded = "succeeded", Failed = "failed" }
local J = { tracked = O4b, failQuests = false }
function J:GetQuests(ctx)
    self.reads = (self.reads or 0) + 1
    if self.failQuests then error("journal exploded") end
    local f, out = ctx.stateFilter, {}
    for _, q in ipairs(top) do if f[STATEKEY[q.state]] then out[#out + 1] = q end end
    return out
end
function J:GetChildren(e, f)
    local out = {}
    for _, c in ipairs(e.children) do if f[STATEKEY[c.state]] then out[#out + 1] = c end end
    return out
end
function J:GetEntryHash(e) return e.hash end
function J:GetEntry(h) assert(h >= 0, "GetEntry got a negative hash"); return byHash[h] end
function J:GetEntryState(e) return e.state end
function J:GetQuestType(q) return q.qtype end
function J:GetTrackedEntry() return self.tracked end
function J:TrackEntry(e) CALLS[#CALLS + 1] = "track:" .. e.hash; self.tracked = e end
function J:UntrackEntry() CALLS[#CALLS + 1] = "untrack"; self.tracked = nil end
function J:GetParentEntry(e) return e.parent end
function J:GetObjectiveCurrentCounter(o) return o.cur or 0 end
function J:GetObjectiveTotalCounter(o) return o.total or 0 end
function J:GetIsObjectiveOptional(o) return o.optional or false end
function J:GetDistanceToNearestMappin(o, f) assert(f and f.active and f.inactive, "distance filter"); return o.dist or 0 end
function J:GetEntryTimestamp(e) return { seconds = e.ts or 0 } end
function J:GetDistrict(q) return nil end
function J:IsEp1Entry(q) return false end

local KTQ = {}
function KTQ:BeginPlayerAction() CALLS[#CALLS + 1] = "begin" end
function KTQ:EndPlayerAction() CALLS[#CALLS + 1] = "end" end
function KTQ:ToggleByKey() CALLS[#CALLS + 1] = "toggle"; J.tracked = nil; return true end
local ktqPresent = true
-- time skip state (1.1.0)
local TSM = { days = 3, h = 21, m = 4, can = true, ints = { Combat = 0, Swimming = 0, Vehicle = 0, HighLevel = 0 },
    bools = {}, tags = {}, speed = 0, zone = 1, phone = false, chase = false, hw = false, auto = false,
    dil = false, failCan = false }
local PSM = {
    GetInt = function(self, k) return TSM.ints[k] or 0 end,
    GetBool = function(self, k) return TSM.bools[k] or false end,
    GetVariant = function(self, k) return { securityAreaType = TSM.zone } end,
}
function GetAllBlackboardDefs() return { PlayerStateMachine = setmetatable({}, { __index = function(t, k) return k end }) } end
function FromVariant(v) return v end
function EnumInt(e) return e end
StatusEffectSystem = { ObjectHasStatusEffectWithTag = function(p, tag) return TSM.tags[tag] or false end }
HubMenuUtility = { IsPlayerHardwareDisabled = function(p) return TSM.hw end }
GameTimeUtils = { CanPlayerTimeSkip = function(p)
    if TSM.failCan then error("no such function") end
    return TSM.can
end }
local PLAYER = { PlaySoundEvent = function(self, n) CALLS[#CALLS + 1] = "sound:" .. n end,
    GetPlayerStateMachineBlackboard = function() return PSM end,
    IsMovingVertically = function() return false end,
    GetMountedVehicle = function() return { GetCurrentSpeed = function() return TSM.speed end } end,
    GetPreventionSystem = function() return { IsChasingPlayer = function() return TSM.chase end } end,
}
local inGame = true
Game = {
    GetJournalManager = function() return J end,
    GetPlayer = function() return inGame and PLAYER or nil end,
    GetTimeSystem = function() return {
        GetGameTime = function() return { Days = function() return TSM.days end, Hours = function() return TSM.h end,
            Minutes = function() return TSM.m end } end,
        IsTimeDilationActive = function(self, r) assert(r == nil, "dilation reason"); return TSM.dil end,
    } end,
    GetPhoneManager = function() return { IsPhoneCallActive = function() return TSM.phone end } end,
    GetScriptableSystemsContainer = function() return { Get = function(self, name)
        if name == "AutoDriveSystem" then return { GetAutodriveEnabled = function() return TSM.auto end } end
        assert(name == "KeepTrackedQuest.KeepTrackedQuestSystem", "KTQ name")
        return ktqPresent and KTQ or nil
    end } end,
}

-- ------------------------------------------------------------ ImGui stub
local quiet = false
local imCalls = 0
local F = {}          -- frame record
local IN = { click = nil, hover = nil, clickText = nil, dbl = false, mx = 0, input = nil, availW = 560, availH = 640 }
local bal
local function resetFrame()
    F = { texts = {}, wrapped = {}, disabled = {}, colored = {}, buttons = {}, rows = {} }
    bal = { col = 0, var = 0, win = 0, child = 0, clip = 0, indent = 0, scale = 1 }
end
resetFrame()
local cursorY, lastItem = 0, nil
local DL = {}
local Im = {}
function Im.GetTextLineHeight() return 18 end
function Im.CalcTextSize(s) return #s * 8, 18 end
function Im.GetContentRegionAvail() return IN.availW, IN.availH end
function Im.GetWindowSize() return IN.availW, 600 end
function Im.GetScrollY() return 0 end
function Im.GetMousePos() return IN.mx, 0 end
function Im.IsMouseDoubleClicked(b) return IN.dbl end
function Im.GetWindowDrawList() return DL end
function Im.SetCursorPosY(y) cursorY = y end
function Im.GetCursorScreenPos() return 100, 100 + cursorY end
function Im.InvisibleButton(id, w, h)
    assert(w >= 1 and h >= 1, "zero-size InvisibleButton")
    lastItem = id
    if not quiet and id:sub(1, 6) == "##cqpr" then F.rows[#F.rows + 1] = { id = id, x1 = 100, x2 = 100 + w } end
    return IN.click == id
end
function Im.IsItemHovered() return IN.hover ~= nil and IN.hover == lastItem end
function Im.IsItemClicked(b) return IN.clickText ~= nil and IN.clickText == lastItem end
function Im.Button(label) lastItem = label; if not quiet then F.buttons[#F.buttons + 1] = label end; return IN.click == label end
function Im.InputTextWithHint(id, hint, text, n) lastItem = id; if IN.input then local t = IN.input; IN.input = nil; return t, true end; return text, false end
function Im.TextWrapped(s) lastItem = s; if not quiet then F.wrapped[#F.wrapped + 1] = s end end
function Im.TextDisabled(s) lastItem = s; if not quiet then F.disabled[#F.disabled + 1] = s end end
function Im.TextColored(r, g, b, a, s) lastItem = s; if not quiet then F.colored[#F.colored + 1] = s end end
function Im.ImDrawListAddText(dl, x, y, col, s) assert(type(s) == "string", "AddText string"); if not quiet then F.texts[#F.texts + 1] = s end end
function Im.PushStyleColor(i, r, g, b, a) assert(type(i) == "number" and type(a) == "number", "PushStyleColor args"); bal.col = bal.col + 1 end
function Im.PopStyleColor(n) bal.col = bal.col - (n or 1) end
function Im.PushStyleVar(i, x, y) bal.var = bal.var + 1 end
function Im.PopStyleVar(n) bal.var = bal.var - (n or 1) end
function Im.Begin(name, flags) bal.win = bal.win + 1; return not IN.collapsed end
function Im.End() bal.win = bal.win - 1 end
function Im.BeginChild(id, w, h, border) bal.child = bal.child + 1; return true end
function Im.EndChild() bal.child = bal.child - 1 end
function Im.PushClipRect() bal.clip = bal.clip + 1 end
function Im.PopClipRect() bal.clip = bal.clip - 1 end
function Im.SetWindowFontScale(s) bal.scale = s end
function Im.Indent(w) bal.indent = bal.indent + w end
function Im.Unindent(w) bal.indent = bal.indent - w end
ImGui = setmetatable({}, { __index = function(t, k)
    local f = Im[k] or function() end
    local w = function(...) imCalls = imCalls + 1; return f(...) end
    rawset(t, k, w)
    return w
end })

-- ------------------------------------------------------------ helpers
local cwdCfg = "config.json"
os.remove(cwdCfg)
assert(loadfile(MOD))()
handlers.onInit()

local function frame(inputs)
    resetFrame()
    for k, v in pairs(inputs or {}) do IN[k] = v end
    handlers.onDraw()
    IN.click, IN.hover, IN.clickText, IN.dbl, IN.mx = nil, nil, nil, false, 0
    local b = bal
    ok(b.col == 0 and b.var == 0 and b.win == 0 and b.child == 0 and b.clip == 0 and b.indent == 0 and b.scale == 1,
        string.format("balance col=%d var=%d win=%d child=%d clip=%d indent=%d scale=%s", b.col, b.var, b.win, b.child, b.clip, b.indent, tostring(b.scale)))
    return F
end
local function has(list, s) for _, v in ipairs(list) do if v == s then return true end end return false end
local function idx(list, s) for i, v in ipairs(list) do if v == s then return i end end return nil end
local function titlesInOrder(texts, names)
    local last = 0
    for _, n in ipairs(names) do
        local i = idx(texts, n)
        if not i or i <= last then return false, n end
        last = i
    end
    return true
end
local function callsStr() return table.concat(CALLS, ",") end
local function clearCalls() for i = #CALLS, 1, -1 do CALLS[i] = nil end end
local function errs() local n = 0 for _, l in ipairs(logs) do if l:find("error") then n = n + 1 end end return n end

-- ------------------------------------------------------------ tests
-- T1 overlay closed: nothing at all
imCalls = 0
handlers.onDraw()
ok(imCalls == 0, "T1 closed overlay makes no ImGui calls")

-- T2 open: counts, order, texts
handlers.onOverlayOpen()
local f = frame()
ok(has(f.texts, "9") and has(f.texts, "5") and has(f.texts, "3") and has(f.texts, "2"), "T2 tab counts 9/5/3/2")
local good, miss = titlesInOrder(f.texts, { "LIGHT CANDLE FOR JOHNNY", "NOCTURNE OP55N1", "BAD COMPANY", "NC COURIER JOBS",
    "KHOONEYE MA", "SPREAD THE WORD", "PSYCHO HUNT", "SCANNER HUSTLE", "OTHER THING" })
ok(good, "T2 order type then last update (missing/out of order: " .. tostring(miss) .. ")")
ok(has(f.texts, "Find all the meditation locations [5/40]"), "T2 counter text")
ok(has(f.texts, "Optional thing [Optional]"), "T2 first objective with Optional tag")
ok(has(f.texts, "857M") and has(f.texts, "1.1KM"), "T2 distance labels")
ok(not has(f.texts, "50M"), "T2 tracked row shows the pin box, no distance")
ok(not has(f.texts, "hidden objective"), "T2 inactive phase skipped")
ok(not has(f.texts, "THE RESCUE"), "T2 done quests not in All")
ok(#f.rows == 9, "T2 9 rows drawn (" .. #f.rows .. ")")
ok(errs() == 0, "T2 no errors logged")

-- row geometry for pin clicks
local row1 = f.rows[2] -- Nocturne (index 1)
local pinX = row1.x2 - 5
local midX = row1.x1 + 100

-- T3 pin click on Nocturne: KTQ begin, track, end
clearCalls()
frame({ click = "##cqpr1", hover = "##cqpr1", mx = pinX })
ok(callsStr():find("^begin,track:10211,end,sound:ui_menu_map_pin_created") ~= nil, "T3 pin click tracks via KTQ (" .. callsStr() .. ")")
f = frame()
ok(not has(f.texts, "857M"), "T3 Nocturne now tracked (pin box replaces distance)")
-- Bad Company is no longer tracked, so its distance (nearest pin 50 m) shows
ok(has(f.texts, "50M"), "T3b Bad Company shows its distance again")

-- T4 pin click on tracked Nocturne: untrack via ToggleByKey; debounce
clearCalls()
frame({ click = "##cqpr1", hover = "##cqpr1", mx = pinX })
ok(callsStr() == "", "T4a second pin click inside 0.3 s ignored (" .. callsStr() .. ")")
NOW = NOW + 1
frame({ click = "##cqpr1", hover = "##cqpr1", mx = pinX })
ok(callsStr() == "toggle", "T4 untrack through ToggleByKey (" .. callsStr() .. ")")
ok(J.tracked == nil, "T4 nothing tracked")
f = frame()

-- T5 double-click on Bad Company (index 2) away from the pin: tracks the first NON-optional objective
clearCalls()
frame({ hover = "##cqpr2", dbl = true, mx = midX })
ok(callsStr():find("begin,track:%-1234512,end") ~= nil, "T5 double-click tracks non-optional objective (" .. callsStr() .. ")")

-- T5b click then double-click (the real sequence): tracks, never opens the details
NOW = NOW + 1
frame()
clearCalls()
frame({ click = "##cqpr0", hover = "##cqpr0", mx = midX })
frame({ hover = "##cqpr0", dbl = true, mx = midX })
ok(callsStr():find("begin,track:10111,end") ~= nil, "T5b click + double-click tracks (" .. callsStr() .. ")")
NOW = NOW + 0.5
f = frame()
ok(not has(f.wrapped, "LIGHT CANDLE FOR JOHNNY"), "T5b double-click does not open the details")
NOW = NOW + 1
frame()
frame({ hover = "##cqpr2", dbl = true, mx = midX }) -- Bad Company tracked again for T6
NOW = NOW + 1
frame()

-- T6 select Bad Company -> details; click an objective
NOW = NOW + 2
frame({ click = "##cqpr2", hover = "##cqpr2", mx = midX })
f = frame()
ok(not has(f.wrapped, "BAD COMPANY"), "T6 selection waits for the double-click time")
NOW = NOW + 0.4
f = frame()
ok(has(f.wrapped, "BAD COMPANY"), "T6 details title")
ok(has(f.colored, "SIDE JOB"), "T6 details meta")
ok(has(f.wrapped, "Optional thing [Optional]   50M") and has(f.wrapped, "Return to your apartment   1.5KM"), "T6 active objectives with distance")
ok(has(f.wrapped, "Talked to someone"), "T6 done objective")
ok(has(f.wrapped, "V has to go home."), "T6 description")
ok(has(f.buttons, "UNTRACK##cqp_dt"), "T6 tracked quest shows UNTRACK")
clearCalls()
frame({ clickText = "Optional thing [Optional]   50M", hover = "Optional thing [Optional]   50M" })
ok(callsStr():find("begin,track:%-1234511,end") ~= nil, "T6 clicking an objective tracks it (" .. callsStr() .. ")")
clearCalls()
frame({ click = "UNTRACK##cqp_dt" })
ok(callsStr() == "toggle", "T6 details UNTRACK (" .. callsStr() .. ")")
f = frame()
ok(has(f.buttons, "TRACK QUEST##cqp_dt"), "T6 shows TRACK QUEST after untrack")
clearCalls()
frame({ click = "TRACK QUEST##cqp_dt" })
ok(callsStr():find("begin,track:%-1234512,end") ~= nil, "T6 TRACK QUEST tracks the non-optional objective (" .. callsStr() .. ")")
frame({ click = "CLOSE##cqp_dc" })
f = frame()
ok(not has(f.wrapped, "BAD COMPANY"), "T6 CLOSE hides details")

-- T7 Done tab
frame({ click = "##cqp_t4" })
f = frame()
good = titlesInOrder(f.texts, { "LOST CAUSE", "THE RESCUE" })
ok(good, "T7 done tab, newest first")
ok(has(f.texts, "Quest failed") and has(f.texts, "Quest completed"), "T7 done row texts")
ok(not has(f.texts, "BAD COMPANY"), "T7 active quests not in Done")
local cfgText = io.open(cwdCfg, "r"):read("*a")
ok(cfgText:find('"tab":4') ~= nil, "T7 tab saved to config.json (" .. cfgText .. ")")
clearCalls()
NOW = NOW + 1
local dr = f.rows[1]
frame({ click = "##cqpr0", hover = "##cqpr0", mx = dr.x2 - 5 })
ok(not callsStr():find("track"), "T7 pin area on a done row does not track")
frame({ hover = "##cqpr0", dbl = true, mx = dr.x1 + 50 })
ok(not callsStr():find("track"), "T7 double-click on a done row does not track")
NOW = NOW + 0.4
f = frame()
ok(has(f.wrapped, "LOST CAUSE") and not has(f.buttons, "TRACK QUEST##cqp_dt"), "T7 done quest details, no track button")
frame({ click = "CLOSE##cqp_dc" })

-- T8 Gigs tab + search
frame({ click = "##cqp_t3" })
f = frame()
ok(has(f.texts, "SPREAD THE WORD") and has(f.texts, "PSYCHO HUNT") and has(f.texts, "SCANNER HUSTLE") and not has(f.texts, "OTHER THING"), "T8 gigs tab")
frame({ click = "##cqp_t1" })
frame({ input = "SPREAD" })
f = frame()
ok(has(f.texts, "SPREAD THE WORD") and #f.rows == 1, "T8 search filters (case-insensitive), rows=" .. #f.rows)
frame({ input = "apartment" })
f = frame()
ok(has(f.texts, "BAD COMPANY") == false, "T8 search on first objective only (Bad Company's first objective is the optional one)")
frame({ input = "zzzz" })
f = frame()
ok(has(f.disabled, "No quest matches the search."), "T8 empty search result message")
frame({ input = "" })

-- T9 sort nearest
frame({ click = "UPDATED##cqp_sort" })
f = frame()
good, miss = titlesInOrder(f.texts, { "NOCTURNE OP55N1", "LIGHT CANDLE FOR JOHNNY", "NC COURIER JOBS", "KHOONEYE MA" })
ok(good, "T9 nearest first within a category, no pin last (" .. tostring(miss) .. ")")
ok(has(f.buttons, "NEAREST##cqp_sort"), "T9 sort button label")
frame({ click = "NEAREST##cqp_sort" })

-- T10 periodic refresh picks up a new objective text, a finished quest moves to Done
Q9.state = "Succeeded"
NOW = NOW + 2
f = frame()
ok(not has(f.texts, "SCANNER HUSTLE"), "T10 finished quest leaves the active list")
NOW = NOW + 2
frame()
frame({ click = "##cqp_t4" })
f = frame()
ok(has(f.texts, "SCANNER HUSTLE"), "T10 finished quest shows in Done after the re-read")
frame({ click = "##cqp_t1" })

-- T11 KTQ missing: direct journal calls
ktqPresent = false
clearCalls()
NOW = NOW + 1
f = frame()
local bi = nil
for i, r in ipairs(f.rows) do if r.id == "##cqpr1" then bi = r end end
frame({ hover = "##cqpr1", dbl = true, mx = bi.x1 + 50 })
ok(callsStr():find("^track:10211") ~= nil, "T11 without KTQ: plain TrackEntry (" .. callsStr() .. ")")
NOW = NOW + 1
frame()
clearCalls()
frame({ click = "##cqpr1", hover = "##cqpr1", mx = bi.x2 - 5 })
ok(callsStr():find("^untrack,sound:ui_menu_map_pin_off") ~= nil, "T11 without KTQ: UntrackEntry (" .. callsStr() .. ")")
ktqPresent = true

-- T12 journal error: message, no crash, logged once, retry after 5 s
J.failQuests = true
NOW = NOW + 2
f = frame()
local shown = false
for _, s in ipairs(f.colored) do if s:find("journal exploded") then shown = true end end
ok(shown, "T12 error shown in the window")
NOW = NOW + 1
frame()
local n = 0
for _, l in ipairs(logs) do if l:find("journal exploded") then n = n + 1 end end
ok(n == 1, "T12 error logged once (" .. n .. ")")
J.failQuests = false
NOW = NOW + 6
f = frame()
shown = false
for _, s in ipairs(f.colored) do if s:find("journal exploded") then shown = true end end
ok(not shown and #f.rows > 0, "T12 recovers after the back-off")

-- T13 not in game
inGame = false
NOW = NOW + 2
f = frame()
ok(has(f.disabled, "Load a save to see your quests.") and #f.rows == 0, "T13 main menu message")
inGame = true
NOW = NOW + 2
frame()

-- T14 overlay closed again: no calls, and garbage per open frame
handlers.onOverlayClose()
imCalls = 0
for _ = 1, 100 do handlers.onDraw() end
ok(imCalls == 0, "T14 closed overlay: no ImGui calls")
handlers.onOverlayOpen()
frame()
quiet = true
collectgarbage("collect")
collectgarbage("stop")
local before = collectgarbage("count")
for _ = 1, 2000 do handlers.onDraw() end
local perFrame = (collectgarbage("count") - before) / 2000
collectgarbage("restart")
io.stdout:write(string.format("garbage per open-overlay frame (no refresh): %.3f KB\n", perFrame))
ok(perFrame < 0.5, "T14 per-frame garbage below 0.5 KB")
collectgarbage("collect")
before = collectgarbage("count")
collectgarbage("stop")
NOW = NOW + 2
handlers.onDraw()
local perRefresh = collectgarbage("count") - before
collectgarbage("restart")
io.stdout:write(string.format("garbage per refresh (8 active quests): %.1f KB\n", perRefresh))
quiet = false

-- T15 narrow window: details stack below the list, search wraps
IN.availW = 380
frame({ click = "##cqpr0", hover = "##cqpr0", mx = 150 })
NOW = NOW + 0.4
f = frame()
ok(has(f.wrapped, "LIGHT CANDLE FOR JOHNNY"), "T15 narrow layout details")
IN.availW = 900
f = frame()
ok(has(f.wrapped, "LIGHT CANDLE FOR JOHNNY"), "T15 wide layout details")

-- T16 collapsed window: no journal reads; expanding reads at once
IN.collapsed = true
frame()
local reads0 = J.reads
for _ = 1, 4 do NOW = NOW + 2; frame() end
ok(J.reads == reads0, "T16 collapsed: no journal reads (" .. reads0 .. " -> " .. J.reads .. ")")
IN.collapsed = false
frame()
frame()
ok(J.reads > reads0, "T16 expanded: journal read again")
IN.availW = 560
f = frame()
ok(#f.rows > 0, "T16 rows back")

-- T17 time skip line (1.1.0)
local function tsLine()
    NOW = NOW + 2
    local fr = frame()
    local clock, st = nil, nil
    for _, x in ipairs(fr.colored) do
        if x:find("^DAY ") then clock = x end
        if x:find("^TIME SKIP") then st = x end
    end
    return clock, st
end
local c, st = tsLine()
ok(c == "DAY 4  21:04", "T17 clock (" .. tostring(c) .. ")")
ok(st == "TIME SKIP AVAILABLE", "T17 available (" .. tostring(st) .. ")")
TSM.can = false; TSM.ints.Combat = 1
c, st = tsLine()
ok(st == "TIME SKIP BLOCKED: IN COMBAT", "T17 combat (" .. tostring(st) .. ")")
TSM.ints.Combat = 0; TSM.ints.Vehicle = 1; TSM.speed = 20
c, st = tsLine()
ok(st == "TIME SKIP BLOCKED: DRIVING FASTER THAN 50 KM/H", "T17 speed (" .. tostring(st) .. ")")
TSM.speed = -20
c, st = tsLine()
ok(st == "TIME SKIP BLOCKED: BLOCKED BY A QUEST OR MOD", "T17 unknown reason (" .. tostring(st) .. ")")
TSM.ints.Vehicle = 0; TSM.zone = 3
c, st = tsLine()
ok(st == "TIME SKIP BLOCKED: RESTRICTED OR DANGEROUS AREA", "T17 zone (" .. tostring(st) .. ")")
TSM.zone = 1; TSM.tags.NoTimeSkip = true
c, st = tsLine()
ok(st == "TIME SKIP BLOCKED: A QUEST OR EFFECT FORBIDS IT", "T17 tag (" .. tostring(st) .. ")")
TSM.tags.NoTimeSkip = nil; TSM.can = true; TSM.bools.IsPlayerInsideElevator = true
c, st = tsLine()
ok(st == "TIME SKIP BLOCKED: IN AN ELEVATOR", "T17 elevator (" .. tostring(st) .. ")")
TSM.bools.IsPlayerInsideElevator = nil; TSM.dil = true
c, st = tsLine()
ok(st == "TIME SKIP BLOCKED: TIME IS SLOWED", "T17 dilation (" .. tostring(st) .. ")")
TSM.dil = false; TSM.failCan = true; TSM.auto = true
c, st = tsLine()
ok(st == "TIME SKIP BLOCKED: AUTODRIVE ON", "T17 own check when the game call fails (" .. tostring(st) .. ")")
TSM.auto = false
c, st = tsLine()
ok(st == "TIME SKIP AVAILABLE", "T17 own check: free (" .. tostring(st) .. ")")
TSM.failCan = false; TSM.tags.NoTimeDisplay = true
c, st = tsLine()
ok(c == "DAY --  --:--", "T17 glitched clock (" .. tostring(c) .. ")")
TSM.tags.NoTimeDisplay = nil
inGame = false
c, st = tsLine()
ok(c == nil and st == nil, "T17 no line in the main menu")
inGame = true
c, st = tsLine()
ok(c ~= nil and #logs > 0, "T17 back in game")

ok(errs() == 1, "no unexpected errors (" .. errs() .. ")")
for _, l in ipairs(logs) do if l:find("error") and not l:find("journal exploded") then io.stdout:write("LOG: " .. l .. "\n") end end
io.stdout:write(string.format("mock: %d passed, %d failed\n", pass, fail))
os.exit(fail == 0 and 0 or 1)
