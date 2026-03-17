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


local function CloseTrackers()
    if not Infusion or not Infusion.CloseTrackers then
        return
    end

    if Infusion.AreTrackersVisible and not Infusion.AreTrackersVisible() then
        DEFAULT_CHAT_FRAME:AddMessage("Infusion: tracking widgets are already closed.", 1.0, 0.2, 0.2)
        return
    end

    local hasRealDruids = (not Infusion.NoDruidInRaid) and (next(Infusion.scannedDruids) ~= nil)
    if hasRealDruids then
        DEFAULT_CHAT_FRAME:AddMessage("Infusion: Cannot close trackers while raid druids are being tracked.", 1.0, 0.2, 0.2)
        return
    end

    Infusion.CloseTrackers()
end
local function ShowWidgetConfig()
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("Infusion: cannot use configuration windows when inside a raid.", 1.0, 0.2, 0.2)
        return
    end

    if Infusion and Infusion.ShowWidgetConfig then
        Infusion.ShowWidgetConfig()
    end
end

SLASH_INFUSION1 = "/infusion"
SlashCmdList["INFUSION"] = function()
    ToggleMainUI()
end


SLASH_INFUSIONCLOSE1 = "/infusionclose"
SLASH_INFUSIONCLOSE2 = "/infc"
SlashCmdList["INFUSIONCLOSE"] = function()
    CloseTrackers()
end

SLASH_INFUSIONWIDGET1 = "/infusionwidget"
SLASH_INFUSIONWIDGET2 = "/infw"
SlashCmdList["INFUSIONWIDGET"] = function()
    ShowWidgetConfig()
end