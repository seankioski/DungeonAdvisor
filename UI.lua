-- DungeonAdvisor: UI
-- Renders the main advisor window
local addonName, ns = ...

DungeonAdvisorUI = {}

local FRAME_WIDTH  = 1130
local FRAME_HEIGHT = 460
local ROW_HEIGHT   = 26
local DETAIL_WIDTH = 330
local DETAIL_COLOR = { r = 0.8, g = 0.8, b = 0.8 }
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

-- Color gradient: green (great) → yellow → orange → red (poor)
local function ScoreColor(score)
    if score >= 70 then
        return 0.2, 1.0, 0.2        -- green
    elseif score >= 45 then
        return 1.0, 0.85, 0.0       -- gold
    elseif score >= 20 then
        return 1.0, 0.5, 0.0        -- orange
    else
        return 0.8, 0.2, 0.2        -- red
    end
end

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

local function StatMatchColor(stats, weights)
    if not stats or not weights then return 1, 1, 1 end

    -- normalize weights to proportions
    local totalWeight = 0
    for _, w in pairs(weights) do totalWeight = totalWeight + w end
    if totalWeight == 0 then return 1, 1, 1 end

    local weightProp = {}
    for key, w in pairs(weights) do
        weightProp[key] = w / totalWeight
    end

    -- normalize item stats to proportions
    local totalStats = 0
    for shortKey, _ in pairs(weights) do
        local wowKey = DungeonAdvisorCalc.STAT_KEY_MAP[shortKey]
        if wowKey then totalStats = totalStats + (stats[wowKey] or 0) end
    end

    if totalStats == 0 then return 0.6, 0.6, 0.6 end  -- no secondary stats, gray

    local statProp = {}
    for shortKey, _ in pairs(weights) do
        local wowKey = DungeonAdvisorCalc.STAT_KEY_MAP[shortKey]
        statProp[shortKey] = wowKey and ((stats[wowKey] or 0) / totalStats) or 0
    end

    -- similarity: 1 - average absolute difference between proportions
    -- perfect match = 1.0, complete mismatch = 0.0
    local totalDiff = 0
    for key, _ in pairs(weights) do
        totalDiff = totalDiff + math.abs((statProp[key] or 0) - (weightProp[key] or 0))
    end
    -- totalDiff ranges 0-2 (sum of absolute differences of proportions)
    local similarity = 1 - (totalDiff / 2)

    -- map similarity to green→yellow→red
    if similarity >= 0.5 then
        -- green to yellow: similarity 1.0=green, 0.5=yellow
        local t = (similarity - 0.5) / 0.5
        return 1 - t, 1, 0  -- r goes 1→0, g stays 1
    else
        -- yellow to red: similarity 0.5=yellow, 0.0=red
        local t = similarity / 0.5
        return 1, t, 0  -- r stays 1, g goes 1→0
    end
end

-- Build the detail panel shown below the dungeon list
local detailRows = {}
local detailHeader
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

    local startY = -50  -- below spec text

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

local function AddItemLinkLine(itemLink, itemName, indent)
    local font = "GameFontHighlightSmall"
    local fs = detailScrollChild:CreateFontString(nil, "OVERLAY", font)
    local yOffset = -(#detailContent * 16 + 8)
    fs:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", indent or 8, yOffset)
    fs:SetWidth(DETAIL_WIDTH - (indent or 8) - 8)
    fs:SetJustifyH("LEFT")
    fs:SetText(itemLink or itemName)
    fs:Show()
    table.insert(detailContent, fs)

    -- invisible button over the font string for tooltip interaction
    local btn = CreateFrame("Button", nil, detailScrollChild)
    btn:SetPoint("TOPLEFT", fs, "TOPLEFT")
    btn:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT")
    btn:SetScript("OnEnter", function(self)
        if itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetHyperlink(itemLink)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    table.insert(detailContent, btn)
end

local function RenderDetailPanel(result)
    ClearDetailPanel()
    if not detailScrollChild then return end
    local weights = ns:GetSpecWeights()

    if not result then
        AddLine("\n\n\n\n\n\n\n\n\n\n\nHover over a dungeon to preview details", 0.6, 0.6, 0.6)
        return
    end

    -- Header
    AddLine(result.name, 1, 0.82, 0)
    AddLine(string.format("%d upgrades  +%d ilvl total", result.upgradeCount, result.totalIlvlGain), 0.2, 1, 0.2)
    AddLine(" ")

    local sorted = {}
    for _, detail in ipairs(result.upgradeDetails) do
        table.insert(sorted, detail)
    end
    -- merge in stat-only upgrades
    if result.statOnlyUpgrades then
        for _, detail in ipairs(result.statOnlyUpgrades) do
            table.insert(sorted, detail)
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
        local gain  = "|cff00ff44+" .. detail.gain .. "|r"
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
                { key = "ITEM_MOD_VERSATILITY",          label = "Vers",    color = "|cff44ff88" },
            }

            for _, stat in ipairs(statDefs) do
                if s[stat.key] then
                    table.insert(parts, string.format("%s%s %d|r", stat.color, stat.label, s[stat.key]))
                end
            end

            if #parts > 0 then
                local indicator = ""
                if detail.stats and weights then
                    -- normalize weights to proportions
                    local totalWeight = 0
                    for _, w in pairs(weights) do totalWeight = totalWeight + w end

                    local dropRatio = ns:StatRatioScore(detail.stats)
                    local currentRatio = ns:StatRatioScore(detail.currentStats)

                    if dropRatio > currentRatio + 0.01 then
                        indicator = "|cff00ffff+|r "
                    end
                end

                AddLine(indicator .. table.concat(parts, " · "), 1, 1, 1, 14, "small")
            end
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

    detailRows = {}
    detailHeader = nil
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
        if r.info then r.info:Hide() end
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
    headerDrops:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 340, headerY)
    headerDrops:SetText("iLvl Upgrades")
    headerDrops:SetTextColor(1, 1, 1)
    AttachHeaderTooltip(headerDrops, scrollChild,
        "% Upgrades",
        "How many of this dungeon's drops are an upgrade for you.\n(Upgrades / Total drops).")

    local headerStatUpgrades = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerStatUpgrades:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 510, headerY)
    headerStatUpgrades:SetText("Stat Upgrades")
    headerStatUpgrades:SetTextColor(1, 1, 1)
    AttachHeaderTooltip(headerStatUpgrades, scrollChild,
        "Stat Upgrades",
        "How many drops have a better secondary stat distribution than your currently equipped item.\n(Stat Upgrades / Total drops).")

    local y = headerY - 20
    for i, result in ipairs(results) do
        local r, g, b = ScoreColor(result.score)
        -- local stars    = ScoreStars(result.score)

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
        bgTex:SetColorTexture(r * 0.12, g * 0.12, b * 0.12, 0.5)

        bg:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")

        -- Rank number
        local rankText = bg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rankText:SetPoint("LEFT", bg, "LEFT", 6, 0)
        rankText:SetWidth(24)
        rankText:SetText("|cffAAAAAA" .. i .. ".|r")

        -- Dungeon name
        local label = bg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetPoint("LEFT", rankText, "RIGHT", 4, 0)
        label:SetWidth(220)
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

            GameTooltip:AddDoubleLine("Total ilvl gain:", result.totalIlvlGain, 0.8,0.8,0.8, 1,1,1)
            GameTooltip:AddDoubleLine("Drop count:", result.dropCount, 0.8,0.8,0.8, 1,1,1)

            GameTooltip:AddLine(" ")

            GameTooltip:AddDoubleLine("Base (gain/drops):",
                string.format("%.2f", result.baseValue or 0),
                0.8,0.8,0.8, 0.6,1,0.6)

            GameTooltip:AddDoubleLine("Avg stat score:",
                string.format("%.2f", result.avgStatScore or 0),
                0.8,0.8,0.8, 0.6,0.8,1)

            GameTooltip:AddDoubleLine("Stat multiplier:",
                string.format("%.2f", result.statMultiplier or 0),
                0.8,0.8,0.8, 1,0.8,0.4)

            GameTooltip:AddLine(" ")

            GameTooltip:AddDoubleLine("Final Efficiency:",
                string.format("%.2f", result.efficiency or 0),
                1,1,1, 0,1,0)

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
        local upgradePct = result.dropCount > 0 
            and math.floor((result.upgradeCount / result.dropCount) * 100) 
            or 0

        local dropsText = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        dropsText:SetPoint("LEFT", bg, "LEFT", 340, 0)
        dropsText:SetWidth(140)
        dropsText:SetJustifyH("LEFT")

        -- Color the percentage: green if high, yellow if mid, red if low
        local pctColor
        if upgradePct >= 50 then
            pctColor = "|cff00ff00"
        elseif upgradePct >= 25 then
            pctColor = "|cffFFD700"
        else
            pctColor = "|cffff4444"
        end
        local gainStr    = "|cFFAAAAFF+" .. result.totalIlvlGain .. " ilvl|r"
        dropsText:SetText(pctColor .. upgradePct .. "%|r" .. " (" .. result.upgradeCount .. "/" .. result.dropCount .. ") " .. gainStr)

        local statUpgradePct = result.dropCount > 0
            and math.floor(((result.statUpgradeCount or 0) / result.dropCount) * 100)
            or 0

        local statUpgradeText = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        statUpgradeText:SetPoint("LEFT", bg, "LEFT", 510, 0)
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

        table.insert(dungeonRows, { bg = bg, label = label, info = info, pinHighlight = pinHighlight })


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
    local yOffset = -140  -- Start below the title
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



local sidebar
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
    subtitle:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)  -- Shift right to avoid sidebar
    subtitle:SetText("|cffAAAAAAAt the end of a dungeon 2/5 players will get a loot drop|r")

    -- Version
    local verString = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    verString:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    verString:SetText(DungeonAdvisor.version)

    -- Sidebar for difficulty buttons (separate vertical stack)
    sidebar = CreateFrame("Frame", nil, f)
    sidebar:SetSize(130, FRAME_HEIGHT - 60)  -- Width for buttons, height to fit
    sidebar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
    -- Optional: Add a subtle background to the sidebar
    local sidebarBg = sidebar:CreateTexture(nil, "BACKGROUND")
    sidebarBg:SetAllPoints()
    sidebarBg:SetColorTexture(0.1, 0.1, 0.1, 0.3)  -- Dark background for separation

    -- Add difficulty buttons to the sidebar
    CreateDifficultyButtons(sidebar)

    -- Rescan button below spec name in sidebar
    local scanBtn = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
    scanBtn:SetSize(110, 22)
    scanBtn:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, -0)
    scanBtn:SetText("Rescan Gear")
    scanBtn:SetScript("OnClick", function()
        DungeonAdvisorUI:Refresh()
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
    listFrame:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
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
function DungeonAdvisorUI:UpdateSpecInfo()
    if not self.frame then return end
    if not specString then
        specString = sidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        specString:SetPoint("TOP", sidebar, "TOP", 0, -26)
        specString:SetJustifyH("CENTER")

        CreateStatInputs(sidebar)
    end

    specString:SetText(string.format("%s %s", ns.state.selectedSpecName, ns.state.selectedClassName))

    local weights = ns:GetSpecWeights()
    for stat, box in pairs(statInputs) do
        box:SetText(string.format("%.2f", weights[stat] or 1))
    end
end

function DungeonAdvisorUI:Refresh()
    self:Create()  -- ensure frame exists before rebuilding
    DungeonAdvisor.playerGear = DungeonAdvisor:GetEquippedGear()
    ns:DetectLootSpec()
    DungeonAdvisorUI:UpdateSpecInfo()
    --After loading loot spec, load loot DB to ensure it's for the correct spec. This also ensures the DB is loaded before we try to render anything.
    DungeonAdvisor:InitializeLootDB()
    DungeonAdvisorUI:RefreshDungeonList()
    -- Clear detail panel
    for _, r in ipairs(detailRows) do r:Hide() end
    detailRows = {}
    if detailHeader then detailHeader:Hide() end
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
