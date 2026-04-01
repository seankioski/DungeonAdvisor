-- DungeonAdvisor: SpecFilter
-- Detects the player's class and active spec, then filters loot to only
-- include items that spec can actually equip and use.

DungeonAdvisorSpecFilter = {}

-- -----------------------------------------------------------------------
-- Armor type each class can wear
-- -----------------------------------------------------------------------
local CLASS_ARMOR = {
    WARRIOR      = { Plate=true,                                        },
    PALADIN      = { Plate=true,                                        },
    DEATHKNIGHT  = { Plate=true,                                        },
    DEMONHUNTER  = {                          Leather=true,             },
    SHAMAN       = {              Mail=true,                            },
    HUNTER       = {              Mail=true,                            },
    MONK         = {                          Leather=true,             },
    DRUID        = {                          Leather=true,             },
    ROGUE        = {                          Leather=true,             },
    EVOKER       = {              Mail=true,                            },
    MAGE         = {                                        Cloth=true  },
    WARLOCK      = {                                        Cloth=true  },
    PRIEST       = {                                        Cloth=true  },
}

-- -----------------------------------------------------------------------
-- Weapon types each spec can equip/use in practice.
-- Key format: "CLASS_SPECINDEX" (specIndex 1/2/3/4 as returned by GetSpecialization)
-- Classes with identical weapon rules per spec share the same table.
    -- ["One-Handed Axes"]=true,
    -- ["One-Handed Swords"]=true,
    -- ["One-Handed Maces"]=true, 
    -- ["Daggers"]=true,
    -- ["Fist Weapons"]=true,
    -- ["Two-Handed Axes"]=true,
    -- ["Two-Handed Swords"]=true,
    -- ["Two-Handed Maces"]=true,
    -- ["Polearms"]=true,
    -- ["Staves"]=true,
    -- OFFHAND=true
-- -----------------------------------------------------------------------
local SPEC_WEAPONS = {
    -- WARRIOR
    WARRIOR_1 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Arms
    WARRIOR_2 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Fury (dual wield, same types)
    WARRIOR_3 = { ONE_HAND=true, TWO_HAND=false,SHIELD=true,  STAFF=false, BOW=false, WAND=false }, -- Protection

    -- PALADIN
    PALADIN_1 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=false, BOW=false, WAND=false }, -- Holy
    PALADIN_2 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=false, BOW=false, WAND=false }, -- Protection (uses 1H+shield but shield separate)
    PALADIN_3 = { ONE_HAND=true, TWO_HAND=true, SHIELD=true,  STAFF=false, BOW=false, WAND=false }, -- Retribution

    -- DEATH KNIGHT
    DEATHKNIGHT_1 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=false, BOW=false, WAND=false }, -- Blood
    DEATHKNIGHT_2 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=false, BOW=false, WAND=false }, -- Frost
    DEATHKNIGHT_3 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=false, BOW=false, WAND=false }, -- Unholy

    -- DEMON HUNTER
    DEMONHUNTER_1 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=false, BOW=false, WAND=false }, -- Havoc
    DEMONHUNTER_2 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=false, BOW=false, WAND=false }, -- Vengeance
    DEMONHUNTER_3 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=false, BOW=false, WAND=false }, -- Devourer

    -- SHAMAN
    SHAMAN_1 = { ONE_HAND=true, TWO_HAND=true, SHIELD=true,  STAFF=true,  BOW=false, WAND=false }, -- Elemental
    SHAMAN_2 = { -- Enhancement
        ["One-Handed Axes"]=true,
        ["One-Handed Maces"]=true, 
        ["Fist Weapons"]=true,
    }, 
    SHAMAN_3 = { --Restoration
        ["One-Handed Axes"]=true,
        ["One-Handed Maces"]=true, 
        ["Daggers"]=true,
        ["Fist Weapons"]=true,
        ["Two-Handed Maces"]=true,
        ["Staves"]=true,
    },

    -- HUNTER
    HUNTER_1 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=true,  WAND=false }, -- Beast Mastery
    HUNTER_2 = { --Marksmanship
        ["Bows"]=true,
        ["Crossbows"]=true,
        ["Guns"]=true,
    },
    HUNTER_3 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=true,  WAND=false }, -- Survival

    -- MONK  (no shields, no ranged weapons)
    MONK_1 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Brewmaster
    MONK_2 = { --Mistweaver
        ["One-Handed Axes"]=true,
        ["One-Handed Maces"]=true, 
        ["One-Handed Swords"]=true, 
        ["Fist Weapons"]=true,
        ["Staves"]=true,
        ["Polearms"]=true,
        OFFHAND=true
    },
    MONK_3 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Windwalker

    -- DRUID
    DRUID_1 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Balance
    DRUID_2 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Feral
    DRUID_3 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Guardian
    DRUID_4 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Restoration

    -- ROGUE
    ROGUE_1 = {  -- Assassination
        ["Daggers"]=true,
    },
    ROGUE_2  = {  -- Outlaw
        ["One-Handed Axes"]=true,
        ["One-Handed Swords"]=true,
        ["One-Handed Maces"]=true, 
        ["Fist Weapons"]=true,
    },
    ROGUE_3 = {  -- Subtlety
        ["Daggers"]=true,
    },

    -- EVOKER
    EVOKER_1 = { --Devastation
        ["One-Handed Axes"]=true,
        ["One-Handed Swords"]=true,
        ["One-Handed Maces"]=true, 
        ["Daggers"]=true,
        ["Fist Weapons"]=true,
        ["Two-Handed Axes"]=true,
        ["Two-Handed Swords"]=true,
        ["Two-Handed Maces"]=true,
        ["Polearms"]=true,
        ["Staves"]=true,
        OFFHAND=true
    },
    EVOKER_2 = { --Preservation
        ["One-Handed Axes"]=true,
        ["One-Handed Swords"]=true,
        ["One-Handed Maces"]=true, 
        ["Daggers"]=true,
        ["Fist Weapons"]=true,
        ["Two-Handed Axes"]=true,
        ["Two-Handed Swords"]=true,
        ["Two-Handed Maces"]=true,
        ["Polearms"]=true,
        ["Staves"]=true,
        OFFHAND=true
    },
    EVOKER_3 = { --Augmentation
        ["One-Handed Axes"]=true,
        ["One-Handed Swords"]=true,
        ["One-Handed Maces"]=true, 
        ["Daggers"]=true,
        ["Fist Weapons"]=true,
        ["Two-Handed Axes"]=true,
        ["Two-Handed Swords"]=true,
        ["Two-Handed Maces"]=true,
        ["Polearms"]=true,
        ["Staves"]=true,
        OFFHAND=true
    },

    -- MAGE
    MAGE_1 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=true,  BOW=false, WAND=true  }, -- Arcane
    MAGE_2 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=true,  BOW=false, WAND=true  }, -- Fire
    MAGE_3 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=true,  BOW=false, WAND=true  }, -- Frost

    -- WARLOCK
    WARLOCK_1 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=true,  BOW=false, WAND=true  },
    WARLOCK_2 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=true,  BOW=false, WAND=true  },
    WARLOCK_3 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=true,  BOW=false, WAND=true  },

    -- PRIEST
    PRIEST_1 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=true,  BOW=false, WAND=true  }, -- Discipline
    PRIEST_2 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=true,  BOW=false, WAND=true  }, -- Holy
    PRIEST_3 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=true,  BOW=false, WAND=true  }, -- Shadow
}

-- Expand shorthand weapon tables into actual WoW itemSubType strings
local ONE_HAND_TYPES = {
    ["One-Handed Swords"] = true,
    ["One-Handed Axes"]   = true,
    ["One-Handed Maces"]  = true,
    ["Daggers"]           = true,
    ["Fist Weapons"]      = true,
}
local TWO_HAND_TYPES = {
    ["Two-Handed Swords"] = true,
    ["Two-Handed Axes"]   = true,
    ["Two-Handed Maces"]  = true,
    ["Polearms"]          = true,
    ["Staves"]            = true,
}
local BOW_TYPES  = { ["Bows"]=true, ["Guns"]=true, ["Crossbows"]=true }
local WAND_TYPES = { ["Wands"]=true }
local OFFHAND_TYPES = { ["HOLDABLE"]=true }

local function ExpandWeaponTable(specWeapons)
    local expanded = {}
    
    for k, v in pairs(specWeapons) do
        if k == "ONE_HAND" and v then
            for subType in pairs(ONE_HAND_TYPES) do expanded[subType] = true end
        elseif k == "TWO_HAND" and v then
            for subType in pairs(TWO_HAND_TYPES) do expanded[subType] = true end
        elseif k == "STAFF" and v then
            expanded["Staves"] = true
        elseif k == "SHIELD" and v then
            expanded["Shields"] = true
        elseif k == "BOW" and v then
            for subType in pairs(BOW_TYPES) do expanded[subType] = true end
        elseif k == "WAND" and v then
            for subType in pairs(WAND_TYPES) do expanded[subType] = true end
        elseif k == "OFFHAND" and v then
            for subType in pairs(OFFHAND_TYPES) do expanded[subType] = true end
        else
            -- Already a raw subtype string (e.g. from Mistweaver/Marksman tables)
            expanded[k] = v
        end
    end
    return expanded
end

-- -----------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------

-- Returns { className, specIndex, specName } for the current player
function DungeonAdvisorSpecFilter:GetPlayerSpec()
    local specIndex = GetSpecialization()
    local className = select(2, UnitClass("player")) -- e.g. "WARRIOR"
    local specName  = ""
    if specIndex then
        specName = select(2, GetSpecializationInfo(specIndex)) or ""
    end
    return className, specIndex or 1, specName
end

-- Returns true if the given drop (from LootTable) is usable by the current class/spec
function DungeonAdvisorSpecFilter:CanUse(drop)
    local className, specIndex = self:GetPlayerSpec()
    local specKey = className .. "_" .. specIndex
    return true
    -- Rings, necks, trinkets, cloaks are universal
    local universalSlots = { FINGER=true, NECK=true, TRINKET=true, BACK=true }
    if drop.slot and universalSlots[drop.slot] then
        return true
    end

    -- Held-in-hand offhand check (tomes, orbs etc.)
    print("OFFHAND??" .. drop.slot .. drop.itemType)
    if drop.slot == "OFFHAND" and drop.itemType == "Armor" then
        local specWeapons = SPEC_WEAPONS[specKey]
        if not specWeapons then return true end
        local expanded = ExpandWeaponTable(specWeapons)
        print(specWeapons)
        print(expanded)
        return expanded["HOLDABLE"] == true
    end

    -- Armor check
    if drop.itemType == "Armor" and drop.itemSubType and drop.itemSubType ~= "Jewelry" and drop.itemSubType ~= "Cloak" then
        local classArmor = CLASS_ARMOR[className]
        if not classArmor or not classArmor[drop.itemSubType] then
            return false
        end
    end

    -- Shield check (itemType == "Armor", subType == "Shields")
    if drop.itemType == "Armor" and drop.itemSubType == "Shields" then
        local specWeapons = SPEC_WEAPONS[specKey]
        if not specWeapons then return true end
        local expanded = ExpandWeaponTable(specWeapons)
        return expanded["Shields"] == true
    end

    

    -- Weapon check
    if drop.itemType == "Weapon" then
        local specWeapons = SPEC_WEAPONS[specKey]
        if not specWeapons then return true end

        local expanded = ExpandWeaponTable(specWeapons)
        if not expanded[drop.itemSubType] then
            return false
        end
    end

    return true
end

-- Filters a list of drops to only those usable by the current spec
function DungeonAdvisorSpecFilter:FilterDrops(drops)
    local filtered = {}
    for _, drop in ipairs(drops) do
        if self:CanUse(drop) then
            table.insert(filtered, drop)
        end
    end
    return filtered
end
