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

    -- Create a unique ID for this panel instance
    self.UniqueID = "ContractList_" .. math.random(1, 100000)

    -- Header
    self.Header = vgui.Create("DPanel", self)
    self.Header:Dock(TOP)
    self.Header:SetTall(30)
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
            self:GetParent():GetParent():UpdateContractList()
        end)
        menu:AddOption("Highest Reward", function() 
            self.SortMode = "Highest Reward"
            self:GetParent():GetParent():UpdateContractList()
        end)
        menu:AddOption("Target Name (A-Z)", function() 
            self.SortMode = "Target Name"
            self:GetParent():GetParent():UpdateContractList()
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

    -- Create the scroll panel
    self.scroll = vgui.Create("DScrollPanel", self)
    self.scroll:Dock(FILL)
    self.scroll:DockMargin(10, 5, 10, 10)
    
    local sbar = self.scroll:GetVBar()
    sbar:SetWide(5)
    sbar:SetHideButtons(true)
    function sbar:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, rHitman.UI.Colors.Background)
    end
    function sbar.btnGrip:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, rHitman.UI.Colors.Primary)
    end
    
    -- Add hook for contract updates
    hook.Add("rHitman.ContractsUpdated", "rHitman.ContractList_Update_" .. self.UniqueID, function()
        if IsValid(self) then
            self:UpdateContractList()
        end
    end)

    -- Request initial contracts
    rHitman.requestContracts()

    -- Initial update
    self:UpdateContractList()
end

function PANEL:UpdateContractList()
    self.scroll:Clear()
    local contracts = rHitman.Contracts:GetAll()
    
    -- Filter contracts based on player permissions
    local function filterContracts(contracts)
        local filtered = {}
        local isHitman = rHitman.Util.isHitman(LocalPlayer())
        local canAcceptPremium = rHitman.Util.canAcceptPremiumHits(LocalPlayer())
        
        for _, contract in pairs(contracts) do
            -- Only show premium hits to hitmen with premium permissions
            if contract.premium then
                if isHitman and canAcceptPremium then
                    table.insert(filtered, contract)
                end
            else
                -- Show regular hits to all hitmen
                if isHitman then
                    table.insert(filtered, contract)
                end
            end
        end
        
        return filtered
    end
    
    contracts = filterContracts(contracts)
    
    -- Convert to array for sorting
    local contractArray = {}
    for id, contract in pairs(contracts) do
        contract.id = id  -- Ensure ID is set
        table.insert(contractArray, contract)
    end
    
    -- Sort contracts based on selected mode
    if self.SortButton.SortMode == "Newest First" then
        table.sort(contractArray, function(a, b) 
            if not a.created or not b.created then return false end
            return a.created > b.created 
        end)
    elseif self.SortButton.SortMode == "Highest Reward" then
        table.sort(contractArray, function(a, b)
            if not a.reward or not b.reward then return false end
            return a.reward > b.reward
        end)
    elseif self.SortButton.SortMode == "Target Name" then
        table.sort(contractArray, function(a, b)
            if not a.targetName or not b.targetName then return false end
            return a.targetName < b.targetName
        end)
    end

    -- Update active contract count
    local activeCount = 0
    for _, contract in ipairs(contractArray) do
        if contract.status == "active" then
            activeCount = activeCount + 1
        end
    end
    if IsValid(self.Stats) then
        self.Stats.ActiveCount = activeCount
    end

    -- Create panels for each contract
    for _, contract in ipairs(contractArray) do
        local panel = vgui.Create("rHitman_ContractPanel")
        panel:SetContract(contract)
        self.scroll:AddItem(panel)
    end
end

function PANEL:Paint(w, h)
    draw.RoundedBox(6, 0, 0, w, h, rHitman.UI.Colors.Background)
end

function PANEL:OnRemove()
    -- Clean up the hook when the panel is removed
    hook.Remove("rHitman.ContractsUpdated", "rHitman.ContractList_Update_" .. self.UniqueID)
end

vgui.Register("rHitman.ContractList", PANEL, "EditablePanel")


local PANEL = {}

function PANEL:Init()
    self:SetTall(120)
    self:Dock(TOP)
    self:DockMargin(5, 5, 5, 5)
end

function PANEL:SetContract(contract)
    self.contract = contract
    
    -- Main container with padding
    local mainContainer = vgui.Create("DPanel", self)
    mainContainer:Dock(FILL)
    mainContainer:DockMargin(10, 10, 10, 10)
    mainContainer.Paint = function() end

    -- Left column - Target Info
    local leftCol = vgui.Create("DPanel", mainContainer)
    leftCol:Dock(LEFT)
    leftCol:SetWide(250)
    leftCol.Paint = function() end
    
    -- Target info header
    local targetHeader = vgui.Create("DLabel", leftCol)
    targetHeader:SetText("TARGET")
    targetHeader:SetFont("rHitman.Text.Small")
    targetHeader:SetTextColor(rHitman.UI.Colors.TextDim)
    targetHeader:Dock(TOP)
    targetHeader:DockMargin(0, 0, 0, 5)
    
    -- Target avatar container
    local avatarContainer = vgui.Create("DPanel", leftCol)
    avatarContainer:Dock(TOP)
    avatarContainer:SetTall(48)
    avatarContainer.Paint = function() end
    
    -- Target avatar
    local avatar = vgui.Create("AvatarImage", avatarContainer)
    avatar:SetSize(48, 48)
    avatar:Dock(LEFT)
    avatar:DockMargin(0, 0, 10, 0)
    
    -- Get player by Steam ID
    local targetPlayer = player.GetBySteamID64(contract.target)
    if IsValid(targetPlayer) then
        avatar:SetPlayer(targetPlayer, 64)  -- Use larger avatar size
    else
        avatar:SetSteamID(contract.target, 64)
    end
    
    -- Target info (next to avatar)
    local targetInfo = vgui.Create("DPanel", avatarContainer)
    targetInfo:Dock(FILL)
    targetInfo.Paint = function() end
    
    -- Target name
    local targetName = vgui.Create("DLabel", targetInfo)
    targetName:SetText(contract.targetName or "Unknown")
    targetName:SetFont("rHitman.Text")
    targetName:SetTextColor(rHitman.UI.Colors.Text)
    targetName:Dock(TOP)
    
    -- Target job
    local targetJob = vgui.Create("DLabel", targetInfo)
    targetJob:SetText(contract.targetJob or "Unknown Job")
    targetJob:SetFont("rHitman.Text.Small")
    targetJob:SetTextColor(rHitman.UI.Colors.TextDim)
    targetJob:Dock(TOP)
    
    -- Right column - Contract Info
    local rightCol = vgui.Create("DPanel", mainContainer)
    rightCol:Dock(RIGHT)
    rightCol:SetWide(200)
    rightCol.Paint = function() end
    
    -- Reward container
    local rewardContainer = vgui.Create("DPanel", rightCol)
    rewardContainer:Dock(TOP)
    rewardContainer:DockMargin(0, 0, 0, 10)
    rewardContainer.Paint = function() end
    
    -- Reward header
    local rewardHeader = vgui.Create("DLabel", rewardContainer)
    rewardHeader:SetText("REWARD")
    rewardHeader:SetFont("rHitman.Text.Small")
    rewardHeader:SetTextColor(rHitman.UI.Colors.TextDim)
    rewardHeader:Dock(TOP)
    
    -- Reward amount
    local rewardAmount = vgui.Create("DLabel", rewardContainer)
    rewardAmount:SetText(DarkRP.formatMoney(contract.reward))
    rewardAmount:SetFont("rHitman.Text.Large")
    rewardAmount:SetTextColor(rHitman.UI.Colors.Success)
    rewardAmount:Dock(TOP)
    
    -- Accept button
    local acceptBtn = vgui.Create("DButton", rightCol)
    acceptBtn:SetText("ACCEPT CONTRACT")
    acceptBtn:SetFont("rHitman.Text")
    acceptBtn:Dock(TOP)
    acceptBtn:DockMargin(0, 10, 0, 0)
    acceptBtn.Paint = function(self, w, h)
        local bgColor = self:IsHovered() and rHitman.UI.Colors.Success or ColorAlpha(rHitman.UI.Colors.Success, 200)
        draw.RoundedBox(6, 0, 0, w, h, bgColor)
    end
    acceptBtn.DoClick = function()
        -- Send accept request to server
        net.Start("rHitman_AcceptContract")
        net.WriteString(contract.id)
        net.SendToServer()
        
        -- Disable button temporarily
        acceptBtn:SetEnabled(false)
        timer.Simple(1, function()
            if IsValid(acceptBtn) then
                acceptBtn:SetEnabled(true)
            end
        end)
    end
    
    -- Center column - Contract Details
    local centerCol = vgui.Create("DPanel", mainContainer)
    centerCol:Dock(FILL)
    centerCol:DockMargin(20, 0, 20, 0)
    centerCol.Paint = function() end
    
    -- Contractor info
    local contractorInfo = vgui.Create("DPanel", centerCol)
    contractorInfo:Dock(TOP)
    contractorInfo.Paint = function() end
    
    -- Contractor header
    local contractorHeader = vgui.Create("DLabel", contractorInfo)
    contractorHeader:SetText("CONTRACTOR")
    contractorHeader:SetFont("rHitman.Text.Small")
    contractorHeader:SetTextColor(rHitman.UI.Colors.TextDim)
    contractorHeader:Dock(TOP)
    
    -- Contractor name
    local contractorName = vgui.Create("DLabel", contractorInfo)
    contractorName:SetText(contract.contractorName or "Anonymous")
    contractorName:SetFont("rHitman.Text")
    contractorName:SetTextColor(rHitman.UI.Colors.Text)
    contractorName:Dock(TOP)
end

function PANEL:Paint(w, h)
    -- Panel background with subtle gradient
    draw.RoundedBox(8, 0, 0, w, h, rHitman.UI.Colors.Surface)
    
    -- Add subtle highlight at the top
    local highlight = ColorAlpha(rHitman.UI.Colors.Primary, 10)
    draw.RoundedBoxEx(8, 0, 0, w, h/4, highlight, true, true, false, false)
end

vgui.Register("rHitman_ContractPanel", PANEL, "DPanel")
