if not Infusion or Infusion.Disabled then
    return
end

-- Slash commands for Infusion main UI and tracker control.

local function ToggleMainUI()
    if not Infusion or not Infusion.MainUI then
        return
    end

    if Infusion.MainUI:IsVisible() then
        Infusion.MainUI:Hide()
    else
        Infusion.MainUI:Show()
    end
end

local function RunScan()
    if Infusion and Infusion.ScanRaid then
        Infusion.ScanRaid()
    end
end

local function CloseTrackers()
    if Infusion and Infusion.CloseTrackers and Infusion.CloseTrackers() then
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("Infusion: tracking widgets are already closed.", 1.0, 0.2, 0.2)
end

SLASH_INFUSION1 = "/infusion"
SlashCmdList["INFUSION"] = function()
    ToggleMainUI()
end

SLASH_INFUSIONSCAN1 = "/infusionscan"
SLASH_INFUSIONSCAN2 = "/infs"
SlashCmdList["INFUSIONSCAN"] = function()
    RunScan()
end

SLASH_INFUSIONCLOSE1 = "/infusionclose"
SLASH_INFUSIONCLOSE2 = "/infc"
SlashCmdList["INFUSIONCLOSE"] = function()
    CloseTrackers()
end
