--[[
    rHitman - Server Contracts
    Handles all contract-related operations and storage
]]--

rHitman = rHitman or {}
rHitman.Contracts = {
    contracts = {},
    
    -- Money handling helpers
    HandleMoney = function(self, ply, amount, isAdd)
        if not IsValid(ply) or not isnumber(amount) then return false end
        if amount < 0 then return false end
        
        if isAdd then
            return ply:addMoney(amount)
        else
            if not ply:canAfford(amount) then return false end
            return ply:addMoney(-amount)
        end
    end,
    
    -- Validation helpers
    ValidatePrice = function(self, price, isAnonymous)
        if not isnumber(price) then return false end
        if isAnonymous then return true end -- Skip price validation for anonymous contracts
        return price >= rHitman.Config.MinimumHitPrice and price <= rHitman.Config.MaximumHitPrice
    end,
    
    ValidateContract = function(self, contract)
        if not contract then return false, "Invalid contract data" end
        if not contract.target then return false, "No target specified" end
        if not contract.price then return false, "No price specified" end
        if not self:ValidatePrice(contract.price, contract.contractor == "ANONYMOUS") then 
            return false, "Invalid price amount" 
        end
        return true
    end,
    
    -- Core operations
    Create = function(self, contractor, target, price, description, isAnonymous)
        if not isAnonymous and not IsValid(contractor) then 
            return false, "Invalid contractor" 
        end
        if not IsValid(target) then 
            return false, "Invalid target" 
        end
        
        if not isAnonymous then
            if not rHitman.Core:CanPlaceContract(contractor) then
                return false, "You are not authorized to place contracts"
            end
            
            if contractor:SteamID64() == target:SteamID64() then
                return false, "You cannot place a contract on yourself"
            end
            
            -- Take payment if configured
            if not rHitman.Config.PaymentOnCompletion then
                if not self:HandleMoney(contractor, price, false) then
                    return false, "Insufficient funds"
                end
            end
        end
        
        -- Generate contract ID
        local contractId = os.time() .. "_" .. math.random(10000, 99999)
        
        -- Create contract data
        local contract = {
            id = contractId,
            contractor = isAnonymous and "ANONYMOUS" or contractor:SteamID64(),
            contractorName = isAnonymous and "Anonymous" or contractor:Nick(),
            target = target:SteamID64(),
            targetName = target:Nick(),
            targetJob = target:getDarkRPVar("job") or "Unknown",
            price = price,
            reward = price, -- Add reward field for compatibility
            description = description,
            status = "active",
            timeCreated = os.time(),
            timeExpires = os.time() + rHitman.Config.ContractDuration,
            hitman = nil,
            hitmanName = nil,
            evidence = nil,
            paid = true, -- Anonymous contracts are always pre-paid
            premium = isAnonymous and description == "PREMIUM" or false -- Mark premium hits
        }
        
        -- Store contract
        self.contracts[contractId] = contract
        
        -- Set cooldown
        if not isAnonymous then
            contractor:SetNWFloat("rHitman_LastContract", CurTime())
        end
        
        -- Notify hitmen if enabled
        if rHitman.Config.NotifyHitmanNewContract then
            for _, ply in ipairs(player.GetAll()) do
                if rHitman.Core:CanCompleteHits(ply) and ply != contractor then
                    rHitman.Util.notify(ply, "A new contract worth " .. rHitman.Util.formatCurrency(price) .. " is available!", NOTIFY_HINT)
                end
            end
        end
        
        -- Run hook
        hook.Run("rHitman.ContractCreated", contract)
        
        return true, contractId
    end,
    
    Accept = function(self, contractId, hitman)
        local contract = self.contracts[contractId]
        if not contract then return false, "Contract not found" end
        if not IsValid(hitman) then return false, "Invalid hitman" end
        
        -- Verify contract status
        if contract.status ~= "active" then
            return false, "Contract is not active"
        end
        
        -- Verify hitman is not the target or contractor
        if contract.target == hitman:SteamID64() then
            return false, "You cannot accept a contract on yourself"
        end
        if contract.contractor == hitman:SteamID64() then
            return false, "You cannot accept your own contract"
        end
        
        -- Check if hitman can accept contract
        if not rHitman.canAcceptContract(hitman, contract) then
            return false, "You cannot accept this contract"
        end
        
        -- Accept the contract
        contract.hitman = hitman:SteamID64()
        contract.hitmanName = hitman:Nick()
        contract.timeAccepted = os.time()
        
        -- Notify relevant players
        local contractor = player.GetBySteamID64(contract.contractor)
        if IsValid(contractor) then
            rHitman.Util.notify(contractor, hitman:Nick() .. " has accepted your contract on " .. contract.targetName, NOTIFY_GENERIC)
        end
        
        -- Run hook
        hook.Run("rHitman.ContractAccepted", contract, hitman)
        
        return true
    end,
    
    Complete = function(self, contractId, hitman, evidence)
        local contract = self.contracts[contractId]
        if not contract then return false, "Contract not found" end
        if not IsValid(hitman) then return false, "Invalid hitman" end
        
        if not rHitman.Core:CanCompleteHits(hitman) then
            return false, "You are not authorized to complete contracts"
        end
        
        if contract.status ~= "active" then
            return false, "Contract is not active"
        end
        
        -- Handle payment
        if rHitman.Config.PaymentOnCompletion then
            local contractor = player.GetBySteamID64(contract.contractor)
            if not IsValid(contractor) then
                return false, "Contractor not found"
            end
            
            if not self:HandleMoney(contractor, contract.price, false) then
                return false, "Contractor cannot afford the contract"
            end
        end
        
        -- Pay the hitman
        if not self:HandleMoney(hitman, contract.price, true) then
            -- If payment fails and we took money from contractor, refund them
            if rHitman.Config.PaymentOnCompletion then
                local contractor = player.GetBySteamID64(contract.contractor)
                if IsValid(contractor) then
                    self:HandleMoney(contractor, contract.price, true)
                end
            end
            return false, "Failed to pay hitman"
        end
        
        -- Update contract
        contract.status = "completed"
        contract.evidence = evidence
        contract.timeCompleted = os.time()
        
        -- Run hook
        hook.Run("rHitman.ContractCompleted", contract)
        
        return true
    end,
    
    Fail = function(self, contractId, reason)
        local contract = self.contracts[contractId]
        if not contract then return false, "Contract not found" end
        
        if rHitman.Config.ReturnFailedHitsToPool then
            -- Reset hitman and return to pool
            contract.hitman = nil
            contract.hitmanName = nil
            contract.status = "active"
            contract.timeAccepted = nil
        else
            -- Remove contract entirely
            contract.status = "failed"
            contract.failReason = reason
            contract.timeEnded = os.time()
        end
        
        -- Notify relevant players
        local contractor = player.GetBySteamID64(contract.contractor)
        if IsValid(contractor) then
            rHitman.Util.notify(contractor, "Contract " .. (rHitman.Config.ReturnFailedHitsToPool and "returned to pool" or "failed") .. ": " .. reason, NOTIFY_ERROR)
        end
        
        -- Run hook
        hook.Run("rHitman.ContractFailed", contract, reason)
        
        return true
    end,
    
    Cancel = function(self, contractId, reason)
        local contract = self.contracts[contractId]
        if not contract then return false, "Contract not found" end
        
        contract.status = "cancelled"
        contract.cancelReason = reason
        contract.timeEnded = os.time()
        
        -- Refund if payment was made upfront
        if not rHitman.Config.PaymentOnCompletion then
            local contractor = player.GetBySteamID64(contract.contractor)
            if IsValid(contractor) then
                self:HandleMoney(contractor, contract.price, true)
            end
        end
        
        -- Run hook
        hook.Run("rHitman.ContractCancelled", contract, reason)
        
        return true
    end,
    
    Expire = function(self, contractId)
        local contract = self.contracts[contractId]
        if not contract then return false, "Contract not found" end
        
        contract.status = "expired"
        contract.timeEnded = os.time()
        
        -- Refund if payment was made upfront
        if not rHitman.Config.PaymentOnCompletion then
            local contractor = player.GetBySteamID64(contract.contractor)
            if IsValid(contractor) then
                self:HandleMoney(contractor, contract.price, true)
            end
        end
        
        -- Run hook
        hook.Run("rHitman.ContractExpired", contract)
        
        return true
    end,
    
    -- Contract getters
    GetContract = function(self, contractId)
        return self.contracts[contractId]
    end,
    
    GetActiveContractsForHitman = function(self, hitmanId)
        local active = {}
        for id, contract in pairs(self.contracts) do
            if contract.hitman == hitmanId and contract.status == "active" then
                active[id] = table.Copy(contract)
            end
        end
        return active
    end,
    
    -- Queries
    GetAll = function(self)
        local contracts = {}
        for id, contract in pairs(self.contracts) do
            -- Deep copy the contract
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
            
            contracts[id] = contractCopy
        end
        return contracts
    end,
    
    GetActive = function(self)
        local active = {}
        for id, contract in pairs(self.contracts) do
            if contract.status == "active" then
                active[id] = table.Copy(contract)
            end
        end
        return active
    end,
    
    GetForHitman = function(self, steamID64)
        local hitmanContracts = {}
        for id, contract in pairs(self.contracts) do
            if contract.hitman == steamID64 then
                hitmanContracts[id] = table.Copy(contract)
            end
        end
        return hitmanContracts
    end,
    
    GetForContractor = function(self, steamID64)
        local contractorContracts = {}
        for id, contract in pairs(self.contracts) do
            if contract.contractor == steamID64 then
                contractorContracts[id] = table.Copy(contract)
            end
        end
        return contractorContracts
    end
}

-- Check if a player can accept a contract
function rHitman.canAcceptContract(ply, contract)
    if not IsValid(ply) then return false, "Invalid player" end
    if not contract then return false, "Invalid contract" end
    
    -- Check if player is a hitman
    if not rHitman.Util.isHitman(ply) then
        return false, "You must be a hitman to accept contracts"
    end
    
    -- Check if contract is premium and player has permission
    if contract.premium and not rHitman.Util.canAcceptPremiumHits(ply) then
        return false, "You don't have permission to accept premium contracts"
    end
    
    -- Check if hitman already has max contracts
    local activeCount = 0
    for _, c in pairs(rHitman.Contracts.contracts) do
        if c.hitman == ply:SteamID64() then
            activeCount = activeCount + 1
        end
    end
    if activeCount >= rHitman.Config.MaxActiveContractsPerHitman then
        return false, "You already have the maximum number of active contracts"
    end
    
    return true
end

-- Initialize hooks
hook.Add("Initialize", "rHitman_ContractsInit", function()
    -- Check for expired contracts periodically
    timer.Create("rHitman_ContractExpiration", 60, 0, function()
        local currentTime = os.time()
        for id, contract in pairs(rHitman.Contracts.contracts) do
            if contract.status == "active" and contract.timeExpires and currentTime >= contract.timeExpires then
                rHitman.Contracts:Expire(id)
            end
        end
    end)
end)
