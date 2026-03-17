if not Infusion or Infusion.Disabled then
    return
end

-- Innervate tracker frame (click-to-whisper enabled)
local innervateTrackerFrame = CreateFrame("Frame", "InfusionTrackerFrame", UIParent)
innervateTrackerFrame:SetWidth(200)
innervateTrackerFrame:SetMovable(true)
innervateTrackerFrame:EnableMouse(true)
innervateTrackerFrame:SetScript("OnMouseDown", function() if arg1 == "LeftButton" then this:StartMoving() end end)
innervateTrackerFrame:SetScript("OnMouseUp", function()
    if arg1 == "LeftButton" then
        this:StopMovingOrSizing()
        if Infusion.SaveFramePosition then
            Infusion.SaveFramePosition("innervate_tracker", this)
        end
    end
end)
innervateTrackerFrame:Hide()

if Infusion.RestoreFramePosition then
    Infusion.RestoreFramePosition("innervate_tracker", innervateTrackerFrame, "CENTER", UIParent, "CENTER", 200, 0)
else
    innervateTrackerFrame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
end

-- Rebirth tracker frame (same visual style, separate frame)
local rebirthTrackerFrame = CreateFrame("Frame", "InfusionRebirthTrackerFrame", UIParent)
rebirthTrackerFrame:SetWidth(200)
rebirthTrackerFrame:SetMovable(true)
rebirthTrackerFrame:EnableMouse(true)
rebirthTrackerFrame:SetScript("OnMouseDown", function() if arg1 == "LeftButton" then this:StartMoving() end end)
rebirthTrackerFrame:SetScript("OnMouseUp", function()
    if arg1 == "LeftButton" then
        this:StopMovingOrSizing()
        if Infusion.SaveFramePosition then
            Infusion.SaveFramePosition("rebirth_tracker", this)
        end
    end
end)
rebirthTrackerFrame:Hide()

if Infusion.RestoreFramePosition then
    Infusion.RestoreFramePosition("rebirth_tracker", rebirthTrackerFrame, "TOPLEFT", innervateTrackerFrame, "TOPRIGHT", 20, 0)
else
    rebirthTrackerFrame:SetPoint("TOPLEFT", innervateTrackerFrame, "TOPRIGHT", 20, 0)
end

-- Footer hint text at the bottom of the innervate tracker (normal mode only)
local footerText = innervateTrackerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
footerText:SetWidth(180)
footerText:SetPoint("BOTTOM", innervateTrackerFrame, "BOTTOM", 0, 15)
footerText:SetJustifyH("CENTER")
footerText:SetJustifyV("TOP")
footerText:SetText("Click on a name to send a request whisper.")

-- Compact mode drag labels
local dragLabelInnervate = innervateTrackerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dragLabelInnervate:SetPoint("BOTTOM", innervateTrackerFrame, "BOTTOM", 0, 2)
dragLabelInnervate:SetJustifyH("CENTER")
dragLabelInnervate:SetText("[DRAG]")
dragLabelInnervate:Hide()

local dragLabelRebirth = rebirthTrackerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dragLabelRebirth:SetPoint("BOTTOM", rebirthTrackerFrame, "BOTTOM", 0, 2)
dragLabelRebirth:SetJustifyH("CENTER")
dragLabelRebirth:SetText("[DRAG]")
dragLabelRebirth:Hide()

local innervateRows = {}
local rebirthRows = {}

local function IsCompact()
    return Infusion.CompactEnabled and true or false
end

local function IsMockDruid(name)
    return name and Infusion and Infusion.MOCK_DRUID_NAME and name == Infusion.MOCK_DRUID_NAME
end

local function ApplyFrameStyle(frame)
    local compact = IsCompact()
    local inset = compact and 0 or 4
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        insets = { left = inset, right = inset, top = inset, bottom = inset }
    })
    frame:SetBackdropColor(0, 0, 0, 0.65)
    frame:SetWidth(compact and 130 or 200)
end

local function WhisperInnervateRequest(druidName)
    if not druidName or druidName == "" then
        return
    end

    local requester = UnitName("player") or "Unknown"
    local requesterColored = "|cffffffff" .. requester .. "|r"
    local innervateColored = "|cff66ccffInnervate|r"
    local message = "[Infusion] " .. requesterColored .. " requests an " .. innervateColored .. "!"
    SendChatMessage(message, "WHISPER", nil, druidName)
end

local function GetSortedDruids()
    local count = 0
    local sortedNames = {}

    for name in pairs(Infusion.scannedDruids) do
        count = count + 1
        table.insert(sortedNames, name)
    end

    table.sort(sortedNames)
    return count, sortedNames
end

local function GetLayout()
    local compact = IsCompact()
    if compact then
        return {
            compact = true,
            rowWidth = 130,
            rowHeight = 20,
            topPadding = 0,
            rowStep = 20,
            bottomExtra = 16,
            leftPad = 0,
            rightPad = 0,
            nameGap = 4,
            nameWidth = 76,
            cdWidth = 32,
            readyText = "RDY",
            showFooter = false,
            showDrag = true,
        }
    end

    return {
        compact = false,
        rowWidth = 180,
        rowHeight = 20,
        topPadding = 15,
        rowStep = 25,
        bottomExtra = 30,
        leftPad = 5,
        rightPad = 5,
        nameGap = 8,
        nameWidth = 75,
        cdWidth = 65,
        readyText = "CD Ready",
        showFooter = true,
        showDrag = false,
    }
end

local function EnsureInnervateRow(i)
    local row = innervateRows[i]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, innervateTrackerFrame)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(16)
    icon:SetHeight(16)
    icon:SetTexture("Interface\\Icons\\Spell_Nature_Lightning")
    row.icon = icon

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    -- Invisible clickable overlay across the full row content area
    local requestOverlay = CreateFrame("Button", nil, row)
    requestOverlay:SetHeight(20)
    requestOverlay:RegisterForClicks("LeftButtonUp")
    requestOverlay:SetScript("OnClick", function()
        local rowParent = this:GetParent()
        if not rowParent or not rowParent.druidName then
            return
        end

        if IsMockDruid(rowParent.druidName) then
            return
        end

        local cd = Infusion.druids[rowParent.druidName]
        if cd and cd <= 0 then
            WhisperInnervateRequest(rowParent.druidName)
        end
    end)
    requestOverlay:Hide()
    row.requestOverlay = requestOverlay

    local cdText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cdText:SetJustifyH("RIGHT")
    row.cdText = cdText

    innervateRows[i] = row
    return row
end

local function EnsureRebirthRow(i)
    local row = rebirthRows[i]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, rebirthTrackerFrame)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(16)
    icon:SetHeight(16)
    icon:SetTexture("Interface\\Icons\\Spell_Nature_Reincarnation")
    row.icon = icon

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    local cdText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cdText:SetJustifyH("RIGHT")
    row.cdText = cdText

    rebirthRows[i] = row
    return row
end

local function ApplyRowLayout(row, layout)
    row:SetWidth(layout.rowWidth)
    row:SetHeight(layout.rowHeight)

    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", row, "LEFT", layout.leftPad, 0)

    row.nameText:ClearAllPoints()
    row.nameText:SetPoint("LEFT", row.icon, "RIGHT", layout.nameGap, 0)
    row.nameText:SetWidth(layout.nameWidth)

    row.cdText:ClearAllPoints()
    row.cdText:SetPoint("RIGHT", row, "RIGHT", -layout.rightPad, 0)
    row.cdText:SetWidth(layout.cdWidth)

    if row.requestOverlay then
        row.requestOverlay:ClearAllPoints()
        row.requestOverlay:SetPoint("LEFT", row, "LEFT", layout.leftPad, 0)
        row.requestOverlay:SetPoint("RIGHT", row, "RIGHT", -layout.rightPad, 0)
    end
end

-- Called by Core.lua when Scan is clicked
function Infusion.BuildTracker(forceShow)
    ApplyFrameStyle(innervateTrackerFrame)

    local druidCount, sortedNames = GetSortedDruids()
    if ((not Infusion.TrackInnervateEnabled) and (not forceShow)) or druidCount == 0 then
        innervateTrackerFrame:Hide()
        return
    end

    local layout = GetLayout()
    if layout.compact then
        innervateTrackerFrame:SetHeight((druidCount * layout.rowStep) + layout.bottomExtra)
    else
        innervateTrackerFrame:SetHeight(30 + (druidCount * 25) + 30)
    end
    innervateTrackerFrame:Show()

    if layout.showFooter then
        footerText:Show()
    else
        footerText:Hide()
    end

    if layout.showDrag then
        dragLabelInnervate:Show()
    else
        dragLabelInnervate:Hide()
    end

    for _, row in ipairs(innervateRows) do
        row:Hide()
    end

    for i, name in ipairs(sortedNames) do
        local row = EnsureInnervateRow(i)
        ApplyRowLayout(row, layout)
        row:ClearAllPoints()
        row:SetPoint("TOP", innervateTrackerFrame, "TOP", 0, -layout.topPadding - ((i - 1) * layout.rowStep))
        row.nameText:SetText(name)
        if IsMockDruid(name) then
            row.nameText:SetTextColor(1.0, 0.2, 0.2)
            row.nameText:SetWidth(layout.rowWidth - layout.leftPad - layout.rightPad - 16 - layout.nameGap)
            row.cdText:SetWidth(0)
        else
            row.nameText:SetTextColor(1.0, 0.82, 0.0)
            row.nameText:SetWidth(layout.nameWidth)
            row.cdText:SetWidth(layout.cdWidth)
        end
        row.druidName = name
        row:Show()
    end

    Infusion.UpdateTrackerDisplay(forceShow)
end

-- Called by Core.lua when Scan is clicked (separate frame for Rebirth)
function Infusion.BuildRebirthTracker(forceShow)
    ApplyFrameStyle(rebirthTrackerFrame)

    local druidCount, sortedNames = GetSortedDruids()
    if ((not Infusion.TrackRebirthEnabled) and (not forceShow)) or druidCount == 0 then
        rebirthTrackerFrame:Hide()
        return
    end

    local layout = GetLayout()
    if layout.compact then
        rebirthTrackerFrame:SetHeight((druidCount * layout.rowStep) + layout.bottomExtra)
    else
        rebirthTrackerFrame:SetHeight(30 + (druidCount * 25))
    end
    rebirthTrackerFrame:Show()

    if layout.showDrag then
        dragLabelRebirth:Show()
    else
        dragLabelRebirth:Hide()
    end

    for _, row in ipairs(rebirthRows) do
        row:Hide()
    end

    for i, name in ipairs(sortedNames) do
        local row = EnsureRebirthRow(i)
        ApplyRowLayout(row, layout)
        row:ClearAllPoints()
        row:SetPoint("TOP", rebirthTrackerFrame, "TOP", 0, -layout.topPadding - ((i - 1) * layout.rowStep))
        row.nameText:SetText(name)
        if IsMockDruid(name) then
            row.nameText:SetTextColor(1.0, 0.2, 0.2)
            row.nameText:SetWidth(layout.rowWidth - layout.leftPad - layout.rightPad - 16 - layout.nameGap)
            row.cdText:SetWidth(0)
        else
            row.nameText:SetTextColor(1.0, 0.82, 0.0)
            row.nameText:SetWidth(layout.nameWidth)
            row.cdText:SetWidth(layout.cdWidth)
        end
        row.druidName = name
        row:Show()
    end

    Infusion.UpdateRebirthTrackerDisplay(forceShow)
end

-- Called by the OnUpdate loop in Core.lua to refresh innervate tracker
function Infusion.UpdateTrackerDisplay(forceShow)
    if not Infusion.TrackInnervateEnabled and not forceShow then
        innervateTrackerFrame:Hide()
        return
    end

    local readyText = IsCompact() and "RDY" or "CD Ready"

    for _, row in ipairs(innervateRows) do
        if row:IsVisible() and row.druidName then
            if IsMockDruid(row.druidName) then
                row:SetAlpha(1.0)
                row.nameText:SetTextColor(1.0, 0.2, 0.2)
                row.cdText:SetText("")
                if row.requestOverlay then
                    row.requestOverlay:Hide()
                    row.requestOverlay:EnableMouse(false)
                end
            else
                local cd = Infusion.druids[row.druidName]
                row.nameText:SetTextColor(1.0, 0.82, 0.0)
                if cd and cd > 0 then
                    row:SetAlpha(0.4)
                    row.cdText:SetText(math.ceil(cd) .. "s")
                    row.cdText:SetTextColor(1.0, 0.0, 0.0)
                    if row.requestOverlay then
                        row.requestOverlay:Hide()
                        row.requestOverlay:EnableMouse(false)
                    end
                else
                    row:SetAlpha(1.0)
                    row.cdText:SetText(readyText)
                    row.cdText:SetTextColor(0.0, 1.0, 0.0)
                    if row.requestOverlay then
                        row.requestOverlay:Show()
                        row.requestOverlay:EnableMouse(true)
                    end
                end
            end
        end
    end
end

-- Called by the OnUpdate loop in Core.lua to refresh rebirth tracker
function Infusion.UpdateRebirthTrackerDisplay(forceShow)
    if not Infusion.TrackRebirthEnabled and not forceShow then
        rebirthTrackerFrame:Hide()
        return
    end

    local readyText = IsCompact() and "RDY" or "CD Ready"

    for _, row in ipairs(rebirthRows) do
        if row:IsVisible() and row.druidName then
            if IsMockDruid(row.druidName) then
                row:SetAlpha(1.0)
                row.nameText:SetTextColor(1.0, 0.2, 0.2)
                row.cdText:SetText("")
            else
                local cd = Infusion.rebirths[row.druidName]
                row.nameText:SetTextColor(1.0, 0.82, 0.0)
                if cd and cd > 0 then
                    row:SetAlpha(0.4)
                    row.cdText:SetText(math.ceil(cd) .. "s")
                    row.cdText:SetTextColor(1.0, 0.0, 0.0)
                else
                    row:SetAlpha(1.0)
                    row.cdText:SetText(readyText)
                    row.cdText:SetTextColor(0.0, 1.0, 0.0)
                end
            end
        end
    end
end

function Infusion.AreTrackersVisible()
    return (innervateTrackerFrame and innervateTrackerFrame:IsVisible())
        or (rebirthTrackerFrame and rebirthTrackerFrame:IsVisible())
end

function Infusion.CloseTrackers()
    local wasVisible = Infusion.AreTrackersVisible()

    if innervateTrackerFrame then
        innervateTrackerFrame:Hide()
    end

    if rebirthTrackerFrame then
        rebirthTrackerFrame:Hide()
    end

    -- Closing trackers also resets to placeholder so config mode can always display.
    if Infusion.ResetToPlaceholderState then
        Infusion.ResetToPlaceholderState(true)
    else
        Infusion.scannedDruids = {}
        Infusion.druids = {}
        Infusion.rebirths = {}
        Infusion.NoDruidInRaid = false

        if Infusion.RefreshTrackingState then
            Infusion.RefreshTrackingState()
        end
    end

    return wasVisible
end
