--[[
    rHitman - Contract List Panel
    Displays available contracts
]]--

local PANEL = {}

function PANEL:Init()
    if not rHitman.UI then
        ErrorNoHalt("[rHitman] UI utilities not loaded!\n")
        return
    end

    -- Header
    self.Header = vgui.Create("DPanel", self)
    self.Header:Dock(TOP)
    self.Header:SetTall(50)
    self.Header:DockMargin(10, 10, 10, 5)
    self.Header.Paint = function(self, w, h)
        draw.SimpleText("Available Contracts", "rHitman.Title", 10, h/2, rHitman.UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- Controls container
    self.Controls = vgui.Create("DPanel", self)
    self.Controls:Dock(TOP)
    self.Controls:SetTall(40)
    self.Controls:DockMargin(10, 0, 10, 5)
    self.Controls.Paint = function() end

    -- Sort options
    self.SortButton = vgui.Create("DButton", self.Controls)
    self.SortButton:Dock(LEFT)
    self.SortButton:SetWide(150)
    self.SortButton:DockMargin(0, 5, 5, 5)
    self.SortButton:SetText("")
    self.SortButton.Paint = function(self, w, h)
        local col = self:IsHovered() and rHitman.UI.Colors.Primary or ColorAlpha(rHitman.UI.Colors.Primary, 200)
        draw.RoundedBox(6, 0, 0, w, h, col)
        
        -- Draw sort icon if available
        if rHitman.UI.Icons and rHitman.UI.Icons.Sort then
            surface.SetDrawColor(rHitman.UI.Colors.Text)
            surface.SetMaterial(rHitman.UI.Icons.Sort)
            surface.DrawTexturedRect(10, h/2 - 8, 16, 16)
            draw.SimpleText(self.SortMode or "Newest First", "rHitman.Text", 35, h/2, rHitman.UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            -- Fallback without icon
            draw.SimpleText(self.SortMode or "Newest First", "rHitman.Text", w/2, h/2, rHitman.UI.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    self.SortButton.SortMode = "Newest First"
    self.SortButton.DoClick = function(self)
        local menu = DermaMenu()
        menu:AddOption("Newest First", function() 
            self.SortMode = "Newest First"
            self:GetParent():GetParent():UpdateContractList(rHitman.getContracts())
        end)
        menu:AddOption("Highest Reward", function() 
            self.SortMode = "Highest Reward"
            self:GetParent():GetParent():UpdateContractList(rHitman.getContracts())
        end)
        menu:AddOption("Target Name (A-Z)", function() 
            self.SortMode = "Target Name"
            self:GetParent():GetParent():UpdateContractList(rHitman.getContracts())
        end)
        menu:Open()
    end

    -- Stats container
    self.Stats = vgui.Create("DPanel", self.Controls)
    self.Stats:Dock(RIGHT)
    self.Stats:SetWide(200)
    self.Stats:DockMargin(5, 5, 0, 5)
    self.Stats.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.Surface)
        draw.SimpleText("Active Contracts: " .. (self.ActiveCount or 0), "rHitman.Text", w/2, h/2, rHitman.UI.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Contract list
    self.ContractList = vgui.Create("DScrollPanel", self)
    self.ContractList:Dock(FILL)
    self.ContractList:DockMargin(10, 5, 10, 10)
    
    -- Container for contract cards
    self.CardsContainer = vgui.Create("DPanel", self.ContractList)
    self.CardsContainer:Dock(FILL)
    self.CardsContainer:DockMargin(0, 0, 0, 0)
    self.CardsContainer.Paint = function() end
    
    -- Style the scrollbar
    local sbar = self.ContractList:GetVBar()
    sbar:SetHideButtons(true)
    function sbar:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, rHitman.UI.Colors.Background)
    end
    function sbar.btnGrip:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, rHitman.UI.Colors.Primary)
    end
    
    -- Contract update hook
    hook.Add("rHitman.ContractsUpdated", "rHitman.ContractList_Update", function()
        if IsValid(self) then
            self:UpdateContractList(rHitman.getContracts())
        end
    end)

    -- Initial update
    self:UpdateContractList(rHitman.getContracts())
end

function PANEL:CreateContractCard(contract)
    local card = vgui.Create("DPanel", self.CardsContainer)
    card:SetTall(120)
    card:Dock(TOP)
    card:DockMargin(0, 5, 0, 5)
    
    card.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.Surface)
        
        if self:IsHovered() then
            surface.SetDrawColor(rHitman.UI.Colors.Primary)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end
    end
    
    -- Target info container
    local infoContainer = vgui.Create("DPanel", card)
    infoContainer:Dock(FILL)
    infoContainer:DockMargin(10, 10, 10, 10)
    infoContainer.Paint = function() end

    -- Left column - Target Info
    local leftCol = vgui.Create("DPanel", infoContainer)
    leftCol:Dock(LEFT)
    leftCol:SetWide(200)
    leftCol.Paint = function() end
    
    -- Target avatar
    local avatar = vgui.Create("AvatarImage", leftCol)
    avatar:SetSize(32, 32)
    avatar:SetPlayer(contract.target, 32)
    avatar:Dock(LEFT)
    avatar:DockMargin(0, 0, 10, 0)
    
    -- Target name container (next to avatar)
    local nameContainer = vgui.Create("DPanel", leftCol)
    nameContainer:Dock(FILL)
    nameContainer.Paint = function() end
    
    -- Target name
    local targetName = vgui.Create("DLabel", nameContainer)
    targetName:SetText(contract.targetName or "Unknown Target")
    targetName:SetFont("rHitman.Title")
    targetName:SetTextColor(rHitman.UI.Colors.Text)
    targetName:Dock(TOP)
    targetName:DockMargin(0, 0, 0, 5)
    
    -- Target job
    local targetJob = vgui.Create("DLabel", nameContainer)
    targetJob:SetText(team.GetName(contract.target:Team()))
    targetJob:SetFont("rHitman.Text")
    targetJob:SetTextColor(rHitman.UI.Colors.TextDark)
    targetJob:Dock(TOP)

    -- Middle column - Contract Details
    local middleCol = vgui.Create("DPanel", infoContainer)
    middleCol:Dock(LEFT)
    middleCol:SetWide(250)
    middleCol:DockMargin(20, 0, 0, 0)
    middleCol.Paint = function() end

    -- Reward with icon
    local rewardContainer = vgui.Create("DPanel", middleCol)
    rewardContainer:Dock(TOP)
    rewardContainer:SetTall(25)
    rewardContainer.Paint = function() end
    
    -- Only add icon if available
    if rHitman.UI.Icons and rHitman.UI.Icons.Money then
        local rewardIcon = vgui.Create("DImage", rewardContainer)
        rewardIcon:SetSize(16, 16)
        rewardIcon:SetMaterial(rHitman.UI.Icons.Money)
        rewardIcon:Dock(LEFT)
        rewardIcon:DockMargin(0, 4, 5, 0)
    end
    
    local rewardText = rHitman.formatMoney(contract.reward or 0)
    local reward = vgui.Create("DLabel", rewardContainer)
    reward:SetText(rewardText)
    reward:SetFont("rHitman.Title")
    reward:SetTextColor(rHitman.UI.Colors.Success)
    reward:Dock(FILL)

    -- Time remaining with progress bar
    local timeContainer = vgui.Create("DPanel", middleCol)
    timeContainer:Dock(TOP)
    timeContainer:SetTall(40)
    timeContainer:DockMargin(0, 5, 0, 0)
    timeContainer.Paint = function() end
    
    local timeRemaining = vgui.Create("DLabel", timeContainer)
    timeRemaining:SetFont("rHitman.Text")
    timeRemaining:SetTextColor(rHitman.UI.Colors.TextDark)
    timeRemaining:Dock(TOP)
    timeRemaining:SetTall(20)
    
    local timeProgress = vgui.Create("DProgress", timeContainer)
    timeProgress:Dock(TOP)
    timeProgress:SetTall(4)
    timeProgress:DockMargin(0, 2, 0, 0)
    timeProgress.Paint = function(self, w, h)
        draw.RoundedBox(2, 0, 0, w, h, rHitman.UI.Colors.Background)
        local progress = self:GetFraction()
        draw.RoundedBox(2, 0, 0, w * progress, h, rHitman.UI.Colors.Primary)
    end

    -- Update time remaining
    local startTime = contract.startTime or CurTime()
    local endTime = contract.endTime or (startTime + rHitman.Config.ContractDuration)
    local totalDuration = endTime - startTime
    
    local function updateTime()
        if not IsValid(timeRemaining) then return end
        local remaining = endTime - CurTime()
        if remaining <= 0 then
            timeRemaining:SetText("Expired")
            timeRemaining:SetTextColor(rHitman.UI.Colors.Danger)
            timeProgress:SetFraction(0)
            return
        end
        timeRemaining:SetText("Time Remaining: " .. string.NiceTime(remaining))
        timeProgress:SetFraction(remaining / totalDuration)
    end
    updateTime()
    timer.Create("ContractTimer_" .. (contract.id or "0"), 1, 0, updateTime)

    -- Right column - Actions
    local rightCol = vgui.Create("DPanel", infoContainer)
    rightCol:Dock(RIGHT)
    rightCol:SetWide(120)
    rightCol.Paint = function() end
    
    -- Accept button
    local acceptBtn = vgui.Create("DButton", rightCol)
    acceptBtn:SetText("")
    acceptBtn:Dock(TOP)
    acceptBtn:DockMargin(0, 0, 0, 5)
    acceptBtn:SetTall(35)
    
    acceptBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and rHitman.UI.Colors.Success or ColorAlpha(rHitman.UI.Colors.Success, 200)
        draw.RoundedBox(6, 0, 0, w, h, col)
        
        -- Draw accept icon if available
        if rHitman.UI.Icons and rHitman.UI.Icons.Accept then
            surface.SetDrawColor(rHitman.UI.Colors.Text)
            surface.SetMaterial(rHitman.UI.Icons.Accept)
            surface.DrawTexturedRect(10, h/2 - 8, 16, 16)
            draw.SimpleText("Accept", "rHitman.Text", 35, h/2, rHitman.UI.Colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            -- Fallback without icon
            draw.SimpleText("Accept Contract", "rHitman.Text", w/2, h/2, rHitman.UI.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    
    acceptBtn.DoClick = function()
        if not contract.id then return end
        
        -- Confirmation dialog
        local menu = DermaMenu()
        menu:AddOption("Confirm Accept", function()
            net.Start("rHitman.AcceptContract")
            net.WriteString(contract.id)
            net.SendToServer()
        end)
        menu:AddOption("Cancel")
        menu:Open()
    end

    -- Placer info
    local placerInfo = vgui.Create("DLabel", rightCol)
    placerInfo:SetText("By: " .. (contract.placerName or "Unknown"))
    placerInfo:SetFont("rHitman.Text")
    placerInfo:SetTextColor(rHitman.UI.Colors.TextDark)
    placerInfo:Dock(TOP)
    placerInfo:SetTall(20)
    placerInfo:SetContentAlignment(5)

    -- Cleanup
    card.OnRemove = function()
        timer.Remove("ContractTimer_" .. (contract.id or "0"))
    end
    
    return card
end

function PANEL:UpdateContractList(contracts)
    if not IsValid(self.CardsContainer) then return end
    self.CardsContainer:Clear()
    
    -- Filter and sort contracts
    local validContracts = {}
    for _, contract in pairs(contracts) do
        if contract.status == "active" then
            table.insert(validContracts, contract)
        end
    end

    -- Update stats
    if IsValid(self.Stats) then
        self.Stats.ActiveCount = #validContracts
    end

    -- Sort contracts
    local sortMode = self.SortButton.SortMode
    table.sort(validContracts, function(a, b)
        if sortMode == "Newest First" then
            return (a.startTime or 0) > (b.startTime or 0)
        elseif sortMode == "Highest Reward" then
            return (a.reward or 0) > (b.reward or 0)
        else -- Target Name
            return (a.targetName or ""):lower() < (b.targetName or ""):lower()
        end
    end)

    -- Create cards
    for _, contract in ipairs(validContracts) do
        self:CreateContractCard(contract)
    end

    -- Show "no contracts" message if needed
    if #validContracts == 0 then
        local noContracts = vgui.Create("DPanel", self.CardsContainer)
        noContracts:SetTall(100)
        noContracts:Dock(TOP)
        noContracts:DockMargin(0, 20, 0, 0)
        noContracts.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.Surface)
            draw.SimpleText("No Active Contracts", "rHitman.Title", w/2, h/2 - 10, rHitman.UI.Colors.TextDark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Check back later for new contracts", "rHitman.Text", w/2, h/2 + 10, rHitman.UI.Colors.TextDark, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

function PANEL:Paint(w, h)
    draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.Background)
end

function PANEL:OnRemove()
    hook.Remove("rHitman.ContractsUpdated", "rHitman.ContractList_Update")
end

vgui.Register("rHitman.ContractList", PANEL, "EditablePanel")
