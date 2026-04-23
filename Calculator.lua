local addonName, ns = ...

-- DungeonAdvisor: Calculator
-- Scores each dungeon based on potential gear upgrades, filtered by spec.
-- Scoring combines: number of upgrade slots + total ilvl gains + stat desirability.

DungeonAdvisorCalc = {}

-- Minimum ilvl gain to count as an "upgrade"
local MIN_UPGRADE_DELTA = 1

-- Stat weights per spec: how much each secondary stat matters (0.0 - 1.0).
-- Rough SimC-inspired defaults. Players can adjust these in a future settings panel.
-- Key format: "CLASS_SPECINDEX"
DungeonAdvisorCalc.STAT_WEIGHTS = { --TODO did top row of classes from wowhead
    -- Warrior
    WARRIOR_1 = { crit=1.0, haste=0.9, mastery=0.8, versatility=0.5 }, -- Arms
    WARRIOR_2 = { crit=1.0, haste=0.8, mastery=0.9, versatility=0.5 }, -- Fury
    WARRIOR_3 = { crit=0.9, haste=1.0, mastery=0.5, versatility=0.8 }, -- Protection
    -- Paladin
    PALADIN_1 = { crit=0.9, haste=0.8, mastery=1.0, versatility=0.5 }, -- Holy
    PALADIN_2 = { crit=0.75, haste=1.0, mastery=0.75, versatility=0.9 }, -- Protection
    PALADIN_3 = { crit=0.9, haste=0.8, mastery=1.0, versatility=0.5 }, -- Retribution
    -- Death Knight
    DEATHKNIGHT_1 = { crit=1.0, haste=1.0, mastery=1.0, versatility=1.0 }, -- Blood
    DEATHKNIGHT_2 = { crit=1.0, haste=0.8, mastery=0.9, versatility=0.5 }, -- Frost
    DEATHKNIGHT_3 = { crit=0.9, haste=0.8, mastery=1.0, versatility=0.5 }, -- Unholy
    -- Demon Hunter
    DEMONHUNTER_1 = { crit=1.0, haste=0.8, mastery=0.9, versatility=0.5 }, -- Havoc
    DEMONHUNTER_2 = { crit=0.9, haste=1.0, mastery=0.5, versatility=0.8 }, -- Vengeance
    DEMONHUNTER_3 = { crit=0.7, haste=1.0, mastery=0.9, versatility=0.5 }, -- Devourer
    -- Shaman
    SHAMAN_1 = { crit=0.8, haste=0.9, mastery=1.0, versatility=0.5 }, -- Elemental
    SHAMAN_2 = { crit=0.8, haste=0.9, mastery=1.0, versatility=0.5 }, -- Enhancement
    SHAMAN_3 = { crit=1.0, haste=0.5, mastery=0.8, versatility=0.9 }, -- Restoration
    -- Hunter
    HUNTER_1 = { crit=0.8, haste=0.9, mastery=1.0, versatility=0.5 }, -- Beast Mastery
    HUNTER_2 = { crit=1.0, haste=0.8, mastery=0.6, versatility=0.5 }, -- Marksmanship
    HUNTER_3 = { crit=1.0, haste=0.8, mastery=0.9, versatility=0.5 }, -- Survival
    -- Monk
    MONK_1 = { crit=1.0, haste=0.6, mastery=0.95, versatility=0.9 }, -- Brewmaster
    MONK_2 = { crit=0.9, haste=1.0, mastery=0.5, versatility=0.8 }, -- Mistweaver
    MONK_3 = { crit=0.9, haste=1.0, mastery=0.8, versatility=0.5 }, -- Windwalker
    -- Druid
    DRUID_1 = { crit=0.9, haste=0.8, mastery=1.0, versatility=0.5 }, -- Balance
    DRUID_2 = { crit=0.9, haste=0.8, mastery=1.0, versatility=0.5 }, -- Feral
    DRUID_3 = { crit=0.8, haste=1.0, mastery=0.5, versatility=0.9 }, -- Guardian
    DRUID_4 = { crit=0.5, haste=1.0, mastery=0.9, versatility=0.8 }, -- Restoration
    -- Rogue
    ROGUE_1 = { crit=1.0, haste=0.9, mastery=0.8, versatility=0.5 }, -- Assassination
    ROGUE_2 = { crit=0.9, haste=1.0, mastery=0.5, versatility=0.8 }, -- Outlaw
    ROGUE_3 = { crit=0.8, haste=0.9, mastery=1.0, versatility=0.5 }, -- Subtlety
    -- Evoker
    EVOKER_1 = { crit=1.0, haste=0.9, mastery=0.9, versatility=0.5 }, -- Devastation
    EVOKER_2 = { crit=0.9, haste=0.9, mastery=1.0, versatility=0.5 }, -- Preservation
    EVOKER_3 = { crit=1.0, haste=0.9, mastery=0.8, versatility=0.5 }, -- Augmentation
    -- Mage
    MAGE_1 = { crit=0.9, haste=0.8, mastery=1.0, versatility=0.7 }, -- Arcane
    MAGE_2 = { crit=0.7, haste=1.0, mastery=0.9, versatility=0.8 }, -- Fire
    MAGE_3 = { crit=0.9, haste=0.8, mastery=1.0, versatility=0.7 }, -- Frost
    -- Warlock
    WARLOCK_1 = { crit=0.9, haste=0.8, mastery=1.0, versatility=0.5 }, -- Affliction
    WARLOCK_2 = { crit=1.0, haste=1.0, mastery=0.8, versatility=0.5 }, -- Demonology
    WARLOCK_3 = { crit=0.8, haste=1.0, mastery=0.9, versatility=0.5 }, -- Destruction
    -- Priest
    PRIEST_1 = { crit=0.9, haste=1.0, mastery=0.8, versatility=0.5 }, -- Discipline
    PRIEST_2 = { crit=1.0, haste=0.8, mastery=0.9, versatility=0.9 }, -- Holy
    PRIEST_3 = { crit=0.8, haste=1.0, mastery=0.9, versatility=0.5 }, -- Shadow
}

-- Default weights for unknown specs
DungeonAdvisorCalc.DEFAULT_WEIGHTS = { crit=0.8, haste=0.8, mastery=0.8, versatility=0.8 }

-- define which slots can have duplicates
local MULTI_SLOTS = {
    FINGER = 2,
    TRINKET = 2,
}

local MULTI_SLOT_LABELS = {
    FINGER  = "Ring",
    TRINKET = "Trinket",
}

-- Map weight keys to WoW stat keys
DungeonAdvisorCalc.STAT_KEY_MAP = {
    crit = "ITEM_MOD_CRIT_RATING_SHORT",
    haste = "ITEM_MOD_HASTE_RATING_SHORT", 
    mastery = "ITEM_MOD_MASTERY_RATING_SHORT",
    versatility = "ITEM_MOD_VERSATILITY"
}

function ns:StatRatioScore(stats)
    if not stats then return 0 end
    local weights     = ns:GetSpecWeights()
    local totalStats  = 0
    local totalWeight = 0
    for shortKey, w in pairs(weights) do
        local wowKey = DungeonAdvisorCalc.STAT_KEY_MAP[shortKey]
        if wowKey then totalStats = totalStats + (stats[wowKey] or 0) end
        totalWeight = totalWeight + w
    end
    if totalStats == 0 or totalWeight == 0 then return 0 end
    local score = 0
    for shortKey, w in pairs(weights) do
        local wowKey   = DungeonAdvisorCalc.STAT_KEY_MAP[shortKey]
        local statProp = wowKey and ((stats[wowKey] or 0) / totalStats) or 0
        score = score + statProp * (w / totalWeight)
    end
    return score
end

local function StatScore(drop, weights)
    local stats = ns.GetItemStatsCompat(drop.itemLink)
    if not stats then return 0 end
    local total      = 0
    local maxPossible = 0
    for weightKey, weight in pairs(weights) do
        local wowStatKey = DungeonAdvisorCalc.STAT_KEY_MAP[weightKey]
        if wowStatKey then
            total       = total       + (stats[wowStatKey] or 0) * weight
            maxPossible = maxPossible + 350 * weight
        end
    end
    if maxPossible == 0 then return 0 end
    return math.min(total / maxPossible, 1.0)
end

function ns:SecondaryStatScore(stats, weights)
    if not stats then return 0 end
    return
        (stats["ITEM_MOD_CRIT_RATING_SHORT"] or 0)    * (weights.crit or 0) +
        (stats["ITEM_MOD_HASTE_RATING_SHORT"] or 0)   * (weights.haste or 0) +
        (stats["ITEM_MOD_MASTERY_RATING_SHORT"] or 0) * (weights.mastery or 0) +
        (stats["ITEM_MOD_VERSATILITY"] or 0)    * (weights.versatility or 0)
end

-- Handle weapons separately
local function ScoreWeaponLoadout(drops, playerGear, weights)
    local upgradeCount = 0
    local statUpgradeCount = 0
    local trackUpgradeCount = 0
    local MAINHAND_SLOT = 16
    local OFFHAND_SLOT = 17
    local mhLink = GetInventoryItemLink("player", MAINHAND_SLOT)
    local ohLink = GetInventoryItemLink("player", OFFHAND_SLOT)
    local mhStats = ns.GetItemStatsCompat(mhLink)
    local ohStats = ns.GetItemStatsCompat(ohLink)

    local currentMH     = playerGear["MAINHAND"]
    local currentOH     = playerGear["OFFHAND"]
    local currentMHilvl = currentMH and currentMH.ilvl or 0
    local currentOHilvl = ns.playerUsing2H and 0 or (currentOH and currentOH.ilvl or 0)
    local currentMHisCrafted = currentMH and currentMH.isCrafted or false
    local currentOHisCrafted = currentOH and currentOH.isCrafted or false

    local best2H  = nil
    local best1H  = nil
    local bestOH  = nil
    local all1H   = {}
    local allOH   = {}
    local all2H   = {}

    for _, drop in ipairs(drops) do
        local is2H = drop.itemType == "Weapon" and (
            drop.itemSubType == "Two-Handed Swords" or
            drop.itemSubType == "Two-Handed Axes"   or
            drop.itemSubType == "Two-Handed Maces"  or
            drop.itemSubType == "Polearms"          or
            drop.itemSubType == "Staves"            or
            drop.itemSubType == "Bows"              or
            drop.itemSubType == "Guns"              or
            drop.itemSubType == "Crossbows"
        )
        if ns:IsCraftedItem(drop.itemLink) then
        -- skip crafted drops entirely
        elseif is2H then
            table.insert(all2H, drop)
            if not best2H or drop.ilvl > best2H.ilvl then best2H = drop end
        elseif drop.slot == "OFFHAND" then
            table.insert(allOH, drop)
            if not bestOH or drop.ilvl > bestOH.ilvl then bestOH = drop end
        else
            table.insert(all1H, drop)
            if not best1H or drop.ilvl > best1H.ilvl then best1H = drop end
        end
    end

    -- Determine which loadout wins for SCORING purposes only
    local current2Hilvl = ns.playerUsing2H and currentMHilvl or math.max(currentMHilvl, currentOHilvl)
    local gain2H = best2H and math.max(0, best2H.ilvl - current2Hilvl) or 0
    local gain1H = 0
    if best1H then gain1H = gain1H + math.max(0, best1H.ilvl - currentMHilvl) end
    if bestOH and not ns.playerUsing2H then
        gain1H = gain1H + math.max(0, bestOH.ilvl - currentOHilvl)
    end
    local upgrades = {}
    local scoringGain = 0

    -- process all weapon types regardless of mode
    local function ProcessWeaponDrop(drop, compareIlvl, compareStats, compareTrack, compareIsCrafted, slotKey, slotLabel)
        local gain = drop.ilvl - compareIlvl
        local stats = ns.GetItemStatsCompat(drop.itemLink)
        local dropRatio = ns:StatRatioScore(stats)
        local currentRatio = ns:StatRatioScore(compareStats)
        local dropTrack = ns:GetTrackFromItemLink(drop.itemLink) or drop.track
        local dropTrackOrder = dropTrack and ns.TRACK_ORDER[dropTrack] or 0
        local compareTrackOrder = (not compareIsCrafted and compareTrack) and ns.TRACK_ORDER[compareTrack] or 0

        local isIlvlUpgrade  = gain >= MIN_UPGRADE_DELTA
        local isTrackUpgrade = (not compareIsCrafted) and (dropTrackOrder > compareTrackOrder)
        local isStatUpgrade  = (not compareIsCrafted) and (dropTrackOrder >= compareTrackOrder) and (dropRatio > currentRatio + 0.01)
    
        if isIlvlUpgrade  then upgradeCount     = upgradeCount     + 1 end
        if isTrackUpgrade then trackUpgradeCount = trackUpgradeCount + 1 end
        if isStatUpgrade  then statUpgradeCount  = statUpgradeCount  + 1 end

        if isIlvlUpgrade or isTrackUpgrade or isStatUpgrade then
            table.insert(upgrades, {
                slot          = slotKey,
                label         = slotLabel,
                itemName      = drop.name,
                currentIlvl   = compareIlvl,
                dropIlvl      = drop.ilvl,
                gain          = isIlvlUpgrade and gain or 0,
                itemLink      = drop.itemLink,
                stats         = stats,
                secondaryStatScore        = ns:SecondaryStatScore(stats, weights),
                currentSecondaryStatScore = ns:SecondaryStatScore(compareStats, weights),
                dropTrack     = dropTrack,
                currentTrack  = compareTrack,
                isTrackUpgrade = isTrackUpgrade,
                isStatUpgrade  = isStatUpgrade,
                fromClient    = true,
            })
        end
    end

    -- 2H weapons compare against best of MH+OH ilvl
    --And always count for ilvl upgrades
    for _, drop in ipairs(all2H) do
        ProcessWeaponDrop(drop,
            math.max(currentMHilvl, currentOHilvl),
            mhStats,
            currentMH and currentMH.track,
            currentMHisCrafted,
            "MAINHAND",
            currentMH and currentMH.label or "Main Hand")
    end

    -- Only count 1h/offhand as viable drops if we're in 1h mode
    if ns.weaponMode ~= "2H" then
        -- 1H weapons compare against MH
        for _, drop in ipairs(all1H) do
            ProcessWeaponDrop(drop,
                currentMHilvl,
                mhStats,
                currentMH and currentMH.track,
                currentMHisCrafted,
                "MAINHAND",
                currentMH and currentMH.label or "Main Hand")
        end

        -- offhands compare against OH
        for _, drop in ipairs(allOH) do
            ProcessWeaponDrop(drop,
                currentOHilvl,
                ohStats,
                currentOH and currentOH.track,
                currentOHisCrafted,
                "OFFHAND",
                "Off Hand")
        end
    end

    -- Use only the winning loadout's gain for scoring to avoid inflating numbers
    if ns.weaponMode == "2H" then
        scoringGain = gain2H
    else
        scoringGain = gain1H
    end

    return upgrades, scoringGain
end

--[[
    CalculateDungeonScore(dungeonDrops, playerGear)
    Returns:
        upgradeCount   - number of slots with at least one usable upgrade
        totalIlvlGain  - sum of max ilvl gains across upgrade slots
        upgradeDetails - list of { slot, label, itemName, currentIlvl, dropIlvl, gain, stats, fromClient }
]]
function DungeonAdvisorCalc:CalculateDungeonScore(dungeonDrops, playerGear)
    local weights = ns:GetSpecWeights()

    -- Shared cache for stat scores within this scoring pass
    local scoreCache = {}
    local function CachedStatScore(drop)
        local key = drop.itemLink or drop.name or tostring(drop)
        if not scoreCache[key] then
            scoreCache[key] = StatScore(drop, weights)
        end
        return scoreCache[key]
    end

    local weaponDrops = {}
    local armorDrops  = {}
    for _, drop in ipairs(dungeonDrops) do
        if drop.slot == "MAINHAND" or drop.slot == "OFFHAND" then
            table.insert(weaponDrops, drop)
        else
            table.insert(armorDrops, drop)
        end
    end

    local upgradeCount   = 0
    local totalIlvlGain  = 0
    local upgradeDetails = {}
    local statUpgradeCount = 0
    local statOnlyUpgrades = {}
    local trackUpgradeCount = 0

    -- Group all drops by slot (no trimming here)
    local dropsBySlot = {}
    for _, drop in ipairs(armorDrops) do
        local slot = drop.slot
        if not dropsBySlot[slot] then
            dropsBySlot[slot] = {}
        end
        table.insert(dropsBySlot[slot], drop)
        -- Keep sorted descending by ilvl, break ties by stat score
        table.sort(dropsBySlot[slot], function(a, b)
            if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
            return CachedStatScore(a) > CachedStatScore(b)
        end)
    end

    for slot, drops in pairs(dropsBySlot) do
        local maxCount = MULTI_SLOTS[slot] or 1

        -- Build current equipped pieces for this slot, sorted weakest first
        local currentPieces = {}
        for i = 1, maxCount do
            local gearKey = maxCount > 1 and (slot .. i) or slot
            local current = playerGear[gearKey]
            --print("Gear score: " .. playerGear[gearKey].secondaryStatScore)
            table.insert(currentPieces, {
                key                = gearKey,
                ilvl               = current and current.ilvl or 0,
                label              = current and current.label or gearKey,
                secondaryStatScore = current and current.secondaryStatScore or 0,
                stats              = current and current.stats or nil,
                track              = (current and not current.isCrafted) and current.track or nil,
                isCrafted          = current and current.isCrafted or false,
            })
        end
        table.sort(currentPieces, function(a, b) return a.ilvl < b.ilvl end)

        -- SCORING: count every drop that upgrades any equipped piece,
        -- but only sum ilvl gain for the best maxCount assignments to avoid inflation
        local usedDrops = {}

        -- First pass: greedy assignment for ilvl gain scoring (capped at maxCount)
        for _, current in ipairs(currentPieces) do
            for dropIdx, drop in ipairs(drops) do
                if not usedDrops[dropIdx] then
                    local gain = drop.ilvl - current.ilvl
                    if gain >= MIN_UPGRADE_DELTA then
                        totalIlvlGain  = totalIlvlGain + gain
                        usedDrops[dropIdx] = true
                    end
                    break
                end
            end
        end

        -- Find everything that is either an ilvl upgrade, a stat upgrade, or a track upgrade
        -- Track how many of each upgrade happens here
        for _, drop in ipairs(drops) do
            local dropStats = ns.GetItemStatsCompat(drop.itemLink)
            local dropTrack = ns:GetTrackFromItemLink(drop.itemLink) or drop.track
            local dropTrackOrder = dropTrack and ns.TRACK_ORDER[dropTrack] or 0
            local dropRatio = ns:StatRatioScore(dropStats)

            local isIlvlUpgrade  = false
            local isStatUpgrade  = false
            local isTrackUpgrade = false
            local bestIlvlCurrent  = nil  -- weakest piece this beats on ilvl
            local worstTrackCurrent = nil  -- lowest track piece (for track comparison)
            local bestStatCurrent = nil  -- reference piece that triggered stat upgrade

            for _, current in ipairs(currentPieces) do
                local currentTrackOrder = current.track and ns.TRACK_ORDER[current.track] or 0
                local currentRatio = ns:StatRatioScore(current.stats)

                -- ilvl: beats the weakest piece
                if (drop.ilvl - current.ilvl) >= MIN_UPGRADE_DELTA then
                    isIlvlUpgrade = true
                    if not bestIlvlCurrent or current.ilvl < bestIlvlCurrent.ilvl then
                        bestIlvlCurrent = current
                    end
                end

                -- stat: beats any piece, but only if drop track is same or better
                if dropRatio > currentRatio + 0.01 and dropTrackOrder >= currentTrackOrder and not ns:startsWith(current.key, "TRINKET") then
                    isStatUpgrade = true
                    if not bestStatCurrent then bestStatCurrent = current end
                end

                    -- track: find worst track piece
                if not current.isCrafted then
                    if not worstTrackCurrent then
                        worstTrackCurrent = current
                    else
                        local worstTrackOrder = worstTrackCurrent.track and ns.TRACK_ORDER[worstTrackCurrent.track] or 0
                        if currentTrackOrder < worstTrackOrder then
                            worstTrackCurrent = current
                        end
                    end
                end
            end

            -- track upgrade only if it beats the worst track in this slot
            if worstTrackCurrent then
                local worstTrackOrder = worstTrackCurrent.track and ns.TRACK_ORDER[worstTrackCurrent.track] or 0
                if dropTrackOrder > worstTrackOrder then
                    isTrackUpgrade = true
                end
            end

            if isIlvlUpgrade or isStatUpgrade or isTrackUpgrade then
                -- use weakest ilvl piece as display reference, fall back to track or stat piece
                local displayCurrent = bestIlvlCurrent or worstTrackCurrent or bestStatCurrent
                if displayCurrent then
                    local ignoredSlot = ns:GetEffectiveIgnoreTiers()[displayCurrent.key]
                    local displayLabel = MULTI_SLOT_LABELS[slot] or displayCurrent.label
                    local gain = drop.ilvl - displayCurrent.ilvl

                    if isIlvlUpgrade then upgradeCount = upgradeCount + 1 end
                    if isStatUpgrade  and not ignoredSlot then statUpgradeCount  = statUpgradeCount  + 1 end
                    if isTrackUpgrade then trackUpgradeCount = trackUpgradeCount + 1 end

                    local targetList = isIlvlUpgrade and upgradeDetails or statOnlyUpgrades
                    table.insert(targetList, {
                        slot          = displayCurrent.key,
                        label         = displayLabel,
                        itemName      = drop.name,
                        itemLink      = drop.itemLink,
                        currentIlvl   = displayCurrent.ilvl,
                        dropIlvl      = drop.ilvl,
                        gain          = isIlvlUpgrade and gain or 0,
                        stats         = dropStats,
                        currentStats  = displayCurrent.stats,
                        secondaryStatScore        = ns:SecondaryStatScore(dropStats, weights),
                        currentSecondaryStatScore = displayCurrent.secondaryStatScore,
                        dropTrack     = dropTrack,
                        currentTrack  = worstTrackCurrent and worstTrackCurrent.track or nil,
                        isTrackUpgrade = isTrackUpgrade,
                        isStatUpgrade  = isStatUpgrade,
                        fromClient    = true,
                    })
                end
            end

        end
    end

    local weaponUpgrades, weaponScoringGain = ScoreWeaponLoadout(weaponDrops, playerGear, weights)
    for _, wu in ipairs(weaponUpgrades) do
        if wu.gain > 0 then
            upgradeCount  = upgradeCount + 1
        end
        if wu.isStatUpgrade then
            statUpgradeCount = statUpgradeCount + 1
        end
        if wu.isTrackUpgrade then
            trackUpgradeCount = trackUpgradeCount + 1
        end

        table.insert(upgradeDetails, wu)
    end
    totalIlvlGain = totalIlvlGain + weaponScoringGain  -- but only score the best loadout

    -- Sort upgrades: biggest ilvl gain first
    table.sort(upgradeDetails, function(a, b) return a.gain > b.gain end)

    return upgradeCount, totalIlvlGain, upgradeDetails, statUpgradeCount, statOnlyUpgrades, trackUpgradeCount
end

--[[
    RankDungeons()
    Returns a sorted list of dungeon results (best dungeon first).
]]
function DungeonAdvisorCalc:RankDungeons()
    -- Ensure player gear is available (scan if needed)
    local playerGear = DungeonAdvisor.playerGear or DungeonAdvisor:GetEquippedGear()
    if not playerGear or next(playerGear) == nil then
        print("|cff00ccff[DungeonAdvisor]|r Player gear not available. Try rescanning.")
        return
    end

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
                    --print(string.format("[DungeonAdvisor] RankDungeons: unresolved item, dungeon=%s item=%s", dungeonEntry.name or "unknown", tostring(source)))
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
                            itemLink   = item.itemLink,
                            track      = item.track,
                            itemType  = itemType,
                            itemSubType = itemSubType,
                        })
                    end
                end
            end
        end
        --print(string.format("[DungeonAdvisor] %s: found %d drops for %s", selectedDiff, #drops, dungeonEntry.name or "unknown"))
        if #drops > 0 then
            local upgradeCount, totalIlvlGain, upgradeDetails, statUpgradeCount, statOnlyUpgrades, trackUpgradeCount = self:CalculateDungeonScore(drops, playerGear)
            -- Voidcore: everything drops at Myth 1/6, so stat quality dominates;
            -- ilvl gains are marginally useful, track upgrades are irrelevant.
            local wIlvlDensity, wUpgradeRate, wStatQuality, wTrack
            if selectedDiff == "Voidcore" then
                wIlvlDensity = 0.05
                wUpgradeRate = 1
                wStatQuality = 12
                wTrack       = 1
            else
                wIlvlDensity = ns.W_ILVL_DENSITY
                wUpgradeRate = ns.W_UPGRADE_RATE
                wStatQuality = ns.W_STAT_QUALITY
                wTrack       = ns.W_TRACK
            end
            local ilvlDensity  = totalIlvlGain / #drops * wIlvlDensity
            local upgradeRate  = upgradeCount / #drops * wUpgradeRate
            local statQuality  = statUpgradeCount / #drops * wStatQuality
            local trackQuality = trackUpgradeCount / #drops * wTrack
            local efficiency   = ilvlDensity + upgradeRate + statQuality + trackQuality

            table.insert(results, {
                name             = dungeonEntry.name,
                upgradeCount     = upgradeCount,
                totalIlvlGain    = totalIlvlGain,
                efficiency       = efficiency,
                dropCount        = #drops,
                upgradeDetails   = upgradeDetails,
                statUpgradeCount = statUpgradeCount,
                statOnlyUpgrades = statOnlyUpgrades,
                trackUpgradeCount = trackUpgradeCount,
            })
        end
    end

    table.sort(results, function(a, b)
        return (a.efficiency or 0) > (b.efficiency or 0)
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
    }
    return equipLocToSlot[equipLoc]
end
