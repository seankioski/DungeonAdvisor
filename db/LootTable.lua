-- GearAdvisor: Loot Table Database
-- The War Within Season 2 Mythic+ Dungeons
--
-- Each drop includes:
--   itemId    : used to request live stats from the game client cache
--   slot      : gear slot constant
--   ilvl      : base ilvl at +2 keystone level
--   armorType : PLATE / MAIL / LEATHER / CLOTH / SHIELD / CLOAK / JEWELRY / nil (weapons)
--   weaponType: TWO_HAND / ONE_HAND / BOW / STAFF / WAND / SHIELD / nil (armor)
--   stats     : fallback secondary stats { crit, haste, mastery, versatility } (rating units)
--
-- armorType / weaponType are used by SpecFilter.lua to exclude unusable items per class/spec

GearAdvisorLootDB = {

    ["Darkflame Cleft"] = {
        id = "darkflame-cleft",
        drops = {
            { itemId=212404, name="Void-Touched Helm",            slot="HEAD",     ilvl=619, armorType="PLATE",    stats={crit=240,haste=0,  mastery=320,versatility=0  } },
            { itemId=212405, name="Ashen Shoulderplates",          slot="SHOULDER", ilvl=619, armorType="PLATE",    stats={crit=0,  haste=310,mastery=0,  versatility=250} },
            { itemId=212406, name="Cleft-Walker Cloak",            slot="BACK",     ilvl=619, armorType="CLOAK",    stats={crit=180,haste=220,mastery=0,  versatility=0  } },
            { itemId=212407, name="Darkflame Chestguard",          slot="CHEST",    ilvl=619, armorType="MAIL",     stats={crit=0,  haste=0,  mastery=290,versatility=310} },
            { itemId=212408, name="Smoldering Wristwraps",         slot="WRIST",    ilvl=619, armorType="LEATHER",  stats={crit=200,haste=180,mastery=0,  versatility=0  } },
            { itemId=212409, name="Grips of the Ashen Horde",      slot="HANDS",    ilvl=619, armorType="PLATE",    stats={crit=0,  haste=260,mastery=240,versatility=0  } },
            { itemId=212410, name="Cinch of Smoldering Ruin",      slot="WAIST",    ilvl=619, armorType="LEATHER",  stats={crit=210,haste=0,  mastery=0,  versatility=230} },
            { itemId=212411, name="Legguards of Darkened Flame",   slot="LEGS",     ilvl=619, armorType="MAIL",     stats={crit=0,  haste=280,mastery=300,versatility=0  } },
            { itemId=212412, name="Cleft-Walker Treads",           slot="FEET",     ilvl=619, armorType="PLATE",    stats={crit=190,haste=0,  mastery=0,  versatility=270} },
            { itemId=212413, name="Ring of the Ashen Choir",       slot="FINGER",   ilvl=619, armorType="JEWELRY",  stats={crit=220,haste=200,mastery=0,  versatility=0  } },
            { itemId=212414, name="Pendant of Dimming Light",      slot="NECK",     ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=240,mastery=220,versatility=0  } },
            { itemId=212415, name="Torch of the Darkflame",        slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212416, name="Cinders of the Forgotten",      slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212417, name="Flamebrand Axe",                slot="MAINHAND", ilvl=619, weaponType="ONE_HAND",stats={crit=260,haste=240,mastery=0,  versatility=0  } },
            { itemId=212418, name="Smoldering Ritual Dagger",      slot="MAINHAND", ilvl=619, weaponType="ONE_HAND",stats={crit=0,  haste=300,mastery=260,versatility=0  } },
        },
    },

    ["The Rookery"] = {
        id = "the-rookery",
        drops = {
            { itemId=212420, name="Stormfeather Helm",             slot="HEAD",     ilvl=619, armorType="MAIL",     stats={crit=250,haste=0,  mastery=0,  versatility=290} },
            { itemId=212421, name="Rookward Mantle",               slot="SHOULDER", ilvl=619, armorType="CLOTH",    stats={crit=0,  haste=280,mastery=260,versatility=0  } },
            { itemId=212422, name="Cloak of the Eyrie",            slot="BACK",     ilvl=619, armorType="CLOAK",    stats={crit=200,haste=0,  mastery=220,versatility=0  } },
            { itemId=212423, name="Thunderstrike Chestplate",      slot="CHEST",    ilvl=619, armorType="PLATE",    stats={crit=0,  haste=310,mastery=0,  versatility=280} },
            { itemId=212424, name="Galeborn Bracers",              slot="WRIST",    ilvl=619, armorType="LEATHER",  stats={crit=190,haste=210,mastery=0,  versatility=0  } },
            { itemId=212425, name="Talon-Grip Gauntlets",          slot="HANDS",    ilvl=619, armorType="MAIL",     stats={crit=0,  haste=0,  mastery=270,versatility=260} },
            { itemId=212426, name="Gust-Lashed Girdle",            slot="WAIST",    ilvl=619, armorType="PLATE",    stats={crit=230,haste=200,mastery=0,  versatility=0  } },
            { itemId=212427, name="Featherfall Legwraps",          slot="LEGS",     ilvl=619, armorType="CLOTH",    stats={crit=0,  haste=290,mastery=310,versatility=0  } },
            { itemId=212428, name="Windwalker Boots",              slot="FEET",     ilvl=619, armorType="LEATHER",  stats={crit=210,haste=0,  mastery=0,  versatility=240} },
            { itemId=212429, name="Signet of the Eyrie",           slot="FINGER",   ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=250,mastery=230,versatility=0  } },
            { itemId=212430, name="Stormcaller's Amulet",          slot="NECK",     ilvl=619, armorType="JEWELRY",  stats={crit=240,haste=0,  mastery=0,  versatility=220} },
            { itemId=212431, name="Tempest Caller's Badge",        slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212432, name="Stormrook's Eye",               slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212433, name="Gale-Touched Warblade",         slot="MAINHAND", ilvl=619, weaponType="TWO_HAND",stats={crit=300,haste=280,mastery=0,  versatility=0  } },
            { itemId=212434, name="Rookery Greatbow",              slot="RANGED",   ilvl=619, weaponType="BOW",     stats={crit=0,  haste=320,mastery=0,  versatility=270} },
        },
    },

    ["The Stonevault"] = {
        id = "the-stonevault",
        drops = {
            { itemId=212440, name="Vault-Keeper's Crown",          slot="HEAD",     ilvl=619, armorType="PLATE",    stats={crit=0,  haste=300,mastery=280,versatility=0  } },
            { itemId=212441, name="Stoneshaper Pauldrons",         slot="SHOULDER", ilvl=619, armorType="MAIL",     stats={crit=260,haste=0,  mastery=0,  versatility=280} },
            { itemId=212442, name="Draped Vault Shroud",           slot="BACK",     ilvl=619, armorType="CLOAK",    stats={crit=0,  haste=210,mastery=190,versatility=0  } },
            { itemId=212443, name="Earthbound Chestguard",         slot="CHEST",    ilvl=619, armorType="LEATHER",  stats={crit=290,haste=0,  mastery=310,versatility=0  } },
            { itemId=212444, name="Shackles of the Deep Earth",    slot="WRIST",    ilvl=619, armorType="PLATE",    stats={crit=0,  haste=230,mastery=0,  versatility=210} },
            { itemId=212445, name="Stoneshaper Handguards",        slot="HANDS",    ilvl=619, armorType="CLOTH",    stats={crit=240,haste=260,mastery=0,  versatility=0  } },
            { itemId=212446, name="Girdle of the Vault",           slot="WAIST",    ilvl=619, armorType="MAIL",     stats={crit=0,  haste=0,  mastery=250,versatility=230} },
            { itemId=212447, name="Petrified Legplates",           slot="LEGS",     ilvl=619, armorType="PLATE",    stats={crit=270,haste=290,mastery=0,  versatility=0  } },
            { itemId=212448, name="Vault-Walker Sabatons",         slot="FEET",     ilvl=619, armorType="MAIL",     stats={crit=0,  haste=220,mastery=240,versatility=0  } },
            { itemId=212449, name="Loop of Sunken Stone",          slot="FINGER",   ilvl=619, armorType="JEWELRY",  stats={crit=210,haste=0,  mastery=0,  versatility=230} },
            { itemId=212450, name="Amulet of Sunken Depths",       slot="NECK",     ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=250,mastery=230,versatility=0  } },
            { itemId=212451, name="Golem Control Unit",            slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212452, name="Carved Stonevault Idol",        slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212453, name="Stonecutter's Blade",           slot="MAINHAND", ilvl=619, weaponType="ONE_HAND",stats={crit=270,haste=250,mastery=0,  versatility=0  } },
            { itemId=212454, name="Vault Warden's Shield",         slot="OFFHAND",  ilvl=619, weaponType="SHIELD",  stats={crit=0,  haste=280,mastery=0,  versatility=260} },
        },
    },

    ["City of Threads"] = {
        id = "city-of-threads",
        drops = {
            { itemId=212460, name="Voidweaver's Hood",             slot="HEAD",     ilvl=619, armorType="CLOTH",    stats={crit=270,haste=250,mastery=0,  versatility=0  } },
            { itemId=212461, name="Silken Shadow Mantle",          slot="SHOULDER", ilvl=619, armorType="LEATHER",  stats={crit=0,  haste=0,  mastery=280,versatility=260} },
            { itemId=212462, name="Cloak of Crawling Threads",     slot="BACK",     ilvl=619, armorType="CLOAK",    stats={crit=190,haste=210,mastery=0,  versatility=0  } },
            { itemId=212463, name="Robes of the Woven Dark",       slot="CHEST",    ilvl=619, armorType="CLOTH",    stats={crit=0,  haste=300,mastery=280,versatility=0  } },
            { itemId=212464, name="Bindings of the Nether-Silk",   slot="WRIST",    ilvl=619, armorType="CLOTH",    stats={crit=200,haste=0,  mastery=0,  versatility=220} },
            { itemId=212465, name="Gloves of Threading Void",      slot="HANDS",    ilvl=619, armorType="LEATHER",  stats={crit=0,  haste=240,mastery=260,versatility=0  } },
            { itemId=212466, name="Belt of the Silken Web",        slot="WAIST",    ilvl=619, armorType="CLOTH",    stats={crit=230,haste=210,mastery=0,  versatility=0  } },
            { itemId=212467, name="Legwraps of the Shadowed City", slot="LEGS",     ilvl=619, armorType="LEATHER",  stats={crit=0,  haste=0,  mastery=300,versatility=280} },
            { itemId=212468, name="Treads of Woven Shadow",        slot="FEET",     ilvl=619, armorType="CLOTH",    stats={crit=220,haste=200,mastery=0,  versatility=0  } },
            { itemId=212469, name="Ring of Entwined Fates",        slot="FINGER",   ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=260,mastery=240,versatility=0  } },
            { itemId=212470, name="Choker of the Void Weave",      slot="NECK",     ilvl=619, armorType="JEWELRY",  stats={crit=250,haste=0,  mastery=230,versatility=0  } },
            { itemId=212471, name="Void-Caller's Pendant",         slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212472, name="Sigil of the Woven Realm",      slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212473, name="Needle of the Nether Stitch",   slot="MAINHAND", ilvl=619, weaponType="ONE_HAND",stats={crit=260,haste=280,mastery=0,  versatility=0  } },
            { itemId=212474, name="Blade of Tangled Threads",      slot="MAINHAND", ilvl=619, weaponType="ONE_HAND",stats={crit=0,  haste=310,mastery=270,versatility=0  } },
        },
    },

    ["Ara-Kara, City of Echoes"] = {
        id = "ara-kara",
        drops = {
            { itemId=212480, name="Echo-Stitched Crown",           slot="HEAD",     ilvl=619, armorType="LEATHER",  stats={crit=260,haste=240,mastery=0,  versatility=0  } },
            { itemId=212481, name="Webspinner's Shoulderpads",     slot="SHOULDER", ilvl=619, armorType="MAIL",     stats={crit=0,  haste=270,mastery=0,  versatility=250} },
            { itemId=212482, name="Cloak of Resonant Silk",        slot="BACK",     ilvl=619, armorType="CLOAK",    stats={crit=200,haste=0,  mastery=180,versatility=0  } },
            { itemId=212483, name="Carapace of the Resonant Hive", slot="CHEST",    ilvl=619, armorType="MAIL",     stats={crit=0,  haste=300,mastery=320,versatility=0  } },
            { itemId=212484, name="Silkweave Bindings",            slot="WRIST",    ilvl=619, armorType="LEATHER",  stats={crit=210,haste=190,mastery=0,  versatility=0  } },
            { itemId=212485, name="Grips of the Webwarden",        slot="HANDS",    ilvl=619, armorType="PLATE",    stats={crit=0,  haste=0,  mastery=260,versatility=240} },
            { itemId=212486, name="Cord of Chitinous Links",       slot="WAIST",    ilvl=619, armorType="MAIL",     stats={crit=230,haste=210,mastery=0,  versatility=0  } },
            { itemId=212487, name="Leggings of the Echo-Touched",  slot="LEGS",     ilvl=619, armorType="LEATHER",  stats={crit=0,  haste=0,  mastery=290,versatility=270} },
            { itemId=212488, name="Skittering Sabatons",           slot="FEET",     ilvl=619, armorType="PLATE",    stats={crit=200,haste=220,mastery=0,  versatility=0  } },
            { itemId=212489, name="Signet of the Silk Court",      slot="FINGER",   ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=240,mastery=220,versatility=0  } },
            { itemId=212490, name="Pendant of Hollow Resonance",   slot="NECK",     ilvl=619, armorType="JEWELRY",  stats={crit=230,haste=0,  mastery=0,  versatility=210} },
            { itemId=212491, name="Crit-Coated Stinger",           slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212492, name="Ara-Kara Silkspinner",          slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212493, name="Fang of the Echo Queen",        slot="MAINHAND", ilvl=619, weaponType="ONE_HAND",stats={crit=270,haste=250,mastery=0,  versatility=0  } },
            { itemId=212494, name="Resonant Warbow",               slot="RANGED",   ilvl=619, weaponType="BOW",     stats={crit=0,  haste=310,mastery=0,  versatility=280} },
        },
    },

    ["Cinderbrew Meadery"] = {
        id = "cinderbrew-meadery",
        drops = {
            { itemId=212500, name="Brewmaster's Greathelm",        slot="HEAD",     ilvl=619, armorType="PLATE",    stats={crit=240,haste=260,mastery=0,  versatility=0  } },
            { itemId=212501, name="Emberscaled Shoulderpads",      slot="SHOULDER", ilvl=619, armorType="MAIL",     stats={crit=0,  haste=0,  mastery=280,versatility=260} },
            { itemId=212502, name="Mead-Soaked Drape",             slot="BACK",     ilvl=619, armorType="CLOAK",    stats={crit=190,haste=170,mastery=0,  versatility=0  } },
            { itemId=212503, name="Forge-Stitched Tunic",          slot="CHEST",    ilvl=619, armorType="LEATHER",  stats={crit=0,  haste=290,mastery=0,  versatility=310} },
            { itemId=212504, name="Wristguards of the Cinder",     slot="WRIST",    ilvl=619, armorType="PLATE",    stats={crit=210,haste=0,  mastery=230,versatility=0  } },
            { itemId=212505, name="Gloves of the Brewing Arts",    slot="HANDS",    ilvl=619, armorType="CLOTH",    stats={crit=0,  haste=250,mastery=270,versatility=0  } },
            { itemId=212506, name="Cord of the Meadery",           slot="WAIST",    ilvl=619, armorType="LEATHER",  stats={crit=220,haste=200,mastery=0,  versatility=0  } },
            { itemId=212507, name="Scorched Brewhand Legwraps",    slot="LEGS",     ilvl=619, armorType="MAIL",     stats={crit=0,  haste=280,mastery=300,versatility=0  } },
            { itemId=212508, name="Cinder-Treads",                 slot="FEET",     ilvl=619, armorType="PLATE",    stats={crit=200,haste=0,  mastery=0,  versatility=220} },
            { itemId=212509, name="Ring of the Blazing Brew",      slot="FINGER",   ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=230,mastery=210,versatility=0  } },
            { itemId=212510, name="Amulet of Fermented Fire",      slot="NECK",     ilvl=619, armorType="JEWELRY",  stats={crit=240,haste=220,mastery=0,  versatility=0  } },
            { itemId=212511, name="Keg of Liquid Flames",          slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212512, name="Beekeeper's Smoked Trinket",    slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212513, name="Emberbrand Blade",              slot="MAINHAND", ilvl=619, weaponType="ONE_HAND",stats={crit=260,haste=240,mastery=0,  versatility=0  } },
            { itemId=212514, name="Meadery Pummeler",              slot="MAINHAND", ilvl=619, weaponType="ONE_HAND",stats={crit=0,  haste=280,mastery=260,versatility=0  } },
        },
    },

    ["Priory of the Sacred Flame"] = {
        id = "priory-sacred-flame",
        drops = {
            { itemId=212520, name="Devout Crusader's Helm",        slot="HEAD",     ilvl=619, armorType="PLATE",    stats={crit=250,haste=230,mastery=0,  versatility=0  } },
            { itemId=212521, name="Pauldrons of the Sacred Flame", slot="SHOULDER", ilvl=619, armorType="PLATE",    stats={crit=0,  haste=260,mastery=0,  versatility=240} },
            { itemId=212522, name="Cloak of Holy Embers",          slot="BACK",     ilvl=619, armorType="CLOAK",    stats={crit=180,haste=0,  mastery=200,versatility=0  } },
            { itemId=212523, name="Breastplate of Sacred Vows",    slot="CHEST",    ilvl=619, armorType="PLATE",    stats={crit=0,  haste=300,mastery=280,versatility=0  } },
            { itemId=212524, name="Bracers of the Ardent Flame",   slot="WRIST",    ilvl=619, armorType="MAIL",     stats={crit=200,haste=0,  mastery=0,  versatility=220} },
            { itemId=212525, name="Gauntlets of the Holy Pyre",    slot="HANDS",    ilvl=619, armorType="PLATE",    stats={crit=0,  haste=240,mastery=260,versatility=0  } },
            { itemId=212526, name="Girdle of Sacred Fire",         slot="WAIST",    ilvl=619, armorType="MAIL",     stats={crit=220,haste=200,mastery=0,  versatility=0  } },
            { itemId=212527, name="Legplates of the Priory",       slot="LEGS",     ilvl=619, armorType="PLATE",    stats={crit=0,  haste=0,  mastery=290,versatility=270} },
            { itemId=212528, name="Sabatons of the Holy March",    slot="FEET",     ilvl=619, armorType="PLATE",    stats={crit=210,haste=230,mastery=0,  versatility=0  } },
            { itemId=212529, name="Ring of the Sacred Order",      slot="FINGER",   ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=220,mastery=200,versatility=0  } },
            { itemId=212530, name="Pendant of Hallowed Flame",     slot="NECK",     ilvl=619, armorType="JEWELRY",  stats={crit=230,haste=0,  mastery=0,  versatility=210} },
            { itemId=212531, name="Tome of Holy Rites",            slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212532, name="Sacred Flame Effigy",           slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212533, name="Sword of the Sacred Flame",     slot="MAINHAND", ilvl=619, weaponType="ONE_HAND",stats={crit=260,haste=240,mastery=0,  versatility=0  } },
            { itemId=212534, name="Holy Avenger's Shield",         slot="OFFHAND",  ilvl=619, weaponType="SHIELD",  stats={crit=0,  haste=270,mastery=0,  versatility=250} },
        },
    },

    ["Operation: Floodgate"] = {
        id = "operation-floodgate",
        drops = {
            { itemId=212540, name="Floodwarden's Helm",            slot="HEAD",     ilvl=619, armorType="MAIL",     stats={crit=240,haste=0,  mastery=260,versatility=0  } },
            { itemId=212541, name="Shoulderplates of the Deluge",  slot="SHOULDER", ilvl=619, armorType="PLATE",    stats={crit=0,  haste=280,mastery=0,  versatility=260} },
            { itemId=212542, name="Cloak of the Rising Waters",    slot="BACK",     ilvl=619, armorType="CLOAK",    stats={crit=200,haste=180,mastery=0,  versatility=0  } },
            { itemId=212543, name="Floodgate Chestguard",          slot="CHEST",    ilvl=619, armorType="LEATHER",  stats={crit=0,  haste=0,  mastery=300,versatility=280} },
            { itemId=212544, name="Bracers of the Torrent",        slot="WRIST",    ilvl=619, armorType="MAIL",     stats={crit=210,haste=230,mastery=0,  versatility=0  } },
            { itemId=212545, name="Grips of the Geyser",           slot="HANDS",    ilvl=619, armorType="PLATE",    stats={crit=0,  haste=250,mastery=270,versatility=0  } },
            { itemId=212546, name="Tide-Lashed Belt",              slot="WAIST",    ilvl=619, armorType="LEATHER",  stats={crit=220,haste=0,  mastery=0,  versatility=240} },
            { itemId=212547, name="Legguards of the Floodgate",    slot="LEGS",     ilvl=619, armorType="PLATE",    stats={crit=0,  haste=290,mastery=310,versatility=0  } },
            { itemId=212548, name="Boots of the Rising Tide",      slot="FEET",     ilvl=619, armorType="MAIL",     stats={crit=200,haste=220,mastery=0,  versatility=0  } },
            { itemId=212549, name="Ring of the Surging Current",   slot="FINGER",   ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=240,mastery=220,versatility=0  } },
            { itemId=212550, name="Amulet of the Open Floodgate",  slot="NECK",     ilvl=619, armorType="JEWELRY",  stats={crit=230,haste=0,  mastery=210,versatility=0  } },
            { itemId=212551, name="Pressure Valve Trinket",        slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212552, name="Surge Capacitor",               slot="TRINKET",  ilvl=619, armorType="JEWELRY",  stats={crit=0,  haste=0,  mastery=0,  versatility=0  } },
            { itemId=212553, name="Floodgate Cleaver",             slot="MAINHAND", ilvl=619, weaponType="ONE_HAND",stats={crit=260,haste=240,mastery=0,  versatility=0  } },
            { itemId=212554, name="Tide-Caller's Staff",           slot="MAINHAND", ilvl=619, weaponType="STAFF",   stats={crit=0,  haste=300,mastery=280,versatility=0  } },
        },
    },

}
