--[[
    rHitman - Client HUD
    Displays active contracts information for hitmen
]]--

local PANEL = {}

-- Colors (using shared UI colors)
local Colors = rHitman.UI.Colors

-- Contract end states
local endStates = {
    completed = {
        sound = "buttons/button3.wav",
        message = "CONTRACT COMPLETED",
        color = Colors.Success
    },
    failed = {
        sound = "buttons/button10.wav",
        message = "CONTRACT FAILED",
        color = Colors.Error
    },
    cancelled = {
        sound = "buttons/button16.wav",
        message = "CONTRACT CANCELLED",
        color = Colors.TextDark
    },
    expired = {
        sound = "buttons/button16.wav",
        message = "CONTRACT EXPIRED",
        color = Colors.TextDark
    }
}

-- Scale helper function
local function Scale(size)
    return math.Round(size * (ScrH() / 1080) * 0.75)
end

function PANEL:Init()
    local width = Scale(300)
    local height = Scale(200)
    self:SetSize(width, height)
    self:SetPos(rHitman.Config.HUDPosition.x, rHitman.Config.HUDPosition.y)
    self.ActiveContract = nil
    self.LastUpdate = 0
    self.FadeAlpha = 255
    self.FadeOutSpeed = 0
    self.HealthLerp = 100
    self.ArmorLerp = 100
    self.TargetDistance = 0
    self.CompletionState = nil
    self.CompletionAnim = 0
    self.CompletionTime = 0
    self:ParentToHUD()
    self:SetPaintedManually(false)
end

function PANEL:StartCompletion(state)
    if not endStates[state] then return end
    
    self.CompletionState = state
    self.CompletionAnim = 0
    self.FadeAlpha = 255
    self.FadeOutSpeed = 0 -- Reset fade out speed
    
    -- Play completion sound
    surface.PlaySound(endStates[state].sound)
    
    -- Start the completion animation
    local animTime = rHitman.Config.HUDCompletionAnimTime or 0.5
    local startTime = CurTime()
    
    timer.Create("rHitman_CompletionAnim_" .. self:EntIndex(), 0, 0, function()
        if not IsValid(self) then
            timer.Remove("rHitman_CompletionAnim_" .. self:EntIndex())
            return
        end
        
        local progress = (CurTime() - startTime) / animTime
        self.CompletionAnim = math.min(1, progress)
        
        -- When animation is done, start fade out after delay
        if progress >= 1 then
            timer.Remove("rHitman_CompletionAnim_" .. self:EntIndex())
            
            timer.Simple(rHitman.Config.HUDCompletionHoldTime or 2, function()
                if IsValid(self) then
                    self.FadeOutSpeed = rHitman.Config.HUDFadeSpeed or 5
                end
            end)
        end
    end)
end

function PANEL:Think()
    -- Update fade out
    if self.FadeOutSpeed > 0 then
        self.FadeAlpha = math.max(0, self.FadeAlpha - self.FadeOutSpeed)
        if self.FadeAlpha <= 0 then
            if IsValid(self) then
                self:Remove()
                rHitman.HUD = nil
            end
            return
        end
    end
    
    -- Update every 0.1 seconds
    if CurTime() - self.LastUpdate < 0.1 then return end
    self.LastUpdate = CurTime()

    -- Update completion animation
    if self.CompletionState then
        local dt = CurTime() - self.CompletionTime
        self.CompletionAnim = math.Clamp(dt * 2, 0, 1) -- 0.5 second animation
    end

    -- Check if we have an active contract
    local found = false
    if rHitman.ActiveContract then
        self.ActiveContract = rHitman.ActiveContract
        found = true
    else
        -- Look for active contracts where we are the hitman
        for _, contract in pairs(rHitman.Contracts.cache) do
            if contract.status == "active" and contract.hitman == LocalPlayer():SteamID64() then
                self.ActiveContract = contract
                rHitman.ActiveContract = contract
                found = true
                break
            end
        end
    end

    if not found and not self.CompletionState then
        self.FadeOutSpeed = rHitman.Config.HUDFadeSpeed or 5
    end

    -- Update target info if we have a target
    if self.ActiveContract then
        local target = player.GetBySteamID64(self.ActiveContract.target)
        if IsValid(target) then
            self.TargetDistance = math.Round(LocalPlayer():GetPos():Distance(target:GetPos()) / 52.49, 1)
            -- Smooth lerp health and armor values
            self.HealthLerp = Lerp(0.1, self.HealthLerp, target:Health())
            self.ArmorLerp = Lerp(0.1, self.ArmorLerp, target:Armor())
        end
    end
end

-- Draw a progress bar
local function DrawBar(x, y, w, h, value, maxValue, color, alpha)
    -- Background
    draw.RoundedBox(4, x, y, w, h, ColorAlpha(Colors.SurfaceLight, alpha))
    
    -- Progress
    local progress = math.Clamp(value / maxValue, 0, 1)
    draw.RoundedBox(4, x, y, w * progress, h, ColorAlpha(color, alpha))
end

function PANEL:Paint(w, h)
    if self.CompletionState then
        local state = endStates[self.CompletionState]
        if not state then return end
        
        -- Background
        draw.RoundedBox(6, 0, 0, w, h, ColorAlpha(Colors.Background, self.FadeAlpha))
        
        -- Message background
        local messageH = Scale(60)
        local messageY = h/2 - messageH/2
        draw.RoundedBox(6, 0, messageY, w, messageH, ColorAlpha(Colors.Surface, self.FadeAlpha))
        
        -- Draw completion message with animation
        local textY = messageY + messageH/2 + (1 - self.CompletionAnim) * Scale(20)
        local messageAlpha = self.CompletionAnim * 255
        
        draw.SimpleText(state.message, "rHitman.HUD.Large", w/2, textY, 
            ColorAlpha(state.color, messageAlpha), 
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        return
    end

    if not self.ActiveContract then return end

    -- Main background
    draw.RoundedBox(6, 0, 0, w, h, ColorAlpha(Colors.Background, self.FadeAlpha))
    
    -- Header background
    draw.RoundedBoxEx(Scale(6), 0, 0, w, Scale(40), ColorAlpha(Colors.Surface, self.FadeAlpha), true, true, false, false)
    
    -- Top border accent
    surface.SetDrawColor(ColorAlpha(Colors.Primary, self.FadeAlpha))
    surface.DrawRect(0, 0, w, Scale(2))

    -- Header text
    draw.SimpleText("ACTIVE CONTRACT", "rHitman.HUD.Header", w/2, Scale(20), ColorAlpha(Colors.Text, self.FadeAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Target section
    local target = player.GetBySteamID64(self.ActiveContract.target)
    if IsValid(target) then
        draw.SimpleText("TARGET", "rHitman.Text.Small", Scale(15), Scale(55), ColorAlpha(Colors.TextDark, self.FadeAlpha))
        draw.SimpleText(target:Nick(), "rHitman.Text.Large", Scale(15), Scale(75), ColorAlpha(Colors.Text, self.FadeAlpha))

        -- Distance
        local distStr = string.format("%.1fm away", self.TargetDistance)
        draw.SimpleText(distStr, "rHitman.Text.Small", w - Scale(15), Scale(75), ColorAlpha(Colors.TextDark, self.FadeAlpha), TEXT_ALIGN_RIGHT)

        -- Health and Armor bars
        local barWidth = w - Scale(30)
        local barHeight = Scale(12)
        local padding = Scale(15)

        -- Health Bar
        draw.SimpleText("Health", "rHitman.Text.Small", padding, Scale(105), ColorAlpha(Colors.TextDark, self.FadeAlpha))
        DrawBar(padding, Scale(125), barWidth, barHeight, self.HealthLerp, 100, Colors.Health, self.FadeAlpha)
        draw.SimpleText(math.Round(self.HealthLerp) .. "%", "rHitman.Text.Small", w - padding, Scale(125) + barHeight/2, ColorAlpha(Colors.Text, self.FadeAlpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        -- Armor Bar
        draw.SimpleText("Armor", "rHitman.Text.Small", padding, Scale(145), ColorAlpha(Colors.TextDark, self.FadeAlpha))
        DrawBar(padding, Scale(165), barWidth, barHeight, self.ArmorLerp, 100, Colors.Armor, self.FadeAlpha)
        draw.SimpleText(math.Round(self.ArmorLerp) .. "%", "rHitman.Text.Small", w - padding, Scale(165) + barHeight/2, ColorAlpha(Colors.Text, self.FadeAlpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end

-- Create HUD when player spawns
hook.Add("InitPostEntity", "rHitman.CreateHUD", function()
    if IsValid(rHitman.HUD) then rHitman.HUD:Remove() end
    rHitman.HUD = vgui.Create("rHitman_HUD")
end)

-- Update HUD when contracts change
hook.Add("rHitman.ContractsUpdated", "rHitman_HUD_ContractUpdate", function()
    if not IsValid(rHitman.HUD) then return end
    
    -- Check if our active contract was completed/failed/cancelled
    if rHitman.ActiveContract then
        local contract = rHitman.Contracts:GetContract(rHitman.ActiveContract.id)
        if contract and contract.hitman == LocalPlayer():SteamID64() then
            if contract.status ~= "active" then
                rHitman.HUD:StartCompletion(contract.status)
                rHitman.ActiveContract = nil
            end
        end
    end
end)

-- Handle contract acceptance
hook.Add("rHitman.ContractAccepted", "rHitman.ShowHUD", function(contract)
    if not IsValid(rHitman.HUD) then
        rHitman.HUD = vgui.Create("rHitman_HUD")
    end
    
    if contract.hitman == LocalPlayer():SteamID64() then
        rHitman.ActiveContract = contract
    end
end)

-- Cleanup on player death
hook.Add("PlayerDeath", "rHitman_CleanupHUD", function(victim)
    if victim == LocalPlayer() and IsValid(rHitman.HUD) then
        rHitman.HUD:StartCompletion("failed")
        rHitman.ActiveContract = nil
    end
end)

-- Register the panel
vgui.Register("rHitman_HUD", PANEL, "DPanel")
