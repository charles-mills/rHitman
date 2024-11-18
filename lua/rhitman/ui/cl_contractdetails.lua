--[[
    rHitman - Contract Details Panel
    Detailed view of a single contract with actions
]]--

local PANEL = {}

-- Use config colors
local colors = rHitman.Config.Colors

-- Helper function to create styled buttons
local function CreateStyledButton(parent, text, color)
    local btn = vgui.Create("DButton", parent)
    btn:SetTall(40)
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
        
        draw.RoundedBox(8, 0, 0, w, h, color or colors.accent)
        
        if alpha > 0 then
            draw.RoundedBox(8, 0, 0, w, h, ColorAlpha(colors.cardHover, alpha))
        end
        
        draw.SimpleText(
            text,
            "rHitman.Text",
            w/2,
            h/2,
            colors.text,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end
    
    return btn
end

function PANEL:Init()
    self.Contract = nil
    
    -- Header
    self.Header = vgui.Create("DPanel", self)
    self.Header:Dock(TOP)
    self.Header:SetTall(60)
    self.Header:DockMargin(0, 0, 0, 10)
    
    function self.Header:Paint(w, h)
        draw.RoundedBoxEx(8, 0, 0, w, h, colors.card, true, true, false, false)
        
        -- Contract ID
        draw.SimpleText(
            "Contract #" .. (self:GetParent().Contract and self:GetParent().Contract.id or ""),
            "rHitman.Heading",
            10,
            h/2,
            colors.text,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
        
        -- Status
        if self:GetParent().Contract then
            local status = self:GetParent().Contract.status or "UNKNOWN"
            local statusColor = {
                ACTIVE = colors.success,
                COMPLETED = colors.textDark,
                FAILED = colors.error,
                CANCELLED = colors.warning
            }
            
            draw.SimpleText(
                status,
                "rHitman.Text",
                w - 10,
                h/2,
                statusColor[status] or colors.textDark,
                TEXT_ALIGN_RIGHT,
                TEXT_ALIGN_CENTER
            )
        end
    end
    
    -- Content
    self.Content = vgui.Create("DScrollPanel", self)
    self.Content:Dock(FILL)
    self.Content:DockMargin(0, 0, 0, 10)
    
    -- Details section
    self.DetailsSection = vgui.Create("DPanel", self.Content)
    self.DetailsSection:Dock(TOP)
    self.DetailsSection:DockMargin(0, 0, 0, 10)
    self.DetailsSection:SetTall(200)
    
    function self.DetailsSection:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.card)
        
        local contract = self:GetParent():GetParent().Contract
        if not contract then return end
        
        -- Target info
        draw.SimpleText(
            "Target",
            "rHitman.Text",
            10,
            10,
            colors.textDark,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_TOP
        )
        
        draw.SimpleText(
            contract.targetName or "Unknown",
            "rHitman.Heading",
            10,
            35,
            colors.text,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_TOP
        )
        
        -- Reward
        draw.SimpleText(
            "Reward",
            "rHitman.Text",
            10,
            80,
            colors.textDark,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_TOP
        )
        
        draw.SimpleText(
            DarkRP.formatMoney(contract.reward or 0),
            "rHitman.Heading",
            10,
            105,
            colors.success,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_TOP
        )
        
        -- Contractor
        draw.SimpleText(
            "Contractor",
            "rHitman.Text",
            10,
            150,
            colors.textDark,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_TOP
        )
        
        draw.SimpleText(
            contract.contractorName or "Unknown",
            "rHitman.Heading",
            10,
            175,
            colors.text,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_TOP
        )
    end
    
    -- Actions section
    self.ActionsSection = vgui.Create("DPanel", self.Content)
    self.ActionsSection:Dock(TOP)
    self.ActionsSection:DockMargin(0, 0, 0, 10)
    self.ActionsSection:SetTall(120)
    
    function self.ActionsSection:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.card)
        
        draw.SimpleText(
            "Actions",
            "rHitman.Text",
            10,
            10,
            colors.textDark,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_TOP
        )
    end
    
    -- Action buttons container
    self.ButtonContainer = vgui.Create("DPanel", self.ActionsSection)
    self.ButtonContainer:Dock(TOP)
    self.ButtonContainer:DockMargin(10, 40, 10, 10)
    self.ButtonContainer:SetTall(60)
    self.ButtonContainer.Paint = function() end
    
    -- Accept button
    self.AcceptButton = CreateStyledButton(self.ButtonContainer, "Accept Contract", colors.success)
    self.AcceptButton:Dock(LEFT)
    self.AcceptButton:SetWide(150)
    self.AcceptButton:DockMargin(0, 0, 10, 0)
    self.AcceptButton.DoClick = function()
        if self.Contract then
            rHitman.acceptContract(self.Contract.id)
        end
    end
    
    -- Cancel button
    self.CancelButton = CreateStyledButton(self.ButtonContainer, "Cancel Contract", colors.error)
    self.CancelButton:Dock(LEFT)
    self.CancelButton:SetWide(150)
    self.CancelButton.DoClick = function()
        if self.Contract then
            rHitman.cancelContract(self.Contract.id)
        end
    end
end

function PANEL:SetContract(contract)
    self.Contract = contract
    
    -- Update button visibility based on contract state and player role
    local isContractor = LocalPlayer():SteamID64() == contract.contractorID
    local isHitman = rHitman.isHitman(LocalPlayer())
    local isActive = contract.status == "ACTIVE"
    
    self.AcceptButton:SetVisible(isHitman and isActive)
    self.CancelButton:SetVisible(isContractor and isActive)
end

function PANEL:Paint(w, h)
    draw.RoundedBox(8, 0, 0, w, h, colors.background)
end

vgui.Register("rHitman_ContractDetails", PANEL, "DPanel")
