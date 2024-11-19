--[[
    rHitman - Server Contracts
    Handles contract management and operations
]]--

-- Initialize contract table if not exists
rHitman = rHitman or {}
rHitman.Contracts = rHitman.Contracts or {}
rHitman.Contracts.contracts = rHitman.Contracts.contracts or {}

-- Get all contracts
rHitman.Contracts.GetAll = function(self)
    local contracts = {}
    -- Debug print
    print("[rHitman] Getting all contracts, count:", table.Count(self.contracts))
    for id, contract in pairs(self.contracts) do
        print("[rHitman] Found contract:", id)
        
        -- Deep copy the contract to prevent reference issues
        local contractCopy = table.Copy(contract)
        
        -- Update names if players are still on server
        local contractorPly = player.GetBySteamID64(contractCopy.contractor)
        if IsValid(contractorPly) then
            contractCopy.contractorName = contractorPly:Nick()
        end
        
        local targetPly = player.GetBySteamID64(contractCopy.target)
        if IsValid(targetPly) then
            contractCopy.targetName = targetPly:Nick()
            contractCopy.targetJob = targetPly:getDarkRPVar("job") or "Unknown"
        end
        
        -- Store with ID as key
        contracts[id] = contractCopy
    end
    return contracts
end

-- Get specific contract
rHitman.Contracts.GetContract = function(self, id)
    local contract = self.contracts[id]
    if contract then
        -- Deep copy the contract
        contract = table.Copy(contract)
        
        -- Update names
        local contractorPly = player.GetBySteamID64(contract.contractor)
        if IsValid(contractorPly) then
            contract.contractorName = contractorPly:Nick()
        end
        
        local targetPly = player.GetBySteamID64(contract.target)
        if IsValid(targetPly) then
            contract.targetName = targetPly:Nick()
            contract.targetJob = targetPly:getDarkRPVar("job") or "Unknown"
        end
    end
    return contract
end

-- Get active contracts for hitman
rHitman.Contracts.GetActiveContractsForHitman = function(self, steamID64)
    local active = {}
    for _, contract in pairs(self.contracts) do
        if contract.hitman == steamID64 and contract.status == "active" then
            table.insert(active, contract)
        end
    end
    return active
end

-- Create contract
rHitman.Contracts.Create = function(self, contractor, target, reward, duration)
    if not IsValid(contractor) or not IsValid(target) then
        return false, "Invalid contractor or target"
    end
    
    -- Prevent self-contracts
    if contractor:SteamID64() == target:SteamID64() then
        return false, "Cannot place contract on yourself"
    end
    
    -- Generate contract ID
    local contractId = os.time() .. "_" .. math.random(10000, 99999) .. "_" .. string.format("%04d", math.random(0, 9999))
    
    -- Create contract data
    local contract = {
        id = contractId,
        contractor = contractor:SteamID64(),
        contractorName = contractor:Nick(),
        target = target:SteamID64(),
        targetName = target:Nick(),
        targetJob = target:getDarkRPVar("job") or "Unknown",
        reward = reward,
        status = "active",
        created = os.time(),
        expires = duration and (os.time() + duration) or nil
    }
    
    -- Store contract
    self.contracts[contractId] = contract
    
    -- Print debug info
    print("[rHitman] Created contract:", contractId)
    print("[rHitman] Contract count:", table.Count(self.contracts))
    
    -- Notify players
    hook.Run("rHitman.ContractCreated", contract)
    
    return true, contractId
end

-- Contract status helpers
local function isValidStatus(status)
    return table.HasValue({"active", "completed", "failed", "cancelled", "expired"}, status)
end

-- Contract validation
local function validateContract(contract)
    if not contract then return false, "Invalid contract data" end
    if not contract.target then return false, "No target specified" end
    if not contract.reward then return false, "No reward specified" end
    if contract.reward < rHitman.Config.MinimumHitPrice then return false, "Reward too low" end
    if contract.reward > rHitman.Config.MaximumHitPrice then return false, "Reward too high" end
    return true
end

-- Helper function to count active contracts for a player
local function countActiveContracts(steamID64, asHitman)
    local count = 0
    for _, contract in pairs(rHitman.Contracts.contracts) do
        if contract.status == "active" then
            if asHitman then
                if contract.hitman == steamID64 then
                    count = count + 1
                end
            else
                if contract.contractor == steamID64 then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- Accept a contract
function rHitman:AcceptContract(contractId, hitman)
    if not self.Contracts then self.Contracts = {} end
    if not self.Contracts.contracts then self.Contracts.contracts = {} end
    
    local contract = self.Contracts.contracts[contractId]
    if not contract then 
        print("[rHitman] Contract not found:", contractId)
        return false, "Contract not found" 
    end
    if not IsValid(hitman) then 
        return false, "Invalid hitman" 
    end
    
    -- Verify contract status
    if contract.status ~= "active" then
        return false, "Contract is not active"
    end
    
    -- Verify hitman is not the target
    if contract.target == hitman:SteamID64() then
        return false, "You cannot accept a contract on yourself"
    end
    
    -- Verify hitman is not the contractor
    if contract.contractor == hitman:SteamID64() then
        return false, "You cannot accept your own contract"
    end
    
    -- Check if hitman has too many active contracts
    local activeCount = 0
    for _, c in pairs(self.Contracts.contracts) do
        if c.hitman == hitman:SteamID64() and c.status == "active" then
            activeCount = activeCount + 1
        end
    end
    
    if activeCount >= (rHitman.Config.MaxActiveContractsPerHitman or 1) then
        return false, "You have too many active contracts"
    end
    
    -- Accept the contract
    contract.hitman = hitman:SteamID64()
    contract.hitmanName = hitman:Nick()
    contract.acceptedAt = os.time()
    
    -- Notify relevant players
    local contractor = player.GetBySteamID64(contract.contractor)
    if IsValid(contractor) then
        DarkRP.notify(contractor, 0, 4, hitman:Nick() .. " has accepted your contract on " .. contract.targetName)
    end
    
    -- Run hook
    hook.Run("rHitman.ContractAccepted", contract, hitman)
    
    -- Sync contract update to all clients
    net.Start("rHitman_ContractUpdate")
    net.WriteString(contractId)
    net.WriteString("accepted")
    net.WriteString(hitman:SteamID64())
    net.WriteString(hitman:Nick())
    net.Broadcast()
    
    return true
end

-- Complete a contract
function rHitman:CompleteContract(contractId, hitman)
    local contract = rHitman.Contracts.contracts[contractId]
    if not contract then return false, "Contract not found" end
    if not IsValid(hitman) then return false, "Invalid hitman" end
    
    -- Verify hitman
    if contract.hitman ~= hitman:SteamID64() then
        return false, "Not your contract"
    end
    
    -- Update contract
    contract.status = "completed"
    contract.timeCompleted = os.time()
    
    -- Pay the hitman
    hitman:addMoney(contract.reward)
    
    -- Sync to clients
    rHitman:SyncContracts()
    
    return true
end

-- Cancel a contract
function rHitman:CancelContract(contractId, reason)
    local contract = rHitman.Contracts.contracts[contractId]
    if not contract then return false, "Contract not found" end
    
    -- Update contract
    contract.status = "cancelled"
    contract.timeCancelled = os.time()
    contract.cancelReason = reason
    
    -- Notify players
    local hitman = Player(contract.hitman)
    if IsValid(hitman) then
        DarkRP.notify(hitman, 1, 4, "Contract cancelled: " .. reason)
    end
    
    -- Sync to clients
    rHitman:SyncContracts()
    
    return true
end

-- Fail a contract
function rHitman:FailContract(contractId, reason)
    local contract = rHitman.Contracts.contracts[contractId]
    if not contract then return false, "Contract not found" end
    
    -- Update contract
    contract.status = "failed"
    contract.timeFailed = os.time()
    contract.failReason = reason
    
    -- Notify players
    local contractor = Player(contract.contractor)
    if IsValid(contractor) then
        DarkRP.notify(contractor, 1, 4, "Contract failed: " .. reason)
    end
    
    -- Sync to clients
    rHitman:SyncContracts()
    
    return true
end

-- Expire a contract
function rHitman:ExpireContract(contractId)
    local contract = rHitman.Contracts.contracts[contractId]
    if not contract then return false, "Contract not found" end
    
    -- Update contract
    contract.status = "expired"
    contract.timeExpired = os.time()
    
    -- Sync to clients
    rHitman:SyncContracts()
    
    return true
end

-- Get all contracts
function rHitman:GetContracts()
    return rHitman.Contracts.GetAll(rHitman.Contracts)
end

-- Get active contracts for a player (as hitman)
function rHitman:GetActiveContractsForHitman(steamId)
    return rHitman.Contracts.GetActiveContractsForHitman(rHitman.Contracts, steamId)
end

-- Get contracts on a target
function rHitman:GetContractsOnTarget(steamId)
    local targetContracts = {}
    for id, contract in pairs(rHitman.Contracts.contracts) do
        if contract.target == steamId and contract.status == "active" then
            targetContracts[id] = contract
        end
    end
    return targetContracts
end

-- End a contract with a specific result
function rHitman.Contracts:EndContract(contract, result)
    if not contract then return end
    
    print("[rHitman] Ending contract", contract.id, "with result:", result)
    
    -- Update contract status based on result
    contract.status = result
    contract.completedAt = os.time()
    
    -- Update the contract in the main contracts table
    self.contracts[contract.id] = contract
    
    -- Get hitman player
    local hitman = player.GetBySteamID64(contract.hitman)
    if IsValid(hitman) then
        -- Pay the hitman if successful
        if result == "completed" then
            hitman:addMoney(contract.reward)
            DarkRP.notify(hitman, 0, 6, "Contract completed! You earned " .. rHitman.Config.CurrencySymbol .. contract.reward)
        else
            DarkRP.notify(hitman, 1, 6, "Contract failed!")
        end
    end
    
    -- Notify contractor
    local contractor = player.GetBySteamID64(contract.contractor)
    if IsValid(contractor) then
        if result == "completed" then
            DarkRP.notify(contractor, 0, 6, "Your contract has been completed by " .. contract.hitmanName)
        else
            DarkRP.notify(contractor, 1, 6, "Your contract has failed!")
            -- Refund the contractor if the contract failed
            contractor:addMoney(contract.reward)
        end
    end
    
    -- Sync the updated contract to all clients
    net.Start("rHitman_ContractUpdate")
    net.WriteString(contract.id)
    net.WriteString(contract.status)
    net.WriteString(contract.hitman or "")
    net.WriteString(contract.hitmanName or "")
    net.Broadcast()
    
    -- Run contract ended hook
    hook.Run("rHitman_ContractEnded", contract)
end

-- Hook for when a player dies
hook.Add("PlayerDeath", "rHitman_ContractEndConditions", function(victim, inflictor, attacker)
    -- Get all active contracts
    for id, contract in pairs(rHitman.Contracts:GetAll()) do
        if contract.status ~= "active" then continue end
        
        -- Check if target died
        if victim:SteamID64() == contract.target then
            -- If killed by the hitman, complete the contract
            if IsValid(attacker) and attacker:IsPlayer() and attacker:SteamID64() == contract.hitman then
                rHitman.Contracts:EndContract(rHitman.Contracts.contracts[id], "completed")
            else
                -- Target died but not by hitman
                rHitman.Contracts:EndContract(rHitman.Contracts.contracts[id], "failed")
            end
        end
        
        -- Check if hitman died (if enabled in config)
        if rHitman.Config.EndOnHitmanDeath and victim:SteamID64() == contract.hitman then
            rHitman.Contracts:EndContract(rHitman.Contracts.contracts[id], "failed")
        end
    end
end)

-- Hook for when a contract is accepted
hook.Add("rHitman_ContractAccepted", "rHitman_ContractTimer", function(contract)
    -- Start timer for contract expiration
    timer.Create("rHitman_ContractTimer_" .. contract.id, rHitman.Config.ContractTimeLimit, 1, function()
        -- Check if contract is still active
        contract = rHitman.Contracts:GetContract(contract.id)
        if contract and contract.status == "active" then
            rHitman.Contracts:EndContract(contract, "expired")
        end
    end)
end)

-- Hook for when a contract ends
hook.Add("rHitman_ContractEnded", "rHitman_CleanupTimer", function(contract)
    -- Clean up the timer
    if timer.Exists("rHitman_ContractTimer_" .. contract.id) then
        timer.Remove("rHitman_ContractTimer_" .. contract.id)
    end
end)
