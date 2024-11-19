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
    function CONTRACTS:Create(contractor, target, reward, description, isAnonymous)
        if not isAnonymous then
            -- Validate contract placement for non-anonymous contracts
            local canPlace, reason = rHitman.Util.canPlaceContract(contractor, target, reward)
            if not canPlace then return false, reason end
        else
            -- Basic validation for anonymous contracts
            if not target then return false, "Invalid target" end
            local success, msg = rHitman.Util.validateReward(reward)
            if not success then return false, msg end
        end
        
        -- Generate contract ID and data
        local contractorID = isAnonymous and "ANONYMOUS" or contractor:SteamID64()
        local targetID = target:SteamID64()
        local id = rHitman.Util.generateContractID()
        
        local contract = {
            id = id,
            contractor = contractorID,
            contractorName = isAnonymous and "Anonymous" or string.sub(contractor:Nick(), 1, 32),
            target = targetID,
            targetName = string.sub(target:Nick(), 1, 32),
            targetJob = string.sub(team.GetName(target:Team()), 1, 32),
            reward = reward,
            description = description or "",
            status = "active",
            created = os.time(),
            expires = os.time() + rHitman.Config.ContractDuration,
            isAnonymous = isAnonymous,
            premium = isAnonymous and reward == rHitman.Config.randomHitsPremiumPayout or false,
            paid = isAnonymous or rHitman.Config.PaymentOnCompletion == false
        }
        
        -- Take payment if configured and not anonymous
        if not isAnonymous and not rHitman.Config.PaymentOnCompletion then
            contractor:addMoney(-reward)
        end
        
        -- Store contract
        contractCache[id] = contract
        
        -- Notify hitmen if enabled
        if rHitman.Config.NotifyHitmanNewContract then
            for _, ply in ipairs(player.GetAll()) do
                if rHitman.Core:CanCompleteHits(ply) and (not contractor or ply != contractor) then
                    rHitman.Util.notify(ply, "A new contract worth " .. rHitman.Util.formatCurrency(reward) .. " is available!", NOTIFY_HINT)
                end
            end
        end
        
        -- Run hook
        hook.Run("rHitman.ContractCreated", contract)
        
        return true, id
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
        return contractCache
    end
    
    function CONTRACTS:GetContract(id)
        return contractCache[id]
    end
    
    function CONTRACTS:GetActiveContracts()
        local active = {}
        for id, contract in pairs(contractCache) do
            if contract.status == "active" then
                active[id] = contract
            end
        end
        return active
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
