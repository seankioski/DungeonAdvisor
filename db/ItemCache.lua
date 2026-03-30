-- GearAdvisor: ItemCache
-- Attempts to fetch live secondary stats from the WoW client item cache
-- using GetItemStats(itemLink). Falls back to hardcoded stats if the
-- client hasn't cached the item yet (i.e. player has never seen it).

GearAdvisorItemCache = {}

-- WoW stat ID constants used by GetItemStats()
-- Full list: https://wowpedia.fandom.com/wiki/Enum.ItemMod
local STAT_IDS = {
    crit        = 32,   -- ITEM_MOD_CRIT_RATING_SHORT
    haste       = 36,   -- ITEM_MOD_HASTE_RATING_SHORT
    mastery     = 49,   -- ITEM_MOD_MASTERY_RATING_SHORT
    versatility = 40,   -- ITEM_MOD_VERSATILITY
}

-- In-session cache: itemId -> { crit, haste, mastery, versatility, fromClient }
local sessionCache = {}

-- Build a minimal item link from an itemId so GetItemStats can query it.
-- Format: |cff...|Hitem:ITEMID:::::::::::::|h[name]|h|r
local function MakeItemLink(itemId)
    return string.format(
        "|cff1eff00|Hitem:%d:0:0:0:0:0:0:0:0:0:0:0:0|h[item]|h|r",
        itemId
    )
end

-- Try to get live stats for a single itemId from the client cache.
-- Returns a stats table or nil if not cached.
local function FetchLiveStats(itemId)
    local item = Item:CreateFromItemID(itemId)
    local rawStats = {}

    local statTable = C_Item.GetItemStats(item)
    if not statTable then return nil end

    local any = false
    for _, v in pairs(rawStats) do
        if v and v > 0 then any = true break end
    end
    if not any then return nil end

    local stats = { crit=0, haste=0, mastery=0, versatility=0, fromClient=true }
    for statName, statId in pairs(STAT_IDS) do
        stats[statName] = rawStats[statId] or 0
    end

    return stats
end

-- Public: Get stats for a drop, using live data when available.
-- drop must have .itemId and .stats (fallback)
function GearAdvisorItemCache:GetStats(drop)
    local id = drop.itemId
    if not id then
        return drop.stats or { crit=0, haste=0, mastery=0, versatility=0, fromClient=false }
    end

    -- Return session-cached result if we already looked this up
    if sessionCache[id] then
        return sessionCache[id]
    end

    -- Try live fetch
    local live = FetchLiveStats(id)
    if live then
        sessionCache[id] = live
        return live
    end

    -- Fall back to hardcoded stats
    local fallback = {}
    if drop.stats then
        for k, v in pairs(drop.stats) do fallback[k] = v end
    else
        fallback = { crit=0, haste=0, mastery=0, versatility=0 }
    end
    fallback.fromClient = false
    sessionCache[id] = fallback
    return fallback
end

-- Warm the cache for all drops in the loot DB.
-- Called on login so items have a chance to be fetched before the UI opens.
-- Uses C_Item.RequestLoadItemDataByID to ask the client to cache items it
-- doesn't already know about.
function GearAdvisorItemCache:WarmCache()
    for _, dungeon in pairs(GearAdvisorLootDB) do
        for _, drop in ipairs(dungeon.drops) do
            if drop.itemId then
                -- Request the item data; result comes in on ITEM_DATA_LOAD_RESULT
                C_Item.RequestLoadItemDataByID(drop.itemId)
            end
        end
    end
end

-- Listen for item data load events to update the session cache
local warmFrame = CreateFrame("Frame")
warmFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
warmFrame:SetScript("OnEvent", function(self, event, itemId, success)
    if event == "ITEM_DATA_LOAD_RESULT" and success and itemId then
        -- Only bother if it's in our DB and not yet live-cached
        if not sessionCache[itemId] or not sessionCache[itemId].fromClient then
            -- Find the drop in the loot DB so we can pass it to FetchLiveStats
            for _, dungeon in pairs(GearAdvisorLootDB) do
                for _, drop in ipairs(dungeon.drops) do
                    if drop.itemId == itemId then
                        local live = FetchLiveStats(itemId)
                        if live then
                            sessionCache[itemId] = live
                        end
                        return
                    end
                end
            end
        end
    end
end)
