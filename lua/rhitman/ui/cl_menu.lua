--[[
    rHitman - Client Menu
    Main menu for contract management
]]--

local PANEL = {}

function PANEL:Init()
    self:SetSize(800, 600)
    self:Center()
    self:SetTitle("Contract Management")
    self:MakePopup()
    
    -- Create tabs
    self.Tabs = vgui.Create("DPropertySheet", self)
    self.Tabs:Dock(FILL)
    
    -- Active Contracts Tab
    self.ActiveContracts = vgui.Create("DPanel", self.Tabs)
    self.ActiveContracts.Paint = function(s, w, h)
        surface.SetDrawColor(45, 45, 45)
        surface.DrawRect(0, 0, w, h)
    end
    
    -- Contract list
    self.ContractList = vgui.Create("DListView", self.ActiveContracts)
    self.ContractList:Dock(FILL)
    self.ContractList:SetMultiSelect(false)
    self.ContractList:AddColumn("Target")
    self.ContractList:AddColumn("Reward")
    self.ContractList:AddColumn("Status")
    self.ContractList:AddColumn("Time Left")
    
    -- Add right-click menu
    function self.ContractList:OnRowRightClick(lineID, line)
        local contract = line.ContractData
        if not contract then return end
        
        local menu = DermaMenu()
        
        -- Only show accept option if contract is active and we're not the contractor
        if contract.status == "active" and contract.contractor ~= LocalPlayer():SteamID64() then
            menu:AddOption("Accept Contract", function()
                rHitman.acceptContract(contract.id)
            end):SetIcon("icon16/accept.png")
        end
        
        -- Only show cancel option if we're the contractor or hitman
        if contract.status == "active" and 
           (contract.contractor == LocalPlayer():SteamID64() or contract.hitman == LocalPlayer():SteamID64()) then
            menu:AddOption("Cancel Contract", function()
                rHitman.cancelContract(contract.id)
            end):SetIcon("icon16/cancel.png")
        end
        
        -- Add view details option
        menu:AddOption("View Details", function()
            local details = vgui.Create("DFrame")
            details:SetSize(400, 300)
            details:Center()
            details:SetTitle("Contract Details")
            details:MakePopup()
            
            local scroll = vgui.Create("DScrollPanel", details)
            scroll:Dock(FILL)
            scroll:DockMargin(5, 5, 5, 5)
            
            local function AddDetail(label, value)
                local panel = vgui.Create("DPanel", scroll)
                panel:Dock(TOP)
                panel:DockMargin(0, 0, 0, 5)
                panel:SetTall(25)
                panel.Paint = function(s, w, h)
                    surface.SetDrawColor(60, 60, 60)
                    surface.DrawRect(0, 0, w, h)
                end
                
                local lbl = vgui.Create("DLabel", panel)
                lbl:SetText(label .. ":")
                lbl:Dock(LEFT)
                lbl:DockMargin(5, 0, 5, 0)
                lbl:SetWide(100)
                lbl:SetTextColor(color_white)
                
                local val = vgui.Create("DLabel", panel)
                val:SetText(value)
                val:Dock(FILL)
                val:DockMargin(5, 0, 5, 0)
                val:SetTextColor(color_white)
            end
            
            local target = player.GetBySteamID64(contract.target)
            local contractor = player.GetBySteamID64(contract.contractor)
            local hitman = contract.hitman and player.GetBySteamID64(contract.hitman)
            
            AddDetail("Target", IsValid(target) and target:Nick() or "Unknown")
            AddDetail("Contractor", IsValid(contractor) and contractor:Nick() or "Unknown")
            AddDetail("Hitman", IsValid(hitman) and hitman:Nick() or "None")
            AddDetail("Reward", rHitman.Util.formatMoney(contract.reward))
            AddDetail("Status", string.upper(contract.status))
            AddDetail("Time Left", rHitman.Util.formatTimeLeft(contract))
            AddDetail("Created", os.date("%Y-%m-%d %H:%M:%S", contract.timeCreated))
            if contract.expireTime then
                AddDetail("Expires", os.date("%Y-%m-%d %H:%M:%S", contract.expireTime))
            end
        end):SetIcon("icon16/magnifier.png")
        
        menu:Open()
    end
    
    -- Add tabs
    self.Tabs:AddSheet("Active Contracts", self.ActiveContracts, "icon16/book.png")
    
    -- Refresh contracts initially
    self:RefreshContracts()
    
    -- Set up auto-refresh
    timer.Create("rHitman_MenuRefresh", 1, 0, function()
        if IsValid(self) then
            self:RefreshContracts()
        end
    end)
end

function PANEL:RefreshContracts()
    if not IsValid(self.ContractList) then return end
    
    self.ContractList:Clear()
    
    -- Get all contracts
    local contracts = rHitman.getContracts()
    
    -- Add each contract to the list
    for id, contract in pairs(contracts) do
        if contract.status == "active" then
            local target = player.GetBySteamID64(contract.target)
            local targetName = IsValid(target) and target:Nick() or "Unknown"
            
            local line = self.ContractList:AddLine(
                targetName,
                rHitman.Util.formatMoney(contract.reward),
                contract.status,
                rHitman.Util.formatTimeLeft(contract)
            )
            
            -- Store contract data in the line
            line.ContractData = contract
            
            -- Color the line based on status
            line.Paint = function(s, w, h)
                local color = rHitman.Util.getStatusColor(contract)
                surface.SetDrawColor(color.r, color.g, color.b, 25)
                surface.DrawRect(0, 0, w, h)
            end
        end
    end
end

function PANEL:OnRemove()
    timer.Remove("rHitman_MenuRefresh")
end

vgui.Register("rHitman_Menu", PANEL, "DFrame")

-- Command to open menu
concommand.Add("rhitman_menu", function()
    if IsValid(rHitman.Menu) then
        rHitman.Menu:Remove()
    end
    
    rHitman.Menu = vgui.Create("rHitman_Menu")
end)
