local addonName, ns = ...

-- DungeonAdvisor: Calculator
-- Scores each dungeon based on potential gear upgrades, filtered by spec.
-- Scoring combines: number of upgrade slots + total ilvl gains + stat desirability.

DungeonAdvisorCalc = {}

-- Scoring weights (must sum to 1.0)
local WEIGHT_UPGRADE_COUNT = 0.40  -- how many slots have an upgrade
local WEIGHT_ILVL_GAIN     = 0.40  -- total ilvl gain across all upgrade slots
local WEIGHT_STATS         = 0.20  -- secondary stat quality of upgrades

-- Minimum ilvl gain to count as an "upgrade"
local MIN_UPGRADE_DELTA = 1

-- Stat weights per spec: how much each secondary stat matters (0.0 - 1.0).
-- Rough SimC-inspired defaults. Players can adjust these in a future settings panel.
-- Key format: "CLASS_SPECINDEX"
local STAT_WEIGHTS = {
    -- Warrior
    WARRIOR_1 = { crit=1.0, haste=0.7, mastery=0.8, versatility=0.5 }, -- Arms
    WARRIOR_2 = { crit=0.8, haste=1.0, mastery=0.6, versatility=0.5 }, -- Fury
    WARRIOR_3 = { crit=0.6, haste=0.8, mastery=0.5, versatility=1.0 }, -- Protection
    -- Paladin
    PALADIN_1 = { crit=0.7, haste=1.0, mastery=0.6, versatility=0.5 }, -- Holy
    PALADIN_2 = { crit=0.6, haste=0.8, mastery=0.5, versatility=1.0 }, -- Protection
    PALADIN_3 = { crit=1.0, haste=0.8, mastery=0.7, versatility=0.5 }, -- Retribution
    -- Death Knight
    DEATHKNIGHT_1 = { crit=0.6, haste=0.8, mastery=1.0, versatility=0.5 }, -- Blood
    DEATHKNIGHT_2 = { crit=1.0, haste=0.9, mastery=0.7, versatility=0.5 }, -- Frost
    DEATHKNIGHT_3 = { crit=0.8, haste=0.7, mastery=1.0, versatility=0.5 }, -- Unholy
    -- Demon Hunter
    DEMONHUNTER_1 = { crit=1.0, haste=0.8, mastery=0.5, versatility=0.6 }, -- Havoc
    DEMONHUNTER_2 = { crit=0.5, haste=0.8, mastery=0.7, versatility=1.0 }, -- Vengeance
    -- Shaman
    SHAMAN_1 = { crit=0.8, haste=1.0, mastery=0.7, versatility=0.5 }, -- Elemental
    SHAMAN_2 = { crit=1.0, haste=0.9, mastery=0.8, versatility=0.5 }, -- Enhancement
    SHAMAN_3 = { crit=0.6, haste=1.0, mastery=0.8, versatility=0.7 }, -- Restoration
    -- Hunter
    HUNTER_1 = { crit=0.8, haste=0.7, mastery=1.0, versatility=0.5 }, -- Beast Mastery
    HUNTER_2 = { crit=1.0, haste=0.8, mastery=0.6, versatility=0.5 }, -- Marksmanship
    HUNTER_3 = { crit=0.9, haste=1.0, mastery=0.7, versatility=0.5 }, -- Survival
    -- Monk
    MONK_1 = { crit=0.7, haste=1.0, mastery=0.8, versatility=0.6 }, -- Brewmaster
    MONK_2 = { crit=0.6, haste=1.0, mastery=0.8, versatility=0.7 }, -- Mistweaver
    MONK_3 = { crit=1.0, haste=0.8, mastery=0.7, versatility=0.5 }, -- Windwalker
    -- Druid
    DRUID_1 = { crit=0.9, haste=1.0, mastery=0.7, versatility=0.5 }, -- Balance
    DRUID_2 = { crit=1.0, haste=0.7, mastery=0.9, versatility=0.5 }, -- Feral
    DRUID_3 = { crit=0.5, haste=0.8, mastery=1.0, versatility=0.7 }, -- Guardian
    DRUID_4 = { crit=0.6, haste=1.0, mastery=0.8, versatility=0.7 }, -- Restoration
    -- Rogue
    ROGUE_1 = { crit=1.0, haste=0.8, mastery=0.7, versatility=0.5 }, -- Assassination
    ROGUE_2 = { crit=1.0, haste=0.9, mastery=0.6, versatility=0.5 }, -- Outlaw
    ROGUE_3 = { crit=1.0, haste=0.8, mastery=0.9, versatility=0.5 }, -- Subtlety
    -- Evoker
    EVOKER_1 = { crit=0.9, haste=1.0, mastery=0.7, versatility=0.5 }, -- Devastation
    EVOKER_2 = { crit=0.6, haste=1.0, mastery=0.8, versatility=0.7 }, -- Preservation
    EVOKER_3 = { crit=0.8, haste=1.0, mastery=0.9, versatility=0.5 }, -- Augmentation
    -- Mage
    MAGE_1 = { crit=0.8, haste=1.0, mastery=0.7, versatility=0.5 }, -- Arcane
    MAGE_2 = { crit=1.0, haste=0.9, mastery=0.7, versatility=0.5 }, -- Fire
    MAGE_3 = { crit=1.0, haste=0.8, mastery=0.7, versatility=0.5 }, -- Frost
    -- Warlock
    WARLOCK_1 = { crit=0.8, haste=1.0, mastery=0.7, versatility=0.5 }, -- Affliction
    WARLOCK_2 = { crit=1.0, haste=0.8, mastery=0.9, versatility=0.5 }, -- Demonology
    WARLOCK_3 = { crit=1.0, haste=0.9, mastery=0.7, versatility=0.5 }, -- Destruction
    -- Priest
    PRIEST_1 = { crit=0.7, haste=1.0, mastery=0.8, versatility=0.6 }, -- Discipline
    PRIEST_2 = { crit=0.6, haste=1.0, mastery=0.8, versatility=0.7 }, -- Holy
    PRIEST_3 = { crit=1.0, haste=0.8, mastery=0.9, versatility=0.5 }, -- Shadow
}

-- Default weights for unknown specs
local DEFAULT_WEIGHTS = { crit=0.8, haste=0.8, mastery=0.8, versatility=0.8 }

-- define which slots can have duplicates
local MULTI_SLOTS = {
    FINGER = 2,
    TRINKET = 2,
}

-- Get the stat weight table for the current player spec
local function GetSpecWeights()
    local className, specIndex = DungeonAdvisorSpecFilter:GetPlayerSpec()
    local key = className .. "_" .. specIndex
    return STAT_WEIGHTS[key] or DEFAULT_WEIGHTS
end

-- Compute a weighted stat score for a drop (0.0 - 1.0 range)
local function StatScore(drop, weights)
    local stats = ns.GetItemStatsCompat(drop.itemLink)
    local total = 0
    local maxPossible = 0
    
    -- Map weight keys to WoW stat keys
    local statKeyMap = {
        crit = "ITEM_MOD_CRIT_RATING_SHORT",
        haste = "ITEM_MOD_HASTE_RATING_SHORT", 
        mastery = "ITEM_MOD_MASTERY_RATING_SHORT",
        versatility = "ITEM_MOD_VERSATILITY"
    }
    
    for weightKey, weight in pairs(weights) do
        local wowStatKey = statKeyMap[weightKey]
        if wowStatKey then
            local val = stats[wowStatKey] or 0
            total = total + val * weight
            maxPossible = maxPossible + 350 * weight  -- 350 is a rough ceiling for a single secondary
        end
    end
    if maxPossible == 0 then return 0 end
    return math.min(total / maxPossible, 1.0)
end

--[[
    CalculateDungeonScore(dungeonDrops, playerGear)
    Returns:
        score          - combined weighted score (0-100, higher = better)
        upgradeCount   - number of slots with at least one usable upgrade
        totalIlvlGain  - sum of max ilvl gains across upgrade slots
        upgradeDetails - list of { slot, label, itemName, currentIlvl, dropIlvl, gain, stats, fromClient }
]]
function DungeonAdvisorCalc:CalculateDungeonScore(dungeonDrops, playerGear)
    local weights = GetSpecWeights()

    -- Filter to spec-usable drops first
    local usableDrops = DungeonAdvisorSpecFilter:FilterDrops(dungeonDrops)

    -- For each slot, find the best drops (up to the max count for that slot)
    local bestDropsPerSlot = {}
    for _, drop in ipairs(usableDrops) do
        local slot = drop.slot
        local maxCount = MULTI_SLOTS[slot] or 1
        if not bestDropsPerSlot[slot] then
            bestDropsPerSlot[slot] = {}
        end
        local list = bestDropsPerSlot[slot]
        table.insert(list, drop)
        -- Sort descending by ilvl, then stat score on tie
        table.sort(list, function(a, b)
            local sa = StatScore(a, weights)
            local sb = StatScore(b, weights)
            if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
            return sa > sb
        end)
        -- Trim to max allowed
        while #list > maxCount do
            table.remove(list)
        end
    end

    local upgradeCount   = 0
    local totalIlvlGain  = 0
    local totalStatScore = 0
    local upgradeDetails = {}

    for slot, drops in pairs(bestDropsPerSlot) do
        local maxCount = MULTI_SLOTS[slot] or 1

        -- Build a list of current gear for this slot type, sorted worst-first
        -- so we greedily assign each drop upgrade to the weakest current piece
        local currentPieces = {}
        for i = 1, maxCount do
            local gearKey = maxCount > 1 and (slot .. i) or slot
            local current = playerGear[gearKey]
            table.insert(currentPieces, {
                key   = gearKey,
                ilvl  = current and current.ilvl or 0,
                label = current and current.label or gearKey,
            })
        end
        -- Sort ascending so index 1 = weakest equipped piece
        table.sort(currentPieces, function(a, b) return a.ilvl < b.ilvl end)

        for dropIdx, drop in ipairs(drops) do
            -- Match each drop against the weakest remaining slot
            local current = currentPieces[dropIdx]
            if not current then break end

            local gain = drop.ilvl - current.ilvl
            if gain >= MIN_UPGRADE_DELTA then
                local stats     = ns.GetItemStatsCompat(drop.itemLink)
                local statScore = StatScore(drop, weights)

                upgradeCount   = upgradeCount + 1
                totalIlvlGain  = totalIlvlGain + gain
                totalStatScore = totalStatScore + statScore

                table.insert(upgradeDetails, {
                    slot        = current.key,
                    label       = current.label,
                    itemName    = drop.name,
                    currentIlvl = current.ilvl,
                    dropIlvl    = drop.ilvl,
                    gain        = gain,
                    stats       = stats,
                    fromClient  = true,
                })
            end
        end
    end

    -- Normalize
    local maxSlots    = 15
    local maxGain     = 300
    local normCount   = math.min(upgradeCount / maxSlots, 1.0)
    local normGain    = math.min(totalIlvlGain / maxGain, 1.0)
    local normStats   = upgradeCount > 0 and (totalStatScore / upgradeCount) or 0

    local score = (normCount * WEIGHT_UPGRADE_COUNT
                 + normGain  * WEIGHT_ILVL_GAIN
                 + normStats * WEIGHT_STATS) * 100

    -- Sort upgrades: biggest ilvl gain first
    table.sort(upgradeDetails, function(a, b) return a.gain > b.gain end)

    return score, upgradeCount, totalIlvlGain, upgradeDetails
end

--[[
    RankDungeons(playerGear)
    Returns a sorted list of dungeon results (best dungeon first).
]]
function DungeonAdvisorCalc:RankDungeons(playerGear)
    local selectedDiff = ns.state.selectedDifficulty or "M+2"  -- Default to M+2 if not set
    local dungeonMap = {}

    -- Merge boss results into per-dungeon entries (by instance ID or name)
    for _, bossEntry in ipairs(DungeonAdvisorLootDB or {}) do
        if bossEntry.items and bossEntry.items[selectedDiff] then
            local key = bossEntry.instanceID or bossEntry.sourceName or bossEntry.name
            if not key then
                key = "unknown"
            end

            local merged = dungeonMap[key]
            if not merged then
                merged = {
                    name  = bossEntry.sourceName or bossEntry.name or "Unknown Dungeon",
                    items = {},
                }
                dungeonMap[key] = merged
            end

            -- Append this boss's loot into dungeon-level loot per diff.
            merged.items[selectedDiff] = merged.items[selectedDiff] or {}
            for _, item in ipairs(bossEntry.items[selectedDiff]) do
                table.insert(merged.items[selectedDiff], item)
            end
        end
    end

    local results = {}
    for _, dungeonEntry in pairs(dungeonMap) do
        local drops = {}
        for _, item in ipairs(dungeonEntry.items[selectedDiff] or {}) do
            local source = item.itemLink or item.itemID
            if not source then
                print("[DungeonAdvisor] RankDungeons: item missing itemLink/itemID", dungeonEntry.name or "unknown")
            else
                local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
                      itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent = GetItemInfo(source)

                if not itemName or not itemLevel then
                    print(string.format("[DungeonAdvisor] RankDungeons: unresolved item, dungeon=%s item=%s", dungeonEntry.name or "unknown", tostring(source)))
                else
                    local slot = self:GetSlotFromEquipLoc(itemEquipLoc)
                    if not slot then
                        -- print(string.format("[DungeonAdvisor] RankDungeons: unknown equip slot %s for item %s", tostring(itemEquipLoc), tostring(itemName)))
                    else
                        table.insert(drops, {
                            slot       = slot,
                            name       = item.name or itemName,
                            ilvl       = itemLevel,
                            itemID     = item.itemID,
                            itemLink   = itemLink or item.itemLink,
                            armorType  = itemType,
                            weaponType = itemSubType,
                        })
                    end
                end
            end
        end

        if #drops > 0 then
            local score, upgradeCount, totalIlvlGain, upgradeDetails = self:CalculateDungeonScore(drops, playerGear)
            local efficiency = totalIlvlGain / #drops
            table.insert(results, {
                name           = dungeonEntry.name,
                score          = score,
                upgradeCount   = upgradeCount,
                totalIlvlGain  = totalIlvlGain,
                efficiency     = efficiency,
                dropCount      = #drops,
                upgradeDetails = upgradeDetails,
            })
        end
    end

    table.sort(results, function(a, b)
        if a.efficiency and b.efficiency then
            if a.efficiency ~= b.efficiency then
                return a.efficiency > b.efficiency
            end
        end
        -- Fallback to score if efficiency is equal or missing
        return (a.score or 0) > (b.score or 0)
    end)
    return results
end

-- Helper function to convert WoW equip location to slot name
function DungeonAdvisorCalc:GetSlotFromEquipLoc(equipLoc)
    local equipLocToSlot = {
        ["INVTYPE_HEAD"] = "HEAD",
        ["INVTYPE_NECK"] = "NECK", 
        ["INVTYPE_SHOULDER"] = "SHOULDER",
        ["INVTYPE_CLOAK"] = "BACK",
        ["INVTYPE_CHEST"] = "CHEST",
        ["INVTYPE_ROBE"] = "CHEST",  -- Robes are chest
        ["INVTYPE_WRIST"] = "WRIST",
        ["INVTYPE_HAND"] = "HANDS",
        ["INVTYPE_WAIST"] = "WAIST",
        ["INVTYPE_LEGS"] = "LEGS",
        ["INVTYPE_FEET"] = "FEET",
        ["INVTYPE_FINGER"] = "FINGER",
        ["INVTYPE_TRINKET"] = "TRINKET",
        ["INVTYPE_WEAPON"] = "MAINHAND",
        ["INVTYPE_2HWEAPON"] = "MAINHAND",
        ["INVTYPE_WEAPONMAINHAND"] = "MAINHAND",
        ["INVTYPE_WEAPONOFFHAND"] = "OFFHAND",
        ["INVTYPE_SHIELD"] = "OFFHAND",
        ["INVTYPE_HOLDABLE"] = "OFFHAND",
        ["INVTYPE_RANGED"] = "RANGED",
        ["INVTYPE_RANGEDRIGHT"] = "RANGED",
    }
    return equipLocToSlot[equipLoc]
end
