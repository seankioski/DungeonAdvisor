-- GearAdvisor: Core
-- Initializes the addon and reads character gear via WoW API

GearAdvisor = {}
GearAdvisor.version = "1.0.0"

-- Slot IDs we care about (WoW inventory slot numbers)
GearAdvisor.SLOTS = {
    HEAD      = { id = 1,  label = "Head" },
    NECK      = { id = 2,  label = "Neck" },
    SHOULDER  = { id = 3,  label = "Shoulder" },
    BACK      = { id = 15, label = "Back" },
    CHEST     = { id = 5,  label = "Chest" },
    WRIST     = { id = 9,  label = "Wrist" },
    HANDS     = { id = 10, label = "Hands" },
    WAIST     = { id = 6,  label = "Waist" },
    LEGS      = { id = 7,  label = "Legs" },
    FEET      = { id = 8,  label = "Feet" },
    FINGER    = { id = 11, label = "Ring 1" }, -- we'll also check slot 12
    TRINKET   = { id = 13, label = "Trinket 1" }, -- we'll also check slot 14
    MAINHAND  = { id = 16, label = "Main Hand" },
    OFFHAND   = { id = 17, label = "Off Hand" },
    RANGED    = { id = 18, label = "Ranged" },
}

-- Extra ring/trinket slots
GearAdvisor.EXTRA_SLOTS = {
    FINGER2  = { id = 12, slot = "FINGER",  label = "Ring 2" },
    TRINKET2 = { id = 14, slot = "TRINKET", label = "Trinket 2" },
}

-- Returns a table of { slotName -> currentIlvl } for the player
function GearAdvisor:GetEquippedGear()
    local gear = {}

    for slotName, slotInfo in pairs(self.SLOTS) do
        local itemLink = GetInventoryItemLink("player", slotInfo.id)
        if itemLink then
            local ilvl = select(4, GetItemInfo(itemLink)) or 0
            gear[slotName] = {
                ilvl  = ilvl,
                name  = GetItemInfo(itemLink) or "Unknown",
                label = slotInfo.label,
            }
        else
            gear[slotName] = { ilvl = 0, name = "Empty", label = slotInfo.label }
        end
    end

    -- Handle second ring and trinket (use the lower of the two for each slot)
    for extraName, extraInfo in pairs(self.EXTRA_SLOTS) do
        local itemLink = GetInventoryItemLink("player", extraInfo.id)
        local ilvl = 0
        local name = "Empty"
        if itemLink then
            ilvl = select(4, GetItemInfo(itemLink)) or 0
            name = GetItemInfo(itemLink) or "Unknown"
        end
        local slotName = extraInfo.slot
        -- If this second slot is lower ilvl than the first, use it for upgrade comparison
        if gear[slotName] and ilvl < gear[slotName].ilvl then
            gear[slotName] = { ilvl = ilvl, name = name, label = extraInfo.label }
        end
    end

    return gear
end

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "GearAdvisor" then
        if not GearAdvisorDB then
            GearAdvisorDB = {}
        end
        print("|cff00ccff[GearAdvisor]|r Loaded! Type |cffFFD700/ga|r to open.")
    end

    if event == "PLAYER_LOGIN" then
        -- Gear info becomes available after login
        GearAdvisor.playerGear = GearAdvisor:GetEquippedGear()
        -- Kick off item data requests so GetItemStats() has data ready
        GearAdvisorItemCache:WarmCache()
        -- Print active spec so player knows what filter is active
        local className, specIndex, specName = GearAdvisorSpecFilter:GetPlayerSpec()
        print(string.format("|cff00ccff[GearAdvisor]|r Filtering for |cffFFD700%s %s|r. Type |cffFFD700/ga|r to open.", specName, className))
    end
end)

-- Slash command
SLASH_GEARADVISOR1 = "/ga"
SLASH_GEARADVISOR2 = "/gearadvisor"
SlashCmdList["GEARADVISOR"] = function(msg)
    msg = msg:lower():trim()
    if msg == "scan" then
        GearAdvisor.playerGear = GearAdvisor:GetEquippedGear()
        print("|cff00ccff[GearAdvisor]|r Gear rescanned.")
    elseif msg == "debug" then
        GearAdvisor:PrintGearDebug()
    else
        GearAdvisorUI:Toggle()
    end
end

-- Debug helper
function GearAdvisor:PrintGearDebug()
    local gear = self:GetEquippedGear()
    print("|cff00ccff[GearAdvisor]|r Current gear:")
    for slot, info in pairs(gear) do
        print(string.format("  %s: %s (ilvl %d)", info.label, info.name, info.ilvl))
    end
end
