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
    User = Material("icon16/user.png")
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
    card:SetTall(80)
    card:Dock(TOP)
    card:DockMargin(5, 5, 5, 5)
    
    -- Override Paint
    card.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, isSelected and rHitman.UI.Colors.Secondary or rHitman.UI.Colors.Surface)
        
        if self:IsHovered() or isSelected then
            surface.SetDrawColor(rHitman.UI.Colors.Primary)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end
    end
    
    -- Player Model Preview
    local model = vgui.Create("DModelPanel", card)
    model:SetSize(70, 70)
    model:SetPos(5, 5)
    model:SetModel(ply:GetModel())
    model:SetFOV(30)
    model:SetCamPos(Vector(50, 0, 60))
    model:SetLookAt(Vector(0, 0, 60))
    
    -- Player Info Container
    local info = vgui.Create("DPanel", card)
    info:SetPos(85, 5)
    info:SetSize(200, 70)
    info.Paint = function() end
    
    -- Player Name
    local name = vgui.Create("DLabel", info)
    name:SetText(ply:Nick())
    name:SetFont("rHitman.Text")
    name:SetTextColor(rHitman.UI.Colors.Text)
    name:Dock(TOP)
    name:DockMargin(0, 5, 0, 0)
    name:SetContentAlignment(4)
    
    -- Player Job
    local job = vgui.Create("DLabel", info)
    job:SetText(team.GetName(ply:Team()))
    job:SetFont("rHitman.Text.Small")
    job:SetTextColor(rHitman.UI.Colors.TextDark)
    job:Dock(TOP)
    job:DockMargin(0, 2, 0, 0)
    job:SetContentAlignment(4)
    
    -- Make the entire card clickable
    card:SetCursor("hand")
    card.OnMousePressed = function()
        onClick(ply)
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
