--[[
    rHitman - Main Menu
    Modern, responsive UI for contract management
]]--

local PANEL = {}

-- Colors reference
local colors = rHitman.Config.Colors

-- Helper function to create styled buttons
local function CreateStyledButton(text, icon)
    local btn = vgui.Create("DButton")
    btn:SetTall(45)
    btn:SetText("")
    
    local alpha = 0
    local targetAlpha = 0
    
    function btn:Paint(w, h)
        if self:IsHovered() then
            targetAlpha = 255
        else
            targetAlpha = 0
        end
        
        alpha = Lerp(FrameTime() * 10, alpha, targetAlpha)
        draw.RoundedBox(6, 0, 0, w, h, colors.input)
        
        if alpha > 0 then
            draw.RoundedBox(6, 0, 0, w, h, ColorAlpha(colors.inputHover, alpha))
        end
        
        -- Icon
        if icon then
            surface.SetDrawColor(colors.text)
            surface.SetMaterial(Material(icon))
            surface.DrawTexturedRect(10, h/2 - 8, 16, 16)
            draw.SimpleText(text, "rHitman.Text", 36, h/2, colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText(text, "rHitman.Text", w/2, h/2, colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    
    return btn
end

function PANEL:Init()
    if not colors then
        ErrorNoHalt("[rHitman] Colors not initialized in menu panel!\n")
        return
    end
    
    self:SetTitle("")
    self:ShowCloseButton(false)
    self:SetDraggable(true)
    
    -- Header with proper close button positioning
    self.HeaderContainer = vgui.Create("DPanel", self)
    self.HeaderContainer:Dock(TOP)
    self.HeaderContainer:SetTall(60)
    self.HeaderContainer:DockMargin(10, 10, 10, 5)
    self.HeaderContainer.Paint = function() end
    
    self.Header = vgui.Create("DPanel", self.HeaderContainer)
    self.Header:Dock(FILL)
    
    function self.Header:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.header)
        draw.SimpleText("rHitman", "rHitman.Title", 20, h/2, colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    
    -- Close button (with higher z-index)
    self.CloseBtn = vgui.Create("DButton", self)
    self.CloseBtn:SetSize(32, 32)
    self.CloseBtn:SetText("")
    self.CloseBtn:SetZPos(999)
    self.CloseBtn:MoveToFront()
    
    function self.CloseBtn:Paint(w, h)
        local hovered = self:IsHovered()
        local color = Color(40, 40, 40, hovered and 255 or 220)
        local textColor = hovered and colors.accent or colors.text
        
        draw.RoundedBox(6, 0, 0, w, h, color)
        draw.SimpleText("✕", "rHitman.Text", w/2, h/2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    function self.CloseBtn:Think()
        local parent = self:GetParent()
        local headerContainer = parent.HeaderContainer
        if not IsValid(headerContainer) then return end
        
        local headerHeight = headerContainer:GetTall()
        local headerTop = headerContainer:GetY()
        self:SetPos(
            parent:GetWide() - self:GetWide() - 15,
            headerTop + (headerHeight - self:GetTall())/2
        )
        self:MoveToFront()
    end
    
    self.CloseBtn.DoClick = function()
        self:Remove()
    end
    
    -- Content container
    self.Container = vgui.Create("DPanel", self)
    self.Container:Dock(FILL)
    self.Container:DockMargin(10, 5, 10, 10)
    self.Container.Paint = function() end
    
    -- Sidebar
    self.Sidebar = vgui.Create("DPanel", self.Container)
    self.Sidebar:Dock(LEFT)
    self.Sidebar:SetWide(220)
    self.Sidebar:DockMargin(0, 0, 5, 0)
    
    function self.Sidebar:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.header)
    end
    
    -- Create contract button (highlighted)
    self.CreateContractBtn = CreateStyledButton("Place Contract", "icon16/add.png")
    self.CreateContractBtn:SetParent(self.Sidebar)
    self.CreateContractBtn:Dock(TOP)
    self.CreateContractBtn:DockMargin(10, 10, 10, 5)
    
    self.CreateContractBtn.DoClick = function()
        self:ClearContent()
        local contractCreate = vgui.Create("rHitman_ContractCreate", self.Content)
        contractCreate:Dock(FILL)
        contractCreate:DockMargin(10, 10, 10, 10)
    end
    
    -- Navigation buttons
    local navButtons = {
        {text = "Available Contracts", icon = "icon16/book.png", panel = "rHitman_ContractList"},
        {text = "My Contracts", icon = "icon16/user.png"},
        {text = "Active Contract", icon = "icon16/star.png"},
        {text = "Statistics", icon = "icon16/chart_bar.png"},
        {text = "Settings", icon = "icon16/cog.png"}
    }
    
    -- Add separator after create button
    local separator = vgui.Create("DPanel", self.Sidebar)
    separator:Dock(TOP)
    separator:SetTall(1)
    separator:DockMargin(10, 5, 10, 5)
    separator.Paint = function(s, w, h)
        surface.SetDrawColor(ColorAlpha(colors.text, 50))
        surface.DrawRect(0, 0, w, h)
    end
    
    for _, btn in ipairs(navButtons) do
        local navBtn = CreateStyledButton(btn.text, btn.icon)
        navBtn:SetParent(self.Sidebar)
        navBtn:Dock(TOP)
        navBtn:DockMargin(10, 5, 10, 0)
        
        navBtn.DoClick = function()
            if btn.panel then
                self:ClearContent()
                local panel = vgui.Create(btn.panel, self.Content)
                panel:Dock(FILL)
                panel:DockMargin(10, 10, 10, 10)
            end
        end
    end
    
    -- Content area
    self.Content = vgui.Create("DPanel", self.Container)
    self.Content:Dock(FILL)
    
    function self.Content:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.header)
    end
    
    -- Load default panel
    local contractList = vgui.Create("rHitman_ContractList", self.Content)
    contractList:Dock(FILL)
    contractList:DockMargin(10, 10, 10, 10)
end

function PANEL:PerformLayout(w, h)
    if IsValid(self.CloseBtn) and IsValid(self.HeaderContainer) then
        local headerHeight = self.HeaderContainer:GetTall()
        local headerTop = self.HeaderContainer:GetY()
        self.CloseBtn:SetPos(
            self:GetWide() - self.CloseBtn:GetWide() - 15,
            headerTop + (headerHeight - self.CloseBtn:GetTall())/2
        )
        self.CloseBtn:MoveToFront()
    end
end

function PANEL:Paint(w, h)
    if not colors then return end
    
    -- Background with blur
    Derma_DrawBackgroundBlur(self, 0)
    
    -- Main background
    draw.RoundedBox(8, 0, 0, w, h, colors.background)
    
    -- Top accent line
    surface.SetDrawColor(colors.accent)
    surface.DrawRect(0, 0, w, 2)
end

function PANEL:ClearContent()
    if IsValid(self.Content) then
        self.Content:Clear()
    end
end

vgui.Register("rHitman_Menu", PANEL, "DFrame")

-- Create menu command
concommand.Add("rhitman_menu", function()
    if IsValid(rHitman.Menu) then
        rHitman.Menu:Remove()
    end
    
    rHitman.Menu = vgui.Create("rHitman_Menu")
    rHitman.Menu:SetSize(1200, 700)
    rHitman.Menu:Center()
    rHitman.Menu:MakePopup()
end)
