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
    
    -- Reward input
    local rewardLabel = vgui.Create("DLabel", form)
    rewardLabel:SetText("Contract Reward")
    rewardLabel:SetFont("rHitman.Text")
    rewardLabel:SetTextColor(rHitman.UI.Colors.Text)
    rewardLabel:Dock(TOP)
    rewardLabel:DockMargin(10, 10, 10, 5)
    
    -- Show reward range
    local rewardRange = vgui.Create("DLabel", form)
    rewardRange:SetText(string.format("Range: %s - %s", 
        rHitman.Util.formatCurrency(rHitman.Config.MinimumHitReward),
        rHitman.Util.formatCurrency(rHitman.Config.MaximumHitReward)
    ))
    rewardRange:SetFont("rHitman.Text")
    rewardRange:SetTextColor(rHitman.UI.Colors.TextDark)
    rewardRange:Dock(TOP)
    rewardRange:DockMargin(10, 0, 10, 5)
    
    -- Create reward input
    self.RewardInput = vgui.Create("DTextEntry", form)
    self.RewardInput:SetFont("rHitman.Text")
    self.RewardInput:SetNumeric(true)
    self.RewardInput:SetPlaceholderText("Enter contract reward...")
    self.RewardInput:Dock(TOP)
    self.RewardInput:DockMargin(10, 0, 10, 10)
    self.RewardInput.OnChange = function(pnl)
        local val = tonumber(pnl:GetValue())
        if not val then return end
        
        if val < rHitman.Config.MinimumHitReward then
            pnl:SetValue(rHitman.Config.MinimumHitReward)
        elseif val > rHitman.Config.MaximumHitReward then
            pnl:SetValue(rHitman.Config.MaximumHitReward)
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
    local reward = tonumber(self.RewardInput:GetValue()) or 0
    
    if not IsValid(self.SelectedPlayer) then
        notification.AddLegacy("Invalid target selected.", NOTIFY_ERROR, 3)
        return false
    end
    
    if reward < rHitman.Config.MinimumHitReward then
        notification.AddLegacy("Reward is below minimum allowed", NOTIFY_ERROR, 3)
        return false
    end
    
    if reward > rHitman.Config.MaximumHitReward then
        notification.AddLegacy("Reward exceeds maximum allowed", NOTIFY_ERROR, 3)
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
        net.WriteUInt(tonumber(self.RewardInput:GetValue()) or 0, 32)
        net.WriteString("") -- Empty reason for now
    net.SendToServer()
end

function PANEL:Paint(w, h)
    draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.Background)
end

vgui.Register("rHitman.ContractCreate", PANEL, "EditablePanel")
