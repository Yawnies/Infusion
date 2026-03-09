-- Innervate tracker frame (click-to-whisper enabled)
local innervateTrackerFrame = CreateFrame("Frame", "InfusionTrackerFrame", UIParent)
innervateTrackerFrame:SetWidth(200)
innervateTrackerFrame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
innervateTrackerFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    tile = true,
    tileSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
innervateTrackerFrame:SetBackdropColor(0, 0, 0, 0.65)
innervateTrackerFrame:SetMovable(true)
innervateTrackerFrame:EnableMouse(true)
innervateTrackerFrame:SetScript("OnMouseDown", function() if arg1 == "LeftButton" then this:StartMoving() end end)
innervateTrackerFrame:SetScript("OnMouseUp", function() if arg1 == "LeftButton" then this:StopMovingOrSizing() end end)
innervateTrackerFrame:Hide()

-- Rebirth tracker frame (same visual style, separate frame)
local rebirthTrackerFrame = CreateFrame("Frame", "InfusionRebirthTrackerFrame", UIParent)
rebirthTrackerFrame:SetWidth(200)
rebirthTrackerFrame:SetPoint("TOPLEFT", innervateTrackerFrame, "TOPRIGHT", 20, 0)
rebirthTrackerFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    tile = true,
    tileSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
rebirthTrackerFrame:SetBackdropColor(0, 0, 0, 0.65)
rebirthTrackerFrame:SetMovable(true)
rebirthTrackerFrame:EnableMouse(true)
rebirthTrackerFrame:SetScript("OnMouseDown", function() if arg1 == "LeftButton" then this:StartMoving() end end)
rebirthTrackerFrame:SetScript("OnMouseUp", function() if arg1 == "LeftButton" then this:StopMovingOrSizing() end end)
rebirthTrackerFrame:Hide()

-- Footer hint text at the bottom of the innervate tracker
local footerText = innervateTrackerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
footerText:SetWidth(180)
footerText:SetPoint("BOTTOM", innervateTrackerFrame, "BOTTOM", 0, 15)
footerText:SetJustifyH("CENTER")
footerText:SetJustifyV("TOP")
footerText:SetText("Click on a name to send a request whisper.")

local innervateRows = {}
local rebirthRows = {}

local function DebugLog(msg)
    -- DEBUG DISABLED FOR LIVE TESTING
    -- if Infusion and Infusion.Debug then
    --     DEFAULT_CHAT_FRAME:AddMessage("Infusion DEBUG: " .. msg, 0.4, 0.8, 1.0)
    -- end
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
    -- DebugLog("Whisper sent to " .. druidName .. ": " .. message)
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

-- Called by Core.lua when Scan is clicked
function Infusion.BuildTracker()
    local druidCount, sortedNames = GetSortedDruids()

    if not Infusion.TrackInnervateEnabled then
        innervateTrackerFrame:Hide()
        return
    end

    if druidCount == 0 then
        innervateTrackerFrame:Hide()
        return
    end

    -- Dynamic Height: Top padding(15) + (rows * 25) + Bottom padding(15) + Footer space(30)
    innervateTrackerFrame:SetHeight(30 + (druidCount * 25) + 30)
    innervateTrackerFrame:Show()
    -- DebugLog("Innervate tracker built with " .. druidCount .. " druid row(s).")

    for _, row in ipairs(innervateRows) do
        row:Hide()
    end

    for i, name in ipairs(sortedNames) do
        local row = innervateRows[i]
        if not row then
            row = CreateFrame("Frame", nil, innervateTrackerFrame)
            row:SetWidth(180)
            row:SetHeight(20)

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetWidth(16)
            icon:SetHeight(16)
            icon:SetPoint("LEFT", row, "LEFT", 5, 0)
            icon:SetTexture("Interface\\Icons\\Spell_Nature_Lightning")
            row.icon = icon

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
            nameText:SetWidth(75)
            nameText:SetJustifyH("LEFT")
            row.nameText = nameText

            -- Invisible clickable overlay across the full row content area
            local requestOverlay = CreateFrame("Button", nil, row)
            requestOverlay:SetHeight(20)
            requestOverlay:SetPoint("LEFT", row, "LEFT", 5, 0)
            requestOverlay:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            requestOverlay:RegisterForClicks("LeftButtonUp")
            requestOverlay:SetScript("OnClick", function()
                local rowParent = this:GetParent()
                if not rowParent or not rowParent.druidName then
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
            cdText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            cdText:SetWidth(65)
            cdText:SetJustifyH("RIGHT")
            row.cdText = cdText

            table.insert(innervateRows, row)
        end

        row:SetPoint("TOP", innervateTrackerFrame, "TOP", 0, -15 - ((i - 1) * 25))
        row.nameText:SetText(name)
        row.druidName = name
        row.lastDebugSecond = nil
        row:Show()
    end

    Infusion.UpdateTrackerDisplay()
end

-- Called by Core.lua when Scan is clicked (separate frame for Rebirth)
function Infusion.BuildRebirthTracker()
    local druidCount, sortedNames = GetSortedDruids()

    if not Infusion.TrackRebirthEnabled then
        rebirthTrackerFrame:Hide()
        return
    end

    if druidCount == 0 then
        rebirthTrackerFrame:Hide()
        return
    end

    -- Dynamic Height: Top padding(15) + (rows * 25) + Bottom padding(15)
    rebirthTrackerFrame:SetHeight(30 + (druidCount * 25))
    rebirthTrackerFrame:Show()
    -- DebugLog("Rebirth tracker built with " .. druidCount .. " druid row(s).")

    for _, row in ipairs(rebirthRows) do
        row:Hide()
    end

    for i, name in ipairs(sortedNames) do
        local row = rebirthRows[i]
        if not row then
            row = CreateFrame("Frame", nil, rebirthTrackerFrame)
            row:SetWidth(180)
            row:SetHeight(20)

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetWidth(16)
            icon:SetHeight(16)
            icon:SetPoint("LEFT", row, "LEFT", 5, 0)
            icon:SetTexture("Interface\\Icons\\Spell_Nature_Reincarnation")
            row.icon = icon

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
            nameText:SetWidth(75)
            nameText:SetJustifyH("LEFT")
            row.nameText = nameText

            local cdText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            cdText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            cdText:SetWidth(65)
            cdText:SetJustifyH("RIGHT")
            row.cdText = cdText

            table.insert(rebirthRows, row)
        end

        row:SetPoint("TOP", rebirthTrackerFrame, "TOP", 0, -15 - ((i - 1) * 25))
        row.nameText:SetText(name)
        row.druidName = name
        row.lastDebugSecond = nil
        row:Show()
    end

    Infusion.UpdateRebirthTrackerDisplay()
end

-- Called by the OnUpdate loop in Core.lua to refresh innervate tracker
function Infusion.UpdateTrackerDisplay()
    if not Infusion.TrackInnervateEnabled then
        innervateTrackerFrame:Hide()
        return
    end

    for _, row in ipairs(innervateRows) do
        if row:IsVisible() and row.druidName then
            local cd = Infusion.druids[row.druidName]
            if cd and cd > 0 then
                row:SetAlpha(0.4)
                row.cdText:SetText(math.ceil(cd) .. "s")
                row.cdText:SetTextColor(1.0, 0.0, 0.0)
                if row.requestOverlay then
                    row.requestOverlay:Hide()
                    row.requestOverlay:EnableMouse(false)
                end

                local currentSecond = math.ceil(cd)
                if row.lastDebugSecond ~= currentSecond then
                    row.lastDebugSecond = currentSecond
                    -- DebugLog("Innervate UI row update: " .. row.druidName .. " shows " .. currentSecond .. "s")
                end
            else
                row:SetAlpha(1.0)
                row.cdText:SetText("CD Ready")
                row.cdText:SetTextColor(0.0, 1.0, 0.0)
                if row.requestOverlay then
                    row.requestOverlay:Show()
                    row.requestOverlay:EnableMouse(true)
                end
            end
        end
    end
end

-- Called by the OnUpdate loop in Core.lua to refresh rebirth tracker
function Infusion.UpdateRebirthTrackerDisplay()
    if not Infusion.TrackRebirthEnabled then
        rebirthTrackerFrame:Hide()
        return
    end

    for _, row in ipairs(rebirthRows) do
        if row:IsVisible() and row.druidName then
            local cd = Infusion.rebirths[row.druidName]
            if cd and cd > 0 then
                row:SetAlpha(0.4)
                row.cdText:SetText(math.ceil(cd) .. "s")
                row.cdText:SetTextColor(1.0, 0.0, 0.0)

                local currentSecond = math.ceil(cd)
                if row.lastDebugSecond ~= currentSecond then
                    row.lastDebugSecond = currentSecond
                    -- DebugLog("Rebirth UI row update: " .. row.druidName .. " shows " .. currentSecond .. "s")
                end
            else
                row:SetAlpha(1.0)
                row.cdText:SetText("CD Ready")
                row.cdText:SetTextColor(0.0, 1.0, 0.0)
            end
        end
    end
end