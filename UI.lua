-- DungeonAdvisor: UI
-- Renders the main advisor window
local addonName, ns = ...

DungeonAdvisorUI = {}

local FRAME_WIDTH  = 740
local FRAME_HEIGHT = 480
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

local function ScoreStars(score)
    if score >= 75 then return "OOOOO"
    elseif score >= 55 then return "OOOO."
    elseif score >= 35 then return "OOO.."
    elseif score >= 15 then return "OO..."
    else return "O...." end
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
                if s.crit        > 0 then table.insert(statParts, string.format("|cffff4444Crit %d|r", s.crit)) end
                if s.haste       > 0 then table.insert(statParts, string.format("|cffFFD700Haste %d|r", s.haste)) end
                if s.mastery     > 0 then table.insert(statParts, string.format("|cff44aaFFMastery %d|r", s.mastery)) end
                if s.versatility > 0 then table.insert(statParts, string.format("|cff44ff88Vers %d|r", s.versatility)) end
                local sourceTag = detail.fromClient and "|cff888888(live)|r" or "|cff666666(est.)|r"
                if #statParts > 0 then
                    GameTooltip:AddLine("     " .. table.concat(statParts, "  ") .. "  " .. sourceTag)
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
            if s.crit        > 0 then table.insert(statParts, string.format("|cffff4444Crit %d|r",      s.crit)) end
            if s.haste       > 0 then table.insert(statParts, string.format("|cffFFD700Haste %d|r",     s.haste)) end
            if s.mastery     > 0 then table.insert(statParts, string.format("|cff44aaFFMastery %d|r",   s.mastery)) end
            if s.versatility > 0 then table.insert(statParts, string.format("|cff44ff88Vers %d|r",      s.versatility)) end
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

-- Build the main dungeon list rows
local dungeonRows = {}

local function BuildDungeonRows(scrollChild, results)
    -- Clear old rows
    for _, r in ipairs(dungeonRows) do
        if r.bg then r.bg:Hide() end
        if r.label then r.label:Hide() end
        if r.stars then r.stars:Hide() end
        if r.info then r.info:Hide() end
    end
    dungeonRows = {}

    local y = -10
    for i, result in ipairs(results) do
        local r, g, b = ScoreColor(result.score)
        local stars    = ScoreStars(result.score)

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
        label:SetWidth(230)
        label:SetJustifyH("LEFT")
        label:SetTextColor(r, g, b)
        label:SetText(result.name)

        -- Stars
        local starsFS = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        starsFS:SetPoint("LEFT", label, "RIGHT", 8, 0)
        starsFS:SetTextColor(r, g, b)
        starsFS:SetText(stars)

        -- Info: upgrades + ilvl
        local info = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        info:SetPoint("RIGHT", bg, "RIGHT", -8, 0)
        info:SetJustifyH("RIGHT")
        local upgradeStr = result.upgradeCount .. " slot" .. (result.upgradeCount == 1 and "" or "s")
        local gainStr    = "+" .. result.totalIlvlGain .. " ilvl"
        info:SetText("|cff00ff00" .. upgradeStr .. "|r  |cffaaddff" .. gainStr .. "|r")

        AttachTooltip(bg, result)

        -- Click to show details below the list
        local capturedResult = result
        bg:SetScript("OnClick", function()
            local detailY = -(#results * (ROW_HEIGHT + 6) + 30)
            RenderDetailPanel(scrollChild, capturedResult, detailY)
        end)

        table.insert(dungeonRows, { bg = bg, label = label, stars = starsFS, info = info })

        y = y - (ROW_HEIGHT + 6)
        if i < #results then
            CreateDivider(scrollChild, y + 2)
        end
    end

    -- Set scroll child height to fit all rows + detail panel space
    scrollChild:SetHeight(math.abs(y) + 300)
end


function DungeonAdvisorUI:RefreshDungeonList()
    -- Ensure loot DB is loaded
    if not DungeonAdvisorLootDB or #DungeonAdvisorLootDB == 0 then
        print("|cff00ccff[DungeonAdvisor]|r Loot DB not loaded yet. Try reloading or waiting for login.")
        return
    end
    
    -- Ensure player gear is available (scan if needed)
    local gear = DungeonAdvisor.playerGear or DungeonAdvisor:GetEquippedGear()
    if not gear or next(gear) == nil then
        print("|cff00ccff[DungeonAdvisor]|r Player gear not available. Try rescanning.")
        return
    end
    
    -- Recalculate dungeon rankings with the new selected difficulty
    local results = DungeonAdvisorCalc:RankDungeons(gear)
    
    -- Debug: Check results
    print(string.format("|cff00ccff[DungeonAdvisor]|r Refreshed dungeon list for difficulty %s: %d results", ns.state.selectedDifficulty, #results))
    
    BuildDungeonRows(self.scrollChild, results)
    
    -- Clear any existing detail panel (since the list changed)
    for _, r in ipairs(detailRows) do r:Hide() end
    detailRows = {}
    if detailHeader then detailHeader:Hide() end
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




function DungeonAdvisorUI:Create()
    if self.frame then return end

    local f = CreateFrame("Frame", "DungeonAdvisorFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    -- Title
    f.TitleText:SetText("⚔  DungeonAdvisor — M+ Upgrade Finder")

    -- Subtitle / instruction bar (adjust position to account for sidebar)
    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", f, "TOPLEFT", 150, -30)  -- Shift right to avoid sidebar
    subtitle:SetText("|cffAAAAAAClick a dungeon for slot details  •  Hover for tooltip|r")

    -- Scan button (adjust position)
    local scanBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    scanBtn:SetSize(90, 22)
    scanBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -26)
    scanBtn:SetText("Rescan Gear")
    scanBtn:SetScript("OnClick", function()
        DungeonAdvisor.playerGear = DungeonAdvisor:GetEquippedGear()
        DungeonAdvisorUI:Refresh()
    end)

    -- Sidebar for difficulty buttons (separate vertical stack)
    local sidebar = CreateFrame("Frame", nil, f)
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

    local scrollChild = CreateFrame("Frame", "DungeonAdvisorScrollChild", sf)
    scrollChild:SetSize(FRAME_WIDTH - 180, 800)  -- Adjust width to fit new layout
    sf:SetScrollChild(scrollChild)

    f:Hide()

    self.frame       = f
    self.scrollChild = scrollChild
end

function DungeonAdvisorUI:Refresh()
    local gear    = DungeonAdvisor.playerGear or DungeonAdvisor:GetEquippedGear()
    local results = DungeonAdvisorCalc:RankDungeons(gear)
    BuildDungeonRows(self.scrollChild, results)
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
        self:Refresh()
        self.frame:Show()
    end
end
