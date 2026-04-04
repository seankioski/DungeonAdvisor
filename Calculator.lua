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
DungeonAdvisorCalc.STAT_WEIGHTS = {
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
    local weights = ns:GetSpecWeights()
    local totalStats = 0
    for shortKey, _ in pairs(weights) do
        local wowKey = DungeonAdvisorCalc.STAT_KEY_MAP[shortKey]
        if wowKey then totalStats = totalStats + (stats[wowKey] or 0) end
    end
    if totalStats == 0 then return 0 end
    local score = 0
    local totalWeight = 0
    for _, w in pairs(weights) do totalWeight = totalWeight + w end
    for shortKey, w in pairs(weights) do
        local wowKey = DungeonAdvisorCalc.STAT_KEY_MAP[shortKey]
        local statProp = wowKey and ((stats[wowKey] or 0) / totalStats) or 0
        score = score + statProp * (w / totalWeight)
    end
    return score
end

-- Handle weapons separately
local function ScoreWeaponLoadout(drops, playerGear, weights)
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
    local currentOHilvl = playerUsing2H and 0 or (currentOH and currentOH.ilvl or 0)

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
        if is2H then
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
    local current2Hilvl = playerUsing2H and currentMHilvl or math.max(currentMHilvl, currentOHilvl)
    local gain2H = best2H and math.max(0, best2H.ilvl - current2Hilvl) or 0
    local gain1H = 0
    if best1H then gain1H = gain1H + math.max(0, best1H.ilvl - currentMHilvl) end
    if bestOH and not playerUsing2H then
        gain1H = gain1H + math.max(0, bestOH.ilvl - currentOHilvl)
    end
    local score2HWins = gain2H > gain1H

    local upgrades = {}
    local scoringGain = 0

    if weaponMode == "2H" then
        -- Always show ALL upgrades regardless of which loadout wins scoring
        for _, drop in ipairs(all2H) do
            local gain = math.max(drop.ilvl - math.max(currentMHilvl, currentOHilvl), 0)
            local stats = ns.GetItemStatsCompat(drop.itemLink)
            local dropRatio = ns:StatRatioScore(stats)
            local currentRatio = ns:StatRatioScore(mhStats)
            

            -- track upgrade check
            local dropTrack    = ns:GetTrackFromItemLink(drop.itemLink)
            local currentTrack = currentMH.track
            local dropTrackOrder    = dropTrack    and ns.TRACK_ORDER[dropTrack]    or 0
            local currentTrackOrder = currentTrack and ns.TRACK_ORDER[currentTrack] or 0
            local isTrackUpgrade = dropTrackOrder > currentTrackOrder
            local isStatUpgrade = dropTrackOrder >= currentTrackOrder and dropRatio > currentRatio + 0.01

            if isTrackUpgrade then
                trackUpgradeCount = trackUpgradeCount + 1
            end

            if playerUsing2H and isStatUpgrade then
                statUpgradeCount = statUpgradeCount + 1
            end
            
            if gain >= MIN_UPGRADE_DELTA or isStatUpgrade then
                table.insert(upgrades, {
                    slot        = "MAINHAND",
                    label       = currentMH and currentMH.label or "Main Hand",
                    itemName    = drop.name,
                    currentIlvl = math.max(currentMHilvl, currentOHilvl),
                    dropIlvl    = drop.ilvl,
                    gain        = gain,
                    itemLink    = drop.itemLink,
                    stats       = ns.GetItemStatsCompat(drop.itemLink),
                    secondaryStatScore = ns:SecondaryStatScore(stats, weights),
                    currentSecondaryStatScore = ns:SecondaryStatScore(mhStats, weights),
                    dropTrack        = dropTrack,
                    currentTrack     = currentTrack,
                    isTrackUpgrade   = isTrackUpgrade,
                    fromClient  = true,
                })
            end
        end
    else

        for _, drop in ipairs(all1H) do
            local gain = drop.ilvl - currentMHilvl
            local stats = ns.GetItemStatsCompat(drop.itemLink)
            local dropRatio = ns:StatRatioScore(stats)
            local currentRatio = ns:StatRatioScore(mhStats)
            

            -- track upgrade check
            local dropTrack    = ns:GetTrackFromItemLink(drop.itemLink)
            local currentTrack = currentMH.track
            local dropTrackOrder    = dropTrack    and ns.TRACK_ORDER[dropTrack]    or 0
            local currentTrackOrder = currentTrack and ns.TRACK_ORDER[currentTrack] or 0
            local isTrackUpgrade = dropTrackOrder > currentTrackOrder
            local isStatUpgrade = dropTrackOrder >= currentTrackOrder and dropRatio > currentRatio + 0.01

            if isTrackUpgrade then
                trackUpgradeCount = trackUpgradeCount + 1
            end

            if not playerUsing2H and dropRatio > currentRatio + 0.01 then
                statUpgradeCount = statUpgradeCount + 1
            end

            if gain >= MIN_UPGRADE_DELTA or isStatUpgrade then
                table.insert(upgrades, {
                    slot        = "MAINHAND",
                    label       = currentMH and currentMH.label or "Main Hand",
                    itemName    = drop.name,
                    currentIlvl = currentMHilvl,
                    dropIlvl    = drop.ilvl,
                    gain        = gain,
                    itemLink    = drop.itemLink,
                    stats       = ns.GetItemStatsCompat(drop.itemLink),
                    secondaryStatScore = ns:SecondaryStatScore(stats, weights),
                    currentSecondaryStatScore = ns:SecondaryStatScore(mhStats, weights),
                    dropTrack        = dropTrack,
                    currentTrack     = currentTrack,
                    isTrackUpgrade   = isTrackUpgrade,
                    fromClient  = true,
                })
            end
        end

        for _, drop in ipairs(allOH) do
            -- If player uses 2H, an offhand is only an upgrade if the 1H+OH
            -- combo would beat the current 2H, so compare against 2H ilvl
            local compareIlvl = playerUsing2H and currentMHilvl or currentOHilvl
            local gain = drop.ilvl - compareIlvl
            local stats = ns.GetItemStatsCompat(drop.itemLink)
            local dropRatio = ns:StatRatioScore(stats)
            local currentRatio = ns:StatRatioScore(ohStats)
            
            
            -- track upgrade check
            local dropTrack    = ns:GetTrackFromItemLink(drop.itemLink)
            local currentTrack = currentOH.track
            local dropTrackOrder    = dropTrack    and ns.TRACK_ORDER[dropTrack]    or 0
            local currentTrackOrder = currentTrack and ns.TRACK_ORDER[currentTrack] or 0
            local isTrackUpgrade = dropTrackOrder > currentTrackOrder
            local isStatUpgrade = dropTrackOrder >= currentTrackOrder and dropRatio > currentRatio + 0.01

            if isTrackUpgrade then
                trackUpgradeCount = trackUpgradeCount + 1
            end

            if not playerUsing2H and dropRatio > currentRatio + 0.01 then
                statUpgradeCount = statUpgradeCount + 1
            end
            if gain >= MIN_UPGRADE_DELTA or isStatUpgrade then
                table.insert(upgrades, {
                    slot        = "OFFHAND",
                    label       = "Off Hand",
                    itemName    = drop.name,
                    currentIlvl = compareIlvl,  -- show the real comparison in UI
                    dropIlvl    = drop.ilvl,
                    gain        = gain,
                    itemLink    = drop.itemLink,
                    stats       = stats,
                    secondaryStatScore = ns:SecondaryStatScore(stats, weights),
                    currentSecondaryStatScore = ns:SecondaryStatScore(ohStats, weights),
                    dropTrack        = dropTrack,
                    currentTrack     = currentTrack,
                    isTrackUpgrade   = isTrackUpgrade,
                    fromClient  = true,
                })
            end
        end
    end

    -- Use only the winning loadout's gain for scoring to avoid inflating numbers
    if weaponMode == "2H" then
        scoringGain = gain2H
    else
        scoringGain = gain1H
    end

    return upgrades, scoringGain, statUpgradeCount, trackUpgradeCount
end


-- Compute a weighted stat score for a drop (0.0 - 1.0 range)
local function StatScore(drop, weights)
    local stats = ns.GetItemStatsCompat(drop.itemLink)
    if not stats then return 0 end
    local total = 0
    local maxPossible = 0

    for weightKey, weight in pairs(weights) do
        local wowStatKey = DungeonAdvisorCalc.STAT_KEY_MAP[weightKey]
        if wowStatKey then
            local val = stats[wowStatKey] or 0
            total = total + val * weight
            maxPossible = maxPossible + 350 * weight  -- 350 is a rough ceiling for a single secondary
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

local function HasItemLink(tbl, itemLink)
    for _, entry in ipairs(tbl) do
        if entry.itemLink == itemLink then
            return true
        end
    end
    return false
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

    -- For each slot, find the best drops (up to the max count for that slot)
    local bestDropsPerSlot = {}
    for _, drop in ipairs(armorDrops) do
        local slot = drop.slot
        local maxCount = MULTI_SLOTS[slot] or 1
        if not bestDropsPerSlot[slot] then
            bestDropsPerSlot[slot] = {}
        end
        local list = bestDropsPerSlot[slot]
        table.insert(list, drop)
        -- Sort descending by ilvl, then stat score on tie
        table.sort(list, function(a, b)
            if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
            return CachedStatScore(a) > CachedStatScore(b)
        end)
        -- Trim to max allowed
        while #list > maxCount do
            table.remove(list)
        end
    end

    local upgradeCount   = 0
    local totalIlvlGain  = 0
    local totalStatScore = 0
    local totalSecondaryStatScore = 0
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
                key   = gearKey,
                ilvl  = current and current.ilvl or 0,
                label = current and current.label or gearKey,
                secondaryStatScore = current.secondaryStatScore,
                stats = current.stats,
                track = current and current.track or nil,
            })
        end
        table.sort(currentPieces, function(a, b) return a.ilvl < b.ilvl end)

        local weakestIlvl  = currentPieces[1].ilvl
        local strongestIlvl = currentPieces[maxCount].ilvl

        -- SCORING: count every drop that upgrades any equipped piece,
        -- but only sum ilvl gain for the best maxCount assignments to avoid inflation
        local usedDrops = {}
        local usedSlots = {}

        -- First pass: greedy assignment for ilvl gain scoring (capped at maxCount)
        for _, current in ipairs(currentPieces) do
            for dropIdx, drop in ipairs(drops) do
                if not usedDrops[dropIdx] then
                    local gain = drop.ilvl - current.ilvl
                    if gain >= MIN_UPGRADE_DELTA then
                        local stats = ns.GetItemStatsCompat(drop.itemLink)
                        local statScore = CachedStatScore(drop)
                        local secondaryScore = ns:SecondaryStatScore(stats, weights)

                        totalIlvlGain  = totalIlvlGain + gain
                        totalStatScore = totalStatScore + statScore
                        totalSecondaryStatScore = totalSecondaryStatScore + secondaryScore
                        usedDrops[dropIdx] = true
                        usedSlots[current.key] = true
                    end
                    break
                end
            end
        end

        -- Find everything that is either an ilvl upgrade, a stat upgrade, or a track upgrade
        -- Track how many of each upgrade happens here
        for _, drop in ipairs(drops) do
            local dropStats = ns.GetItemStatsCompat(drop.itemLink)
            local dropTrack = ns:GetTrackFromItemLink(drop.itemLink)
            local dropTrackOrder = dropTrack and ns.TRACK_ORDER[dropTrack] or 0
            local dropRatio = ns:StatRatioScore(dropStats)

            local isIlvlUpgrade  = false
            local isStatUpgrade  = false
            local isTrackUpgrade = false
            local bestIlvlCurrent  = nil  -- weakest piece this beats on ilvl
            local worstTrackCurrent = nil  -- lowest track piece (for track comparison)

            for _, current in ipairs(currentPieces) do
                local currentTrackOrder = current.track and ns.TRACK_ORDER[current.track] or 0

                -- track: find the WORST track piece — that's what we'd replace
                if not worstTrackCurrent then
                    worstTrackCurrent = current
                else
                    local worstTrackOrder = worstTrackCurrent.track and ns.TRACK_ORDER[worstTrackCurrent.track] or 0
                    if currentTrackOrder < worstTrackOrder then
                        worstTrackCurrent = current
                    end
                end
            end

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
                end

                -- track: find worst track piece
                if not worstTrackCurrent then
                    worstTrackCurrent = current
                else
                    local worstTrackOrder = worstTrackCurrent.track and ns.TRACK_ORDER[worstTrackCurrent.track] or 0
                    if currentTrackOrder < worstTrackOrder then
                        worstTrackCurrent = current
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

            -- track upgrade only if it beats the highest track in this slot
            if worstTrackCurrent then
                local worstTrackOrder = worstTrackCurrent.track and ns.TRACK_ORDER[worstTrackCurrent.track] or 0
                if dropTrackOrder > worstTrackOrder then
                    isTrackUpgrade = true
                end
            end

            if isIlvlUpgrade or isStatUpgrade or isTrackUpgrade then
                -- use weakest ilvl piece as display reference, fall back to best track piece
                local displayCurrent = bestIlvlCurrent or worstTrackCurrent
                local ignoredSlot = DungeonAdvisorCharDB.ignoreTiers[displayCurrent.key]
                local displayLabel = MULTI_SLOT_LABELS[slot] or displayCurrent.label
                local gain = drop.ilvl - displayCurrent.ilvl

                if isIlvlUpgrade then upgradeCount = upgradeCount + 1 end
                if isStatUpgrade  and not ignoredSlot then statUpgradeCount  = statUpgradeCount  + 1 end
                if isTrackUpgrade and not ignoredSlot then trackUpgradeCount = trackUpgradeCount + 1 end

                local targetList = isIlvlUpgrade and upgradeDetails or statOnlyUpgrades
                print(string.format("Upgrade found: %s (ilvl %d) -> %s (ilvl %d), gain=%.1f, statUpgrade=%s, trackUpgrade=%s",
                    displayCurrent.label, displayCurrent.ilvl, drop.name, drop.ilvl, gain, tostring(isStatUpgrade), tostring(isTrackUpgrade)))
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

    local weaponUpgrades, weaponScoringGain, weaponStatUpgradeCount, weaponTrackUpgradeCount = ScoreWeaponLoadout(weaponDrops, playerGear, weights)
    statUpgradeCount = statUpgradeCount + weaponStatUpgradeCount
    trackUpgradeCount = trackUpgradeCount + weaponTrackUpgradeCount
    for _, wu in ipairs(weaponUpgrades) do
        if wu.gain > 0 then
            upgradeCount  = upgradeCount + 1
        end

        local statScore = StatScore({ itemLink = wu.itemLink }, weights)
        local secondaryScore = ns:SecondaryStatScore(ns.GetItemStatsCompat(wu.itemLink), weights)

        totalStatScore = totalStatScore + statScore
        totalSecondaryStatScore = totalSecondaryStatScore + wu.secondaryStatScore

        table.insert(upgradeDetails, wu)
    end
    totalIlvlGain = totalIlvlGain + weaponScoringGain  -- but only score the best loadout

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

    return score, upgradeCount, totalIlvlGain, upgradeDetails, totalStatScore, totalSecondaryStatScore, statUpgradeCount, statOnlyUpgrades, trackUpgradeCount
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
                            itemType  = itemType,
                            itemSubType = itemSubType,
                        })
                    end
                end
            end
        end
        --print(string.format("[DungeonAdvisor] %s: found %d drops for %s", selectedDiff, #drops, dungeonEntry.name or "unknown"))
        if #drops > 0 then
            local score, upgradeCount, totalIlvlGain, upgradeDetails, totalStatScore, totalSecondaryStatScore, statUpgradeCount, statOnlyUpgrades, trackUpgradeCount  = self:CalculateDungeonScore(drops, playerGear)
            local avgStatScore = upgradeCount > 0 and (totalStatScore / upgradeCount) or 0
            local baseValue = (#drops > 0) and (totalIlvlGain / #drops) or 0
            
            -- Each component normalized to 0-1 range
            local ilvlDensity  = totalIlvlGain / #drops * W_ILVL_DENSITY
            local upgradeRate  = upgradeCount / #drops * W_UPGRADE_RATE                    -- fraction of drops that are ilvl upgrades
            local statQuality  = statUpgradeCount / #drops * W_STAT_QUALITY -- fraction of drops that are stat upgrades
            local trackQuality  = trackUpgradeCount / #drops * W_TRACK -- fraction of drops that are stat upgrades
            
            local efficiency = ilvlDensity + upgradeRate + statQuality + trackQuality
            
            table.insert(results, {
                name           = dungeonEntry.name,
                score          = score,
                upgradeCount   = upgradeCount,
                totalIlvlGain  = totalIlvlGain,
                efficiency     = efficiency,
                dropCount      = #drops,
                avgStatScore   = avgStatScore,
                baseValue      = baseValue,
                upgradeDetails = upgradeDetails,
                statUpgradeCount = statUpgradeCount,
                statOnlyUpgrades  = statOnlyUpgrades,
                trackUpgradeCount = trackUpgradeCount,
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
