-- Initialize the global namespace for our addon.
-- Every other file will be able to read and write to this table.
Infusion = {}

-- Infusion State Data
Infusion.scannedDruids = {} -- Shared druid roster from last scan
Infusion.druids = {} -- Innervate cooldowns by druid name
Infusion.rebirths = {} -- Rebirth cooldowns by druid name
Infusion.IsTrackingActive = false
Infusion.TrackInnervateEnabled = true
Infusion.TrackRebirthEnabled = true
Infusion.CompactEnabled = false
Infusion.NoDruidInRaid = false
Infusion.MOCK_DRUID_NAME = "NO DRUID IN RAID"

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

local AUTO_SCAN_MIN_INTERVAL = 1.0
local lastAutoScanTime = 0

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
    local hasRealDruid = (next(Infusion.scannedDruids) ~= nil) and (not Infusion.NoDruidInRaid)
    local hasEnabledTracking = Infusion.TrackInnervateEnabled or Infusion.TrackRebirthEnabled
    local shouldTrack = inRaid and hasRealDruid and hasEnabledTracking

    Infusion.IsTrackingActive = shouldTrack
end

function Infusion.EnsurePlaceholderDruid(forceBoth)
    if next(Infusion.scannedDruids) ~= nil then
        return
    end

    local mockName = Infusion.MOCK_DRUID_NAME
    Infusion.NoDruidInRaid = true
    Infusion.scannedDruids[mockName] = true

    if forceBoth or Infusion.TrackInnervateEnabled then
        Infusion.druids[mockName] = 0
    end

    if forceBoth or Infusion.TrackRebirthEnabled then
        Infusion.rebirths[mockName] = 0
    end
end

function Infusion.ResetToPlaceholderState(forceBoth)
    Infusion.scannedDruids = {}
    Infusion.druids = {}
    Infusion.rebirths = {}
    Infusion.EnsurePlaceholderDruid(forceBoth)
    Infusion.RefreshTrackingState()
end

function Infusion.ShowWidgetConfig()
    Infusion.ResetToPlaceholderState(true)

    if Infusion.BuildTracker then
        Infusion.BuildTracker(true)
    end

    if Infusion.BuildRebirthTracker then
        Infusion.BuildRebirthTracker(true)
    end
end

Infusion.ResetToPlaceholderState(true)

local function PerformRaidScan(preserveCooldowns)
    local numRaid = GetNumRaidMembers()
    if numRaid == 0 then
        Infusion.ResetToPlaceholderState(true)
        Infusion.BuildTracker()
        Infusion.BuildRebirthTracker()
        return
    end

    local oldInnervates = Infusion.druids
    local oldRebirths = Infusion.rebirths

    local newScannedDruids = {}
    local newInnervates = {}
    local newRebirths = {}

    for i = 1, numRaid do
        local name, _, _, _, _, fileName = GetRaidRosterInfo(i)
        if name and fileName == "DRUID" then
            newScannedDruids[name] = true

            if Infusion.TrackInnervateEnabled then
                if preserveCooldowns and oldInnervates[name] ~= nil then
                    newInnervates[name] = oldInnervates[name]
                else
                    newInnervates[name] = 0
                end
            end

            if Infusion.TrackRebirthEnabled then
                if preserveCooldowns and oldRebirths[name] ~= nil then
                    newRebirths[name] = oldRebirths[name]
                else
                    newRebirths[name] = 0
                end
            end
        end
    end

    Infusion.scannedDruids = newScannedDruids
    Infusion.druids = newInnervates
    Infusion.rebirths = newRebirths

    if next(Infusion.scannedDruids) == nil then
        Infusion.EnsurePlaceholderDruid(false)
    else
        Infusion.NoDruidInRaid = false
    end

    Infusion.RefreshTrackingState()
    Infusion.BuildTracker()
    Infusion.BuildRebirthTracker()
end

function Infusion.ScanRaid()
    if not Infusion.TrackInnervateEnabled and not Infusion.TrackRebirthEnabled then
        Infusion.RefreshTrackingState()
        Infusion.BuildTracker()
        Infusion.BuildRebirthTracker()
        return
    end

    PerformRaidScan(true)
end

local function RequestAutoScan(force)
    local now = GetTime()
    if not force and (now - lastAutoScanTime) < AUTO_SCAN_MIN_INTERVAL then
        return
    end

    lastAutoScanTime = now
    Infusion.ScanRaid()
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

    --if DEFAULT_CHAT_FRAME then
        -- DEFAULT_CHAT_FRAME:AddMessage("Infusion DEBUG CAST: casterGUID=" .. tostring(casterGUID) .. " spellID=" .. tostring(spellID), 0.4, 0.8, 1.0)
    --end

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
coreFrame:RegisterEvent("RAID_ROSTER_UPDATE")
coreFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

coreFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "Infusion" then
        Infusion.LoadPrefs()
        if Infusion.SyncMainUIFromPrefs then
            Infusion.SyncMainUIFromPrefs()
        end

        if next(Infusion.scannedDruids) == nil then
            Infusion.EnsurePlaceholderDruid(true)
        end

        if GetNumRaidMembers() > 0 then
            RequestAutoScan(true)
        else
            Infusion.RefreshTrackingState()
        end
        return
    end

    if event == "RAID_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        local inRaid = GetNumRaidMembers() > 0

        if not inRaid and Infusion.CloseTrackers then
            Infusion.CloseTrackers()
            return
        end

        RequestAutoScan(false)
        return
    end

    if event == "UNIT_CASTEVENT" then
        HandleUnitCastEvent()
        return
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
