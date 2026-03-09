-- Initialize the global namespace for our addon.
-- Every other file will be able to read and write to this table.
Infusion = {}

-- Infusion State Data
Infusion.scannedDruids = {} -- Shared druid roster from last scan
Infusion.druids = {} -- Innervate cooldowns by druid name
Infusion.rebirths = {} -- Rebirth cooldowns by druid name
-- Infusion.Debug = true
Infusion.Debug = false
Infusion.IsTrackingActive = false
Infusion.TrackInnervateEnabled = true
Infusion.TrackRebirthEnabled = true
Infusion.CompactEnabled = false

local DEFAULT_OPTIONS = {
    track_innervate = true,
    track_rebirth = true,
    compact = false,
}

local INNERVATE_CD = 360
local REBIRTH_CD = 1800
local INNERVATE_SPELL_ID = 29166
local REBIRTH_SPELL_IDS = {
    [20484] = true, -- Rebirth Rank 1
    [20739] = true, -- Rebirth Rank 2
    [20742] = true, -- Rebirth Rank 3
    [20747] = true, -- Rebirth Rank 4
    [20748] = true, -- Rebirth Rank 5
}

local function DebugLog(msg)
    -- DEBUG DISABLED FOR LIVE TESTING
    -- if Infusion.Debug then
    --     DEFAULT_CHAT_FRAME:AddMessage("Infusion DEBUG: " .. msg, 0.4, 0.8, 1.0)
    -- end
end

function Infusion.InitPrefs()
    if type(INFUSION_PREFS) ~= "table" then
        INFUSION_PREFS = {}
    end

    if type(INFUSION_PREFS.options) ~= "table" then
        INFUSION_PREFS.options = {}
    end

    if type(INFUSION_PREFS.positions) ~= "table" then
        INFUSION_PREFS.positions = {}
    end
end

function Infusion.LoadPrefs()
    Infusion.InitPrefs()

    local opts = INFUSION_PREFS.options
    if opts.track_innervate == nil then
        opts.track_innervate = DEFAULT_OPTIONS.track_innervate
    end

    if opts.track_rebirth == nil then
        opts.track_rebirth = DEFAULT_OPTIONS.track_rebirth
    end

    if opts.compact == nil then
        opts.compact = DEFAULT_OPTIONS.compact
    end

    Infusion.TrackInnervateEnabled = opts.track_innervate and true or false
    Infusion.TrackRebirthEnabled = opts.track_rebirth and true or false
    Infusion.CompactEnabled = opts.compact and true or false
end

function Infusion.SaveOptionPrefs()
    Infusion.InitPrefs()

    INFUSION_PREFS.options.track_innervate = Infusion.TrackInnervateEnabled and true or false
    INFUSION_PREFS.options.track_rebirth = Infusion.TrackRebirthEnabled and true or false
    INFUSION_PREFS.options.compact = Infusion.CompactEnabled and true or false
end

function Infusion.SaveFramePosition(prefKey, frame)
    if not prefKey or not frame then
        return
    end

    Infusion.InitPrefs()

    local point, _, relativePoint, x, y = frame:GetPoint()
    INFUSION_PREFS.positions[prefKey] = {
        point = point or "CENTER",
        relativePoint = relativePoint or point or "CENTER",
        x = x or 0,
        y = y or 0,
    }
end

function Infusion.RestoreFramePosition(prefKey, frame, defaultPoint, defaultRelativeFrame, defaultRelativePoint, defaultX, defaultY)
    if not prefKey or not frame then
        return
    end

    Infusion.InitPrefs()

    local pos = INFUSION_PREFS.positions[prefKey]
    frame:ClearAllPoints()

    if pos and pos.point and pos.relativePoint and pos.x and pos.y then
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
        return
    end

    frame:SetPoint(
        defaultPoint or "CENTER",
        defaultRelativeFrame or UIParent,
        defaultRelativePoint or defaultPoint or "CENTER",
        defaultX or 0,
        defaultY or 0
    )
end

local function IsSuperWoWReady()
    if IsAddOnLoaded and (IsAddOnLoaded("SuperWoW") or IsAddOnLoaded("SuperWOW")) then
        return true
    end

    local knownGlobals = {
        "SUPERWOW_VERSION",
        "SuperWoWVersion",
        "SuperWOWVersion",
        "GetSuperWowVersion",
    }

    for _, globalName in ipairs(knownGlobals) do
        if _G[globalName] ~= nil then
            return true
        end
    end

    return false
end

if not IsSuperWoWReady() then
    Infusion.Disabled = true

    StaticPopupDialogs["INFUSION_NO_SUPERWOW"] = {
        text = "SuperWoW is required to run Infusion. Please install it before reloading the addon.",
        button1 = OKAY,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        showAlert = 1,
    }

    StaticPopup_Show("INFUSION_NO_SUPERWOW")
    return
end

Infusion.HasSuperWoW = true

function Infusion.RefreshTrackingState()
    local inRaid = GetNumRaidMembers() > 0
    local hasTrackedDruid = next(Infusion.scannedDruids) ~= nil
    local hasEnabledTracking = Infusion.TrackInnervateEnabled or Infusion.TrackRebirthEnabled
    local shouldTrack = inRaid and hasTrackedDruid and hasEnabledTracking

    Infusion.IsTrackingActive = shouldTrack
end

--[[
SLASH_INFUSIONDEBUG1 = "/infusiondebug"
SlashCmdList["INFUSIONDEBUG"] = function(msg)
    if msg == "0" or msg == "off" then
        Infusion.Debug = false
    elseif msg == "1" or msg == "on" then
        Infusion.Debug = true
    else
        Infusion.Debug = not Infusion.Debug
    end

    DEFAULT_CHAT_FRAME:AddMessage("Infusion: Debug " .. (Infusion.Debug and "ON" or "OFF"), 1.0, 1.0, 0.0)
end

if Infusion.Debug then
    -- DebugLog("SuperWoW detected=" .. tostring(Infusion.HasSuperWoW))
end
]]

Infusion.RefreshTrackingState()

-- 1. The Scanner Logic
function Infusion.ScanRaid()
    if not Infusion.TrackInnervateEnabled and not Infusion.TrackRebirthEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("Infusion: You must select at least one option before scanning!", 1.0, 0.2, 0.2)
        return
    end

    local numRaid = GetNumRaidMembers()

    -- Abort if not in a raid
    if numRaid == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("Infusion: Must be in a raid group for the scanner to work!", 1.0, 0.0, 0.0)
        Infusion.RefreshTrackingState()
        return
    end

    -- Persist checkbox options when scanning.
    Infusion.SaveOptionPrefs()

    -- Clear lists and repopulate them
    Infusion.scannedDruids = {}
    Infusion.druids = {}
    Infusion.rebirths = {}

    for i = 1, numRaid do
        local name, _, _, _, _, fileName = GetRaidRosterInfo(i)
        if name and fileName == "DRUID" then
            Infusion.scannedDruids[name] = true
            if Infusion.TrackInnervateEnabled then
                Infusion.druids[name] = 0
            end
            if Infusion.TrackRebirthEnabled then
                Infusion.rebirths[name] = 0
            end
        end
    end

    if next(Infusion.scannedDruids) == nil then
        DEFAULT_CHAT_FRAME:AddMessage("Infusion: No Druids found in the raid.", 1.0, 0.0, 0.0)
    end

    Infusion.RefreshTrackingState()

    -- Build/refresh trackers according to selected options
    Infusion.BuildTracker()
    Infusion.BuildRebirthTracker()
end

local function GetRaidNameByGUID(casterGUID)
    if not casterGUID then
        return nil
    end

    local numRaid = GetNumRaidMembers()
    for i = 1, numRaid do
        local unit = "raid" .. i
        local exists, guid = UnitExists(unit)
        if exists and guid == casterGUID then
            return UnitName(unit)
        end
    end

    return nil
end

local function HandleUnitCastEvent()
    if not Infusion.IsTrackingActive then
        return
    end

    local casterGUID = arg1
    local castEventType = arg3
    local spellID = tonumber(arg4)

    -- Use CAST to avoid duplicate START/CAST triggers on some abilities.
    if castEventType ~= "CAST" then
        return
    end

    local isInnervateCast = (spellID == INNERVATE_SPELL_ID)
    local isRebirthCast = (spellID and REBIRTH_SPELL_IDS[spellID])

    if not isInnervateCast and not isRebirthCast then
        return
    end

    if isInnervateCast and not Infusion.TrackInnervateEnabled then
        return
    end

    if isRebirthCast and not Infusion.TrackRebirthEnabled then
        return
    end

    local casterName = GetRaidNameByGUID(casterGUID)
    if not casterName then
        return
    end

    if isInnervateCast then
        if Infusion.druids[casterName] ~= nil then
            Infusion.druids[casterName] = INNERVATE_CD
            Infusion.UpdateTrackerDisplay()
        end
        return
    end

    if isRebirthCast then
        if Infusion.rebirths[casterName] ~= nil then
            Infusion.rebirths[casterName] = REBIRTH_CD
            Infusion.UpdateRebirthTrackerDisplay()
        end
    end
end

-- 2. Combat Log Listener & Timer Loop
local coreFrame = CreateFrame("Frame")
coreFrame:RegisterEvent("ADDON_LOADED")
coreFrame:RegisterEvent("UNIT_CASTEVENT")
coreFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
coreFrame:RegisterEvent("CHAT_MSG_SPELL_PARTY_BUFF")
coreFrame:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF")
coreFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
coreFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS")
coreFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS")
coreFrame:RegisterEvent("RAID_ROSTER_UPDATE")
coreFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

coreFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "Infusion" then
        Infusion.LoadPrefs()
        if Infusion.SyncMainUIFromPrefs then
            Infusion.SyncMainUIFromPrefs()
        end
        Infusion.RefreshTrackingState()
        return
    end

    if event == "RAID_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        if GetNumRaidMembers() == 0 and Infusion.CloseTrackers then
            Infusion.CloseTrackers()
        end
        Infusion.RefreshTrackingState()
        return
    end

    if event == "UNIT_CASTEVENT" then
        HandleUnitCastEvent()
        return
    end

    if not Infusion.IsTrackingActive then
        return
    end

    -- Innervate fallback parsing only matters if innervate tracking is enabled.
    if not Infusion.TrackInnervateEnabled then
        return
    end

    if not arg1 then
        return
    end

    -- Fallback path for Innervate if UNIT_CASTEVENT is unavailable.
    local caster
    if string.find(arg1, "^You gain Innervate") then
        caster = UnitName("player")
    end

    if not caster then
        local _, _, gainCaster = string.find(arg1, "^(.-) gains Innervate")
        caster = gainCaster
    end

    if caster and Infusion.druids[caster] ~= nil then
        Infusion.druids[caster] = INNERVATE_CD
        Infusion.UpdateTrackerDisplay()
    end
end)

-- The OnUpdate function runs every visual frame.
-- In 1.12.1, arg1 inside OnUpdate represents elapsed time in seconds.
coreFrame:SetScript("OnUpdate", function()
    if not Infusion.IsTrackingActive then
        return
    end

    local elapsed = arg1
    local needsInnervateUIUpdate = false
    local needsRebirthUIUpdate = false

    if Infusion.TrackInnervateEnabled then
        for name, cd in pairs(Infusion.druids) do
            if cd > 0 then
                Infusion.druids[name] = cd - elapsed

                if Infusion.druids[name] <= 0 then
                    Infusion.druids[name] = 0
                end

                needsInnervateUIUpdate = true
            end
        end
    end

    if Infusion.TrackRebirthEnabled then
        for name, cd in pairs(Infusion.rebirths) do
            if cd > 0 then
                Infusion.rebirths[name] = cd - elapsed

                if Infusion.rebirths[name] <= 0 then
                    Infusion.rebirths[name] = 0
                end

                needsRebirthUIUpdate = true
            end
        end
    end

    if needsInnervateUIUpdate then
        Infusion.UpdateTrackerDisplay()
    end

    if needsRebirthUIUpdate then
        Infusion.UpdateRebirthTrackerDisplay()
    end
end)
