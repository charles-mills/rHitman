--[[
    rHitman - Core Server Functions
    Handles system-level operations and permissions
]]--

rHitman = rHitman or {}
rHitman.Core = {
    -- System operations
    Initialize = function(self)
        -- Initialize hooks
        hook.Add("PlayerDeath", "rHitman_ContractCompletion", function(victim, inflictor, attacker)
            if not IsValid(victim) or not IsValid(attacker) or not attacker:IsPlayer() then return end
            
            -- Check all active contracts
            for id, contract in pairs(rHitman.Contracts.contracts) do
                if contract.status == "active" and contract.target == victim:SteamID64() then
                    if contract.hitman == attacker:SteamID64() then
                        -- Contract completed successfully
                        rHitman.Contracts:Complete(id, attacker)
                    else
                        -- Target killed by someone else
                        rHitman.Contracts:Fail(id, "Target killed by another player")
                    end
                end
            end
        end)
        
        hook.Add("PlayerDisconnected", "rHitman_ContractCleanup", function(ply)
            if not IsValid(ply) then return end
            local steamId = ply:SteamID64()
            
            -- Handle active contracts
            for id, contract in pairs(rHitman.Contracts.contracts) do
                if contract.status == "active" then
                    if contract.target == steamId then
                        rHitman.Contracts:Cancel(id, "Target disconnected")
                    elseif contract.hitman == steamId then
                        rHitman.Contracts:Fail(id, "Hitman disconnected")
                    end
                end
            end
        end)
        
        -- Track team changes for contract validation
        hook.Add("OnPlayerChangedTeam", "rHitman_TrackTeamChange", function(ply)
            ply.lastTeamChange = CurTime()
            
            -- Handle contracts when changing teams
            if not IsValid(ply) then return end
            local settings = rHitman.Config.getJobSettings(team.GetName(ply:Team()))
            local steamId = ply:SteamID64()
            
            -- Handle active contracts
            local contracts = rHitman.Contracts:GetAll()
            if contracts then
                for id, contract in pairs(contracts) do
                    if contract.status == "active" then
                        -- Cancel contracts if player can't use system
                        if not settings.canUseSystem and contract.contractor == steamId then
                            rHitman.Contracts:Cancel(id, "Contractor changed to restricted job")
                        end
                        
                        -- Fail contracts if player can't complete hits
                        if not settings.canCompleteHits and contract.hitman == steamId then
                            rHitman.Contracts:Cancel(id, "Hitman changed to non-hitman job")
                        end
                    end
                end
            end
        end)
    end,
    
    -- Permission checks
    CanUseSystem = function(self, ply)
        if not IsValid(ply) then return false end
        local settings = rHitman.Config.getJobSettings(team.GetName(ply:Team()))
        return settings.canUseSystem
    end,
    
    CanPlaceContract = function(self, ply)
        if not IsValid(ply) then return false end
        local settings = rHitman.Config.getJobSettings(team.GetName(ply:Team()))
        return settings.canPlaceContracts
    end,
    
    CanCompleteHits = function(self, ply)
        if not IsValid(ply) then return false end
        local settings = rHitman.Config.getJobSettings(team.GetName(ply:Team()))
        return settings.canCompleteHits
    end,
    
    -- Contract validation
    CanCompleteHit = function(self, ply, contract)
        if not IsValid(ply) or not contract then return false end
        
        -- Check if player is the target
        if contract.target == ply:SteamID64() then
            return false, "You cannot complete a hit on yourself"
        end
        
        -- Check if player is the contractor
        if contract.contractor == ply:SteamID64() then
            return false, "You cannot complete your own hit"
        end
        
        -- Check if player is a hitman
        if not self:CanCompleteHits(ply) then
            return false, "You are not authorized to complete hits"
        end
        
        -- Additional check for hits placed before becoming a hitman
        if contract.timeCreated and (contract.timeCreated > (ply.lastTeamChange or 0)) then
            return true
        else
            return false, "You cannot complete hits that existed before you became a hitman"
        end
    end
}

-- Initialize the system
hook.Add("Initialize", "rHitman_Init", function()
    rHitman.Core:Initialize()
end)
