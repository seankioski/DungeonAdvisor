-- DungeonAdvisor: UI
-- Renders the main advisor window
local addonName, ns = ...

DungeonAdvisorUI = {}

local FRAME_WIDTH  = 800
local FRAME_HEIGHT = 380
local ROW_HEIGHT   = 26
local DETAIL_COLOR = { r = 0.8, g = 0.8, b = 0.8 }

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

-- Tooltip for a dungeon row
local function AttachTooltip(frame, dungeonResult)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(dungeonResult.name, 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Upgrade slots:", dungeonResult.upgradeCount, 1,1,1, 0.2,1,0.2)
        GameTooltip:AddDoubleLine("Total ilvl gain:", "+" .. dungeonResult.totalIlvlGain, 1,1,1, 0.2,1,0.2)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Best upgrades:", 0.9, 0.7, 0.1)
        local shown = 0
        for _, detail in ipairs(dungeonResult.upgradeDetails) do
            if shown >= 8 then
                GameTooltip:AddLine("  ...", 0.6, 0.6, 0.6)
                break
            end
            local slotText = string.format("  [%s]", detail.label)
            local gainText = string.format("%s  |cff00ff44+%d ilvl|r", detail.itemName, detail.gain)
            GameTooltip:AddDoubleLine(slotText, gainText, 0.8,0.8,0.8, 1,1,1)

            -- Secondary stats line
            if detail.stats then
                local s = detail.stats
                local statParts = {}
                if s["ITEM_MOD_CRIT_RATING_SHORT"] then table.insert(statParts, string.format("|cffff4444Crit %d|r", s["ITEM_MOD_CRIT_RATING_SHORT"])) end
                if s["ITEM_MOD_HASTE_RATING_SHORT"] then table.insert(statParts, string.format("|cffFFD700Haste %d|r", s["ITEM_MOD_HASTE_RATING_SHORT"])) end
                if s["ITEM_MOD_MASTERY_RATING_SHORT"] then table.insert(statParts, string.format("|cff44aaFFMastery %d|r", s["ITEM_MOD_MASTERY_RATING_SHORT"])) end
                if s["ITEM_MOD_VERSATILITY"] then table.insert(statParts, string.format("|cff44ff88Vers %d|r", s["ITEM_MOD_VERSATILITY"])) end
                if #statParts > 0 then
                    GameTooltip:AddLine("     " .. table.concat(statParts, "  "))
                end
            end
            shown = shown + 1
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Build the detail panel shown below the dungeon list
local detailRows = {}
local detailHeader
local dungeonRows = {}

local function RenderDetailPanel(scrollChild, dungeonResult, yStart)
    -- Clear previous detail rows
    for _, r in ipairs(detailRows) do r:Hide() end
    detailRows = {}

    if detailHeader then detailHeader:Hide() end

    -- Header
    detailHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detailHeader:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, yStart - 10)
    detailHeader:SetText("|cffFFD700" .. dungeonResult.name .. "|r — Upgrade Details")
    detailHeader:Show()

    local y = yStart - 36
    for i, detail in ipairs(dungeonResult.upgradeDetails) do
        -- Main row: slot, item name, ilvl change
        local row = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, y)
        row:SetWidth(FRAME_WIDTH - 40)
        row:SetJustifyH("LEFT")
        local arrow = "|cff888888" .. detail.currentIlvl .. "|r → |cff00ff00" .. detail.dropIlvl .. "|r"
        local gain  = "|cff00ff44(+" .. detail.gain .. ")|r"
        row:SetText(string.format("  |cffFFD700[%s]|r  %s  %s  %s",
            detail.label, detail.itemName, arrow, gain))
        row:Show()
        table.insert(detailRows, row)
        y = y - 20

        -- Secondary stats sub-row
        if detail.stats then
            local s = detail.stats
            local statParts = {}
            if s["ITEM_MOD_CRIT_RATING_SHORT"] then table.insert(statParts, string.format("|cffff4444Crit %d|r",      s["ITEM_MOD_CRIT_RATING_SHORT"])) end
            if s["ITEM_MOD_HASTE_RATING_SHORT"] then table.insert(statParts, string.format("|cffFFD700Haste %d|r",     s["ITEM_MOD_HASTE_RATING_SHORT"])) end
            if s["ITEM_MOD_MASTERY_RATING_SHORT"] then table.insert(statParts, string.format("|cff44aaFFMastery %d|r",   s["ITEM_MOD_MASTERY_RATING_SHORT"])) end
            if s["ITEM_MOD_VERSATILITY"] then table.insert(statParts, string.format("|cff44ff88Vers %d|r",      s["ITEM_MOD_VERSATILITY"])) end
            local sourceTag = detail.fromClient and "|cff888888 (live stats)|r" or "|cff555555 (estimated)|r"
            if #statParts > 0 then
                local statRow = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                statRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 38, y)
                statRow:SetWidth(FRAME_WIDTH - 60)
                statRow:SetJustifyH("LEFT")
                statRow:SetText(table.concat(statParts, "  ") .. sourceTag)
                statRow:Show()
                table.insert(detailRows, statRow)
                y = y - 18
            else
                y = y - 4
            end
        end
    end
end

function DungeonAdvisorUI:RebuildScrollChild()
    if not self.scrollFrame then return end
    -- Destroy the old scroll child and create a fresh one
    if self.scrollChild then
        self.scrollChild:Hide()
        self.scrollChild:SetParent(nil)
    end

    local scrollChild = CreateFrame("Frame", nil, self.scrollFrame)
    scrollChild:SetSize(FRAME_WIDTH - 180, 800)
    self.scrollFrame:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild

    -- Reset detail panel references since the parent is gone
    detailRows = {}
    detailHeader = nil
    dungeonRows = {}
end

-- Build the main dungeon list rows
local function BuildDungeonRows(scrollChild, results)
    -- Clear old rows
    for _, r in ipairs(dungeonRows) do
        if r.bg then r.bg:Hide() end
        if r.label then r.label:Hide() end
        if r.stars then r.stars:Hide() end
        if r.info then r.info:Hide() end
    end
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
    headerDrops:SetText("% Upgrades")
    headerDrops:SetTextColor(1, 1, 1)
    AttachHeaderTooltip(headerDrops, scrollChild,
        "% Upgrades",
        "How many of this dungeon's drops are an upgrade for you.\n(Upgrades / Total drops).")

    local headerInfo = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerInfo:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -20, headerY)
    headerInfo:SetText("Upgrades / iLvl")
    headerInfo:SetTextColor(1, 1, 1)
    AttachHeaderTooltip(headerInfo, scrollChild,
        "Upgrades / iLvl",
        "Number of upgrade slots found in this dungeon, and the total cumulative ilvl gain across all of them.")

    local y = headerY - 20
    for i, result in ipairs(results) do
        local r, g, b = ScoreColor(result.score)
        -- local stars    = ScoreStars(result.score)

        -- Clickable highlight background
        local bg = CreateFrame("Button", nil, scrollChild)
        bg:SetHeight(ROW_HEIGHT + 4)
        bg:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  6,  y)
        bg:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -6, y)

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

        -- Efficiency label (replacing stars)
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

        -- Drop count
        local upgradePct = result.dropCount > 0 
            and math.floor((result.upgradeCount / result.dropCount) * 100) 
            or 0

        local dropsText = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        dropsText:SetPoint("LEFT", bg, "LEFT", 350, 0)
        dropsText:SetWidth(90)
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
        dropsText:SetText(pctColor .. upgradePct .. "%|r" .. " (" .. result.upgradeCount .. "/" .. result.dropCount .. ") ")

        -- Info: upgrades + ilvl
        local info = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        info:SetPoint("RIGHT", bg, "RIGHT", -8, 0)
        info:SetJustifyH("RIGHT")
        local upgradeStr = result.upgradeCount .. " slot" .. (result.upgradeCount == 1 and "" or "s")
        local gainStr    = "+" .. result.totalIlvlGain .. " ilvl"

        info:SetText("|cff00ff00" .. upgradeStr .. "|r  |cffaaddff" .. gainStr .. "|r ")

        AttachTooltip(bg, result)

        -- Click to show details below the list
        local capturedResult = result
        bg:SetScript("OnClick", function()
            --local detailY = -(#results * (ROW_HEIGHT + 6) + 30)
            --RenderDetailPanel(scrollChild, capturedResult, detailY)
        end)

        table.insert(dungeonRows, { bg = bg, label = label, stars = starsFS, info = info })

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
    local yOffset = -30  -- Start below the title
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

    -- Scan button (adjust position)
    local scanBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    scanBtn:SetSize(90, 22)
    scanBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -26)
    scanBtn:SetText("Rescan Gear")
    scanBtn:SetScript("OnClick", function()
        DungeonAdvisorUI:Refresh()
    end)

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

    -- Scroll frame (positioned to the right of the sidebar)
    local sf = CreateFrame("ScrollFrame", "DungeonAdvisorScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)  -- Right of sidebar
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)
    self.scrollFrame = sf

    local scrollChild = CreateFrame("Frame", "DungeonAdvisorScrollChild", sf)
    scrollChild:SetSize(FRAME_WIDTH - 180, 800)  -- Adjust width to fit new layout
    sf:SetScrollChild(scrollChild)

    f:Hide()

    self.frame       = f
    self.scrollChild = scrollChild
end

local specString
function DungeonAdvisorUI:UpdateSpecInfo()
    if not self.frame then return end
    if not specString then
        specString = sidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        specString:SetPoint("TOP", sidebar, "TOP", 0, 0)
        specString:SetJustifyH("CENTER")
    end
    specString:SetText(string.format("%s %s", ns.state.selectedSpecName, ns.state.selectedClassName))
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
