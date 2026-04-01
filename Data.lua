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

ns.DIFF_COLORS = {
    GREEN  = { r = 0.12, g = 0.75, b = 0.12 },
    BLUE   = { r = 0.00, g = 0.44, b = 0.87 },
    PURPLE = { r = 0.64, g = 0.21, b = 0.93 },
    ORANGE = { r = 1.00, g = 0.50, b = 0.00 },
}

function ns:GetDifficultyByID(dungeonDiff)
    for _, diff in ipairs(ns.DIFFICULTIES.DUNGEON) do
        print(diff.id, dungeonDiff)
        if diff.id == dungeonDiff then return diff end
    end
end

ns.DIFFICULTIES = {
    DUNGEON = {
        { id = 1,  name = "N",  fullName = "Normal",  color = "GREEN"  },
        { id = 2,  name = "H",  fullName = "Heroic",  color = "BLUE",
          lootIlvl = 230, vaultIlvl = 243, lootColor = "GREEN", vaultColor = "BLUE",
          lootTrack = "Adventurer 4/6", vaultTrack = "Veteran 4/6" },
        { id = 23, name = "M",  fullName = "Mythic",  color = "PURPLE",
          lootIlvl = 246, vaultIlvl = 256, lootColor = "BLUE",  vaultColor = "BLUE",
          lootTrack = "Champion 1/6", vaultTrack = "Champion 4/6" },
        -- M+ virtual columns: same items as Mythic but ilvl scales with key level.
        -- Only showing breakpoints where loot ilvl actually changes.
        { id = "M+2",  name = "M2",  fullName = "Mythic+ 2-3",   color = "PURPLE", mythicPlus = true,
          lootIlvl = 250, vaultIlvl = 259, lootColor = "BLUE",   vaultColor = "PURPLE",
          lootTrack = "Champion 2/6", vaultTrack = "Hero 1/6",
          lootBonusID = "CHAMPION_2", vaultBonusID = "HERO_1" },
        { id = "M+4",  name = "M4",  fullName = "Mythic+ 4",     color = "PURPLE", mythicPlus = true,
          lootIlvl = 253, vaultIlvl = 263, lootColor = "BLUE",   vaultColor = "PURPLE",
          lootTrack = "Champion 3/6", vaultTrack = "Hero 2/6",
          lootBonusID = "CHAMPION_3", vaultBonusID = "HERO_2" },
        { id = "M+5",  name = "M5",  fullName = "Mythic+ 5",     color = "PURPLE", mythicPlus = true,
          lootIlvl = 256, vaultIlvl = 263, lootColor = "BLUE",   vaultColor = "PURPLE",
          lootTrack = "Champion 4/6", vaultTrack = "Hero 2/6",
          lootBonusID = "CHAMPION_4", vaultBonusID = "HERO_2" },
        { id = "M+6",  name = "M6",  fullName = "Mythic+ 6-7",   color = "PURPLE", mythicPlus = true,
          lootIlvl = 259, vaultIlvl = 266, lootColor = "PURPLE", vaultColor = "PURPLE",
          lootTrack = "Hero 1/6", vaultTrack = "Hero 3/6",
          lootBonusID = "HERO_1", vaultBonusID = "HERO_3" },
        { id = "M+8",  name = "M8",  fullName = "Mythic+ 8-9",   color = "PURPLE", mythicPlus = true,
          lootIlvl = 263, vaultIlvl = 269, lootColor = "PURPLE", vaultColor = "PURPLE",
          lootTrack = "Hero 2/6", vaultTrack = "Hero 4/6",
          lootBonusID = "HERO_2", vaultBonusID = "HERO_4" },
        { id = "M+10", name = "M10", fullName = "Mythic+ 10-12", color = "PURPLE", mythicPlus = true,
          lootIlvl = 266, vaultIlvl = 272, lootColor = "PURPLE", vaultColor = "ORANGE",
          lootTrack = "Hero 3/6", vaultTrack = "Myth 1/6",
          lootBonusID = "HERO_3", vaultBonusID = "MYTH_1" },
    },
}

-- strict enum typing required by WoW
local EISFT = Enum.ItemSlotFilterType
ns.SLOT_FILTERS = {
    { name = "Head",      filter = EISFT.Head      },
    { name = "Neck",      filter = EISFT.Neck      },
    { name = "Shoulder",  filter = EISFT.Shoulder  },
    { name = "Back",      filter = EISFT.Cloak     },
    { name = "Chest",     filter = EISFT.Chest     },
    { name = "Wrist",     filter = EISFT.Wrist     },
    { name = "Hands",     filter = EISFT.Hand      },
    { name = "Waist",     filter = EISFT.Waist     },
    { name = "Legs",      filter = EISFT.Legs      },
    { name = "Feet",      filter = EISFT.Feet      },
    { name = "Finger",    filter = EISFT.Finger    },
    { name = "Trinket",   filter = EISFT.Trinket   },
    { name = "Main Hand", filter = EISFT.MainHand  },
    { name = "Off Hand",  filter = EISFT.OffHand   },
}

-- vers uses ITEM_MOD_VERSATILITY (no _SHORT suffix, blizz being blizz)
ns.SECONDARY_STATS = {
    { key = "ITEM_MOD_CRIT_RATING_SHORT",   short = "Crit",    name = "Critical Strike" },
    { key = "ITEM_MOD_HASTE_RATING_SHORT",  short = "Haste",   name = "Haste" },
    { key = "ITEM_MOD_MASTERY_RATING_SHORT", short = "Mastery", name = "Mastery" },
    { key = "ITEM_MOD_VERSATILITY",          short = "Vers",    name = "Versatility" },
}

-- M+ bonus IDs for Midnight S1
-- Maps upgrade track tier to the bonus ID that produces that ilvl + track display.
-- Each upgrade track uses consecutive bonus IDs with a 2-ID gap between tracks.
-- The bonus ID encodes BOTH ilvl AND upgrade track (e.g., Champion 2/6 vs Hero 2/6
-- are the same ilvl 250/263 but different bonus IDs).
local TRACK_BONUS_IDS = {
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
}

local ITEM_QUALITY_COLORS = {
    [0] = "ff9d9d9d", -- Poor
    [1] = "ffffffff", -- Common
    [2] = "ff1eff00", -- Uncommon
    [3] = "ff0070dd", -- Rare
    [4] = "ffa335ee", -- Epic
    [5] = "ffff8000", -- Legendary
}

local function BuildItemLinkWithBonuses(itemID, trackBonusKey)
    if not itemID or not trackBonusKey then return nil end

    local bonusID = TRACK_BONUS_IDS[trackBonusKey]
    if not bonusID then return nil end

    local playerLevel = UnitLevel("player") or 80
    local itemString = "item:" .. itemID .. "::::::::" .. playerLevel .. "::::1:" .. bonusID

    local itemName, _, itemQuality = GetItemInfo(itemID)
    if not itemName then
        --print("|cff00ccffDA DEBUG:|r Registering pending itemID=" .. tostring(itemID))
        pendingItemIDs[itemID] = true
        return nil
    end

    local colorHex = ITEM_QUALITY_COLORS[itemQuality] or ITEM_QUALITY_COLORS[4]
    return "|c" .. colorHex .. "|H" .. itemString .. "|h[" .. itemName .. "]|h|r"
end

local lootCache = {}
local instanceCache = nil
ns.isScanning = false
local pendingItemIDs = {}       -- itemIDs we're waiting on from server cache
local hasNormalPending = false  -- instanceCache has unresolved hasNormal checks
local lastItemReceivedTime = 0
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

function ns:IsDataSettled()
    local pending = next(pendingItemIDs)
    local timeSince = GetTime() - lastItemReceivedTime
    print(string.format("|cff00ccffDungeonAdvisor DEBUG:|r IsDataSettled - pendingItemIDs empty: %s, timeSince: %.2f", tostring(pending == nil), timeSince))
    return pending == nil and timeSince > 0.5
end

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
        table.insert(items, {
            name     = info.name,
            icon     = info.icon,
            itemID   = info.itemID,
            itemLink = info.link,
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
                            local vaultLink = nil
                            if diff.vaultBonusID then
                                vaultLink = BuildItemLinkWithBonuses(item.itemID, diff.vaultBonusID)
                            end
                            --print("  ", item.name, "->", lootLink, "and", vaultLink)
                            table.insert(mpItems, {
                                name          = item.name,
                                icon          = item.icon,
                                itemID        = item.itemID,
                                itemLink      = lootLink,
                                vaultItemLink = vaultLink,
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

-- filters scan results to items with ALL selected stats (1 = any combo, 2 = exact combo)
function ns:FilterResultsByStats(results, statKeys)
    if not statKeys or #statKeys == 0 then return results, 0 end

    local preFilterCount = #results
    local filtered = {}
    for _, entry in ipairs(results) do
        local newEntry = {
            sourceName  = entry.sourceName,
            sourceType  = entry.sourceType,
            instanceID  = entry.instanceID,
            bossName    = entry.bossName,
            encounterID = entry.encounterID,
            items       = {},
        }

        for diffID, items in pairs(entry.items) do
            local kept = {}
            for _, item in ipairs(items) do
                if not item.itemLink then
                    table.insert(kept, item)  -- no link = keep (uncached)
                else
                    local stats = GetItemStatsCompat(item.itemLink)
                    if not stats then
                        table.insert(kept, item)  -- stats not cached, keep to be safe
                    else
                        local hasAll = true
                        for _, key in ipairs(statKeys) do
                            if not stats[key] then
                                hasAll = false
                                break
                            end
                        end
                        if hasAll then
                            table.insert(kept, item)
                        end
                    end
                end
            end
            if #kept > 0 then
                newEntry.items[diffID] = kept
            end
        end

        local hasItems = false
        for _ in pairs(newEntry.items) do hasItems = true; break end
        if hasItems then
            table.insert(filtered, newEntry)
        end
    end
    return filtered, preFilterCount
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

function ns:ClearAllCaches()
    wipe(lootCache)
    instanceCache = nil
end

-- debounced refresh when EJ data loads in (but not during our own scans)
local ejFrame = CreateFrame("Frame")
local refreshPending = false

function ns:ResetRefreshPending() refreshPending = false end

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
    if ns.isScanning then
        if event == "EJ_LOOT_DATA_RECIEVED" then
            missedRefreshDuringScan = true  -- remember we got new data mid-scan
        end
        return
    end
    ns:ClearLootCache()
    ScheduleRefresh()
end)

