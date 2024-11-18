--[[
    rHitman - Contract List Panel
    Displays available contracts
]]--

local PANEL = {}

-- Use config colors
local colors = rHitman.Config.Colors

-- Contract card panel
local CARD = {}

function CARD:Init()
    self:SetTall(100)
    self:DockMargin(0, 0, 0, 10)
    self:Dock(TOP)
    
    self.Alpha = 0
    self.TargetAlpha = 0
    self.AccentColor = Color(220, 50, 50)
end

function CARD:SetContract(contract)
    self.Contract = contract
    
    -- Set accent color based on contract status
    if contract.status == "active" then
        if contract.hitman == LocalPlayer():SteamID64() then
            self.AccentColor = Color(46, 204, 113) -- Green for my active contract
        elseif contract.contractor == LocalPlayer():SteamID64() then
            self.AccentColor = Color(241, 196, 15) -- Yellow for my placed contract
        else
            self.AccentColor = Color(52, 152, 219) -- Blue for available contract
        end
    else
        self.AccentColor = Color(149, 165, 166) -- Gray for completed/cancelled
    end
end

function CARD:Paint(w, h)
    -- Background
    if self:IsHovered() then
        self.TargetAlpha = 255
    else
        self.TargetAlpha = 0
    end
    
    self.Alpha = Lerp(FrameTime() * 10, self.Alpha, self.TargetAlpha)
    
    -- Main background
    draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30))
    
    -- Hover effect
    if self.Alpha > 0 then
        draw.RoundedBox(8, 0, 0, w, h, ColorAlpha(Color(40, 40, 40), self.Alpha))
    end
    
    -- Accent line
    surface.SetDrawColor(self.AccentColor)
    surface.DrawRect(0, 0, 4, h)
    
    if not self.Contract then return end
    
    -- Target info
    local target = player.GetBySteamID64(self.Contract.target)
    local targetName = IsValid(target) and target:Nick() or "Unknown"
    
    draw.SimpleText(targetName, "rHitman.Heading", 20, 20, color_white, TEXT_ALIGN_LEFT)
    draw.SimpleText("Reward: " .. DarkRP.formatMoney(self.Contract.reward), "rHitman.Text", 20, 50, Color(200, 200, 200), TEXT_ALIGN_LEFT)
    
    -- Status and time
    local timeLeft = rHitman.Util.formatTimeLeft(self.Contract)
    draw.SimpleText("Status: " .. string.upper(self.Contract.status), "rHitman.Small", w - 20, 20, self.AccentColor, TEXT_ALIGN_RIGHT)
    draw.SimpleText(timeLeft, "rHitman.Small", w - 20, 50, Color(200, 200, 200), TEXT_ALIGN_RIGHT)
end

function CARD:OnMousePressed(mouseCode)
    if mouseCode == MOUSE_RIGHT and self.Contract then
        local menu = DermaMenu()
        
        -- View details option
        menu:AddOption("View Details", function()
            -- Show contract details panel (to be implemented)
        end):SetIcon("icon16/magnifier.png")
        
        -- Contract actions based on status and player role
        if self.Contract.status == "active" then
            if self.Contract.contractor ~= LocalPlayer():SteamID64() and not self.Contract.hitman then
                menu:AddOption("Accept Contract", function()
                    rHitman.acceptContract(self.Contract.id)
                end):SetIcon("icon16/accept.png")
            end
            
            if self.Contract.contractor == LocalPlayer():SteamID64() or self.Contract.hitman == LocalPlayer():SteamID64() then
                menu:AddOption("Cancel Contract", function()
                    rHitman.cancelContract(self.Contract.id)
                end):SetIcon("icon16/cancel.png")
            end
        end
        
        menu:Open()
    end
end

vgui.Register("rHitman_ContractCard", CARD, "DPanel")

-- Main contract list panel
function PANEL:Init()
    -- Contract list
    self.ContractList = vgui.Create("DScrollPanel", self)
    self.ContractList:Dock(LEFT)
    self.ContractList:SetWide(300)
    self.ContractList:DockMargin(0, 0, 10, 0)
    
    -- Contract details
    self.ContractDetails = vgui.Create("rHitman_ContractDetails", self)
    self.ContractDetails:Dock(FILL)
    self.ContractDetails:SetVisible(false)
    
    -- Search bar
    self.SearchBar = vgui.Create("DTextEntry", self.ContractList)
    self.SearchBar:Dock(TOP)
    self.SearchBar:DockMargin(5, 5, 5, 5)
    self.SearchBar:SetTall(40)
    self.SearchBar:SetPlaceholderText("Search contracts...")
    self.SearchBar:SetFont("rHitman.Text")
    
    local searchAlpha = 0
    local searchTargetAlpha = 0
    
    function self.SearchBar:Paint(w, h)
        if self:IsHovered() or self:HasFocus() then
            searchTargetAlpha = 255
        else
            searchTargetAlpha = 0
        end
        
        searchAlpha = Lerp(FrameTime() * 10, searchAlpha, searchTargetAlpha)
        
        draw.RoundedBox(8, 0, 0, w, h, colors.input)
        
        if searchAlpha > 0 then
            draw.RoundedBox(8, 0, 0, w, h, ColorAlpha(colors.inputHover, searchAlpha))
        end
        
        self:DrawTextEntryText(
            colors.text,
            colors.accent,
            colors.text
        )
        
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
    
    -- Contract cards container
    self.CardsContainer = vgui.Create("DPanel", self.ContractList)
    self.CardsContainer:Dock(TOP)
    self.CardsContainer.Paint = function() end
    
    -- Helper function to create contract cards
    function self:CreateContractCard(contract)
        local card = vgui.Create("DButton", self.CardsContainer)
        card:Dock(TOP)
        card:DockMargin(5, 0, 5, 5)
        card:SetTall(100)
        card:SetText("")
        
        local alpha = 0
        local targetAlpha = 0
        
        function card:Paint(w, h)
            if self:IsHovered() then
                targetAlpha = 255
            else
                targetAlpha = 0
            end
            
            alpha = Lerp(FrameTime() * 10, alpha, targetAlpha)
            
            draw.RoundedBox(8, 0, 0, w, h, colors.card)
            
            if alpha > 0 then
                draw.RoundedBox(8, 0, 0, w, h, ColorAlpha(colors.cardHover, alpha))
            end
            
            -- Target name
            draw.SimpleText(
                contract.targetName or "Unknown",
                "rHitman.Text",
                10,
                10,
                colors.text,
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_TOP
            )
            
            -- Reward
            draw.SimpleText(
                DarkRP.formatMoney(contract.reward or 0),
                "rHitman.Text",
                10,
                35,
                colors.success,
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_TOP
            )
            
            -- Status
            local status = contract.status or "UNKNOWN"
            local statusColor = {
                ACTIVE = colors.success,
                COMPLETED = colors.textDark,
                FAILED = colors.error,
                CANCELLED = colors.warning
            }
            
            draw.SimpleText(
                status,
                "rHitman.Small",
                10,
                h - 10,
                statusColor[status] or colors.textDark,
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_BOTTOM
            )
            
            -- Contractor
            draw.SimpleText(
                "By " .. (contract.contractorName or "Unknown"),
                "rHitman.Small",
                w - 10,
                h - 10,
                colors.textDark,
                TEXT_ALIGN_RIGHT,
                TEXT_ALIGN_BOTTOM
            )
        end
        
        function card:DoClick()
            self:GetParent():GetParent():GetParent().ContractDetails:SetContract(contract)
            self:GetParent():GetParent():GetParent().ContractDetails:SetVisible(true)
        end
        
        return card
    end
    
    -- Update contract list
    function self:UpdateContractList(contracts)
        self.CardsContainer:Clear()
        
        local searchText = self.SearchBar:GetText():lower()
        
        for _, contract in ipairs(contracts) do
            if searchText == "" or 
               string.find(string.lower(contract.targetName or ""), searchText) or
               string.find(string.lower(contract.contractorName or ""), searchText) then
                self:CreateContractCard(contract)
            end
        end
    end
    
    -- Search functionality
    self.SearchBar.OnChange = function()
        self:UpdateContractList(rHitman.getContracts())
    end
    
    -- Initial update
    self:UpdateContractList(rHitman.getContracts())
    
    -- Contract update hook
    hook.Add("rHitman.ContractsUpdated", "rHitman_ContractList_Update", function()
        if IsValid(self) then
            self:UpdateContractList(rHitman.getContracts())
        end
    end)
end

function PANEL:OnRemove()
    if self.UpdateTimer then
        timer.Remove(self.UpdateTimer)
    end
end

vgui.Register("rHitman_ContractList", PANEL, "DPanel")
