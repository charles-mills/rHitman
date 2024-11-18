--[[
    rHitman - Contract Creation Panel
    Modern form for creating new contracts
]]--

local PANEL = {}

-- Use config colors
local colors = rHitman.Config.Colors

-- Custom dropdown
local function CreateStyledDropdown(parent)
    local dropdown = vgui.Create("DPanel", parent)
    dropdown:SetTall(40)
    dropdown.Choices = {}
    dropdown.Selected = nil
    dropdown.IsOpen = false
    dropdown.SelectedValue = "Select a target..."
    dropdown:SetText("")
    
    local alpha = 0
    local targetAlpha = 0
    
    function dropdown:Paint(w, h)
        if self:IsHovered() then
            targetAlpha = 255
        else
            targetAlpha = 0
        end
        
        alpha = Lerp(FrameTime() * 10, alpha, targetAlpha)
        
        -- Background
        draw.RoundedBox(8, 0, 0, w, h, colors.input)
        
        if alpha > 0 then
            draw.RoundedBox(8, 0, 0, w, h, ColorAlpha(colors.inputHover, alpha))
        end
        
        -- Selected text
        draw.SimpleText(
            self.SelectedValue,
            "rHitman.Text",
            10,
            h/2,
            colors.text,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
        
        -- Arrow
        local arrowSize = 8
        local arrowX = w - arrowSize - 10
        local arrowY = h/2 - arrowSize/2
        
        surface.SetDrawColor(colors.text)
        if self.IsOpen then
            -- Up arrow
            surface.DrawLine(arrowX, arrowY + arrowSize, arrowX + arrowSize/2, arrowY)
            surface.DrawLine(arrowX + arrowSize, arrowY + arrowSize, arrowX + arrowSize/2, arrowY)
        else
            -- Down arrow
            surface.DrawLine(arrowX, arrowY, arrowX + arrowSize/2, arrowY + arrowSize)
            surface.DrawLine(arrowX + arrowSize, arrowY, arrowX + arrowSize/2, arrowY + arrowSize)
        end
    end
    
    -- Dropdown list
    dropdown.List = vgui.Create("DScrollPanel", parent)
    dropdown.List:SetVisible(false)
    dropdown.List:SetZPos(999)
    dropdown.List:MoveToFront()
    
    local sbar = dropdown.List:GetVBar()
    sbar:SetHideButtons(true)
    function sbar:Paint(w, h) 
        draw.RoundedBox(8, 0, 0, w, h, ColorAlpha(colors.input, 100))
    end
    function sbar.btnGrip:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.accent)
    end
    
    -- Container for the choices
    dropdown.ListContainer = vgui.Create("DPanel", dropdown.List)
    dropdown.ListContainer:Dock(FILL)
    dropdown.ListContainer.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.input)
    end
    
    function dropdown:PerformLayout(w, h)
        if #self.Choices == 0 then return end
        
        -- Get absolute position of dropdown
        local x, y = self:LocalToScreen(0, 0)
        
        -- Position the list below the dropdown in screen coordinates
        self.List:SetPos(x, y + h)
        self.List:SetSize(w, math.min(#self.Choices * 40, 200))
        
        -- Set container size
        self.ListContainer:SetSize(w, #self.Choices * 40)
    end
    
    function dropdown:OnMousePressed()
        print("Dropdown clicked")  -- Debug print
        self:ToggleList()
    end
    
    function dropdown:ToggleList()
        print("Toggling list, current state:", self.IsOpen)  -- Debug print
        self.IsOpen = not self.IsOpen
        
        if IsValid(self.List) then
            self.List:SetVisible(self.IsOpen)
            
            if self.IsOpen then
                print("Moving list to front")  -- Debug print
                self.List:MoveToFront()
                self.List:RequestFocus()
            end
        end
    end
    
    function dropdown:AddChoice(text, data)
        print("Adding choice:", text)  -- Debug print
        
        local btn = vgui.Create("DButton", self.ListContainer)
        btn:SetTall(40)
        btn:SetText("")
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 0, 0)
        
        local alpha = 0
        local targetAlpha = 0
        
        function btn:Paint(w, h)
            if self:IsHovered() then
                targetAlpha = 255
            else
                targetAlpha = 0
            end
            
            alpha = Lerp(FrameTime() * 10, alpha, targetAlpha)
            
            if alpha > 0 then
                draw.RoundedBox(8, 0, 0, w, h, ColorAlpha(colors.inputHover, alpha))
            end
            
            draw.SimpleText(text, "rHitman.Text", 10, h/2, colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        
        btn.DoClick = function()
            print("Choice selected:", text)  -- Debug print
            self.Selected = data
            self.SelectedValue = text
            self:ToggleList()
        end
        
        table.insert(self.Choices, {text = text, data = data})
        self:InvalidateLayout()
    end
    
    function dropdown:Clear()
        print("Clearing dropdown")  -- Debug print
        self.ListContainer:Clear()
        self.Choices = {}
        self.Selected = nil
        self.SelectedValue = "Select a target..."
        self:InvalidateLayout()
    end
    
    function dropdown:GetSelected()
        return self.SelectedValue, self.Selected
    end
    
    function dropdown:SetValue(value)
        self.SelectedValue = value
    end
    
    return dropdown
end

-- Styled input field
local function CreateStyledInput(parent, placeholder, numeric)
    local input = vgui.Create("DTextEntry", parent)
    input:SetTall(40)
    input:SetFont("rHitman.Text")
    input:SetPlaceholderText(placeholder)
    if numeric then input:SetNumeric(true) end
    
    local alpha = 0
    local targetAlpha = 0
    
    function input:Paint(w, h)
        -- Background
        if self:IsHovered() or self:HasFocus() then
            targetAlpha = 255
        else
            targetAlpha = 0
        end
        
        alpha = Lerp(FrameTime() * 10, alpha, targetAlpha)
        
        draw.RoundedBox(8, 0, 0, w, h, colors.input)
        
        if alpha > 0 then
            draw.RoundedBox(8, 0, 0, w, h, ColorAlpha(colors.inputHover, alpha))
        end
        
        -- Text
        self:DrawTextEntryText(
            colors.text,
            colors.accent,
            colors.text
        )
        
        -- Placeholder
        if self:GetText() == "" and not self:HasFocus() then
            draw.SimpleText(
                self:GetPlaceholderText(),
                self:GetFont(),
                5,
                h/2,
                ColorAlpha(colors.textDark, 100),
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_CENTER
            )
        end
    end
    
    return input
end

function PANEL:Init()
    -- Set up panel
    self:SetSize(300, 400)
    self:Center()
    self:DockPadding(10, 10, 10, 10)
    
    -- Create header
    self.Header = vgui.Create("DLabel", self)
    self.Header:SetText("Place Contract")
    self.Header:SetFont("rHitman.Title")
    self.Header:SetTextColor(colors.text)
    self.Header:Dock(TOP)
    self.Header:DockMargin(0, 0, 0, 10)
    self.Header:SizeToContents()
    
    -- Target selection
    self.TargetLabel = vgui.Create("DLabel", self)
    self.TargetLabel:SetText("Target:")
    self.TargetLabel:SetFont("rHitman.Text")
    self.TargetLabel:SetTextColor(colors.text)
    self.TargetLabel:Dock(TOP)
    self.TargetLabel:DockMargin(0, 0, 0, 5)
    self.TargetLabel:SizeToContents()
    
    self.TargetCombo = CreateStyledDropdown(self)
    self.TargetCombo:Dock(TOP)
    self.TargetCombo:DockMargin(0, 0, 0, 10)
    
    -- Reward input
    self.RewardLabel = vgui.Create("DLabel", self)
    self.RewardLabel:SetText("Reward:")
    self.RewardLabel:SetFont("rHitman.Text")
    self.RewardLabel:SetTextColor(colors.text)
    self.RewardLabel:Dock(TOP)
    self.RewardLabel:DockMargin(0, 0, 0, 5)
    self.RewardLabel:SizeToContents()
    
    local placeholder = string.format("Enter reward (%s - %s)", 
        rHitman.formatMoney(rHitman.Config.MinimumHitPrice),
        rHitman.formatMoney(rHitman.Config.MaximumHitPrice)
    )
    self.RewardInput = CreateStyledInput(self, placeholder, true)
    self.RewardInput:Dock(TOP)
    self.RewardInput:DockMargin(0, 0, 0, 10)
    
    -- Error label
    self.ErrorLabel = vgui.Create("DLabel", self)
    self.ErrorLabel:SetText("")
    self.ErrorLabel:SetFont("rHitman.Text")
    self.ErrorLabel:SetTextColor(colors.error)
    self.ErrorLabel:Dock(TOP)
    self.ErrorLabel:DockMargin(0, 0, 0, 10)
    self.ErrorLabel:SetWrap(true)
    self.ErrorLabel:SetAutoStretchVertical(true)
    
    -- Place button
    self.PlaceButton = vgui.Create("DButton", self)
    self.PlaceButton:SetText("Place Contract")
    self.PlaceButton:SetFont("rHitman.Text")
    self.PlaceButton:SetTextColor(colors.text)
    self.PlaceButton:Dock(TOP)
    self.PlaceButton:DockMargin(0, 0, 0, 0)
    self.PlaceButton:SetTall(40)
    
    local alpha = 0
    local targetAlpha = 0
    
    function self.PlaceButton:Paint(w, h)
        if self:IsHovered() then
            targetAlpha = 255
        else
            targetAlpha = 0
        end
        
        alpha = Lerp(FrameTime() * 10, alpha, targetAlpha)
        
        draw.RoundedBox(8, 0, 0, w, h, colors.input)
        if alpha > 0 then
            draw.RoundedBox(8, 0, 0, w, h, ColorAlpha(colors.inputHover, alpha))
        end
    end
    
    -- Initialize functionality
    self:SetupTargetList()
    self:SetupContractPlacement()
    self:StartUpdates()
    
    -- Do initial update
    self:UpdateTargetList()
end

function PANEL:SetupTargetList()
    -- Update target list
    function self:UpdateTargetList()
        local players = player.GetAll()
        print("Updating target list")
        print("Number of players:\t" .. #players)
        
        -- Create a table of current players for comparison
        local currentPlayers = {}
        for _, choice in ipairs(self.TargetCombo.Choices) do
            currentPlayers[choice.data] = choice.text
        end
        
        -- Check if we need to update
        local needsUpdate = false
        local newPlayers = {}
        
        for _, ply in ipairs(players) do
            if ply == LocalPlayer() then continue end
            
            local steamID = ply:SteamID64()
            newPlayers[steamID] = ply:Nick()
            
            -- If this player isn't in our current list, we need to update
            if not currentPlayers[steamID] then
                needsUpdate = true
            end
        end
        
        -- Also check if any players have left
        for steamID, _ in pairs(currentPlayers) do
            if not newPlayers[steamID] then
                needsUpdate = true
                break
            end
        end
        
        -- Only update if there are changes
        if needsUpdate then
            print("Players changed, updating dropdown")
            self.TargetCombo:Clear()
            
            for steamID, nick in pairs(newPlayers) do
                print("Adding player:\t" .. nick .. "\t" .. steamID)
                self.TargetCombo:AddChoice(nick, steamID)
            end
        end
    end
    
    -- Initial update
    self:UpdateTargetList()
    
    -- Start periodic updates
    self:StartUpdates()
end

function PANEL:SetupContractPlacement()
    self.PlaceButton.DoClick = function()
        local _, targetID = self.TargetCombo:GetSelected()
        local reward = tonumber(self.RewardInput:GetValue())
        
        if not targetID then
            self:ShowError("Please select a target")
            return
        end
        
        if not reward then
            self:ShowError("Please enter a valid reward amount")
            return
        end
        
        if reward < rHitman.Config.MinimumHitPrice then
            self:ShowError("Minimum reward is " .. rHitman.formatMoney(rHitman.Config.MinimumHitPrice))
            return
        end
        
        if reward > rHitman.Config.MaximumHitPrice then
            self:ShowError("Maximum reward is " .. rHitman.formatMoney(rHitman.Config.MaximumHitPrice))
            return
        end
        
        -- Place contract
        rHitman.placeContract(targetID, reward)
        
        -- Clear inputs
        self.TargetCombo:SetValue("Select a target...")
        self.RewardInput:SetValue("")
        self:ShowError("")
    end
end

function PANEL:ShowError(message)
    self.ErrorLabel:SetText(message)
    self.ErrorLabel:SizeToContentsY()
end

function PANEL:StartUpdates()
    -- Update timer for target list
    if not IsValid(self) then return end
    
    -- Create a unique timer name and store it
    if not self.UpdateTimer then
        self.UpdateTimer = "rHitman_ContractCreate_" .. tostring(math.random(1, 100000))
    end
    
    if timer.Exists(self.UpdateTimer) then
        timer.Remove(self.UpdateTimer)
    end
    
    timer.Create(self.UpdateTimer, 1, 0, function()
        if IsValid(self) then
            self:UpdateTargetList()
        else
            if self.UpdateTimer and timer.Exists(self.UpdateTimer) then
                timer.Remove(self.UpdateTimer)
            end
        end
    end)
end

function PANEL:OnRemove()
    -- Clean up timer
    if type(self.UpdateTimer) == "string" and timer.Exists(self.UpdateTimer) then
        timer.Remove(self.UpdateTimer)
    end
end

function PANEL:Paint(w, h)
    -- Background
    draw.RoundedBox(8, 0, 0, w, h, colors.background)
end

vgui.Register("rHitman_ContractCreate", PANEL, "DPanel")
