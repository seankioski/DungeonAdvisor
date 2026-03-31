-- DungeonAdvisor: SpecFilter
-- Detects the player's class and active spec, then filters loot to only
-- include items that spec can actually equip and use.

DungeonAdvisorSpecFilter = {}

-- -----------------------------------------------------------------------
-- Armor type each class can wear
-- -----------------------------------------------------------------------
local CLASS_ARMOR = {
    WARRIOR      = { PLATE=true,  MAIL=true,  LEATHER=true, CLOTH=true  },
    PALADIN      = { PLATE=true,  MAIL=true,  LEATHER=true, CLOTH=true  },
    DEATHKNIGHT  = { PLATE=true,  MAIL=true,  LEATHER=true, CLOTH=true  },
    DEMONHUNTER  = {              MAIL=true,  LEATHER=true, CLOTH=true  },
    SHAMAN       = {              MAIL=true,  LEATHER=true, CLOTH=true  },
    HUNTER       = {              MAIL=true,  LEATHER=true, CLOTH=true  },
    MONK         = {              MAIL=true,  LEATHER=true, CLOTH=true  },
    DRUID        = {                          LEATHER=true, CLOTH=true  },
    ROGUE        = {                          LEATHER=true, CLOTH=true  },
    EVOKER       = {                          LEATHER=true, CLOTH=true  },
    MAGE         = {                                        CLOTH=true  },
    WARLOCK      = {                                        CLOTH=true  },
    PRIEST       = {                                        CLOTH=true  },
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

    -- SHAMAN
    SHAMAN_1 = { ONE_HAND=true, TWO_HAND=true, SHIELD=true,  STAFF=true,  BOW=false, WAND=false }, -- Elemental
    SHAMAN_2 = { ONE_HAND=true, TWO_HAND=true, SHIELD=true,  STAFF=true,  BOW=false, WAND=false }, -- Enhancement
    SHAMAN_3 = { ONE_HAND=true, TWO_HAND=true, SHIELD=true,  STAFF=true,  BOW=false, WAND=false }, -- Restoration

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
    EVOKER_2 = { ONE_HAND=true, TWO_HAND=true, SHIELD=false, STAFF=true,  BOW=false, WAND=false }, -- Preservation
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
    local universalSlots = { FINGER=true, NECK=true, TRINKET=true, BACK=true }
    if drop.slot and universalSlots[drop.slot] then
        return true
    end

    -- Armor check
    if drop.armorType and drop.armorType ~= "JEWELRY" and drop.armorType ~= "CLOAK" then
        local classArmor = CLASS_ARMOR[className]
        if not classArmor or not classArmor[drop.armorType] then
            return false
        end
    end

    -- Weapon / offhand check
    if drop.weaponType then
        local specWeapons = SPEC_WEAPONS[specKey]
        if not specWeapons then
            -- Unknown spec — allow everything to avoid false negatives
            return true
        end
        if specWeapons[drop.weaponType] == false or not specWeapons[drop.weaponType] then
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
