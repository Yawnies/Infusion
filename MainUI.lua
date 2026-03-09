-- Create the Main UI Frame
local mainUI = CreateFrame("Frame", "InfusionMainFrame", UIParent)
mainUI:SetWidth(150)
mainUI:SetHeight(220) -- 220
mainUI:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

-- Black transparent background (no Blizzard border)
mainUI:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    tile = true,
    tileSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
mainUI:SetBackdropColor(0, 0, 0, 0.65)

-- Make the frame draggable
mainUI:SetMovable(true)
mainUI:EnableMouse(true)
mainUI:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then
        this:StartMoving()
    end
end)
mainUI:SetScript("OnMouseUp", function()
    if arg1 == "LeftButton" then
        this:StopMovingOrSizing()
    end
end)

-- Title Heading ("Infusion")
local title = mainUI:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", mainUI, "TOP", 0, -12)
title:SetText("Infusion")

-- Close Button (The 'X' in the top right)
local closeBtn = CreateFrame("Button", nil, mainUI, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", mainUI, "TOPRIGHT", -2, -2)
closeBtn:SetScript("OnClick", function()
    mainUI:Hide()
end)

-- Description Text
local desc = mainUI:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
desc:SetWidth(120)
desc:SetPoint("TOP", title, "BOTTOM", 0, -15)
desc:SetJustifyH("CENTER")
desc:SetJustifyV("TOP")
desc:SetText("A cute little addon that lets you know when Innervates and Rebirths are available.")

-- Raid Warning Text (Red)
local raidWarning = mainUI:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
raidWarning:SetWidth(120)
raidWarning:SetPoint("TOP", desc, "BOTTOM", 0, -10)
raidWarning:SetJustifyH("CENTER")
raidWarning:SetTextColor(1.0, 0.0, 0.0)
raidWarning:SetText("Make sure you're in a raid group!")

-- SuperWoW requirement text (shown only when SuperWoW is unavailable)
local superWoWWarning = mainUI:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
superWoWWarning:SetWidth(120)
superWoWWarning:SetPoint("BOTTOM", mainUI, "BOTTOM", -32, 70)
superWoWWarning:SetJustifyH("CENTER")
superWoWWarning:SetTextColor(1.0, 0.2, 0.2)
superWoWWarning:SetText("SuperWoW is required to scan your raid!")

local function PrintHelp()
    local neonGreen = "|cff00ff00"
    local reset = "|r"

    DEFAULT_CHAT_FRAME:AddMessage("--- " .. neonGreen .. "Infusion Help" .. reset .. " ---")
    DEFAULT_CHAT_FRAME:AddMessage(neonGreen .. "/infusion" .. reset .. " - opens the Scan/Help window.")
    DEFAULT_CHAT_FRAME:AddMessage(neonGreen .. "/infusionscan" .. reset .. " or " .. neonGreen .. "/infs" .. reset .. " - scan the raid without having to click Scan (will use the saved attributes from that screen). Will automatically display the tracker(s).")
    DEFAULT_CHAT_FRAME:AddMessage(neonGreen .. "/infusionclose" .. reset .. " or " .. neonGreen .. "/infc" .. reset .. " - closes the tracking window. Scan to have it appear again.")
end

local function SyncSelectionsToTrackedData()
    if Infusion.TrackInnervateEnabled then
        for name in pairs(Infusion.scannedDruids) do
            if Infusion.druids[name] == nil then
                Infusion.druids[name] = 0
            end
        end
    else
        Infusion.druids = {}
    end

    if Infusion.TrackRebirthEnabled then
        for name in pairs(Infusion.scannedDruids) do
            if Infusion.rebirths[name] == nil then
                Infusion.rebirths[name] = 0
            end
        end
    else
        Infusion.rebirths = {}
    end
end

local function RefreshTrackerWindowsFromSelections()
    SyncSelectionsToTrackedData()
    Infusion.RefreshTrackingState()

    if Infusion.BuildTracker then
        Infusion.BuildTracker()
    end

    if Infusion.BuildRebirthTracker then
        Infusion.BuildRebirthTracker()
    end
end

local actionBtnWidth = 58
local actionBtnHeight = 24
local actionGap = 6
local actionYOffset = 80 -- 65
local halfSeparation = math.floor((actionBtnWidth + actionGap) / 2)

-- The "Scan" Button
local scanBtn = CreateFrame("Button", "InfusionScanButton", mainUI, "UIPanelButtonTemplate")
scanBtn:SetWidth(actionBtnWidth)
scanBtn:SetHeight(actionBtnHeight)
scanBtn:SetPoint("BOTTOM", mainUI, "BOTTOM", -halfSeparation, actionYOffset)
scanBtn:SetText("Scan")
scanBtn:SetScript("OnClick", function()
    Infusion.ScanRaid()
end)

-- The "Help" Button
local helpBtn = CreateFrame("Button", "InfusionHelpButton", mainUI, "UIPanelButtonTemplate")
helpBtn:SetWidth(actionBtnWidth)
helpBtn:SetHeight(actionBtnHeight)
helpBtn:SetPoint("BOTTOM", mainUI, "BOTTOM", halfSeparation, actionYOffset)
helpBtn:SetText("Help")
helpBtn:SetScript("OnClick", function()
    PrintHelp()
end)

-- Checkboxes (left-aligned, stacked)
local trackInnervateCheck = CreateFrame("CheckButton", "InfusionTrackInnervateCheck", mainUI, "UICheckButtonTemplate")
trackInnervateCheck:SetPoint("BOTTOMLEFT", mainUI, "BOTTOMLEFT", 11, 40)
trackInnervateCheck:SetScript("OnClick", function()
    Infusion.TrackInnervateEnabled = this:GetChecked() and true or false
    RefreshTrackerWindowsFromSelections()
end)
getglobal(trackInnervateCheck:GetName() .. "Text"):SetText("Track Innervate")

local trackRebirthCheck = CreateFrame("CheckButton", "InfusionTrackRebirthCheck", mainUI, "UICheckButtonTemplate")
trackRebirthCheck:SetPoint("TOPLEFT", trackInnervateCheck, "BOTTOMLEFT", 0, 4)
trackRebirthCheck:SetScript("OnClick", function()
    Infusion.TrackRebirthEnabled = this:GetChecked() and true or false
    RefreshTrackerWindowsFromSelections()
end)
getglobal(trackRebirthCheck:GetName() .. "Text"):SetText("Track Rebirth")

trackInnervateCheck:SetChecked(Infusion.TrackInnervateEnabled)
trackRebirthCheck:SetChecked(Infusion.TrackRebirthEnabled)

-- Gate scan UI by load-time SuperWoW detection variable
if Infusion.HasSuperWoW then
    scanBtn:Show()
    superWoWWarning:Hide()
    helpBtn:SetPoint("BOTTOM", mainUI, "BOTTOM", halfSeparation, actionYOffset)
else
    scanBtn:Hide()
    superWoWWarning:Show()
    -- Keep Help available even without SuperWoW.
    helpBtn:SetPoint("BOTTOM", mainUI, "BOTTOM", 0, actionYOffset)
end

-- Hide the UI by default when the game loads
mainUI:Hide()

-- Save this frame to our global table so the Minimap button can find it
Infusion.MainUI = mainUI