--[[
    rHitman - Shared Contract Management
    Centralized contract handling for both client and server
]]--

rHitman = rHitman or {}
rHitman.Contracts = rHitman.Contracts or {}

-- Contract cache
local contractCache = {}

-- Initialize contract functions
local CONTRACTS = rHitman.Contracts

if SERVER then
    -- Server-side contract management
    function CONTRACTS:Create(contractor, target, reward)
        if not IsValid(contractor) or not target then return false, "Invalid contractor or target" end
        if not isnumber(reward) or reward <= 0 then return false, "Invalid reward amount" end
        
        -- Sanitize and validate inputs
        local contractorID = contractor:SteamID64()
        local targetID = target:SteamID64()
        if not contractorID or not targetID then return false, "Invalid Steam IDs" end
        
        -- Generate a unique ID using timestamp and random number
        local id = os.time() .. "_" .. math.random(10000, 99999) .. "_" .. string.sub(contractorID, -4)
        
        local contract = {
            id = id,
            contractor = contractorID,
            contractorName = string.sub(contractor:Nick(), 1, 32),  -- Limit name length
            target = targetID,
            targetName = string.sub(target:Nick(), 1, 32),
            targetJob = string.sub(team.GetName(target:Team()), 1, 32),
            reward = math.Clamp(reward, rHitman.Config.MinimumHitPrice, rHitman.Config.MaximumHitPrice),
            status = "active",
            created = os.time(),
            expires = os.time() + rHitman.Config.ContractDuration
        }
        
        print("[rHitman] Creating contract:", contract.id)
        contractCache[contract.id] = contract
        return true, contract.id
    end
    
    function CONTRACTS:GetContract(id)
        return contractCache[id]
    end
    
    function CONTRACTS:GetAll()
        local contracts = {}
        for id, contract in pairs(contractCache) do
            contracts[id] = contract
        end
        return contracts
    end
    
    function CONTRACTS:GetActiveContractsForHitman(steamID)
        local contracts = {}
        for id, contract in pairs(contractCache) do
            if contract.status == "active" and contract.hitman == steamID then
                contracts[id] = contract
            end
        end
        return contracts
    end
    
    function CONTRACTS:GetActiveContractsForTarget(steamID)
        local contracts = {}
        for id, contract in pairs(contractCache) do
            if contract.status == "active" and contract.target == steamID then
                contracts[id] = contract
            end
        end
        return contracts
    end
    
    function CONTRACTS:UpdateContract(id, data)
        if not contractCache[id] then return false, "Contract not found" end
        for k, v in pairs(data) do
            contractCache[id][k] = v
        end
        return true
    end
    
    function CONTRACTS:RemoveContract(id)
        contractCache[id] = nil
        return true
    end
    
    function CONTRACTS:Cancel(contractId)
        local contract = contractCache[contractId]
        if contract and contract.status == "active" then
            contract.status = "cancelled"
            contract.cancelTime = os.time()
            return true
        end
        return false
    end
    
    function CONTRACTS:Complete(contractId, hitman)
        if not IsValid(hitman) then return false end
        
        local contract = contractCache[contractId]
        if contract and contract.status == "active" then
            contract.status = "completed"
            contract.hitman = hitman:SteamID64()
            contract.hitmanName = string.sub(hitman:Nick(), 1, 32)
            contract.completeTime = os.time()
            return true
        end
        return false
    end
else
    -- Client-side contract cache
    function CONTRACTS:UpdateCache(contracts)
        -- Validate incoming data
        if not istable(contracts) then return end
        
        -- Clear existing cache
        table.Empty(contractCache)
        
        -- Update cache with new contracts
        for id, contract in pairs(contracts) do
            contractCache[id] = contract
        end
        
        print("[rHitman] Updated contract cache:", table.Count(contractCache), "contracts")
    end
    
    function CONTRACTS:GetAll()
        local contracts = {}
        for id, contract in pairs(contractCache) do
            contracts[id] = contract
        end
        return contracts
    end
    
    function CONTRACTS:GetContract(id)
        return contractCache[id]
    end
    
    function CONTRACTS:ValidateContract(contract)
        if not istable(contract) then return false end
        
        -- Required fields
        local required = {"id", "contractor", "target", "reward", "status"}
        for _, field in ipairs(required) do
            if not contract[field] then return false end
        end
        
        -- Type checking
        if not isstring(contract.id) then return false end
        if not isstring(contract.contractor) then return false end
        if not isstring(contract.target) then return false end
        if not isnumber(contract.reward) then return false end
        if not isstring(contract.status) then return false end
        
        return true
    end
end

-- Shared functions
function CONTRACTS:FormatContract(contract)
    if not contract then return nil end
    
    -- Get current player info if available
    local target = player.GetBySteamID64(contract.target)
    if IsValid(target) then
        contract.targetName = target:Nick()
        contract.targetJob = team.GetName(target:Team())
    end
    
    return contract
end
