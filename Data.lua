local addonName, ns = ...

-- EJ API compat layer
-- Blizzard keeps moving stuff between global EJ_* and C_EncounterJournal.*
local CEJ = C_EncounterJournal or {}

local function EJ_Call(cejName, globalName, ...)
    if CEJ[cejName] then
        return CEJ[cejName](...)
    elseif _G[globalName] then
        return _G[globalName](...)
    end
    return nil
end

local function EJ_GetCurrentTierCompat()
    return EJ_Call("GetCurrentTier", "EJ_GetCurrentTier")
end
local function EJ_SelectTierCompat(tier)
    return EJ_Call("SelectTier", "EJ_SelectTier", tier)
end
local function EJ_GetNumTiersCompat()
    return EJ_Call("GetNumTiers", "EJ_GetNumTiers") or 0
end
local function EJ_GetInstanceByIndexCompat(index, isRaid)
    return EJ_Call("GetInstanceByIndex", "EJ_GetInstanceByIndex", index, isRaid)
end
local function EJ_SelectInstanceCompat(instanceID)
    return EJ_Call("SelectInstance", "EJ_SelectInstance", instanceID)
end
local function EJ_GetEncounterInfoByIndexCompat(index)
    return EJ_Call("GetEncounterInfoByIndex", "EJ_GetEncounterInfoByIndex", index)
end
local function EJ_SelectEncounterCompat(encounterID)
    return EJ_Call("SelectEncounter", "EJ_SelectEncounter", encounterID)
end
local function EJ_SetDifficultyCompat(diffID)
    return EJ_Call("SetDifficulty", "EJ_SetDifficulty", diffID)
end
local function EJ_GetDifficultyCompat()
    return EJ_Call("GetDifficulty", "EJ_GetDifficulty")
end
local function EJ_SetLootFilterCompat(classID, specID)
    return EJ_Call("SetLootFilter", "EJ_SetLootFilter", classID, specID)
end
local function EJ_SetSlotFilterCompat(slotFilter)
    return EJ_Call("SetSlotFilter", "EJ_SetSlotFilter", slotFilter)
end
local function EJ_GetNumLootCompat()
    return EJ_Call("GetNumLoot", "EJ_GetNumLoot") or 0
end

-- C_Item.GetItemStats replaced global GetItemStats in modern WoW
local function GetItemStatsCompat(itemLink)
    if not itemLink then return nil end  
    if C_Item and C_Item.GetItemStats then
        return C_Item.GetItemStats(itemLink)
    elseif _G.GetItemStats then
        local stats = {}
        _G.GetItemStats(itemLink, stats)
        if next(stats) then return stats end
        return nil
    end
    return nil
end

ns.GetItemStatsCompat = GetItemStatsCompat

local function EJ_GetLootInfoByIndexCompat(index)
    if CEJ.GetLootInfoByIndex then
        return CEJ.GetLootInfoByIndex(index)
    end
    -- old global returns multiple values instead of a table
    if _G.EJ_GetLootInfoByIndex then
        local name, icon, slot, armorType, itemID, itemLink = _G.EJ_GetLootInfoByIndex(index)
        if name then
            return { name = name, icon = icon, itemID = itemID, link = itemLink }
        end
    end
    return nil
end

function ns:GetDifficultyByID(dungeonDiff)
    for _, diff in ipairs(ns.DIFFICULTIES.DUNGEON) do
        if diff.id == dungeonDiff then return diff end
    end
end

ns.DIFFICULTIES = {
    DUNGEON = {
        { id = 1,  name = "N",  fullName = "Normal",  color = "GREEN"  },
        { id = 2,  name = "H",  fullName = "Heroic",  color = "BLUE",
          lootTrack = "ADVENTURER" },
        { id = 23, name = "M",  fullName = "Mythic",  color = "PURPLE",
          lootTrack = "VETERAN" },
        -- M+ virtual columns: same items as Mythic but ilvl scales with key level.
        -- Only showing breakpoints where loot ilvl actually changes.
        { id = "M+2",  name = "M2",  fullName = "Mythic+ 2-3",   color = "PURPLE", mythicPlus = true,
          lootTrack = "CHAMPION", lootBonusID = "CHAMPION_2" },
        { id = "M+4",  name = "M4",  fullName = "Mythic+ 4",     color = "PURPLE", mythicPlus = true,
          lootTrack = "CHAMPION", lootBonusID = "CHAMPION_3" },
        { id = "M+5",  name = "M5",  fullName = "Mythic+ 5",     color = "PURPLE", mythicPlus = true,
          lootTrack = "CHAMPION", lootBonusID = "CHAMPION_4" },
        { id = "M+6",  name = "M6",  fullName = "Mythic+ 6-7",   color = "PURPLE", mythicPlus = true,
          lootTrack = "HERO", lootBonusID = "HERO_1" },
        { id = "M+8",  name = "M8",  fullName = "Mythic+ 8-9",   color = "PURPLE", mythicPlus = true,
          lootTrack = "HERO", lootBonusID = "HERO_2" },
        { id = "M+10", name = "M10", fullName = "Mythic+ 10-12", color = "PURPLE", mythicPlus = true,
          lootTrack = "HERO", lootBonusID = "HERO_3" },
        { id = "Voidcore", name = "VC", fullName = "Voidcore", color = "ORANGE", mythicPlus = true,
          lootTrack = "MYTH", lootBonusID = "MYTH_1", voidcore = true },
    },
}

-- strict enum typing required by WoW
local EISFT = Enum.ItemSlotFilterType

-- M+ bonus IDs for Midnight S1
-- Maps upgrade track tier to the bonus ID that produces that ilvl + track display.
-- Each upgrade track uses consecutive bonus IDs with a 2-ID gap between tracks.
-- The bonus ID encodes BOTH ilvl AND upgrade track (e.g., Champion 2/6 vs Hero 2/6
-- are the same ilvl 250/263 but different bonus IDs).
local TRACK_BONUS_IDS = {
    -- Adventurer track: roughly 12771-12776
    ADVENTURER_1 = 12771,
    ADVENTURER_2 = 12772,
    ADVENTURER_3 = 12773,
    ADVENTURER_4 = 12774,
    ADVENTURER_5 = 12775,
    ADVENTURER_6 = 12776,
    -- Veteran track: roughly 12778-12783
    VETERAN_1 = 12778,
    VETERAN_2 = 12779,
    VETERAN_3 = 12780,
    VETERAN_4 = 12781,
    VETERAN_5 = 12782,
    VETERAN_6 = 12783,
    -- Champion track: 12785-12790
    CHAMPION_1 = 12785,  -- 246
    CHAMPION_2 = 12786,  -- 250
    CHAMPION_3 = 12787,  -- 253
    CHAMPION_4 = 12788,  -- 256
    CHAMPION_5 = 12789,  -- 259
    CHAMPION_6 = 12790,  -- 263
    -- Hero track: 12793-12798
    HERO_1     = 12793,  -- 259
    HERO_2     = 12794,  -- 263
    HERO_3     = 12795,  -- 266 (derived)
    HERO_4     = 12796,  -- 269 (derived)
    HERO_5     = 12797,  -- 272 (derived)
    HERO_6     = 12798,  -- 276 (derived)
    -- Myth track: 12801+ (unconfirmed, follows 2-ID gap pattern)
    MYTH_1     = 12801,  -- 272 (unconfirmed)
    MYTH_2     = 12802,  -- 276 (unconfirmed)
    MYTH_3     = 12803,  -- 276 (unconfirmed)
    MYTH_4     = 12804,  -- 276 (unconfirmed)
    MYTH_5     = 12805,  -- 276 (unconfirmed)
    MYTH_6     = 12806,  -- 276 (unconfirmed)
}


local ITEM_QUALITY_COLORS = {
    [0] = "ff9d9d9d", -- Poor
    [1] = "ffffffff", -- Common
    [2] = "ff1eff00", -- Uncommon
    [3] = "ff0070dd", -- Rare
    [4] = "ffa335ee", -- Epic
    [5] = "ffff8000", -- Legendary
}

-- Reverse map: bonusID -> track name
local BONUS_ID_TO_TRACK = {}
for trackKey, bonusID in pairs(TRACK_BONUS_IDS) do
    -- trackKey is like "CHAMPION_2", "HERO_1" etc — extract just the track name
    local trackName = trackKey:match("^(%a+)_")
    BONUS_ID_TO_TRACK[bonusID] = trackName
end

ns.TRACK_ORDER = {
    ADVENTURER = 1,
    VETERAN    = 2,
    CHAMPION   = 3,
    HERO       = 4,
    MYTH       = 5,
}

function ns:IsCraftedItem(itemLink)
    if not itemLink then return false end
    local CRAFTED_BONUS_IDS = { [523] = true, [8960] = true }
    local itemString = itemLink:match("|H(item:[^|]+)|h") or itemLink
    local parts = {}
    for p in (itemString..":"):gmatch("([^:]*):") do
        table.insert(parts, p)
    end

    -- Be tolerant of different item string formats: scan all numeric parts
    for _, part in ipairs(parts) do
        local bonusID = tonumber(part)
        if bonusID and CRAFTED_BONUS_IDS[bonusID] then
            return true
        end
    end
    return false
end

-- Parses an item link string and returns the upgrade track name, or nil if unrecognized
function ns:GetTrackFromItemLink(itemLink)
    if not itemLink then return nil end
    --print(itemLink:gsub('|', '||'))
    -- extract the item: string from the hyperlink
    local itemString = itemLink:match("|H(item:[^|]+)|h")
    if not itemString then
        -- might already be a bare item string
        itemString = itemLink
    end
    local parts = {}
    for part in (itemString .. ":"):gmatch("([^:]*):") do
        table.insert(parts, part)
    end

    -- Scan all numeric parts for a known track bonus ID. This is robust
    -- against different item string layouts where the bonus count index
    -- may vary between clients/patches.
    for _, part in ipairs(parts) do
        local bonusID = tonumber(part)
        if bonusID and BONUS_ID_TO_TRACK[bonusID] then
            return BONUS_ID_TO_TRACK[bonusID]
        end
    end
    return nil
end

local function BuildItemLinkWithBonuses(itemID, trackBonusKey)
    if not itemID or not trackBonusKey then return nil end

    local bonusID = TRACK_BONUS_IDS[trackBonusKey]
    if not bonusID then return nil end

    local playerLevel = UnitLevel("player") or 80
    local itemString = "item:" .. itemID .. "::::::::" .. playerLevel .. "::::1:" .. bonusID

    local itemName = GetItemInfo(itemID)
    if not itemName then
        pendingItemIDs[itemID] = true
        return nil
    end

    -- M+ bonus IDs always produce Epic quality regardless of the base item quality
    local colorHex = ITEM_QUALITY_COLORS[4]
    return "|c" .. colorHex .. "|H" .. itemString .. "|h[" .. itemName .. "]|h|r"
end

local pendingItemIDs = {}       -- itemIDs we're waiting on from server cache
local lootCache = {}
local instanceCache = nil
ns.isScanning = false
local hasNormalPending = false  -- instanceCache has unresolved hasNormal checks
local missedRefreshDuringScan = false

------------------------------------------------------------------------
-- EJ suppression
-- Blizzard's EJ reacts to our API calls and fights our state changes.
-- We null its event handler during scans. Ref-counted so nested calls work.
------------------------------------------------------------------------
local ejOriginalOnEvent = nil
local ejSuppressCount = 0
local ejSavedDifficulty = nil
local ejSavedSlotFilter = nil
local ejSavedLootClassID = nil
local ejSavedLootSpecID = nil

local function EJ_GetSlotFilterCompat()
    return EJ_Call("GetSlotFilter", "EJ_GetSlotFilter")
end

local function EJ_GetLootFilterCompat()
    if CEJ.GetLootFilter then
        return CEJ.GetLootFilter()
    elseif _G.EJ_GetLootFilter then
        return _G.EJ_GetLootFilter()
    end
    return nil, nil
end

local function SuppressEJ()
    ejSuppressCount = ejSuppressCount + 1
    if ejSuppressCount > 1 then return end

    if EncounterJournal then
        ejSavedDifficulty = EJ_GetDifficultyCompat()
        ejSavedSlotFilter = EJ_GetSlotFilterCompat()
        ejSavedLootClassID, ejSavedLootSpecID = EJ_GetLootFilterCompat()

        ejOriginalOnEvent = EncounterJournal:GetScript("OnEvent")
        EncounterJournal:SetScript("OnEvent", nil)
        EncounterJournal:UnregisterEvent("EJ_LOOT_DATA_RECIEVED")
        EncounterJournal:UnregisterEvent("EJ_DIFFICULTY_UPDATE")
        EncounterJournal:UnregisterEvent("UNIT_LEVEL")
        -- don't hide the EJ frame itself — user might have it open
    end
end

local function UnsuppressEJ()
    ejSuppressCount = ejSuppressCount - 1
    if ejSuppressCount > 0 then return end
    ejSuppressCount = 0
    --print("|cff00ccffDungeonAdvisor DEBUG:|r UnsuppressEJ called from: " .. debugstack(2, 3, 0))
    
    if EncounterJournal then
        -- restore EJ state before re-enabling events so it doesn't see our scan's leftovers
        if ejSavedDifficulty then
            EJ_SetDifficultyCompat(ejSavedDifficulty)
            ejSavedDifficulty = nil
        end
        if ejSavedSlotFilter then
            EJ_SetSlotFilterCompat(ejSavedSlotFilter)
            ejSavedSlotFilter = nil
        end
        if ejSavedLootClassID and ejSavedLootSpecID then
            EJ_SetLootFilterCompat(ejSavedLootClassID, ejSavedLootSpecID)
            ejSavedLootClassID = nil
            ejSavedLootSpecID = nil
        end

        if ejOriginalOnEvent then
            EncounterJournal:SetScript("OnEvent", ejOriginalOnEvent)
            ejOriginalOnEvent = nil
        end
        EncounterJournal:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
        EncounterJournal:RegisterEvent("EJ_DIFFICULTY_UPDATE")
        EncounterJournal:RegisterEvent("UNIT_LEVEL")
    end
end

-- seasonal dungeon allowlist (update each season)
-- uses instanceIDs so it works in any locale
local SEASONAL_DUNGEON_IDS = {
    [1300] = true,  -- Magisters' Terrace
    [1315] = true,  -- Maisara Caverns
    [1316] = true,  -- Nexus-Point Xenas
    [1299] = true,  -- Windrunner Spire
    [1201] = true,  -- Algeth'ar Academy
    [278]  = true,  -- Pit of Saron
    [945]  = true,  -- Seat of the Triumvirate
    [476]  = true,  -- Skyreach
}

-- runs once per session, caches dungeon/raid/boss structure
function ns:BuildInstanceCache()
    --print("|cff00ccff[DungeonAdvisor]|r Building instance cache...")
    if instanceCache then return instanceCache end

    SuppressEJ()

    local ok, result = pcall(function()
        local instances = { dungeons = {} }

        local currentTier = EJ_GetCurrentTierCompat()
        if not currentTier then return nil end

        -- scan newest tier first so returning dungeons (e.g. Algeth'ar Academy)
        -- use their rescaled version with correct item data, not the old expansion's
        local numTiers = EJ_GetNumTiersCompat()
        local foundDungeons = {}
        for tier = numTiers, 1, -1 do
            EJ_SelectTierCompat(tier)
            local index = 1
            while true do
                local instanceID, name = EJ_GetInstanceByIndexCompat(index, false)
                if not instanceID then break end
                if SEASONAL_DUNGEON_IDS[instanceID] and not foundDungeons[instanceID] then
                    foundDungeons[instanceID] = true
                    EJ_SelectInstanceCompat(instanceID)
                    local bosses = {}
                    local bi = 1
                    while true do
                        local bossName, desc, bossID = EJ_GetEncounterInfoByIndexCompat(bi)
                        if not bossName then break end
                        table.insert(bosses, { name = bossName, encounterID = bossID })
                        bi = bi + 1
                    end

                    -- check if Normal is real or just legacy garbage (old dungeons have
                    -- Normal items with super low ilvl that shouldn't be shown)
                    local hasNormal = false
                    if #bosses > 0 then
                        EJ_SelectEncounterCompat(bosses[1].encounterID)
                        EJ_SetDifficultyCompat(1)
                        EJ_SetSlotFilterCompat(EISFT.NoFilter)
                        local numLoot = EJ_GetNumLootCompat()
                        if numLoot and numLoot > 0 then
                            local testInfo = EJ_GetLootInfoByIndexCompat(1)
                            if testInfo and testInfo.link then
                                local itemID = testInfo.itemID
                                local _, _, _, itemLevel = GetItemInfo(testInfo.link)
                                if itemLevel then
                                    hasNormal = (itemLevel >= 200)
                                else
                                    -- cold cache — register miss, will re-evaluate on GET_ITEM_INFO_RECEIVED
                                    if itemID then pendingItemIDs[itemID] = true end
                                    hasNormalPending = true
                                    hasNormal = false  -- safe default: hide Normal until confirmed
                                end
                            end
                        end
                    end

                    table.insert(instances.dungeons, {
                        instanceID = instanceID,
                        name = name,
                        bosses = bosses,
                        hasNormal = hasNormal,
                    })
                    EJ_SelectTierCompat(tier)  -- EJ_SelectInstance may have changed tier
                end
                index = index + 1
            end
        end

        return instances
    end)

    UnsuppressEJ()

    if not ok then
        print("|cffff6060DungeonAdvisor:|r Instance cache error: " .. tostring(result))
        return nil
    end

    instanceCache = result
    return result
end

local function ScanLootForEncounter(instanceID, encounterID, difficultyID, classID, specID)
    local items = {}

    -- must select instance THEN encounter (EJ is stateful and order matters)
    EJ_SelectInstanceCompat(instanceID)
    EJ_SelectEncounterCompat(encounterID)
    EJ_SetDifficultyCompat(difficultyID)
    EJ_SetSlotFilterCompat(EISFT.NoFilter) -- explicitly clear slot filter every time


    if classID and specID then
        EJ_SetLootFilterCompat(classID, specID)
    end

    local index = 1
    while true do
        local info = EJ_GetLootInfoByIndexCompat(index)
        if not info or not info.name then break end
        local track = nil
        if info.link then
            track = ns:GetTrackFromItemLink(info.link)
        end
        -- fallback: if the link has no bonusIDs, derive track from the difficulty table
        if not track then
            local diff = ns:GetDifficultyByID(difficultyID)
            if diff and diff.lootTrack then
                local t = diff.lootTrack:match("^(%a+)")
                if t then track = t:upper() end
            end
        end

        table.insert(items, {
            name     = info.name,
            icon     = info.icon,
            itemID   = info.itemID,
            itemLink = info.link,
            track    = track,
        })
        index = index + 1
    end

    --print(string.format("|cff00ccffDA DEBUG:|r encounter=%d diff=%d items=%d", encounterID, difficultyID, #items))
    return items
end

local function ScanSourceType(results, instances, sourceType, difficulties, classID, specID)
    for _, inst in ipairs(instances) do
        --print(string.format("Scanning %s: %s...", sourceType, inst.name))
        for _, boss in ipairs(inst.bosses) do
            local entry = {
                sourceName  = inst.name,
                sourceType  = sourceType,
                instanceID  = inst.instanceID,
                bossName    = boss.name,
                encounterID = boss.encounterID,
                items       = {},
            }

            for _, diff in ipairs(difficulties) do
                if diff.mythicPlus then
                    -- M+ virtual columns generated below, not scanned
                else
                    local skip = false
                    if sourceType == "dungeon" and diff.id == 1 and inst.hasNormal == false then
                        skip = true  -- returning dungeon, no real Normal
                    end

                    if not skip then
                        local items = ScanLootForEncounter(inst.instanceID, boss.encounterID, diff.id, classID, specID)
                        if #items > 0 then
                            entry.items[diff.id] = items
                        end
                    end
                end
            end
            -- clone Mythic items into M+ columns with proper bonus-ID links
            --print(string.format("Scanned loot for %s - %s: %d items", entry.sourceName, entry.bossName, #(entry.items[23] or {})))
            if sourceType == "dungeon" and entry.items[23] then
                for _, diff in ipairs(difficulties) do
                    if diff.mythicPlus then
                        --print(string.format("Building M+ loot for %s - %s (%s)", entry.sourceName, entry.bossName, diff.fullName))
                        local mpItems = {}
                        for _, item in ipairs(entry.items[23]) do
                            local lootLink = item.itemLink
                            if diff.lootBonusID then
                                local built = BuildItemLinkWithBonuses(item.itemID, diff.lootBonusID)
                                if built then lootLink = built end
                            end
                            --print("  ", item.name, "->", lootLink)
                            table.insert(mpItems, {
                                name     = item.name,
                                icon     = item.icon,
                                itemID   = item.itemID,
                                itemLink = lootLink,
                            })
                        end
                        entry.items[diff.id] = mpItems
                    end
                end
            end
            local hasItems = false
            for _ in pairs(entry.items) do hasItems = true; break end
            if hasItems then
                table.insert(results, entry)
            end
        end
    end
end

function ns:ScanLoot(specIndex)
    local classID = ns.state.selectedClassID or select(3, UnitClass("player"))
    local specID
    if ns.state.isViewingOtherClass then
        specID = GetSpecializationInfoForClassID(classID, specIndex)
    else
        specID = select(1, GetSpecializationInfo(specIndex))
    end

    local cacheKey = specID
    if lootCache[cacheKey] then
        return lootCache[cacheKey]
    end

    if not instanceCache then
        local built = ns:BuildInstanceCache()
        if not built then
            print("|cffff6060DungeonAdvisor:|r Could not load instance data. Try /reload and try again.")
            return {}
        end
    end

    SuppressEJ()
    ns.isScanning = true
    --print("|cff00ccff[DungeonAdvisor]|r Scanning loot data for " .. (ns.state.isViewingOtherClass and (GetClassInfo(classID) or "Unknown Class") or "current spec") .. "...")
    local ok, results = pcall(function()
        local r = {}
        ScanSourceType(r, instanceCache.dungeons,   "dungeon",   ns.DIFFICULTIES.DUNGEON, classID, specID)
        return r
    end)

    ns.isScanning = false
    UnsuppressEJ()

    if not ok then
        print("|cffff6060DungeonAdvisor:|r Scan error: " .. tostring(results))
        return {}
    end

    if missedRefreshDuringScan then
        missedRefreshDuringScan = false
        ns:ClearLootCache()
        ScheduleRefresh()  -- trigger the refresh we missed during the scan
    end


    -- DEBUG: count total loot items per dungeon after scan
    -- local dungeonTotals = {}
    -- for _, entry in ipairs(results) do
    --     local key = entry.sourceName
    --     if not dungeonTotals[key] then dungeonTotals[key] = 0 end
    --     for diffID, items in pairs(entry.items) do
    --         dungeonTotals[key] = dungeonTotals[key] + #items
    --     end
    -- end
    -- print("|cff00ccffDungeonAdvisor DEBUG:|r Scan complete for specID=" .. tostring(cacheKey))
    -- for dungeonName, total in pairs(dungeonTotals) do
    --     print(string.format("  %s: %d total item slots", dungeonName, total))
    -- end



    lootCache[cacheKey] = results
    return results
end

function ns:IsDataPending()
    local pendingCount = 0
    for id, _ in pairs(pendingItemIDs) do
        pendingCount = pendingCount + 1
    end
    --print(string.format("|cff00ccffDA DEBUG:|r IsDataPending - pendingCount=%d, hasNormalPending=%s", pendingCount, tostring(hasNormalPending)))
    return pendingCount > 0 or hasNormalPending
end

function ns:ClearLootCache()
    wipe(lootCache)
    DungeonAdvisorLootDB = {}  -- force InitializeLootDB to rescan
end

-- debounced refresh when EJ data loads in (but not during our own scans)
local ejFrame = CreateFrame("Frame")
local refreshPending = false

local settleTimer = nil

local function ScheduleRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.5, function()
        refreshPending = false
        if DungeonAdvisorUI.frame and DungeonAdvisorUI.frame:IsShown() then
            DungeonAdvisor:InitializeLootDB()
            DungeonAdvisorUI:RefreshDungeonList()
        end
    end)

    -- reset the settle timer every time new data arrives
    if settleTimer then
        settleTimer:Cancel()
    end
    settleTimer = C_Timer.NewTimer(2.0, function()
        settleTimer = nil
        if DungeonAdvisorUI.frame and DungeonAdvisorUI.frame:IsShown() then
            DungeonAdvisorUI:HideSpinner()
        end
    end)
end

ejFrame:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
ejFrame:RegisterEvent("EJ_DIFFICULTY_UPDATE")
ejFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ejFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "GET_ITEM_INFO_RECEIVED" then
        local itemID = ...
        pendingItemIDs[itemID] = nil
    end
    if ns.isScanning then
        if event == "EJ_LOOT_DATA_RECIEVED" then
            missedRefreshDuringScan = true  -- remember we got new data mid-scan
        end
        return
    end
    ns:ClearLootCache()
    ScheduleRefresh()
end)

