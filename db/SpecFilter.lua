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
    SHAMAN_2 = { ONE_HAND=true, TWO_HAND=true, SHIELD=true,  STAFF=true,  BOW=false, WAND=false }, -- Enhancement
    SHAMAN_3 = { --Restoration
        ["One-Handed Axes"]=true,
        ["One-Handed Swords"]=false,
        ["One-Handed Maces"]=true, 
        ["Daggers"]=true,
        ["Fist Weapons"]=true,
        ["Two-Handed Swords"]=false,
        ["Two-Handed Maces"]=true,
        ["Two-Handed Axes"]=false,
        ["Polearms"]=false,
        ["Staves"]=true,
    },

    -- HUNTER
    HUNTER_1 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=true,  WAND=false }, -- Beast Mastery
    HUNTER_2 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=true,  WAND=false }, -- Marksmanship
    HUNTER_3 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=true,  WAND=false }, -- Survival

    -- MONK  (no shields, no ranged weapons)
    MONK_1 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Brewmaster
    MONK_2 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Mistweaver
    MONK_3 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Windwalker

    -- DRUID
    DRUID_1 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Balance
    DRUID_2 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Feral
    DRUID_3 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Guardian
    DRUID_4 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Restoration

    -- ROGUE
    ROGUE_1 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=false, BOW=false, WAND=false }, -- Assassination
    ROGUE_2 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=false, BOW=false, WAND=false }, -- Outlaw
    ROGUE_3 = { ONE_HAND=true, TWO_HAND=false,SHIELD=false, STAFF=false, BOW=false, WAND=false }, -- Subtlety

    -- EVOKER
    EVOKER_1 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Devastation
    EVOKER_2 = { --Preservation
        ["One-Handed Swords"]=true,
        ["One-Handed Maces"]=true, 
        ["Daggers"]=true,
        ["Fist Weapons"]=true,
        ["Two-Handed Swords"]=true,
        ["Two-Handed Maces"]=true,
        ["Polearms"]=true,
        ["Staves"]=true,
    },
    EVOKER_3 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Augmentation

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

    -- Rings, necks, trinkets, cloaks are universal
    local universalSlots = { FINGER=true, NECK=true, TRINKET=true, BACK=true, OFFHAND=true }
    if drop.slot and universalSlots[drop.slot] then
        return true
    end

    -- Armor check
    if drop.itemType == "Armor" and drop.itemSubType and drop.itemSubType ~= "Jewelry" and drop.itemSubType ~= "Cloak" then
        local classArmor = CLASS_ARMOR[className]
        if not classArmor or not classArmor[drop.itemSubType] then
            return false
        end
    end

    -- Weapon / offhand check
    print("Checking weapon type", drop.itemType, drop.itemSubType, "for spec", specKey)
    if drop.itemType == "Weapon" or drop.itemType == "OffHand" then
        local specWeapons = SPEC_WEAPONS[specKey]
        if not specWeapons then
            -- Unknown spec — allow everything to avoid false negatives
            return true
        end
        
        if specWeapons[drop.itemSubType] == false or not specWeapons[drop.itemSubType] then
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
