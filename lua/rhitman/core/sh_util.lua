--[[
    rHitman - Shared Utilities
    Contains utility functions used by both server and client
]]--

rHitman.Util = rHitman.Util or {}

-- Network strings for notifications
if SERVER then
    util.AddNetworkString("rHitman_Notify")
end

-- Notification types
rHitman.NotifyType = {
    ERROR = 1,
    GENERIC = 0,
    HINT = 2
}

-- Format money value
function rHitman.Util.formatMoney(amount)
    return DarkRP.formatMoney(amount)
end

-- Format time duration (e.g. "2h 30m" or "45m 30s")
function rHitman.Util.formatDuration(seconds)
    if seconds <= 0 then return "Expired" end
    
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    else
        return string.format("%dm %ds", minutes, secs)
    end
end

-- Format time left for a contract
function rHitman.Util.formatTimeLeft(contract)
    if not contract then return "Invalid" end
    if contract.status ~= "active" then return contract.status end
    
    local expiryTime = contract.expireTime or (contract.timeCreated + (rHitman.Config.ContractDuration or 3600))
    local timeLeft = expiryTime - os.time()
    
    if timeLeft <= 0 then
        return "Expired"
    end
    
    return rHitman.Util.formatDuration(timeLeft)
end

-- Check if a player can use the hitman system
function rHitman.Util.canUseSystem(ply)
    if not IsValid(ply) then return false end
    
    -- Get team name and category
    local teamName = team.GetName(ply:Team())
    local category = DarkRP.getJobByCommand(RPExtraTeams[ply:Team()].command).category
    if not teamName then return false end
    
    -- Check if player's category is disallowed
    if rHitman.Config.DisallowedCategories[category] then
        return false
    end
    
    -- Check if player's team is disallowed
    if rHitman.Config.DisallowedTeams[teamName] then
        return false
    end
    
    -- Check for job overrides
    if rHitman.Config.JobOverrides[teamName] then
        return rHitman.Config.JobOverrides[teamName].canUseSystem
    end
    
    return rHitman.Config.DefaultCanUseSystem
end

-- Check if a player can place contracts
function rHitman.Util.canPlaceContracts(ply)
    if not IsValid(ply) then return false end
    
    -- First check if they can use the system at all
    if not rHitman.Util.canUseSystem(ply) then
        return false
    end
    
    -- Get team name
    local teamName = team.GetName(ply:Team())
    if not teamName then return false end
    
    -- Check cooldown
    local lastContract = ply:GetNWFloat("rHitman_LastContract", 0)
    local cooldownLeft = lastContract + rHitman.Config.ContractCooldown - CurTime()
    if cooldownLeft > 0 then
        return false, string.format("Please wait %.0f seconds before placing another contract", cooldownLeft)
    end
    
    -- Check for job overrides
    if rHitman.Config.JobOverrides[teamName] then
        if not rHitman.Config.JobOverrides[teamName].canPlaceContracts then
            return false, "Your job cannot place contracts"
        end
    elseif not rHitman.Config.DefaultCanPlaceContracts then
        return false, "Your job cannot place contracts"
    end
    
    return true
end

-- Check if a player can complete hits
function rHitman.Util.canCompleteHits(ply)
    if not IsValid(ply) then return false end
    
    -- Get job command
    local jobTable = RPExtraTeams[ply:Team()]
    if not jobTable then return false end
    
    -- Check if player is a hitman (this overrides all other restrictions)
    if rHitman.Config.HitmanJobs[jobTable.command] then
        return true
    end
    
    -- If not a hitman, check if they can use the system
    if not rHitman.Util.canUseSystem(ply) then
        return false
    end
    
    -- Check for job overrides
    local teamName = team.GetName(ply:Team())
    if rHitman.Config.JobOverrides[teamName] then
        return rHitman.Config.JobOverrides[teamName].canCompleteHits
    end
    
    return rHitman.Config.DefaultCanCompleteHits
end

-- Check if a player can see a specific contract
function rHitman.Util.canSeeContract(ply, contract)
    if not IsValid(ply) then return false end
    if not contract then return false end
    
    -- Admins can see all contracts
    if ply:IsAdmin() then return true end
    
    -- Players can see contracts they placed
    if contract.contractor == ply:SteamID64() then return true end
    
    -- Players can see contracts on them
    if contract.target == ply:SteamID64() then return true end
    
    -- Hitmen can see active contracts
    if rHitman.Util.canCompleteHits(ply) and contract.status == "active" then return true end
    
    -- Players can see contracts they've accepted
    if contract.hitman == ply:SteamID64() then return true end
    
    return false
end

-- Send notification to player
function rHitman.Util.notify(ply, message, notifyType)
    notifyType = notifyType or rHitman.NotifyType.GENERIC
    
    if SERVER then
        if IsValid(ply) then
            net.Start("rHitman_Notify")
            net.WriteString(message)
            net.WriteUInt(notifyType, 3)
            net.Send(ply)
        end
    else
        -- Play sound based on notification type
        local sound = "buttons/button15.wav"
        if notifyType == rHitman.NotifyType.ERROR then
            sound = "buttons/button10.wav"
        elseif notifyType == rHitman.NotifyType.HINT then
            sound = "buttons/button17.wav"
        end
        
        -- Add chat message
        chat.AddText(Color(255, 200, 0), "[rHitman] ", Color(255, 255, 255), message)
        
        -- Play sound
        surface.PlaySound(sound)
    end
end

-- Register client-side notification receiver
if CLIENT then
    net.Receive("rHitman_Notify", function()
        local message = net.ReadString()
        local notifyType = net.ReadUInt(3)
        rHitman.Util.notify(nil, message, notifyType)
    end)
end

-- Validate contract price
function rHitman.Util.validatePrice(price)
    return price and 
           type(price) == "number" and 
           price >= rHitman.Config.MinimumHitPrice and 
           price <= rHitman.Config.MaximumHitPrice
end

-- Generate a unique contract ID
function rHitman.Util.generateContractID()
    return os.time() .. "_" .. math.random(1000, 9999)
end

-- Get contract status text
function rHitman.Util.getStatusText(contract)
    if not contract then return "Invalid" end
    
    local status = contract.status or "unknown"
    local timeLeft = ""
    
    if status == "active" then
        timeLeft = " (" .. rHitman.Util.formatTimeLeft(contract) .. ")"
    end
    
    return string.upper(status) .. timeLeft
end

-- Get contract color based on status
function rHitman.Util.getStatusColor(contract)
    if not contract then return Color(200, 200, 200) end
    
    local status = contract.status or "unknown"
    local colors = {
        active = Color(50, 255, 50),
        completed = Color(50, 150, 255),
        failed = Color(255, 50, 50),
        cancelled = Color(255, 150, 50),
        expired = Color(150, 150, 150)
    }
    
    return colors[status] or Color(200, 200, 200)
end
