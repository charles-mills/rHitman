--[[
    rHitman - Server Contracts
    Handles contract management and operations
]]--

-- Initialize contract table if not exists
rHitman.Contracts = rHitman.Contracts or {}

-- Contract status helpers
local function isValidStatus(status)
    return table.HasValue({"active", "completed", "failed", "cancelled", "expired"}, status)
end

-- Contract validation
local function validateContract(contract)
    if not contract then return false, "Invalid contract data" end
    if not contract.target then return false, "No target specified" end
    if not contract.reward then return false, "No reward specified" end
    if contract.reward < rHitman.Config.MinimumReward then return false, "Reward too low" end
    if contract.reward > rHitman.Config.MaximumReward then return false, "Reward too high" end
    return true
end

-- Create a new contract
function rHitman:CreateContract(contractor, target, reward, duration)
    if not IsValid(contractor) or not IsValid(target) then
        return false, "Invalid contractor or target"
    end
    
    -- Prevent self-contracts
    if contractor:SteamID64() == target:SteamID64() then
        return false, "Cannot place contract on yourself"
    end
    
    -- Create contract data
    local contract = {
        id = os.time() .. "_" .. contractor:SteamID64(),
        contractor = contractor:SteamID64(),
        target = target:SteamID64(),
        reward = reward,
        status = "active",
        timeCreated = os.time(),
        expireTime = duration and (os.time() + duration) or nil
    }
    
    -- Validate contract
    local valid, error = validateContract(contract)
    if not valid then
        return false, error
    end
    
    -- Store contract
    rHitman.Contracts[contract.id] = contract
    
    -- Notify relevant players
    DarkRP.notify(contractor, 0, 4, "Contract placed successfully!")
    
    -- Sync to clients
    rHitman:SyncContracts()
    
    return true, contract.id
end

-- Accept a contract
function rHitman:AcceptContract(contractId, hitman)
    local contract = rHitman.Contracts[contractId]
    if not contract then 
        print("[rHitman] Contract not found:", contractId)
        return false, "Contract not found" 
    end
    if not IsValid(hitman) then 
        print("[rHitman] Invalid hitman for contract:", contractId)
        return false, "Invalid hitman" 
    end
    
    -- Check if contract is still active
    if contract.status ~= "active" then
        print("[rHitman] Contract not active:", contractId, "Status:", contract.status)
        return false, "Contract is no longer active"
    end
    
    -- Prevent hitman from accepting contract on themselves
    if hitman:SteamID64() == contract.target then
        print("[rHitman] Self-contract attempt:", contractId)
        return false, "Cannot accept contract on yourself"
    end
    
    print("[rHitman] Accepting contract:", contractId, "for hitman:", hitman:Nick())
    
    -- Update contract
    contract.hitman = hitman:SteamID64()
    contract.timeAccepted = os.time()
    contract.status = "active" -- Ensure status is set
    
    -- Sync to clients (don't notify here, let networking handle it)
    rHitman:SyncContracts()
    
    return true
end

-- Complete a contract
function rHitman:CompleteContract(contractId, hitman)
    local contract = rHitman.Contracts[contractId]
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
    local contract = rHitman.Contracts[contractId]
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
    local contract = rHitman.Contracts[contractId]
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
    local contract = rHitman.Contracts[contractId]
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
    return rHitman.Contracts
end

-- Get active contracts for a player (as hitman)
function rHitman:GetActiveContractsForHitman(steamId)
    local activeContracts = {}
    for id, contract in pairs(rHitman.Contracts) do
        if contract.hitman == steamId and contract.status == "active" then
            activeContracts[id] = contract
        end
    end
    return activeContracts
end

-- Get contracts on a target
function rHitman:GetContractsOnTarget(steamId)
    local targetContracts = {}
    for id, contract in pairs(rHitman.Contracts) do
        if contract.target == steamId and contract.status == "active" then
            targetContracts[id] = contract
        end
    end
    return targetContracts
end
