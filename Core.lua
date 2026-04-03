--TODO
--add filter for champ vs hero upgrades
-- add filter for tier set slot track upgrades
-- trinket info not showing
-- make secondary stat breakdown more useful somehow
-- todo color the secondary stats detailed text per item based on the stat weights. the ABSOLUTE BEST state weight is green
    -- (100% in the highest weight) compared to the lowest stat is red (100% in the lowest weight). This way you can easily see which item has better secondary stats even if the overall score is close. Maybe also add the actual score number for each item in the details text?

local addonName, ns = ...

ns.state = {
    selectedSpecIndex = nil,
    selectedSpecID    = nil,
    selectedClassID   = nil,
    selectedClassName = nil,
    selectedClassFile = nil,
    selectedSpecName  = nil,
    isViewingOtherClass = false,
    selectedStats     = {},    -- stat keys, max 2
    showingChart      = false,
    vaultMode         = false,
    selectedDifficulty = "M+10",  -- Default difficulty
}

-- DungeonAdvisor: Core
-- Initializes the addon and reads character gear via WoW API

DungeonAdvisor = {}
DungeonAdvisor.version = "1.0.2"

-- Global loot database (populated at PLAYER_LOGIN)
DungeonAdvisorLootDB = {}

-- Slot IDs we care about (WoW inventory slot numbers)
DungeonAdvisor.SLOTS = {
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
DungeonAdvisor.EXTRA_SLOTS = {
    FINGER2  = { id = 12, slot = "FINGER", label = "Ring 2" },
    TRINKET2 = { id = 14, slot = "TRINKET", label = "Trinket 2" },
}

function ns:DetectLootSpec()
    local className, classFile, classID = UnitClass("player")
    ns.playerClassID   = classID
    ns.playerClassName = className
    ns.playerClassFile = classFile

    ns.state.selectedClassID   = classID
    ns.state.selectedClassName = className
    ns.state.selectedClassFile = classFile
    ns.state.isViewingOtherClass = false

    -- 0 means "use current spec"
    local lootSpecID = GetLootSpecialization()
    if lootSpecID == 0 then
        local currentSpec = GetSpecialization()
        if currentSpec then
            ns.state.selectedSpecIndex = currentSpec
            ns.state.selectedSpecID = select(1, GetSpecializationInfo(currentSpec))
        end
    else
        for i = 1, GetNumSpecializations() do
            local specID = GetSpecializationInfo(i)
            if specID == lootSpecID then
                ns.state.selectedSpecIndex = i
                ns.state.selectedSpecID = specID
                break
            end
        end
    end

    ns.state.selectedSpecName = select(2, GetSpecializationInfo(ns.state.selectedSpecIndex)) or ""

    --print(string.format("|cff00ccff[DungeonAdvisor]|r Detected loot spec |cffFFD700%s %s|r.", ns.state.selectedSpecName, ns.playerClassName))
end

-- Get the stat weight table for the current player spec
function ns:GetSpecWeights()
    local key = ns.state.selectedSpecID .. "_" .. ns.state.selectedSpecIndex
    if not DungeonAdvisorDB.weights then
        DungeonAdvisorDB.weights = {}
    end
    --See if the DB has custom weights for this spec, otherwise return defaults
    if DungeonAdvisorDB.weights[key] then
        return DungeonAdvisorDB.weights[key]
    else
        return DungeonAdvisorCalc.STAT_WEIGHTS[key] or DungeonAdvisorCalc.DEFAULT_WEIGHTS
    end
end

function ns:SetStatWeight(stat, value)
    local key = ns.state.selectedSpecID .. "_" .. ns.state.selectedSpecIndex
    local weights = ns:GetSpecWeights()
    print(string.format("Setting weight for %s %s to %.2f", key, stat, value))
    weights[key][stat] = value
    --Update saved weights if they don't match default of current spec wights
    if weights[key] ~= DungeonAdvisorCalc.STAT_WEIGHTS[key] then
        DungeonAdvisorDB.weights[key] = weights[key]
    else
        --They match default, just delete custom weights to save space
        DungeonAdvisorDB.weights[key] = nil
    end
end

-- Returns a table of { slotName -> currentIlvl } for the player
function DungeonAdvisor:GetEquippedGear()
    local weights = ns:GetSpecWeights()
    local gear = {}

    for slotName, slotInfo in pairs(self.SLOTS) do
        local itemLink = GetInventoryItemLink("player", slotInfo.id)
        -- Rename base finger/trinket to FINGER1/TRINKET1 for consistency
        local key = slotName
        if slotName == "FINGER" then key = "FINGER1" end
        if slotName == "TRINKET" then key = "TRINKET1" end

        if itemLink then
            local ilvl = select(4, GetItemInfo(itemLink)) or 0
            local stats = ns.GetItemStatsCompat(itemLink)
            gear[key] = {
                ilvl  = ilvl,
                name  = GetItemInfo(itemLink) or "Unknown",
                label = slotInfo.label,
                secondaryStatScore = ns:SecondaryStatScore(stats, weights),
            }
        else
            gear[key] = { ilvl = 0, secondaryStatScore = 0,name = "Empty", label = slotInfo.label }
        end
    end

    -- Store second ring and trinket as their own entries
    for extraName, extraInfo in pairs(self.EXTRA_SLOTS) do
        local itemLink = GetInventoryItemLink("player", extraInfo.id)
        if itemLink then
            local ilvl = select(4, GetItemInfo(itemLink)) or 0
            local stats = ns.GetItemStatsCompat(itemLink)
            gear[extraName] = {
                ilvl  = ilvl,
                name  = GetItemInfo(itemLink) or "Unknown",
                label = extraInfo.label,
                secondaryStatScore = ns:SecondaryStatScore(stats, weights),
            }
        else
            gear[extraName] = { ilvl = 0, secondaryStatScore = 0, name = "Empty", label = extraInfo.label }
        end
    end

    return gear
end

function DungeonAdvisor:InitializeLootDB()
    -- show spinner only if we know items are still pending or DB is empty
    if #DungeonAdvisorLootDB == 0 or ns:IsDataPending() then
        DungeonAdvisorUI:ShowSpinner()
    end
    local results = ns:ScanLoot(ns.state.selectedSpecIndex)
    if not results or #results == 0 then
        print("|cff00ccff[DungeonAdvisor]|r Warning: No loot data returned")
        DungeonAdvisorUI:HideSpinner()
        return
    end
    DungeonAdvisorLootDB = results
end

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        DungeonAdvisorDB = DungeonAdvisorDB or {}
        print("|cff00ccff[DungeonAdvisor]|r Loaded! Type |cffFFD700/da|r to open.")
    end
    if event == "PLAYER_ENTERING_WORLD" then
        ns:DetectLootSpec()
        DungeonAdvisor.playerGear = DungeonAdvisor:GetEquippedGear()
    end
end)



-- Slash command
SLASH_DUNGEONADVISOR1 = "/da"
SLASH_DUNGEONADVISOR2 = "/dungeonadvisor"
SlashCmdList["DUNGEONADVISOR"] = function(msg)
    msg = msg:lower():trim()
    if msg == "debug" then
        DungeonAdvisor:PrintGearDebug()
    else
        DungeonAdvisorUI:Toggle()
    end
end

-- Debug helper
function DungeonAdvisor:PrintGearDebug()
    local gear = self:GetEquippedGear()
    print("|cff00ccff[DungeonAdvisor]|r Current gear:")
    for slot, info in pairs(gear) do
        print(string.format("  %s: %s (ilvl %d)", info.label, info.name, info.ilvl))
    end
end
