--[[
    rHitman - Server Hooks
    Handles automatic contract completion and cleanup
]]--

-- Handle contract completion when target dies
hook.Add("PlayerDeath", "rHitman_ContractCompletion", function(victim, inflictor, attacker)
    if not IsValid(victim) or not IsValid(attacker) or not attacker:IsPlayer() then return end
    
    -- Check all active contracts
    for contractId, contract in pairs(rHitman.Contracts) do
        if contract.status == "active" and contract.target == victim:SteamID64() and contract.hitman == attacker:SteamID64() then
            local success, err = rHitman:CompleteContract(contractId, attacker)
            
            if success then
                DarkRP.notify(attacker, 0, 4, "Contract completed successfully!")
                DarkRP.notify(victim, 1, 4, "You were eliminated by a hitman!")
            else
                DarkRP.notify(attacker, 1, 4, "Failed to complete contract: " .. (err or "Unknown error"))
            end
        end
    end
end)

-- Clean up contracts when players disconnect
hook.Add("PlayerDisconnected", "rHitman_ContractCleanup", function(ply)
    if not IsValid(ply) then return end
    
    local steamId = ply:SteamID64()
    
    -- Check all contracts
    for contractId, contract in pairs(rHitman.Contracts) do
        -- Cancel contracts where the disconnected player is the target
        if contract.status == "active" and contract.target == steamId then
            local success = rHitman:CancelContract(contractId, "Target disconnected")
            if not success then
                ErrorNoHalt("[rHitman] Failed to cancel contract " .. contractId .. " after target disconnect\n")
            end
        end
        
        -- Fail contracts where the disconnected player is the hitman
        if contract.status == "active" and contract.hitman == steamId then
            local success = rHitman:FailContract(contractId, "Hitman disconnected")
            if not success then
                ErrorNoHalt("[rHitman] Failed to fail contract " .. contractId .. " after hitman disconnect\n")
            end
        end
    end
end)

-- Handle contract expiration
timer.Create("rHitman_ContractExpiration", 60, 0, function()
    local currentTime = os.time()
    
    -- Check all contracts
    for contractId, contract in pairs(rHitman.Contracts) do
        if contract.status == "active" and contract.expireTime and currentTime >= contract.expireTime then
            local success = rHitman:ExpireContract(contractId)
            
            -- Notify relevant players
            if success then
                local hitman = Player(contract.hitman)
                if IsValid(hitman) then
                    DarkRP.notify(hitman, 1, 4, "Your contract has expired!")
                end
            else
                ErrorNoHalt("[rHitman] Failed to expire contract " .. contractId .. "\n")
            end
        end
    end
end)
