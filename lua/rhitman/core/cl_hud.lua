--[[
    rHitman - Client HUD
    Displays active contracts information for hitmen
]]--

local PANEL = {}

-- Colors
local colors = {
    background = Color(20, 20, 20, 230),
    header = Color(220, 50, 50, 255),
    text = Color(255, 255, 255, 255),
    subtext = Color(200, 200, 200, 255),
    warning = Color(255, 100, 100, 255),
    border = Color(220, 50, 50, 100),
    highlight = Color(255, 80, 80, 255),
    shadow = Color(0, 0, 0, 100),
    health = Color(46, 204, 113),
    armor = Color(52, 152, 219),
    headerBg = Color(30, 30, 30, 250),
    success = Color(46, 204, 113, 255),
    failure = Color(231, 76, 60, 255)
}

-- Contract end states
local endStates = {
    completed = {
        sound = "buttons/button3.wav",
        message = "TARGET ELIMINATED",
        color = colors.success
    },
    failed = {
        sound = "buttons/button10.wav",
        message = "CONTRACT FAILED",
        color = colors.failure
    },
    cancelled = {
        sound = "buttons/button16.wav",
        message = "CONTRACT CANCELLED",
        color = colors.warning
    },
    expired = {
        sound = "buttons/button16.wav",
        message = "CONTRACT EXPIRED",
        color = colors.warning
    }
}

-- Fonts
surface.CreateFont("rHitman.HUD.Header", {
    font = "Roboto",
    size = 24,
    weight = 700,
    antialias = true,
    shadow = true
})

surface.CreateFont("rHitman.HUD.Title", {
    font = "Roboto",
    size = 22,
    weight = 600,
    antialias = true,
    shadow = true
})

surface.CreateFont("rHitman.HUD.Info", {
    font = "Roboto",
    size = 18,
    weight = 500,
    antialias = true,
    shadow = true
})

surface.CreateFont("rHitman.HUD.Small", {
    font = "Roboto",
    size = 16,
    weight = 400,
    antialias = true,
    shadow = true
})

surface.CreateFont("rHitman.HUD.Complete", {
    font = "Roboto",
    size = 32,
    weight = 800,
    antialias = true,
    shadow = true
})

function PANEL:Init()
    self:SetSize(300, 180) 
    self:SetPos(10, ScrH() * 0.3)
    self.ActiveContract = nil
    self.LastUpdate = 0
    self.TargetDistance = 0
    self.FadeAlpha = 255
    self.FadeOutSpeed = 0
    self.HealthLerp = 0
    self.ArmorLerp = 0
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
    local animTime = rHitman.Config.HUDCompletionAnimTime
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
            
            timer.Simple(rHitman.Config.HUDCompletionHoldTime, function()
                if IsValid(self) then
                    self.FadeOutSpeed = rHitman.Config.HUDFadeSpeed
                end
            end)
        end
    end)
end

function PANEL:StartFadeOut(fast)
    self.ActiveContract = nil
    self.FadeOutSpeed = fast and rHitman.Config.HUDFastFadeSpeed or rHitman.Config.HUDFadeSpeed
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

    -- Find active contract where player is hitman
    local found = false
    if rHitman.getActiveContract() then
        self.ActiveContract = rHitman.getActiveContract()
        found = true
    end

    if not found and not self.CompletionState then
        self.FadeOutSpeed = rHitman.Config.HUDFadeSpeed
    end

    -- Update target info if we have a target
    if self.ActiveContract then
        self.FadeAlpha = math.min(255, self.FadeAlpha + 5)
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
    draw.RoundedBox(4, x, y, w, h, ColorAlpha(colors.shadow, alpha * 0.5))
    
    -- Progress
    local progress = math.Clamp(value / maxValue, 0, 1)
    draw.RoundedBox(4, x, y, w * progress, h, ColorAlpha(color, alpha))
end

function PANEL:Paint(w, h)
    -- If we're in completion state, draw the completion animation
    if self.CompletionState then
        -- Background
        draw.RoundedBoxEx(8, 0, 0, w, h, ColorAlpha(colors.background, self.FadeAlpha), false, false, true, true)
        
        -- Header background
        draw.RoundedBox(0, 0, 0, w, 40, ColorAlpha(colors.headerBg, self.FadeAlpha))
        
        -- Top border accent
        surface.SetDrawColor(ColorAlpha(endStates[self.CompletionState].color, self.FadeAlpha))
        surface.DrawRect(0, 0, w, 2)

        -- rHitman Header
        draw.SimpleText("rHitman", "rHitman.HUD.Header", w/2, 20, ColorAlpha(colors.highlight, self.FadeAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Animate completion message
        local messageY = Lerp(self.CompletionAnim, h + 40, h/2)
        local messageAlpha = Lerp(self.CompletionAnim, 0, 255)
        
        draw.SimpleText(endStates[self.CompletionState].message, "rHitman.HUD.Complete", 
            w/2, messageY, 
            ColorAlpha(endStates[self.CompletionState].color, messageAlpha * (self.FadeAlpha/255)), 
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
        return
    end

    if not self.ActiveContract then return end

    -- Main background with rounded bottom corners only
    draw.RoundedBoxEx(8, 0, 0, w, h, ColorAlpha(colors.background, self.FadeAlpha), false, false, true, true)
    
    -- Header background with no rounded corners
    draw.RoundedBox(0, 0, 0, w, 40, ColorAlpha(colors.headerBg, self.FadeAlpha))
    
    -- Top border accent
    surface.SetDrawColor(ColorAlpha(colors.highlight, self.FadeAlpha))
    surface.DrawRect(0, 0, w, 2)

    -- rHitman Header
    draw.SimpleText("rHitman", "rHitman.HUD.Header", w/2, 20, ColorAlpha(colors.highlight, self.FadeAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Target section
    draw.SimpleText("TARGET", "rHitman.HUD.Small", 15, 55, ColorAlpha(colors.subtext, self.FadeAlpha))
    draw.SimpleText(player.GetBySteamID64(self.ActiveContract.target):Nick(), "rHitman.HUD.Title", 15, 75, ColorAlpha(colors.text, self.FadeAlpha))

    -- Distance
    local distStr = string.format("Distance: %.1f meters", self.TargetDistance)
    draw.SimpleText(distStr, "rHitman.HUD.Small", w - 15, 55, ColorAlpha(colors.subtext, self.FadeAlpha), TEXT_ALIGN_RIGHT)

    -- Health and Armor bars
    local barWidth = w - 30
    local barHeight = 8

    -- Health Bar
    draw.SimpleText("Health", "rHitman.HUD.Small", 15, 105, ColorAlpha(colors.subtext, self.FadeAlpha))
    DrawBar(15, 125, barWidth, barHeight, self.HealthLerp, 100, colors.health, self.FadeAlpha)
    draw.SimpleText(math.Round(self.HealthLerp) .. "%", "rHitman.HUD.Small", w - 15, 122, ColorAlpha(colors.text, self.FadeAlpha), TEXT_ALIGN_RIGHT)

    -- Armor Bar
    draw.SimpleText("Armor", "rHitman.HUD.Small", 15, 140, ColorAlpha(colors.subtext, self.FadeAlpha))
    DrawBar(15, 160, barWidth, barHeight, self.ArmorLerp, 100, colors.armor, self.FadeAlpha)
    draw.SimpleText(math.Round(self.ArmorLerp) .. "%", "rHitman.HUD.Small", w - 15, 157, ColorAlpha(colors.text, self.FadeAlpha), TEXT_ALIGN_RIGHT)
end

-- Create HUD when needed
hook.Add("rHitman.ContractUpdated", "rHitman_UpdateHUD", function(contract)
    -- Check if we should create a new HUD
    if not IsValid(rHitman.HUD) then
        if contract.status == "active" and contract.hitman == LocalPlayer():SteamID64() then
            rHitman.HUD = vgui.Create("rHitman_HUD")
            rHitman.HUD.ActiveContract = contract
            print("[rHitman] Created new HUD for contract", contract.id) -- Debug
        end
        return
    end
    
    -- Update existing HUD
    if contract.hitman == LocalPlayer():SteamID64() then
        if contract.status == "active" then
            rHitman.HUD.ActiveContract = contract
            print("[rHitman] Updated HUD with contract", contract.id) -- Debug
        else
            rHitman.HUD:StartCompletion(contract.status)
            print("[rHitman] Starting completion for contract", contract.id, "with status", contract.status) -- Debug
        end
    end
end)

-- Cleanup on player death
hook.Add("PlayerDeath", "rHitman_CleanupHUD", function(victim)
    if victim == LocalPlayer() and IsValid(rHitman.HUD) then
        rHitman.HUD:StartCompletion("failed")
    end
end)

-- Register the panel
vgui.Register("rHitman_HUD", PANEL, "DPanel")
