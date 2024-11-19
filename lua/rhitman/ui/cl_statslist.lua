--[[
    rHitman - Statistics Menu
    Shows player statistics for both contractor and hitman roles
]]--

local PANEL = {}

function PANEL:Init()
    if not rHitman.UI then
        ErrorNoHalt("[rHitman] UI utilities not loaded!\n")
        return
    end

    -- Create main container
    self:DockPadding(10, 10, 10, 10)
    
    -- Create title
    self.TitleLabel = vgui.Create("DLabel", self)
    self.TitleLabel:SetText("rHitman Statistics")
    self.TitleLabel:SetFont("rHitman.Title")
    self.TitleLabel:SetTextColor(rHitman.UI.Colors.Text)
    self.TitleLabel:Dock(TOP)
    self.TitleLabel:DockMargin(10, 10, 10, 5)
    self.TitleLabel:SetTall(30)
    self.TitleLabel:SetContentAlignment(5)
    
    -- Create scroll panel
    self.scroll = vgui.Create("DScrollPanel", self)
    self.scroll:Dock(FILL)
    self.scroll:DockMargin(0, 5, 0, 0)
    
    -- Style the scrollbar
    local sbar = self.scroll:GetVBar()
    sbar:SetHideButtons(true)
    function sbar:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, rHitman.UI.Colors.Background)
    end
    function sbar.btnGrip:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, rHitman.UI.Colors.Primary)
    end

    self:UpdateStats()
end

function PANEL:AddSection(title)
    local section = vgui.Create("DPanel", self.scroll)
    section:Dock(TOP)
    section:DockMargin(5, 5, 5, 10)
    section:SetTall(25)
    section.Paint = function(self, w, h)
        draw.SimpleText(title, "rHitman.Text.Large", 5, h/2, rHitman.UI.Colors.Primary, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.RoundedBox(2, 0, h-2, w, 2, rHitman.UI.Colors.Primary)
    end
    return section
end

function PANEL:CreateStatRow(parent, label, value, color)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(10, 5, 10, 5)
    row:SetTall(30)
    row.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.SurfaceLight)
        draw.SimpleText(label, "rHitman.Text", 10, h/2, rHitman.UI.Colors.TextDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(value, "rHitman.Text", w-10, h/2, color or rHitman.UI.Colors.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    return row
end

function PANEL:UpdateStats()
    self.scroll:Clear()
    
    local stats = rHitman.Stats.cache
    if not stats then
        rHitman.Stats:Load()
        stats = rHitman.Stats.cache
    end
    if not stats then return end
    
    -- Rank Display (without section header)
    local rank = rHitman.Stats:GetRank()
    local rankProgress = rHitman.Stats:GetRankProgress()
    
    local rankPanel = vgui.Create("DPanel", self.scroll)
    rankPanel:Dock(TOP)
    rankPanel:DockMargin(10, 5, 10, 10)
    rankPanel:SetTall(90)
    
    function rankPanel:Paint(w, h)
        -- Background
        draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.Surface)
        
        -- Rank name
        draw.SimpleText(rank.name, "rHitman.Text.Large", w/2, 25, rank.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Progress bar
        local barWidth = w - 40
        local barHeight = 6
        local barX = 20
        local barY = h - 20
        
        -- Background
        draw.RoundedBox(4, barX, barY, barWidth, barHeight, rHitman.UI.Colors.SurfaceLight)
        
        -- Progress
        local fillWidth = math.Clamp((rankProgress / 100) * barWidth, 0, barWidth)
        draw.RoundedBox(4, barX, barY, fillWidth, barHeight, rank.color)
        
        -- Progress text
        local nextRankIndex = 0
        for i, r in ipairs(rHitman.Config.Ranks) do
            if r.name == rank.name then
                nextRankIndex = i + 1
                break
            end
        end
        
        local progressText
        if nextRankIndex > #rHitman.Config.Ranks then
            progressText = "Maximum Rank Achieved!"
        else
            local nextRank = rHitman.Config.Ranks[nextRankIndex]
            local hitsNeeded = nextRank.minHits - stats.hitman.contractsCompleted
            progressText = string.format("%d hits needed for %s", hitsNeeded, nextRank.name)
        end
        
        draw.SimpleText(progressText, "rHitman.Text.Small", w/2, h - 25, rHitman.UI.Colors.TextDark, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    end
    
    -- Contractor Statistics
    local contractor = self:AddSection("Contractor Statistics")
    local cStats = vgui.Create("DPanel", self.scroll)
    cStats:Dock(TOP)
    cStats:DockMargin(10, 5, 10, 10)
    cStats:SetTall(120)
    
    function cStats:Paint(w, h)
        draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.Surface)
    end
    
    self:CreateStatRow(cStats, "Contracts Created", stats.contractor.contractsCreated or 0)
    self:CreateStatRow(cStats, "Contracts Completed", stats.contractor.contractsCompleted or 0, rHitman.UI.Colors.Success)
    self:CreateStatRow(cStats, "Contracts Failed", stats.contractor.contractsFailed or 0, rHitman.UI.Colors.Danger)
    self:CreateStatRow(cStats, "Money Spent", rHitman.Config.CurrencySymbol .. string.Comma(stats.contractor.moneySpent or 0), rHitman.UI.Colors.Primary)
    
    -- Hitman Statistics
    local hitman = self:AddSection("Hitman Statistics")
    local hStats = vgui.Create("DPanel", self.scroll)
    hStats:Dock(TOP)
    hStats:DockMargin(10, 5, 10, 5)
    hStats:SetTall(120)
    
    function hStats:Paint(w, h)
        draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.Surface)
    end
    
    self:CreateStatRow(hStats, "Contracts Completed", stats.hitman.contractsCompleted or 0, rHitman.UI.Colors.Success)
    self:CreateStatRow(hStats, "Contracts Failed", stats.hitman.contractsFailed or 0, rHitman.UI.Colors.Danger)
    self:CreateStatRow(hStats, "Money Earned", rHitman.Config.CurrencySymbol .. string.Comma(stats.hitman.moneyEarned or 0), rHitman.UI.Colors.Primary)
    self:CreateStatRow(hStats, "Targets Eliminated", stats.hitman.targetsEliminated or 0, rank.color)
end

function PANEL:Paint(w, h)
    draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.Background)
end

vgui.Register("rHitman.StatsList", PANEL, "DPanel")
