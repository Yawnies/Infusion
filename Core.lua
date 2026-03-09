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

function Infusion.CheckSuperWoW()
    -- Turtle WoW clients can expose SuperWoW via addon state and/or globals from the DLL/addon.
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

function Infusion.RefreshTrackingState()
    local inRaid = GetNumRaidMembers() > 0
    local hasTrackedDruid = next(Infusion.scannedDruids) ~= nil
    local hasEnabledTracking = Infusion.TrackInnervateEnabled or Infusion.TrackRebirthEnabled
    local shouldTrack = Infusion.HasSuperWoW and inRaid and hasTrackedDruid and hasEnabledTracking

    if Infusion.IsTrackingActive ~= shouldTrack then
        Infusion.IsTrackingActive = shouldTrack
        --[[ DebugLog(
            "Tracking active=" .. tostring(Infusion.IsTrackingActive) ..
            " (inRaid=" .. tostring(inRaid) ..
            ", scannedDruids=" .. tostring(hasTrackedDruid) ..
            ", trackInnervate=" .. tostring(Infusion.TrackInnervateEnabled) ..
            ", trackRebirth=" .. tostring(Infusion.TrackRebirthEnabled) ..
            ", superWoW=" .. tostring(Infusion.HasSuperWoW) .. ")"
        )
            ]]--
    else
        Infusion.IsTrackingActive = shouldTrack
    end
end

-- Checked once when addon loads; UI uses this to gate raid scanning.
Infusion.HasSuperWoW = Infusion.CheckSuperWoW()

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

    if not Infusion.HasSuperWoW then
        DEFAULT_CHAT_FRAME:AddMessage("Infusion: SuperWoW is required to scan your raid!", 1.0, 0.2, 0.2)
        Infusion.RefreshTrackingState()
        return
    end

    local numRaid = GetNumRaidMembers()

    -- Abort if not in a raid
    if numRaid == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("Infusion: Must be in a raid group for the scanner to work!", 1.0, 0.2, 0.2)
        Infusion.RefreshTrackingState()
        return
    end

    -- Clear lists and repopulate them
    Infusion.scannedDruids = {}
    Infusion.druids = {}
    Infusion.rebirths = {}
    -- DebugLog("Scan started. Raid members=" .. numRaid)

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
            -- DebugLog("Tracked druid: " .. name)
        end
    end

    if next(Infusion.scannedDruids) == nil then
        DEFAULT_CHAT_FRAME:AddMessage("Infusion: No Druids found in the raid.", 1.0, 1.0, 0.0)
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

    if Infusion.Debug then
        --[[ DebugLog(
            "UNIT_CASTEVENT casterGUID=" .. tostring(casterGUID) ..
            " type=" .. tostring(castEventType) ..
            " spellID=" .. tostring(spellID)
        )
            ]]--
    end

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
        -- DebugLog("Tracked cast detected, but caster GUID was not found in raid roster.")
        return
    end

    if isInnervateCast then
        if Infusion.druids[casterName] ~= nil then
            Infusion.druids[casterName] = INNERVATE_CD
            -- DebugLog("Innervate cooldown set via UNIT_CASTEVENT: " .. casterName .. " => " .. INNERVATE_CD .. "s")
            Infusion.UpdateTrackerDisplay()
        else
            -- DebugLog("Innervate caster resolved, but not in scanned druid list: " .. casterName)
        end
        return
    end

    if isRebirthCast then
        if Infusion.rebirths[casterName] ~= nil then
            Infusion.rebirths[casterName] = REBIRTH_CD
            -- DebugLog("Rebirth cooldown set via UNIT_CASTEVENT: " .. casterName .. " => " .. REBIRTH_CD .. "s")
            Infusion.UpdateRebirthTrackerDisplay()
        else
            -- DebugLog("Rebirth caster resolved, but not in scanned druid list: " .. casterName)
        end
    end
end

-- 2. Combat Log Listener & Timer Loop
local coreFrame = CreateFrame("Frame")
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
    if event == "RAID_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
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

    if not arg1 then return end

    if Infusion.Debug and (string.find(arg1, "Innervate") or string.find(arg1, "innervate")) then
        -- DebugLog("Event=" .. tostring(event) .. " Msg='" .. arg1 .. "'")
    end

    -- Fallback path for Innervate if UNIT_CASTEVENT is unavailable.
    local caster
    if string.find(arg1, "^You gain Innervate") then
        caster = UnitName("player")
        -- DebugLog("Matched self Innervate (fallback). Caster=" .. tostring(caster))
    end

    if not caster then
        local _, _, gainCaster = string.find(arg1, "^(.-) gains Innervate")
        caster = gainCaster
        if caster then
            -- DebugLog("Matched Innervate gain (fallback). Caster=" .. caster)
        end
    end

    if caster and Infusion.druids[caster] ~= nil then
        Infusion.druids[caster] = INNERVATE_CD
        -- DebugLog("Innervate cooldown set (fallback): " .. caster .. " => " .. INNERVATE_CD .. "s")
        Infusion.UpdateTrackerDisplay()
    elseif caster then
        -- DebugLog("Innervate caster not tracked (not in scanned druid list): " .. caster)
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
                local previous = cd
                Infusion.druids[name] = cd - elapsed

                if Infusion.druids[name] <= 0 then
                    Infusion.druids[name] = 0
                    -- DebugLog("Innervate cooldown finished: " .. name)
                end

                if math.floor(previous) ~= math.floor(Infusion.druids[name]) then
                    -- DebugLog("Innervate tick " .. name .. " => " .. string.format("%.1f", Infusion.druids[name]))
                end

                needsInnervateUIUpdate = true
            end
        end
    end

    if Infusion.TrackRebirthEnabled then
        for name, cd in pairs(Infusion.rebirths) do
            if cd > 0 then
                local previous = cd
                Infusion.rebirths[name] = cd - elapsed

                if Infusion.rebirths[name] <= 0 then
                    Infusion.rebirths[name] = 0
                    -- DebugLog("Rebirth cooldown finished: " .. name)
                end

                if math.floor(previous) ~= math.floor(Infusion.rebirths[name]) then
                    -- DebugLog("Rebirth tick " .. name .. " => " .. string.format("%.1f", Infusion.rebirths[name]))
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