-- GearAdvisor: Calculator
-- Scores each dungeon based on potential gear upgrades, filtered by spec.
-- Scoring combines: number of upgrade slots + total ilvl gains + stat desirability.

GearAdvisorCalc = {}

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

-- Get the stat weight table for the current player spec
local function GetSpecWeights()
    local className, specIndex = GearAdvisorSpecFilter:GetPlayerSpec()
    local key = className .. "_" .. specIndex
    return STAT_WEIGHTS[key] or DEFAULT_WEIGHTS
end

-- Compute a weighted stat score for a drop (0.0 - 1.0 range)
local function StatScore(drop, weights)
    local stats = GearAdvisorItemCache:GetStats(drop)
    local total = 0
    local maxPossible = 0
    for statName, weight in pairs(weights) do
        local val = stats[statName] or 0
        total = total + val * weight
        maxPossible = maxPossible + 350 * weight  -- 350 is a rough ceiling for a single secondary
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
function GearAdvisorCalc:CalculateDungeonScore(dungeonDrops, playerGear)
    local weights = GetSpecWeights()

    -- Filter to spec-usable drops first
    local usableDrops = GearAdvisorSpecFilter:FilterDrops(dungeonDrops)

    -- For each slot, find the best drop: prioritise ilvl gain, break ties by stat score
    local bestDropPerSlot = {}
    for _, drop in ipairs(usableDrops) do
        local slot = drop.slot
        local current = bestDropPerSlot[slot]
        if not current then
            bestDropPerSlot[slot] = drop
        else
            -- Prefer higher ilvl; if equal, prefer better stats
            if drop.ilvl > current.ilvl or
              (drop.ilvl == current.ilvl and StatScore(drop, weights) > StatScore(current, weights)) then
                bestDropPerSlot[slot] = drop
            end
        end
    end

    local upgradeCount   = 0
    local totalIlvlGain  = 0
    local totalStatScore = 0
    local upgradeDetails = {}

    for slot, drop in pairs(bestDropPerSlot) do
        local current     = playerGear[slot]
        local currentIlvl = current and current.ilvl or 0
        local gain        = drop.ilvl - currentIlvl

        if gain >= MIN_UPGRADE_DELTA then
            local stats      = GearAdvisorItemCache:GetStats(drop)
            local statScore  = StatScore(drop, weights)

            upgradeCount   = upgradeCount + 1
            totalIlvlGain  = totalIlvlGain + gain
            totalStatScore = totalStatScore + statScore

            table.insert(upgradeDetails, {
                slot        = slot,
                label       = current and current.label or slot,
                itemName    = drop.name,
                currentIlvl = currentIlvl,
                dropIlvl    = drop.ilvl,
                gain        = gain,
                stats       = stats,
                fromClient  = stats.fromClient,
            })
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
function GearAdvisorCalc:RankDungeons(playerGear)
    local results = {}
    for dungeonName, dungeonData in pairs(GearAdvisorLootDB) do
        local score, upgradeCount, totalIlvlGain, upgradeDetails =
            self:CalculateDungeonScore(dungeonData.drops, playerGear)
        table.insert(results, {
            name           = dungeonName,
            score          = score,
            upgradeCount   = upgradeCount,
            totalIlvlGain  = totalIlvlGain,
            upgradeDetails = upgradeDetails,
        })
    end
    table.sort(results, function(a, b) return a.score > b.score end)
    return results
end
