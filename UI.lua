-- GearAdvisor: UI
-- Renders the main advisor window

GearAdvisorUI = {}

local FRAME_WIDTH  = 540
local FRAME_HEIGHT = 580
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
    if score >= 75 then return "★★★★★"
    elseif score >= 55 then return "★★★★☆"
    elseif score >= 35 then return "★★★☆☆"
    elseif score >= 15 then return "★★☆☆☆"
    else return "★☆☆☆☆" end
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

-- Create main window
function GearAdvisorUI:Create()
    if self.frame then return end

    local f = CreateFrame("Frame", "GearAdvisorFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    -- Title
    f.TitleText:SetText("⚔  GearAdvisor — M+ Upgrade Finder")

    -- Subtitle / instruction bar
    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -30)
    subtitle:SetText("|cffAAAAAAClick a dungeon for slot details  •  Hover for tooltip|r")

    -- Scan button
    local scanBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    scanBtn:SetSize(90, 22)
    scanBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -26)
    scanBtn:SetText("Rescan Gear")
    scanBtn:SetScript("OnClick", function()
        GearAdvisor.playerGear = GearAdvisor:GetEquippedGear()
        GearAdvisorUI:Refresh()
    end)

    -- Scroll frame
    local sf = CreateFrame("ScrollFrame", "GearAdvisorScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",  f, "TOPLEFT",  10, -54)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)

    local scrollChild = CreateFrame("Frame", "GearAdvisorScrollChild", sf)
    scrollChild:SetSize(FRAME_WIDTH - 40, 800)
    sf:SetScrollChild(scrollChild)

    f:Hide()

    self.frame       = f
    self.scrollChild = scrollChild
end

function GearAdvisorUI:Refresh()
    local gear    = GearAdvisor.playerGear or GearAdvisor:GetEquippedGear()
    local results = GearAdvisorCalc:RankDungeons(gear)
    BuildDungeonRows(self.scrollChild, results)
    -- Clear detail panel
    for _, r in ipairs(detailRows) do r:Hide() end
    detailRows = {}
    if detailHeader then detailHeader:Hide() end
end

function GearAdvisorUI:Toggle()
    self:Create()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:Refresh()
        self.frame:Show()
    end
end
