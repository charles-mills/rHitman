--[[
    rHitman - UI Utilities
    Contains reusable UI components and helpers
]]--

rHitman = rHitman or {}
rHitman.UI = rHitman.UI or {}

-- Font configuration
rHitman.UI.Fonts = {
    Families = {
        Primary = "Roboto",
        Fallback = "Arial"
    },
    Weights = {
        Normal = 400,
        Medium = 500,
        Bold = 600,
        ExtraBold = 700
    }
}

-- Icons (Material objects)
rHitman.UI.Icons = {
    Sort = Material("icon16/arrow_down.png"),
    Money = Material("icon16/money.png"),
    Accept = Material("icon16/tick.png"),
    Time = Material("icon16/time.png"),
    User = Material("icon16/user.png"),
    Star = Material("icon16/star.png"),
    Location = Material("icon16/world.png")
}

-- Colors
rHitman.UI.Colors = {
    Primary = Color(79, 91, 213),      -- Modern Blue
    Secondary = Color(67, 77, 180),    -- Darker Blue
    Background = Color(18, 18, 18),    -- Dark Background
    Surface = Color(24, 24, 24),       -- Slightly Lighter Surface
    SurfaceLight = Color(32, 32, 32),  -- Lighter Surface for Hover
    Text = Color(255, 255, 255),       -- White Text
    TextDark = Color(180, 180, 180),   -- Gray Text
    Success = Color(67, 181, 129),     -- Modern Green
    Error = Color(240, 71, 71),        -- Modern Red
    Warning = Color(255, 188, 66),     -- Modern Orange
    Accent = Color(79, 91, 213),       -- Same as Primary for consistency
    Health = Color(67, 181, 129),      -- Same as Success for health bar
    Armor = Color(79, 91, 213)         -- Same as Primary for armor bar
}

-- Font utility functions
function rHitman.UI.GetFontFamily()
    -- Check if Roboto is available, otherwise use fallback
    local fontFamily = rHitman.UI.Fonts.Families.Primary
    if not surface.GetFontFallbacks then
        return fontFamily
    end
    
    local fonts = surface.GetFontFallbacks()
    if not table.HasValue(fonts, fontFamily) then
        fontFamily = rHitman.UI.Fonts.Families.Fallback
    end
    
    return fontFamily
end

-- Player Card Component
function rHitman.UI.CreatePlayerCard(parent, ply, isSelected, onClick)
    local card = vgui.Create("DPanel", parent)
    card:SetTall(100)
    card:Dock(TOP)
    card:DockMargin(5, 5, 5, 5)
    
    -- Override Paint
    card.Paint = function(self, w, h)
        -- Background with gradient
        draw.RoundedBox(8, 0, 0, w, h, rHitman.UI.Colors.Surface)
        
        -- Highlight effect on hover/selected
        if self:IsHovered() or isSelected then
            local highlight = ColorAlpha(rHitman.UI.Colors.Primary, 20)
            draw.RoundedBox(8, 0, 0, w, h, highlight)
            surface.SetDrawColor(rHitman.UI.Colors.Primary)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end
    end
    
    -- Left side container (model + health/armor)
    local leftSide = vgui.Create("DPanel", card)
    leftSide:SetSize(90, card:GetTall())
    leftSide:SetPos(5, 0)
    leftSide.Paint = function() end
    
    -- Player Model Preview
    local model = vgui.Create("DModelPanel", leftSide)
    model:SetSize(80, 80)
    model:SetPos(5, 5)
    model:SetModel(ply:GetModel())
    model:SetFOV(30)
    model:SetCamPos(Vector(50, 0, 60))
    model:SetLookAt(Vector(0, 0, 60))
    
    -- Health and armor bars container
    local barsContainer = vgui.Create("DPanel", leftSide)
    barsContainer:SetSize(80, 6)
    barsContainer:SetPos(5, 88)
    barsContainer.Paint = function(self, w, h)
        local barHeight = 3
        local spacing = 1
        
        -- Health bar
        local healthFraction = ply:Health() / ply:GetMaxHealth()
        draw.RoundedBox(2, 0, 0, w, barHeight, ColorAlpha(rHitman.UI.Colors.Error, 50))
        draw.RoundedBox(2, 0, 0, w * healthFraction, barHeight, rHitman.UI.Colors.Error)
        
        -- Armor bar
        local armorFraction = ply:Armor() / 100
        draw.RoundedBox(2, 0, barHeight + spacing, w, barHeight, ColorAlpha(rHitman.UI.Colors.Primary, 50))
        draw.RoundedBox(2, 0, barHeight + spacing, w * armorFraction, barHeight, rHitman.UI.Colors.Primary)
    end
    
    -- Info container
    local info = vgui.Create("DPanel", card)
    info:SetPos(95, 5)
    info:SetSize(card:GetWide() - 100, card:GetTall() - 10)
    info.Paint = function() end
    
    -- Player Name with rank icon
    local name = vgui.Create("DPanel", info)
    name:Dock(TOP)
    name:SetTall(25)
    name.Paint = function(self, w, h)
        local rank = rHitman.Stats and rHitman.Stats:GetRank(ply) or nil
        local nameText = ply:Nick()
        local nameColor = rHitman.UI.Colors.Text
        
        -- Draw rank icon if available
        if rank then
            surface.SetDrawColor(rank.color)
            surface.SetMaterial(rHitman.UI.Icons.Star or Material("icon16/star.png"))
            surface.DrawTexturedRect(0, h/2 - 8, 16, 16)
            draw.SimpleText(nameText, "rHitman.Text", 24, h/2, nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText(nameText, "rHitman.Text", 0, h/2, nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    
    -- Player Job with icon
    local job = vgui.Create("DPanel", info)
    job:Dock(TOP)
    job:SetTall(20)
    job.Paint = function(self, w, h)
        surface.SetDrawColor(rHitman.UI.Colors.TextDark)
        surface.SetMaterial(rHitman.UI.Icons.User or Material("icon16/user.png"))
        surface.DrawTexturedRect(0, h/2 - 8, 16, 16)
        draw.SimpleText(team.GetName(ply:Team()), "rHitman.Text.Small", 24, h/2, rHitman.UI.Colors.TextDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    
    -- Additional info (e.g., last known location)
    local location = vgui.Create("DPanel", info)
    location:Dock(TOP)
    location:SetTall(20)
    location.Paint = function(self, w, h)
        surface.SetDrawColor(rHitman.UI.Colors.TextDark)
        surface.SetMaterial(rHitman.UI.Icons.Location or Material("icon16/world.png"))
        surface.DrawTexturedRect(0, h/2 - 8, 16, 16)
        draw.SimpleText(ply:GetLocationName() or "Unknown Location", "rHitman.Text.Small", 24, h/2, rHitman.UI.Colors.TextDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    
    -- Status indicators (online/offline, wanted, etc.)
    local status = vgui.Create("DPanel", info)
    status:Dock(TOP)
    status:SetTall(20)
    status.Paint = function(self, w, h)
        local indicators = {}
        
        -- Online status
        if ply:IsValid() and not ply:IsBot() then
            table.insert(indicators, {
                text = "Online",
                color = rHitman.UI.Colors.Success
            })
        end
        
        -- Wanted status (if DarkRP is available)
        if ply.isWanted and ply:isWanted() then
            table.insert(indicators, {
                text = "Wanted",
                color = rHitman.UI.Colors.Error
            })
        end
        
        -- Draw indicators
        local x = 0
        for _, indicator in ipairs(indicators) do
            local width = surface.GetTextSize(indicator.text)
            draw.RoundedBox(4, x, h/2 - 8, width + 10, 16, ColorAlpha(indicator.color, 50))
            draw.SimpleText(indicator.text, "rHitman.Text.Small", x + 5, h/2, indicator.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            x = x + width + 20
        end
    end
    
    -- Make the entire card clickable
    card:SetCursor("hand")
    card.OnMousePressed = function()
        if onClick then onClick(ply) end
    end
    
    return card
end

-- Button Component
function rHitman.UI.CreateButton(parent, text, color, callback)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn:SetTall(40)
    
    local hoverAlpha = 0
    local targetAlpha = 0
    
    btn.Paint = function(self, w, h)
        if self:IsHovered() then
            targetAlpha = 255
        else
            targetAlpha = 0
        end
        
        hoverAlpha = Lerp(FrameTime() * 10, hoverAlpha, targetAlpha)
        
        -- Background
        draw.RoundedBox(6, 0, 0, w, h, color or rHitman.UI.Colors.Primary)
        
        -- Hover effect
        if hoverAlpha > 0 then
            draw.RoundedBox(6, 0, 0, w, h, ColorAlpha(rHitman.UI.Colors.SurfaceLight, hoverAlpha * 0.2))
        end
        
        -- Text
        draw.SimpleText(text, "rHitman.Text", w/2, h/2, rHitman.UI.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    if callback then
        btn.DoClick = callback
    end
    
    return btn
end
