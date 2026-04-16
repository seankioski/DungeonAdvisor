-- DungeonAdvisor: UI
-- Renders the main advisor window
local addonName, ns = ...

DungeonAdvisorUI = {}

local FRAME_WIDTH  = 1390
local FRAME_HEIGHT = 460
local ROW_HEIGHT   = 26
local DETAIL_WIDTH = 350
local SLOT_SORT_ORDER = {
    ["Main Hand"] = 1,
    ["Off Hand"]  = 2,
    ["Head"]      = 3,
    ["Neck"]      = 4,
    ["Shoulder"]  = 5,
    ["Back"]      = 6,
    ["Chest"]     = 7,
    ["Wrist"]     = 8,
    ["Hands"]     = 9,
    ["Waist"]     = 10,
    ["Legs"]      = 11,
    ["Feet"]      = 12,
    ["Ring"]      = 13,
    ["Trinket"]   = 14,
}

-- Helper to attach a tooltip to a FontString via an invisible frame
local function AttachHeaderTooltip(fontString, parent, title, body)
    local tip = CreateFrame("Frame", nil, parent)
    tip:SetAllPoints(fontString)
    tip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(title, 1, 0.82, 0)
        GameTooltip:AddLine(body, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    tip:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Create a thin horizontal divider
local function CreateDivider(parent, yOffset)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT",  parent, "TOPLEFT",  10, yOffset)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, yOffset)
    line:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    return line
end

-- Build the detail panel shown below the dungeon list
local dungeonRows = {}
local pinnedResult = nil   -- set when a dungeon is clicked, cleared on second click
local detailPanel          -- the frame itself
local detailContent = {}   -- font strings inside the panel, rebuilt on each render
local detailScrollChild
local statInputs = {}

local function CreateStatInputs(parent)
    local stats = {
        { key = "crit",        label = "Crit" },
        { key = "haste",       label = "Haste" },
        { key = "mastery",     label = "Mastery" },
        { key = "versatility", label = "Versatility" },
    }

    local startY = -85  -- below spec text (shifted for inspect banner buffer)

    for i, stat in ipairs(stats) do
        local rowY = startY - (i - 1) * 26

        -- Label
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, rowY)
        label:SetText(stat.label)

        -- Input box
        local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        editBox:SetSize(36, 20)
        editBox:SetPoint("LEFT", label, "LEFT", 78, 0)
        editBox:SetAutoFocus(false)
        editBox:SetNumeric(false)

        editBox:SetScript("OnEnterPressed", function(self)
            local val = tonumber(self:GetText())
            if val then
                ns:SetStatWeight(stat.key, val)
                DungeonAdvisorUI:RefreshDungeonList()
            end
            self:ClearFocus()
        end)

        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)

        statInputs[stat.key] = editBox
    end
end

local function CreateRadioButton(parent, label, group, onSelected)
    local btn = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")

    btn.text:SetText(label)
    btn.group = group

    btn:SetScript("OnClick", function(self)
        -- Uncheck all others in the group
        for _, other in ipairs(self.group) do
            other:SetChecked(false)
        end

        -- Check this one
        self:SetChecked(true)

        -- Fire callback
        if onSelected then
            onSelected()
        end
    end)

    table.insert(group, btn)

    return btn
end

local tierCheckboxes = {}  -- keyed by slot key, populated by CreateIgnoreTierInputs
local weaponRadio2H  -- "2H Only" radio button
local weaponRadio1H  -- "All" radio button

local function CreateIgnoreTierInputs(parent)
    if not DungeonAdvisorCharDB.ignoreTiers then
        DungeonAdvisorCharDB.ignoreTiers = {}
    end

    local slots = {
        { key = "HEAD",        label = "Head" },
        { key = "SHOULDER",    label = "Shoulder" },
        { key = "CHEST",       label = "Chest" },
        { key = "HANDS",       label = "Hands" },
        { key = "LEGS",        label = "Legs" },
    }

    local startY = -225

    for i, stat in ipairs(slots) do
        local rowY = startY - (i - 1) * 26

        -- Label
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, rowY)
        label:SetText(stat.label)

        local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, rowY + 10)
        checkbox:SetChecked(DungeonAdvisorCharDB.ignoreTiers and DungeonAdvisorCharDB.ignoreTiers[stat.key])

        -- Click handler
        checkbox:SetScript("OnClick", function(self)
            local isChecked = self:GetChecked()
            DungeonAdvisorCharDB.ignoreTiers[stat.key] = isChecked
            DungeonAdvisorUI:RefreshDungeonList()
        end)

        tierCheckboxes[stat.key] = checkbox
    end
end

local function ClearDetailPanel()
    for _, fs in ipairs(detailContent) do fs:Hide() end
    detailContent = {}
end

local function AddLine(text, r, g, b, indent, fontSize)
    local font = fontSize == "small" and "GameFontHighlightSmall" or "GameFontHighlight"
    local fs = detailScrollChild:CreateFontString(nil, "OVERLAY", font)
    local yOffset = -(#detailContent * 16 + 8)
    fs:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", indent or 8, yOffset)
    fs:SetWidth(DETAIL_WIDTH - (indent or 8) - 8)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetText(text)
    fs:Show()
    table.insert(detailContent, fs)
end

local function RenderDetailPanel(result)
    ClearDetailPanel()
    if not detailScrollChild then return end
    local weights = ns:GetSpecWeights()

    if not result then
        AddLine("\n\n\n\n\n\n\n\n\n\n\n\n\n\n        Hover over or click a dungeon to see details", 0.6, 0.6, 0.6)
        return
    end

    -- Header
    AddLine(result.name, 1, 0.82, 0)
    if result.upgradeCount > 0 then
        AddLine(string.format("%d ilvl upgrades  +%d ilvl total", result.upgradeCount, result.totalIlvlGain), 0.2, 1, 0.2)
    end
    if result.statUpgradeCount > 0 then
        AddLine(string.format("%d stat upgrades", result.statUpgradeCount), 0.2, 1, 0.2)
    end
    if result.trackUpgradeCount > 0 then
        AddLine(string.format("%d track upgrades", result.trackUpgradeCount), 0.2, 1, 0.2)
    end
    AddLine(" ")

    local sorted = {}
    for _, detail in ipairs(result.upgradeDetails) do
        table.insert(sorted, detail)
    end
    -- merge in stat-only upgrades
    if result.statOnlyUpgrades then
        for _, detail in ipairs(result.statOnlyUpgrades) do
            -- If this already exists in sorted, merge the stat-only info into the existing entry instead of adding a duplicate line
            if not sorted[detail.key] then
                table.insert(sorted, detail)
            end
        end
    end
    table.sort(sorted, function(a, b)
        local orderA = SLOT_SORT_ORDER[a.label] or 99
        local orderB = SLOT_SORT_ORDER[b.label] or 99
        return orderA < orderB
    end)

    for _, detail in ipairs(sorted) do
        -- line 1: slot + item name + ilvl arrow all on one line
        local arrow = "|cff888888" .. detail.currentIlvl .. " -> " .. detail.dropIlvl .. "|r"
        local gain  = ""
        if detail.gain > 0 then
            gain = "|cff00ff44+" .. detail.gain .. "|r"
        end
        AddLine(string.format("|cffFFD700[%s]|r %s %s %s", detail.label, detail.itemLink, arrow, gain), 1, 1, 1, 8, "small")

        -- local arrow = "|cff888888" .. detail.currentIlvl .. " -> " .. detail.dropIlvl .. "|r"
        -- local gain  = "|cff00ff44+" .. detail.gain .. "|r"
        -- AddLine(string.format("|cffFFD700[%s]|r  %s  %s", detail.label, arrow, gain), 1, 1, 1, 8, "small")

        -- -- use the actual item link if available, fall back to plain name
        -- AddItemLinkLine(detail.itemLink, detail.itemName, 14)

        -- line 2: secondary stats only if present
        -- if detail.stats then
        --     local s = detail.stats
        --     local parts = {}
        --     if s["ITEM_MOD_CRIT_RATING_SHORT"]    then table.insert(parts, string.format("|cffff4444Crit %d|r",    s["ITEM_MOD_CRIT_RATING_SHORT"]))    end
        --     if s["ITEM_MOD_HASTE_RATING_SHORT"]   then table.insert(parts, string.format("|cffFFD700Haste %d|r",   s["ITEM_MOD_HASTE_RATING_SHORT"]))   end
        --     if s["ITEM_MOD_MASTERY_RATING_SHORT"] then table.insert(parts, string.format("|cff44aaFFMastery %d|r", s["ITEM_MOD_MASTERY_RATING_SHORT"])) end
        --     if s["ITEM_MOD_VERSATILITY"]          then table.insert(parts, string.format("|cff44ff88Vers %d|r",    s["ITEM_MOD_VERSATILITY"]))          end
        --     if #parts > 0 then
        --         AddLine("  " .. table.concat(parts, " · ") .. " |cff888888(" .. detail.currentSecondaryStatScore .. " -> " .. detail.secondaryStatScore .. ")|r", 1, 1, 1, 8, "small")
        --     end
        -- end

        if detail.stats then
            local s = detail.stats
            local parts = {}

            local statDefs = {
                { key = "ITEM_MOD_CRIT_RATING_SHORT",    label = "Crit",    color = "|cffff4444" },
                { key = "ITEM_MOD_HASTE_RATING_SHORT",   label = "Haste",   color = "|cffFFD700" },
                { key = "ITEM_MOD_MASTERY_RATING_SHORT", label = "Mastery", color = "|cff44aaFF" },
                { key = "ITEM_MOD_VERSATILITY",          label = "Vers",    color = "|cff66aaaa" },
            }

            for _, stat in ipairs(statDefs) do
                if s[stat.key] then
                    table.insert(parts, string.format("%s%s %d|r", stat.color, stat.label, s[stat.key]))
                end
            end

            local indicator = ""
            if detail.stats and weights then
                -- normalize weights to proportions
                local totalWeight = 0
                for _, w in pairs(weights) do totalWeight = totalWeight + w end

                local dropRatio = ns:StatRatioScore(detail.stats)
                local currentRatio = ns:StatRatioScore(detail.currentStats)

                if dropRatio > currentRatio + 0.01 then
                    if not DungeonAdvisorCharDB.ignoreTiers[detail.slot] and not ns:startsWith(detail.slot, "TRINKET") then
                        indicator = "|cff00ff00+++|r "
                    end
                end
            end

            local trackTag = ""
            if detail.isTrackUpgrade and detail.dropTrack then
                trackTag = string.format(" |cff00ff00[%s]|r", detail.dropTrack)
            end

            local partsText = ""
            if #parts > 0 then
                partsText = table.concat(parts, " · ")
            end

            AddLine(indicator .. partsText .. trackTag, 1, 1, 1, 14, "small")
        end
    end

    -- update scroll child height to fit content
    detailScrollChild:SetHeight(math.max(#detailContent * 16 + 16, 100))
end

function DungeonAdvisorUI:RebuildScrollChild()
    if not self.scrollFrame then return end

    -- hide and release all children of the list frame
    local child = self.scrollFrame:GetNumChildren()
    for i = 1, child do
        local c = select(i, self.scrollFrame:GetChildren())
        if c then c:Hide() end
    end

    -- also clear any textures/fontstrings (headers, dividers)
    for i = 1, self.scrollFrame:GetNumRegions() do
        local r = select(i, self.scrollFrame:GetRegions())
        if r then r:Hide() end
    end

    dungeonRows = {}
    pinnedResult = nil
    RenderDetailPanel(nil)
end

-- Build the main dungeon list rows
local function BuildDungeonRows(scrollChild, results)
    -- Clear old rows and detail panel
    for _, r in ipairs(dungeonRows) do
        if r.bg then r.bg:Hide() end
        if r.label then r.label:Hide() end
        if r.stars then r.stars:Hide() end
    end
    pinnedResult = nil
    RenderDetailPanel(nil)
    dungeonRows = {}

    -- Efficiency gradient range
    local minEff = math.huge
    local maxEff = 0
    for _, result in ipairs(results) do
        local eff = result.efficiency or 0
        if eff < minEff then minEff = eff end
        if eff > maxEff then maxEff = eff end
    end
    if minEff == math.huge then minEff = 0 end
    if maxEff == 0 then maxEff = 1 end

    local headerY = -30
    local headerName = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerName:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 40, headerY)
    headerName:SetText("Dungeon")
    headerName:SetTextColor(1, 1, 1)
    AttachHeaderTooltip(headerName, scrollChild,
        "Dungeon",
        "The name of the Mythic+ dungeon, ranked by overall upgrade score.")

    local headerEff = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerEff:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 250, headerY)
    headerEff:SetText("Efficiency")
    headerEff:SetTextColor(1, 1, 1)
    AttachHeaderTooltip(headerEff, scrollChild,
        "Efficiency",
        "Efficiency factor for obtaining upgrades. Higher is better.\nFactors in:\n- ilvl upgrades\n- secondary stat weights\n- item track upgrades")

    local headerDrops = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerDrops:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 335, headerY)
    headerDrops:SetText("iLvl Upgrades")
    headerDrops:SetTextColor(1, 1, 1)
    AttachHeaderTooltip(headerDrops, scrollChild,
        "% Upgrades",
        "How many of this dungeon's drops are an iLvl upgrade for you.\n(Upgrades / Total drops).")

    local headerStatUpgrades = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerStatUpgrades:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 490, headerY)
    headerStatUpgrades:SetText("Stat Upgrades")
    headerStatUpgrades:SetTextColor(1, 1, 1)
    AttachHeaderTooltip(headerStatUpgrades, scrollChild,
        "Stat Upgrades",
        "How many drops have a better secondary stat distribution than your currently equipped item.\n(Stat Upgrades / Total drops).")

    local headerTrackUpgrades = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTrackUpgrades:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 600, headerY)
    headerTrackUpgrades:SetText("Track Upgrades")
    headerTrackUpgrades:SetTextColor(1, 1, 1)
    AttachHeaderTooltip(headerTrackUpgrades, scrollChild,
        "Track Upgrades",
        "How many drops are a higher upgrade track than your currently equipped item.\n(e.g. Hero drop when you have Champion gear)")

    local y = headerY - 20
    for i, result in ipairs(results) do
        local upgradePct = result.dropCount > 0 
            and math.floor((result.upgradeCount / result.dropCount) * 100) 
            or 0
        local ilvlpctColor
        if upgradePct >= 50 then
            ilvlpctColor = "|cff00ff00"
        elseif upgradePct >= 25 then
            ilvlpctColor = "|cffFFD700"
        else
            ilvlpctColor = "|cffff4444"
        end

        -- Clickable highlight background
        local bg = CreateFrame("Button", nil, scrollChild)
        bg:SetHeight(ROW_HEIGHT + 4)
        bg:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  6,  y)
        bg:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -6, y)

        local pinHighlight = bg:CreateTexture(nil, "OVERLAY")
        pinHighlight:SetAllPoints()
        pinHighlight:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
        pinHighlight:SetVertexColor(0.4, 0.6, 1, 0.5)
        pinHighlight:Hide()

        local bgTex = bg:CreateTexture(nil, "BACKGROUND")
        bgTex:SetAllPoints()
        bgTex:SetColorTexture(0.1, 0.1, 0.1, 0.5)

        bg:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")

        -- Rank number
        local rankText = bg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rankText:SetPoint("LEFT", bg, "LEFT", 6, 0)
        rankText:SetWidth(24)
        rankText:SetText("|cffAAAAAA" .. i .. ".|r")

        -- Dungeon name
        local label = bg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetPoint("LEFT", rankText, "RIGHT", 4, 0)
        label:SetWidth(210)
        label:SetJustifyH("LEFT")
        label:SetTextColor(1, 1, 1)  -- always white
        label:SetText(result.name)

        -- Efficiency label
        local eff = result.efficiency or 0
        local effNorm = (eff - minEff) / (maxEff - minEff)
        if effNorm < 0 then effNorm = 0 end
        if effNorm > 1 then effNorm = 1 end
        local effR = 1 - effNorm
        local effG = effNorm
        local effB = 0
        local effColor = string.format("|cff%02x%02x%02x", math.floor(effR * 255), math.floor(effG * 255), math.floor(effB * 255))
        local effStr     = string.format("%.2f", eff)
        local efficiencyText = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        efficiencyText:SetPoint("LEFT", label, "RIGHT", 8, 0)
        efficiencyText:SetTextColor(1, 1, 1)
        efficiencyText:SetText(effColor .. effStr .. "|r")

        local effHitbox = CreateFrame("Frame", nil, bg)
        effHitbox:SetPoint("TOPLEFT", efficiencyText, "TOPLEFT", -2, 2)
        effHitbox:SetPoint("BOTTOMRIGHT", efficiencyText, "BOTTOMRIGHT", 2, -2)
        effHitbox:EnableMouse(true)

        effHitbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

            GameTooltip:AddLine("Efficiency Breakdown", 1, 1, 1)
            GameTooltip:AddLine(" ")

            local densityScore = result.totalIlvlGain / result.dropCount * W_ILVL_DENSITY
            local ilvlRateScore = result.upgradeCount / result.dropCount * W_UPGRADE_RATE
            local statRateScore = result.statUpgradeCount / result.dropCount * W_STAT_QUALITY
            local trackScore = result.trackUpgradeCount / result.dropCount * W_TRACK

            -- Label the scores, to 2 deicmal places
            GameTooltip:AddDoubleLine("iLvls:", string.format("%.2f", densityScore + ilvlRateScore), 1,1,0.3, 1,1,0.3)
            GameTooltip:AddDoubleLine("iLvl density:", string.format("%.2f", densityScore), 0.8,0.8,0.8, 0.8,0.8,0.8)
            GameTooltip:AddDoubleLine("Loot drop rate:", string.format("%.2f", ilvlRateScore), 0.8,0.8,0.8, 0.8,0.8,0.8)
            GameTooltip:AddLine(" ")

            GameTooltip:AddDoubleLine("Stats:", string.format("%.2f", statRateScore), 1,1,0.3, 1,1,0.3)
            GameTooltip:AddLine(" ")

            GameTooltip:AddDoubleLine("Item Track:", string.format("%.2f", trackScore), 1,1,0.3, 1,1,0.3)
            GameTooltip:AddLine(" ")


            GameTooltip:AddDoubleLine("Final Efficiency:",
                string.format("%.2f", result.efficiency or 0),
                1,1,1, effR, effG, effB)

            GameTooltip:Show()

            -- 🔑 ALSO trigger row hover manually
            if bg:GetScript("OnEnter") then
                bg:GetScript("OnEnter")(bg)
            end
        end)

        effHitbox:SetScript("OnLeave", function(self)
            GameTooltip:Hide()

            -- 🔑 ALSO trigger row leave manually
            if bg:GetScript("OnLeave") then
                bg:GetScript("OnLeave")(bg)
            end
        end)

        -- ilvl upgrades
        local dropsText = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        dropsText:SetPoint("LEFT", bg, "LEFT", 330, 0)
        dropsText:SetWidth(140)
        dropsText:SetJustifyH("LEFT")
        -- Color the percentage: green if high, yellow if mid, red if low
        local gainStr    = "|cFFAAAAFF+" .. result.totalIlvlGain .. " ilvl|r"
        dropsText:SetText(ilvlpctColor .. upgradePct .. "%|r" .. " (" .. result.upgradeCount .. "/" .. result.dropCount .. ") " .. gainStr)

        local statUpgradePct = result.dropCount > 0
            and math.floor(((result.statUpgradeCount or 0) / result.dropCount) * 100)
            or 0

        local statUpgradeText = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        statUpgradeText:SetPoint("LEFT", bg, "LEFT", 485, 0)
        statUpgradeText:SetWidth(90)
        statUpgradeText:SetJustifyH("LEFT")

        local statPctColor
        if statUpgradePct >= 50 then
            statPctColor = "|cff00ff00"
        elseif statUpgradePct >= 25 then
            statPctColor = "|cffFFD700"
        else
            statPctColor = "|cffff4444"
        end
        statUpgradeText:SetText(statPctColor .. statUpgradePct .. "%|r" .. 
            " (" .. (result.statUpgradeCount or 0) .. "/" .. result.dropCount .. ")")


        --Track upgrade column data
        local trackUpgradePct = result.dropCount > 0
            and math.floor(((result.trackUpgradeCount or 0) / result.dropCount) * 100)
            or 0

        local trackUpgradeText = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        trackUpgradeText:SetPoint("LEFT", bg, "LEFT", 600, 0)
        trackUpgradeText:SetWidth(90)
        trackUpgradeText:SetJustifyH("LEFT")

        local trackPctColor
        if trackUpgradePct >= 50 then
            trackPctColor = "|cff00ff00"
        elseif trackUpgradePct >= 25 then
            trackPctColor = "|cffFFD700"
        else
            trackPctColor = "|cffff4444"
        end
        trackUpgradeText:SetText(trackPctColor .. trackUpgradePct .. "%|r" ..
            " (" .. (result.trackUpgradeCount or 0) .. "/" .. result.dropCount .. ")")



        local capturedResult = result
        local isPinned = false

        bg:SetScript("OnEnter", function()
            if not pinnedResult then
                RenderDetailPanel(capturedResult)
            end
        end)

        bg:SetScript("OnLeave", function()
            if not pinnedResult then
                RenderDetailPanel(nil)
            end
        end)

        bg:SetScript("OnClick", function()
            -- hide pin highlight on previously pinned row
            for _, r in ipairs(dungeonRows) do
                if r.pinHighlight then r.pinHighlight:Hide() end
            end

            if pinnedResult == capturedResult then
                pinnedResult = nil
                RenderDetailPanel(nil)
            else
                pinnedResult = capturedResult
                pinHighlight:Show()
                RenderDetailPanel(capturedResult)
            end
        end)

        table.insert(dungeonRows, { bg = bg, label = label, pinHighlight = pinHighlight })


        y = y - (ROW_HEIGHT + 6)
        if i < #results then
            CreateDivider(scrollChild, y + 2)
        end
    end


    -- Set scroll child height to fit all rows + detail panel space
    scrollChild:SetHeight(math.abs(y) + 0)
end


function DungeonAdvisorUI:RefreshDungeonList()
    self:Create()  -- safe to call multiple times, returns early if already created
    if not DungeonAdvisorLootDB or #DungeonAdvisorLootDB == 0 then
        print("|cff00ccff[DungeonAdvisor]|r Loot DB not loaded yet.")
        return
    end
    self:RebuildScrollChild()
    local gear = DungeonAdvisor.playerGear or DungeonAdvisor:GetEquippedGear()
    local results = DungeonAdvisorCalc:RankDungeons()
    BuildDungeonRows(self.scrollChild, results)
    --print(string.format("|cff00ccff[DungeonAdvisor]|r Refreshed for difficulty %s: %d results", ns.state.selectedDifficulty, #results))
end



-- Overlay + spinner shown while loot data is incomplete
local spinnerFrame
local spinnerTicker

function DungeonAdvisorUI:ShowSpinner()
    if not self.frame then return end

    if not spinnerFrame then
        -- Dark overlay covering the scroll area
        spinnerFrame = CreateFrame("Frame", nil, self.frame)
        spinnerFrame:SetPoint("TOPLEFT",     self.scrollFrame, "TOPLEFT")
        spinnerFrame:SetPoint("BOTTOMRIGHT", self.scrollFrame, "BOTTOMRIGHT")
        spinnerFrame:SetFrameLevel(self.frame:GetFrameLevel() + 10)

        local bg = spinnerFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.6)

        -- Spinning texture (WoW has a built-in loading circle)
        local spin = spinnerFrame:CreateTexture(nil, "OVERLAY")
        spin:SetSize(64, 64)
        spin:SetPoint("CENTER", spinnerFrame, "CENTER", 0, 10)
        spin:SetTexture("Interface\\Icons\\Spell_Holy_CircleOfHealing")
        spinnerFrame.spin = spin

        -- "Loading..." label
        local label = spinnerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetPoint("CENTER", spin, "CENTER", 0, 0)
        label:SetText("|cffAAAAAALoading loot data...|r")
        spinnerFrame.label = label
    end

    spinnerFrame:Show()

    -- Rotate the texture a bit each tick
    local angle = 0
    if spinnerTicker then spinnerTicker:Cancel() end
    spinnerTicker = C_Timer.NewTicker(0.03, function()
        angle = (angle + 6) % 360
        spinnerFrame.spin:SetRotation(math.rad(angle))
    end)
end

function DungeonAdvisorUI:HideSpinner()
    if spinnerTicker then
        spinnerTicker:Cancel()
        spinnerTicker = nil
    end
    if spinnerFrame then
        spinnerFrame:Hide()
    end
end



-- Difficulty buttons on the left (vertical stack)
local difficultyButtons = {}

local function UpdateDifficultyButtonHighlights()
    for _, button in ipairs(difficultyButtons) do
        if button.diff.id == ns.state.selectedDifficulty then
            button.selectedTexture:Show()
            button.text:SetTextColor(1, 1, 1)  -- White text for selected
        else
            button.selectedTexture:Hide()
            button.text:SetTextColor(0.8, 0.8, 0.8)  -- Gray text for unselected
        end
    end
end

local function CreateDifficultyButtons(parent)
    local yOffset = 0  -- Start below the title
    for i, diff in ipairs(ns.DIFFICULTIES.DUNGEON) do
        local button = CreateFrame("Button", nil, parent)
        button:SetSize(120, 25)  -- Width matches old dropdown, height for readability
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
        yOffset = yOffset - 30  -- Stack vertically with spacing

        -- Button text
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.text:SetPoint("CENTER")
        button.text:SetText(diff.fullName)

        -- Background textures for normal/selected states
        button:SetNormalTexture("Interface\\Buttons\\UI-Listbox-Highlight2")  -- Subtle background
        button:GetNormalTexture():SetVertexColor(0.2, 0.2, 0.2, 0.5)  -- Gray when not selected
        button:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight")  -- Highlight on hover
        button:GetHighlightTexture():SetVertexColor(0.5, 0.5, 0.5, 1)

        -- Selected state: brighter background
        button.selectedTexture = button:CreateTexture(nil, "BACKGROUND")
        button.selectedTexture:SetAllPoints()
        button.selectedTexture:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
        button.selectedTexture:SetVertexColor(0.4, 0.6, 1, 0.8)  -- Blue tint for selected
        button.selectedTexture:Hide()  -- Hidden by default

        -- Store difficulty data
        button.diff = diff

        -- OnClick: Select this difficulty and refresh
        button:SetScript("OnClick", function(self)
            ns.state.selectedDifficulty = self.diff.id
            UpdateDifficultyButtonHighlights()  -- Update all buttons' appearance
            DungeonAdvisorUI:RefreshDungeonList()  -- Refresh dungeon rankings
        end)

        table.insert(difficultyButtons, button)

        -- Hide the normal difficulty button
        if diff.id == ns.DIFFICULTIES.DUNGEON[1].id then
            button:Hide()
        end
    end

    -- Initial highlight based on current selection
    UpdateDifficultyButtonHighlights()
end



local configSidebar
local difficultySidebar
function DungeonAdvisorUI:Create()
    if self.frame then return end

    local f = CreateFrame("Frame", "DungeonAdvisorFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetFrameStrata("HIGH")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    -- Title
    f.TitleText:SetText("DungeonAdvisor — M+ Upgrade Finder")

    -- Bottom info
    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)  -- Shift right to avoid configSidebar
    subtitle:SetText("|cffAAAAAAAt the end of a dungeon 2/5 players will get a loot drop|r")

    -- Version
    local verString = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    verString:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    verString:SetText(DungeonAdvisor.version)

    -- configSidebar for difficulty buttons (separate vertical stack)
    configSidebar = CreateFrame("Frame", nil, f)
    configSidebar:SetSize(150, FRAME_HEIGHT - 60)  -- Width for buttons, height to fit
    configSidebar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
    -- Optional: Add a subtle background to the configSidebar
    local configSidebarBg = configSidebar:CreateTexture(nil, "BACKGROUND")
    configSidebarBg:SetAllPoints()
    configSidebarBg:SetColorTexture(0.1, 0.1, 0.1, 0.3)  -- Dark background for separation

    -- "Stat Weights" on configSidebar
    local statWeightText = configSidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statWeightText:SetPoint("TOP", configSidebar, "TOP", 0, -65)
    statWeightText:SetText("Stat Weights")
    AttachHeaderTooltip(statWeightText, configSidebar,
        "Stat Weights",
        "Stat weights are for determining which items are Stat Upgrades.\n\nA stat upgrade has a better ratio of secondary stats.")


    CreateIgnoreTierInputs(configSidebar)

    -- "Ignore Tier Slots" on configSidebar
    local ignoreTierText = configSidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ignoreTierText:SetPoint("TOP", configSidebar, "TOP", 0, -205)
    ignoreTierText:SetText("Ignore Tier Slots")
    AttachHeaderTooltip(ignoreTierText, configSidebar,
        "Ignore Tier Slots",
        "Check the slots which you wear tier items.\n\nIgnored slots do not count for stat upgrades because you will always wear tier in these chosen slots.\n\niLvl and track upgrades are still counted for these slots.")


    -- "Weapon Mode" on configSidebar
    local weaponModeText = configSidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    weaponModeText:SetPoint("TOP", configSidebar, "TOP", 0, -365)
    weaponModeText:SetText("Weapon Mode")
    AttachHeaderTooltip(weaponModeText, configSidebar,
        "Weapon Mode",
        "2H Only - will only consider 2-handed weapons for any upgrade.\n\nAll - Will consider 1-handed/offhand items for all upgrades, as well as 2-handed weapons for iLvl upgrades (since 2H weapons save crests on all weapon upgrades)")


    local radioGroup = {}
    weaponRadio2H = CreateRadioButton(configSidebar, "2H Only", radioGroup, function()
        ns.weaponMode = "2H"
        DungeonAdvisorUI:RefreshDungeonList()
    end)
    weaponRadio1H = CreateRadioButton(configSidebar, "All", radioGroup, function()
        ns.weaponMode = "1H"
        DungeonAdvisorUI:RefreshDungeonList()
    end)
    weaponRadio2H:SetPoint("TOPLEFT", 0, -375)
    weaponRadio1H:SetPoint("TOPRIGHT", -20, -375)
    if ns.playerUsing2H then
        weaponRadio2H:SetChecked(true)
    else
        weaponRadio1H:SetChecked(true)
    end


    -- difficultySidebar for difficulty buttons (separate vertical stack)
    difficultySidebar = CreateFrame("Frame", nil, f)
    difficultySidebar:SetSize(130, FRAME_HEIGHT - 60)  -- Width for buttons, height to fit
    difficultySidebar:SetPoint("TOPLEFT", f, "TOPLEFT", 160, -30)
    -- Optional: Add a subtle background to the difficultySidebar
    local difficultySidebarBg = difficultySidebar:CreateTexture(nil, "BACKGROUND")
    difficultySidebarBg:SetAllPoints()
    difficultySidebarBg:SetColorTexture(0.1, 0.1, 0.1, 0.3)  -- Dark background for separation

    -- "Select Difficulty" on difficultySidebar
    local selectDifficultyText = difficultySidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selectDifficultyText:SetPoint("TOP", difficultySidebar, "TOP", 0, -10)
    selectDifficultyText:SetText("Select Difficulty")

    -- Add difficulty buttons to the configSidebar
    CreateDifficultyButtons(difficultySidebar)

    -- Rescan button and Inspect button side-by-side at the top of configSidebar
    local scanBtn = CreateFrame("Button", nil, configSidebar, "UIPanelButtonTemplate")
    scanBtn:SetSize(68, 22)
    scanBtn:SetPoint("TOPLEFT", configSidebar, "TOPLEFT", 8, 0)
    scanBtn:SetText("Myself")
    scanBtn:SetScript("OnClick", function()
        DungeonAdvisor:ReturnToSelf()
        DungeonAdvisorUI:HideSpinner()
    end)

    local inspectBtn = CreateFrame("Button", nil, configSidebar, "UIPanelButtonTemplate")
    inspectBtn:SetSize(68, 22)
    inspectBtn:SetPoint("TOPLEFT", configSidebar, "TOPLEFT", 79, 0)
    inspectBtn:SetText("Inspect")
    inspectBtn:SetScript("OnClick", function()
        DungeonAdvisor:InspectTarget()
    end)

    -- Detail panel (right side)
    local dp = CreateFrame("Frame", nil, f)
    dp:SetSize(DETAIL_WIDTH, FRAME_HEIGHT - 60)
    dp:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -50)
    dp:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)
    local dpBg = dp:CreateTexture(nil, "BACKGROUND")
    dpBg:SetAllPoints()
    dpBg:SetColorTexture(0.05, 0.05, 0.05, 0.8)
    detailPanel = dp

    -- scrollable content inside detail panel
    local detailSF = CreateFrame("ScrollFrame", nil, dp, "UIPanelScrollFrameTemplate")
    detailSF:SetPoint("TOPLEFT", dp, "TOPLEFT", 0, 0)
    detailSF:SetPoint("BOTTOMRIGHT", dp, "BOTTOMRIGHT", -16, 0)
    local detailChild = CreateFrame("Frame", nil, detailSF)
    detailChild:SetWidth(DETAIL_WIDTH - 20)
    detailChild:SetHeight(800)
    detailChild:EnableMouse(true)
    detailChild:SetHyperlinksEnabled(true)
    detailChild:SetScript("OnHyperlinkEnter", function(self, link, text)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
        end)

    detailChild:SetScript("OnHyperlinkLeave", function()
        GameTooltip:Hide()
    end)
    detailSF:SetScrollChild(detailChild)
    detailScrollChild = detailChild

    -- List frame (now after dp exists so the anchor is valid)
    local listFrame = CreateFrame("Frame", "DungeonAdvisorList", f)
    listFrame:SetPoint("TOPLEFT", difficultySidebar, "TOPRIGHT", 10, 0)
    listFrame:SetPoint("BOTTOMRIGHT", dp, "BOTTOMLEFT", -8, 0)

    f:Hide()
    RenderDetailPanel(nil)

    self.frame       = f
    self.scrollFrame = listFrame
    self.scrollChild = listFrame

    f:Hide()
    RenderDetailPanel(nil)

    self.frame       = f
    self.scrollFrame = listFrame  -- keep same reference name so RebuildScrollChild still works
    self.scrollChild = listFrame
end

local specString
local inspectedBanner
function DungeonAdvisorUI:UpdateSpecInfo()
    if not self.frame then return end
    if not specString then
        specString = configSidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        specString:SetPoint("TOP", configSidebar, "TOP", 0, -26)
        specString:SetJustifyH("CENTER")

        inspectedBanner = configSidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        inspectedBanner:SetPoint("TOP", specString, "BOTTOM", 0, -2)
        inspectedBanner:SetJustifyH("CENTER")
        inspectedBanner:SetWidth(140)

        CreateStatInputs(configSidebar)
    end

    if ns.inspectedPlayerName then
        specString:SetText("|cffFFD700Viewing:|r " .. ns.inspectedPlayerName)
        inspectedBanner:SetText(string.format("(%s %s)", ns.state.selectedSpecName, ns.state.selectedClassName))
        inspectedBanner:Show()
        -- Reflect auto-detected tier slots; disable checkboxes (read-only during inspect)
        local autoTiers = ns.effectiveIgnoreTiers or {}
        for key, cb in pairs(tierCheckboxes) do
            cb:SetChecked(autoTiers[key] or false)
            cb:Disable()
        end
        -- Reflect inspected player's weapon mode; disable radio buttons
        if weaponRadio2H and weaponRadio1H then
            weaponRadio2H:SetChecked(ns.weaponMode == "2H")
            weaponRadio1H:SetChecked(ns.weaponMode ~= "2H")
            weaponRadio2H:Disable()
            weaponRadio1H:Disable()
        end
    else
        specString:SetText(string.format("%s %s", ns.state.selectedSpecName, ns.state.selectedClassName))
        inspectedBanner:Hide()
        -- Restore saved tier choices; re-enable checkboxes
        local saved = DungeonAdvisorCharDB and DungeonAdvisorCharDB.ignoreTiers or {}
        for key, cb in pairs(tierCheckboxes) do
            cb:SetChecked(saved[key] or false)
            cb:Enable()
        end
        -- Restore player's weapon mode selection; re-enable radio buttons
        if weaponRadio2H and weaponRadio1H then
            weaponRadio2H:SetChecked(ns.weaponMode == "2H")
            weaponRadio1H:SetChecked(ns.weaponMode ~= "2H")
            weaponRadio2H:Enable()
            weaponRadio1H:Enable()
        end
    end

    local weights = ns:GetSpecWeights()
    for stat, box in pairs(statInputs) do
        box:SetText(string.format("%.2f", weights[stat] or 1))
    end
end

function DungeonAdvisorUI:Refresh()
    self:Create()  -- ensure frame exists before rebuilding
    if not ns.inspectedPlayerName then
        DungeonAdvisor.playerGear = DungeonAdvisor:GetEquippedGear("player")
        ns:DetectLootSpec()
    end
    DungeonAdvisorUI:UpdateSpecInfo()
    --After loading loot spec, load loot DB to ensure it's for the correct spec. This also ensures the DB is loaded before we try to render anything.
    DungeonAdvisor:InitializeLootDB()
    DungeonAdvisorUI:RefreshDungeonList()
    -- Clear detail panel
end

function DungeonAdvisorUI:Toggle()
    self:Create()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        DungeonAdvisorUI:Refresh()
    end
end
