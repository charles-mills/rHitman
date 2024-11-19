--[[
    rHitman - Contract Creation UI
    Handles the contract creation interface
]]--

local PANEL = {}

function PANEL:Init()
    if not rHitman.UI then
        ErrorNoHalt("[rHitman] UI utilities not loaded!\n")
        return
    end

    self.State = "player_select" -- or "contract_details"
    self.SelectedPlayer = nil
    
    -- Create the content container
    self.Content = vgui.Create("DPanel", self)
    self.Content:Dock(FILL)
    self.Content:DockMargin(10, 10, 10, 10)
    self.Content.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.Surface)
    end
    
    -- Create title label
    self.TitleLabel = vgui.Create("DLabel", self)
    self.TitleLabel:SetText("Select Target")
    self.TitleLabel:SetFont("rHitman.Title")
    self.TitleLabel:SetTextColor(rHitman.UI.Colors.Text)
    self.TitleLabel:Dock(TOP)
    self.TitleLabel:DockMargin(10, 10, 10, 5)
    self.TitleLabel:SetTall(30)
    self.TitleLabel:SetContentAlignment(5) -- Center alignment
    
    self:SetupPlayerSelection()
end

function PANEL:SetupPlayerSelection()
    -- Clear existing content
    if IsValid(self.ScrollBox) then self.ScrollBox:Remove() end
    if IsValid(self.SelectButton) then self.SelectButton:Remove() end
    if IsValid(self.PlayerContainer) then self.PlayerContainer:Remove() end
    
    -- Create search bar
    self.SearchBar = vgui.Create("DTextEntry", self.Content)
    self.SearchBar:Dock(TOP)
    self.SearchBar:DockMargin(5, 5, 5, 5)
    self.SearchBar:SetTall(30)
    self.SearchBar:SetPlaceholderText("Search players...")
    self.SearchBar.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.SurfaceLight)
        
        -- Draw placeholder text
        if self:GetText() == "" and not self:HasFocus() then
            draw.SimpleText(self:GetPlaceholderText(), "rHitman.Text", 10, h/2, rHitman.UI.Colors.TextDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        
        self:DrawTextEntryText(
            rHitman.UI.Colors.Text,
            rHitman.UI.Colors.Primary,
            rHitman.UI.Colors.TextDark
        )
    end
    self.SearchBar.OnChange = function()
        self:RefreshPlayerList()
    end
    
    -- Create scrollbox for player cards
    self.ScrollBox = vgui.Create("DScrollPanel", self.Content)
    self.ScrollBox:Dock(FILL)
    self.ScrollBox:DockMargin(5, 5, 5, 5)
    
    -- Style the scrollbar
    local sbar = self.ScrollBox:GetVBar()
    sbar:SetHideButtons(true)
    function sbar:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, rHitman.UI.Colors.Background)
    end
    function sbar.btnGrip:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, rHitman.UI.Colors.Primary)
    end
    
    -- Container for player cards
    self.PlayerContainer = vgui.Create("DPanel", self.ScrollBox)
    self.PlayerContainer:Dock(FILL)
    self.PlayerContainer:DockPadding(5, 5, 5, 5)
    self.PlayerContainer.Paint = function() end
    
    -- Add player cards
    self:RefreshPlayerList()
    
    -- Create select button (initially disabled)
    self.SelectButton = rHitman.UI.CreateButton(self.Content, "Select Target", rHitman.UI.Colors.Primary, function()
        if self.SelectedPlayer and IsValid(self.SelectedPlayer) then
            self:SetupContractDetails()
        end
    end)
    self.SelectButton:Dock(BOTTOM)
    self.SelectButton:DockMargin(5, 5, 5, 5)
    self.SelectButton:SetEnabled(false)
end

function PANEL:RefreshPlayerList()
    if not IsValid(self.PlayerContainer) then return end
    
    -- Clear existing player cards
    self.PlayerContainer:Clear()
    
    -- Get search text
    local searchText = self.SearchBar and string.lower(self.SearchBar:GetText()) or ""
    
    -- Get all players except ourselves and filter by search
    local players = {}
    for _, ply in ipairs(player.GetAll()) do
        if ply ~= LocalPlayer() then
            -- Check if player matches search
            local playerName = string.lower(ply:Nick())
            local teamName = string.lower(team.GetName(ply:Team()))
            
            if searchText == "" or 
               string.find(playerName, searchText, 1, true) or 
               string.find(teamName, searchText, 1, true) then
                table.insert(players, ply)
            end
        end
    end
    
    -- Sort players based on config
    if rHitman.Config.PlayerListSortMode == "job" then
        -- Sort by job category first, then by name
        table.sort(players, function(a, b)
            local jobA = team.GetName(a:Team())
            local jobB = team.GetName(b:Team())
            
            if jobA == jobB then
                return a:Nick():lower() < b:Nick():lower() -- Ascending alphabetical within same job
            end
            return jobA:lower() < jobB:lower() -- Ascending job names
        end)
    else
        -- Sort by name only
        table.sort(players, function(a, b)
            return a:Nick():lower() < b:Nick():lower()
        end)
    end
    
    -- Create player cards
    local currentJob = nil
    for _, ply in ipairs(players) do
        -- Add job category header if sorting by job
        if rHitman.Config.PlayerListSortMode == "job" then
            local jobName = team.GetName(ply:Team())
            if currentJob ~= jobName then
                currentJob = jobName
                
                -- Create job header
                local header = vgui.Create("DPanel", self.PlayerContainer)
                header:Dock(TOP)
                header:SetTall(30)
                header:DockMargin(5, 5, 5, 0)
                header.Paint = function(self, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.Surface)
                    draw.SimpleText(jobName, "rHitman.Text", 10, h/2, rHitman.UI.Colors.TextDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
            end
        end
        
        -- Create player card
        rHitman.UI.CreatePlayerCard(self.PlayerContainer, ply, self.SelectedPlayer == ply, function(selectedPly)
            self.SelectedPlayer = selectedPly
            self:RefreshPlayerList()
            if IsValid(self.SelectButton) then
                self.SelectButton:SetEnabled(true)
            end
        end)
    end

    local totalHeight = 0
    for _, child in ipairs(self.PlayerContainer:GetChildren()) do
        totalHeight = totalHeight + child:GetTall() + 5
    end
    self.PlayerContainer:SetTall(totalHeight + 50)
end

function PANEL:SetupContractDetails()
    self.State = "contract_details"
    
    -- Clear existing content
    if IsValid(self.Content) then
        self.Content:Clear()
    end
    
    -- Create contract details form
    local form = vgui.Create("DPanel", self.Content)
    form:Dock(FILL)
    form:DockMargin(10, 10, 10, 10)
    form.Paint = function() end
    
    -- Target info header
    local targetInfo = vgui.Create("DPanel", form)
    targetInfo:Dock(TOP)
    targetInfo:SetTall(100)
    targetInfo.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, rHitman.UI.Colors.Surface)
    end
    
    local targetModel = vgui.Create("DModelPanel", targetInfo)
    targetModel:SetSize(90, 90)
    targetModel:SetPos(5, 5)
    targetModel:SetModel(self.SelectedPlayer:GetModel())
    targetModel:SetFOV(30)
    targetModel:SetCamPos(Vector(50, 0, 60))
    targetModel:SetLookAt(Vector(0, 0, 60))
    
    local targetName = vgui.Create("DLabel", targetInfo)
    targetName:SetPos(105, 20)
    targetName:SetText(self.SelectedPlayer:Nick())
    targetName:SetFont("rHitman.Title")
    targetName:SetTextColor(rHitman.UI.Colors.Text)
    targetName:SizeToContents()
    
    local targetJob = vgui.Create("DLabel", targetInfo)
    targetJob:SetPos(105, 45)
    targetJob:SetText(team.GetName(self.SelectedPlayer:Team()))
    targetJob:SetFont("rHitman.Text")
    targetJob:SetTextColor(rHitman.UI.Colors.TextDark)
    targetJob:SizeToContents()
    
    -- Price input
    local priceLabel = vgui.Create("DLabel", form)
    priceLabel:SetText("Contract Price")
    priceLabel:SetFont("rHitman.Text")
    priceLabel:SetTextColor(rHitman.UI.Colors.Text)
    priceLabel:Dock(TOP)
    priceLabel:DockMargin(10, 10, 10, 5)

    -- Price range info
    local priceRange = vgui.Create("DLabel", form)
    priceRange:SetText(string.format("Range: %s - %s", 
        rHitman.formatMoney(rHitman.Config.MinimumHitPrice), 
        rHitman.formatMoney(rHitman.Config.MaximumHitPrice)))
    priceRange:SetFont("rHitman.Text")
    priceRange:SetTextColor(rHitman.UI.Colors.TextDark)
    priceRange:Dock(TOP)
    priceRange:DockMargin(10, 0, 10, 5)

    -- Local function to format number with commas without currency symbol
    local function formatNumberWithCommas(amount)
        if not amount then return "0" end
        return tostring(math.floor(amount)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    end

    self.PriceInput = vgui.Create("DTextEntry", form)
    self.PriceInput:SetTall(35)
    self.PriceInput:Dock(TOP)
    self.PriceInput:DockMargin(10, 0, 10, 10)
    self.PriceInput:SetPlaceholderText("Enter contract price...")
    self.PriceInput:SetNumeric(true)
    self.PriceInput:RequestFocus() -- Auto-focus the input when created
    self.PriceInput.Paint = function(self, w, h)
        local bgColor = self:HasFocus() and rHitman.UI.Colors.SurfaceLight or rHitman.UI.Colors.Surface
        draw.RoundedBox(6, 0, 0, w, h, bgColor)
        
        -- Draw currency symbol
        surface.SetFont("rHitman.Text")
        local symbol = rHitman.Config.CurrencySymbol
        local symbolWidth = surface.GetTextSize(symbol)
        draw.SimpleText(symbol, "rHitman.Text", 10, h/2, rHitman.UI.Colors.TextDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        
        -- Draw text with padding for currency symbol
        local text = self:GetText()
        if text ~= "" then
            local num = tonumber(text) or 0
            text = formatNumberWithCommas(num)
        end
        if text == "" and not self:HasFocus() then
            draw.SimpleText(self:GetPlaceholderText(), "rHitman.Text", 15 + symbolWidth, h/2, rHitman.UI.Colors.TextDark, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText(text, "rHitman.Text", 15 + symbolWidth, h/2, self:GetTextColor(), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        
        -- Always draw outline, thicker when focused
        local outlineColor = self:HasFocus() and rHitman.UI.Colors.Primary or rHitman.UI.Colors.TextDark
        local thickness = self:HasFocus() and 2 or 1
        surface.SetDrawColor(outlineColor)
        surface.DrawOutlinedRect(0, 0, w, h, thickness)
    end
    
    -- Override default text drawing
    self.PriceInput.DrawTextEntryText = function(self)
        -- We're handling text drawing in Paint
    end
    
    self.PriceInput.OnChange = function(self)
        local text = self:GetText()
        -- Remove any non-numeric characters
        text = string.gsub(text, "[^0-9]", "")
        local value = tonumber(text) or 0
        
        -- Update text color based on value
        if value < rHitman.Config.MinimumHitPrice then
            self:SetTextColor(rHitman.UI.Colors.Error)
        elseif value > rHitman.Config.MaximumHitPrice then
            self:SetTextColor(rHitman.UI.Colors.Error)
        else
            self:SetTextColor(rHitman.UI.Colors.Text)
        end
        
        -- Update the text without commas for proper number handling
        if self:GetText() ~= text then
            self:SetText(text)
            self:SetCaretPos(#text)
        end
    end

    -- Create contract button
    local createButton = rHitman.UI.CreateButton(form, "Place Contract", rHitman.UI.Colors.Success, function()
        if self:ValidateContract() then
            self:CreateContract()
        end
    end)
    createButton:Dock(BOTTOM)
    createButton:DockMargin(0, 20, 0, 0)
    createButton:SetTall(40)
    
    -- Back button
    local backButton = rHitman.UI.CreateButton(form, "Back", rHitman.UI.Colors.Secondary, function()
        self.State = "player_select"
        self.SelectedPlayer = nil
        if IsValid(self.Content) then
            self.Content:Clear()
        end
        self:SetupPlayerSelection()
    end)
    backButton:Dock(BOTTOM)
    backButton:DockMargin(0, 0, 0, 5)
    backButton:SetTall(30)
end

function PANEL:ValidateContract()
    local price = tonumber(self.PriceInput:GetValue()) or 0
    
    if not IsValid(self.SelectedPlayer) then
        notification.AddLegacy("Invalid target selected.", NOTIFY_ERROR, 3)
        return false
    end
    
    if price < rHitman.Config.MinimumHitPrice then
        notification.AddLegacy("Price must be at least " .. rHitman.formatMoney(rHitman.Config.MinimumHitPrice), NOTIFY_ERROR, 3)
        return false
    end
    
    if price > rHitman.Config.MaximumHitPrice then
        notification.AddLegacy("Price cannot exceed " .. rHitman.formatMoney(rHitman.Config.MaximumHitPrice), NOTIFY_ERROR, 3)
        return false
    end
    
    return true
end

function PANEL:CreateContract()
    -- Listen for contract creation response
    hook.Add("rHitman.ContractCreated", "ContractCreationResponse", function(success, message)
        if success then
            -- Close the entire menu
            if IsValid(rHitman.UI.Menu) then
                rHitman.UI.Menu:Remove()
            end
        end
    end)

    -- Send contract creation request
    net.Start("rHitman_PlaceContract")
        net.WriteString(self.SelectedPlayer:SteamID64())
        net.WriteUInt(tonumber(self.PriceInput:GetValue()) or 0, 32)
        net.WriteString("") -- Empty reason for now
    net.SendToServer()
end

function PANEL:Paint(w, h)
    draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.Background)
end

vgui.Register("rHitman.ContractCreate", PANEL, "EditablePanel")
