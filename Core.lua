local addonName, ns = ...

ns.state = {
    selectedSpecIndex = nil,
    selectedSpecID    = nil,
    selectedClassID   = nil,
    selectedClassName = nil,
    selectedClassFile = nil,
    selectedSpecName  = nil,
    isViewingOtherClass = false,
    selectedDifficulty = "M+10",  -- Default difficulty
}

ns.inspectedPlayerName = nil  -- non-nil while viewing another player's data
ns.effectiveIgnoreTiers = nil  -- non-nil while inspecting; overrides saved prefs

-- Slot IDs for the 5 tier-eligible slots
local TIER_SLOT_IDS = { HEAD=1, SHOULDER=3, CHEST=5, HANDS=10, LEGS=7 }

-- Returns the active ignore-tier table: auto-detected when inspecting, saved prefs for self
function ns:GetEffectiveIgnoreTiers()
    return ns.effectiveIgnoreTiers or (DungeonAdvisorCharDB and DungeonAdvisorCharDB.ignoreTiers) or {}
end

-- DungeonAdvisor: Core
-- Initializes the addon and reads character gear via WoW API

DungeonAdvisor = {}
DungeonAdvisor.version = "1.0.9"
DungeonAdvisorLootDB = {} -- Global loot database (populated at PLAYER_LOGIN)

-- Tuneable weights
ns.W_ILVL_DENSITY  = 0.40  -- how much raw ilvl gain per drop matters
ns.W_UPGRADE_RATE  = 4     -- how often you actually get an upgrade
ns.W_STAT_QUALITY  = 4     -- how often the upgrade also has good stats
ns.W_TRACK         = 7     -- how often the upgrade is a track upgrade

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
}

-- Extra ring/trinket slots
DungeonAdvisor.EXTRA_SLOTS = {
    FINGER2  = { id = 12, slot = "FINGER", label = "Ring 2" },
    TRINKET2 = { id = 14, slot = "TRINKET", label = "Trinket 2" },
}

function ns:startsWith(str, start)
    if not start then return false end
    return str:sub(1, #start) == start
end

function ns:DetectLootSpec()
    local className, classFile, classID = UnitClass("player")

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
end

-- Get the stat weight table for the current player spec
function ns:GetSpecWeights()
    local key = ns.state.selectedClassName:upper() .. "_" .. ns.state.selectedSpecIndex
    DungeonAdvisorDB.weights = DungeonAdvisorDB.weights or {}
    return DungeonAdvisorDB.weights[key]
        or DungeonAdvisorCalc.STAT_WEIGHTS[key]
        or DungeonAdvisorCalc.DEFAULT_WEIGHTS
end

local function TablesEqual(a, b)
    if a == b then return true end
    if not a or not b then return false end
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

function ns:SetStatWeight(stat, value)
    local key = ns.state.selectedClassName:upper() .. "_" .. ns.state.selectedSpecIndex

    -- ensure we have a custom weights table in the DB to write to
    -- copy defaults if no custom weights exist yet so we don't mutate STAT_WEIGHTS
    if not DungeonAdvisorDB.weights[key] then
        local defaults = DungeonAdvisorCalc.STAT_WEIGHTS[key] or DungeonAdvisorCalc.DEFAULT_WEIGHTS
        DungeonAdvisorDB.weights[key] = {}
        for k, v in pairs(defaults) do
            DungeonAdvisorDB.weights[key][k] = v
        end
    end

    DungeonAdvisorDB.weights[key][stat] = value

    -- if it now matches defaults, drop the custom entry to save space
    if TablesEqual(DungeonAdvisorDB.weights[key], DungeonAdvisorCalc.STAT_WEIGHTS[key]) then
        DungeonAdvisorDB.weights[key] = nil
    end
end

-- Returns a table of { slotName -> currentIlvl } for the player
ns.playerUsing2H = false
ns.weaponMode = ""

-- Defined here (before BuildGearEntry) so it is available regardless of Calculator.lua load state
function ns:SecondaryStatScore(stats, weights)
    if not stats or not weights then return 0 end
    return
        (stats["ITEM_MOD_CRIT_RATING_SHORT"] or 0)    * (weights.crit or 0) +
        (stats["ITEM_MOD_HASTE_RATING_SHORT"] or 0)   * (weights.haste or 0) +
        (stats["ITEM_MOD_MASTERY_RATING_SHORT"] or 0) * (weights.mastery or 0) +
        (stats["ITEM_MOD_VERSATILITY"] or 0)          * (weights.versatility or 0)
end

local function BuildGearEntry(itemLink, label, weights)
    local itemName = GetItemInfo(itemLink)
    -- GetDetailedItemLevelInfo computes the effective ilvl from the bonus IDs
    -- in the link itself — no cache required, always returns the upgraded value.
    -- GetItemInfo ilvl is wrong on first load: returns base ilvl (e.g. 580)
    -- rather than the track-upgraded ilvl (e.g. 636).
    local ilvl = GetDetailedItemLevelInfo(itemLink) or 0
    local stats = ns.GetItemStatsCompat(itemLink)
    local itemID = tonumber(itemLink:match("item:(%d+)"))
    return {
        ilvl               = ilvl,
        itemID             = itemID,
        name               = itemName or "Unknown",
        label              = label,
        secondaryStatScore = ns:SecondaryStatScore(stats, weights),
        stats              = stats,
        track              = ns:GetTrackFromItemLink(itemLink),
        isCrafted          = ns:IsCraftedItem(itemLink),
    }
end

function DungeonAdvisor:GetEquippedGear(unit, linksBySlotID)
    unit = unit or "player"
    local weights = ns:GetSpecWeights()
    local gear    = {}

    local function getLink(slotID)
        if linksBySlotID then return linksBySlotID[slotID] end
        return GetInventoryItemLink(unit, slotID)
    end

    for slotName, slotInfo in pairs(self.SLOTS) do
        local key      = (slotName == "FINGER") and "FINGER1"
                      or (slotName == "TRINKET") and "TRINKET1"
                      or slotName
        local itemLink = getLink(slotInfo.id)

        if itemLink then
            gear[key] = BuildGearEntry(itemLink, slotInfo.label, weights)

            -- Auto-detect weapon mode: always for inspected units, only on first load for self
            if slotName == "MAINHAND" and (ns.weaponMode == "" or linksBySlotID) then
                local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
                if itemType == "Weapon" then
                    local is2H = itemSubType == "Two-Handed Swords"
                             or  itemSubType == "Two-Handed Axes"
                             or  itemSubType == "Two-Handed Maces"
                             or  itemSubType == "Polearms"
                             or  itemSubType == "Staves"
                             or  itemSubType == "Bows"
                             or  itemSubType == "Guns"
                             or  itemSubType == "Crossbows"
                    ns.playerUsing2H = is2H
                    ns.weaponMode    = is2H and "2H" or "1H"
                elseif linksBySlotID then
                    -- Inspecting and item data not cached yet; default to 1H
                    ns.playerUsing2H = false
                    ns.weaponMode    = "1H"
                end
            end
        else
            gear[key] = { ilvl = 0, secondaryStatScore = 0, name = "Empty", label = slotInfo.label }
        end
    end

    for extraName, extraInfo in pairs(self.EXTRA_SLOTS) do
        local itemLink = getLink(extraInfo.id)
        if itemLink then
            gear[extraName] = BuildGearEntry(itemLink, extraInfo.label, weights)
        else
            gear[extraName] = { ilvl = 0, secondaryStatScore = 0, name = "Empty", label = extraInfo.label }
        end
    end

    return gear
end

-- Populate ns.state from an inspected unit's class/spec
function ns:DetectInspectedSpec(unit)
    local className, classFile, classID = UnitClass(unit)
    if not classID then return false end

    local specID = GetInspectSpecialization(unit)
    if not specID or specID == 0 then return false end

    local numSpecs = GetNumSpecializationsForClassID(classID)
    for i = 1, numSpecs do
        local id, name = GetSpecializationInfoForClassID(classID, i)
        if id == specID then
            ns.state.selectedClassID        = classID
            ns.state.selectedClassName      = className
            ns.state.selectedClassFile      = classFile
            ns.state.selectedSpecIndex      = i
            ns.state.selectedSpecID         = specID
            ns.state.selectedSpecName       = name
            ns.state.isViewingOtherClass    = true
            ns.inspectedPlayerName          = UnitName(unit)
            return true
        end
    end
    return false
end

-- Inspect the current target and load their gear/spec into the advisor
function DungeonAdvisor:InspectTarget()
    if not UnitExists("target") or not UnitIsPlayer("target") then
        print("|cff00ccff[DungeonAdvisor]|r No player targeted.")
        return
    end
    if not CanInspect("target") then
        print("|cff00ccff[DungeonAdvisor]|r Cannot inspect that player (too far away or in combat?).")
        return
    end
    ns.pendingInspectUnit = "target"
    NotifyInspect("target")
end

-- Reset to the local player's own gear and spec
function DungeonAdvisor:ReturnToSelf()
    ns.inspectedPlayerName  = nil
    ns.pendingInspectUnit   = nil
    ns.effectiveIgnoreTiers = nil
    ns.weaponMode           = ""  -- allow auto-detect to re-run
    ns:DetectLootSpec()
    DungeonAdvisor.playerGear = DungeonAdvisor:GetEquippedGear("player")
    DungeonAdvisorUI:UpdateSpecInfo()
    DungeonAdvisor:InitializeLootDB()
    DungeonAdvisorUI:RefreshDungeonList()
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
eventFrame:RegisterEvent("INSPECT_READY")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

ns.pendingInspectUnit = nil  -- set while waiting for INSPECT_READY

-- State for deferred inspect gear load (waiting for item cache)
local inspectStoredLinks  = {}   -- slotID -> itemLink, populated as item data arrives
local inspectTierLinks    = {}   -- slotKey -> itemLink, for tier detection
local inspectPendingItems = {}   -- itemID -> slotID: occupied slots whose data isn't cached yet
local inspectActiveUnit   = nil  -- kept for retrying GetInventoryItemLink after cache load

local function FinishInspect()
    ns.weaponMode = ""  -- reset so auto-detect runs fresh for the inspected unit
    DungeonAdvisor.playerGear = DungeonAdvisor:GetEquippedGear(nil, inspectStoredLinks)

    -- Auto-detect which tier slots the inspected player is wearing tier in
    ns.effectiveIgnoreTiers = {}
    for slotKey, link in pairs(inspectTierLinks) do
        if link then
            local setID = select(16, GetItemInfo(link))
            ns.effectiveIgnoreTiers[slotKey] = setID ~= nil and setID > 0
        else
            ns.effectiveIgnoreTiers[slotKey] = false
        end
    end

    DungeonAdvisorUI:UpdateSpecInfo()
    DungeonAdvisor:InitializeLootDB()
    DungeonAdvisorUI:RefreshDungeonList()
end

-- Once all pending item IDs have loaded, retry GetInventoryItemLink (which
-- requires items to be in the local cache) then build gear and refresh the UI.
local function FinalizeInspect()
    if inspectActiveUnit then
        local unit = inspectActiveUnit
        for _, slotInfo in pairs(DungeonAdvisor.SLOTS) do
            if not inspectStoredLinks[slotInfo.id] then
                inspectStoredLinks[slotInfo.id] = GetInventoryItemLink(unit, slotInfo.id)
            end
        end
        for _, extraInfo in pairs(DungeonAdvisor.EXTRA_SLOTS) do
            if not inspectStoredLinks[extraInfo.id] then
                inspectStoredLinks[extraInfo.id] = GetInventoryItemLink(unit, extraInfo.id)
            end
        end
    end
    for slotKey, slotID in pairs(TIER_SLOT_IDS) do
        inspectTierLinks[slotKey] = inspectStoredLinks[slotID]
    end
    inspectActiveUnit = nil
    FinishInspect()
end

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        DungeonAdvisorDB     = DungeonAdvisorDB     or {}
        DungeonAdvisorCharDB = DungeonAdvisorCharDB or {}
        print("|cff00ccff[DungeonAdvisor]|r Loaded! Type |cffFFD700/da|r to open.")
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns:DetectLootSpec()
        DungeonAdvisor.playerGear = DungeonAdvisor:GetEquippedGear("player")
    elseif event == "INSPECT_READY" then
        if not ns.pendingInspectUnit then return end
        local unit = ns.pendingInspectUnit
        ns.pendingInspectUnit = nil

        if not ns:DetectInspectedSpec(unit) then
            print("|cff00ccff[DungeonAdvisor]|r Could not read target spec (no specialization set?).")
            return
        end

        -- Capture ALL item links NOW while the inspect window is open.
        -- GetInventoryItemLink(unit) only works during the active inspect session;
        -- by the time GET_ITEM_INFO_RECEIVED fires the window may have closed.
        inspectActiveUnit  = unit
        inspectStoredLinks  = {}
        inspectTierLinks    = {}
        inspectPendingItems = {}

        -- GetInventoryItemLink(unit) returns nil for items not yet in the local
        -- client cache. GetInventoryItemID works regardless of cache state.
        -- Strategy: for each slot, try GetInventoryItemLink first (fast path).
        -- If it returns nil but GetInventoryItemID confirms a slot is occupied,
        -- queue that item ID and wait for GET_ITEM_INFO_RECEIVED, then retry.
        local function QueueSlot(slotID)
            local link = GetInventoryItemLink(unit, slotID)
            if link then
                inspectStoredLinks[slotID] = link
                return
            end
            local itemID = GetInventoryItemID(unit, slotID)
            if itemID then
                GetItemInfo(itemID)               -- queue server load
                inspectPendingItems[itemID] = slotID
            end
        end

        for _, slotInfo in pairs(DungeonAdvisor.SLOTS) do QueueSlot(slotInfo.id) end
        for _, extraInfo in pairs(DungeonAdvisor.EXTRA_SLOTS) do QueueSlot(extraInfo.id) end

        if not next(inspectPendingItems) then
            FinalizeInspect()  -- all items already cached
        end
        -- Otherwise wait for GET_ITEM_INFO_RECEIVED to fire for each pending ID

    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if not next(inspectPendingItems) then return end
        local itemID = tonumber(arg1)
        if not inspectPendingItems[itemID] then return end
        inspectPendingItems[itemID] = nil
        if not next(inspectPendingItems) then
            FinalizeInspect()
        end
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
    local gear = self:GetEquippedGear("player")
    print("|cff00ccff[DungeonAdvisor]|r Current gear:")
    for slot, info in pairs(gear) do
        print(string.format("  %s: %s (ilvl %d)", info.label, info.name, info.ilvl))
    end
end
