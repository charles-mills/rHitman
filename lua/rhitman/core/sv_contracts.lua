--[[
    rHitman - Server Contracts
    Handles all contract-related operations and storage
]]--

rHitman = rHitman or {}
rHitman.Contracts = rHitman.Contracts or {}

local CONTRACTS = rHitman.Contracts

-- Money handling helpers
function CONTRACTS:HandleMoney(ply, amount, isAdd)
    if not IsValid(ply) or not isnumber(amount) then return false end
    if amount < 0 then return false end
    
    if isAdd then
        return ply:addMoney(amount)
    else
        if not ply:canAfford(amount) then return false end
        return ply:addMoney(-amount)
    end
end

-- Core operations
function CONTRACTS:Accept(contractId, hitman)
    local contract = self:GetContract(contractId)
    if not contract then return false, "Contract not found" end
    if not IsValid(hitman) then return false, "Invalid hitman" end
    
    -- Check if contract is still active
    if contract.status != "active" then
        return false, "Contract is no longer active"
    end
    
    -- Check if hitman can accept the contract
    local canAccept, reason = rHitman.Core:CanCompleteHits(hitman)
    if not canAccept then
        return false, reason or "You cannot accept contracts"
    end
    
    -- Check if hitman is not the target
    if contract.target == hitman:SteamID64() then
        return false, "You cannot accept a contract on yourself"
    end
    
    -- Check if hitman is not the contractor
    if not contract.isAnonymous and contract.contractor == hitman:SteamID64() then
        return false, "You cannot accept your own contract"
    end
    
    -- Update contract status
    contract.status = "accepted"
    contract.hitman = hitman:SteamID64()
    contract.hitmanName = hitman:Nick()
    contract.acceptedAt = os.time()
    
    -- Notify relevant players
    if not contract.isAnonymous then
        local contractor = player.GetBySteamID64(contract.contractor)
        if IsValid(contractor) then
            rHitman.Util.notify(contractor, "Your contract has been accepted by " .. hitman:Nick(), NOTIFY_GENERIC)
        end
    end
    
    -- Run hook
    hook.Run("rHitman.ContractAccepted", contract, hitman)
    
    return true
end

function CONTRACTS:Complete(contractId, hitman)
    local contract = self:GetContract(contractId)
    if not contract then return false, "Contract not found" end
    if not IsValid(hitman) then return false, "Invalid hitman" end
    
    -- Check if contract is accepted by this hitman
    if contract.status != "accepted" or contract.hitman != hitman:SteamID64() then
        return false, "This is not your contract"
    end
    
    -- Get target
    local target = player.GetBySteamID64(contract.target)
    if not IsValid(target) then
        return false, "Target is not available"
    end
    
    -- Update contract status
    contract.status = "completed"
    contract.completedAt = os.time()
    
    -- Handle payment
    if not contract.paid then
        local contractor = player.GetBySteamID64(contract.contractor)
        if IsValid(contractor) then
            if not contractor:canAfford(contract.reward) then
                return false, "Contractor cannot afford the reward"
            end
            contractor:addMoney(-contract.reward)
        end
    end
    
    -- Pay the hitman
    hitman:addMoney(contract.reward)
    
    -- Notify players
    rHitman.Util.notify(hitman, "Contract completed! You earned " .. rHitman.Util.formatCurrency(contract.reward), NOTIFY_GENERIC)
    
    if not contract.isAnonymous then
        local contractor = player.GetBySteamID64(contract.contractor)
        if IsValid(contractor) then
            rHitman.Util.notify(contractor, "Your contract has been completed by " .. hitman:Nick(), NOTIFY_GENERIC)
        end
    end
    
    -- Run hook
    hook.Run("rHitman.ContractCompleted", contract, hitman, target)
    
    return true
end

function CONTRACTS:Cancel(contractId, reason)
    local contract = self:GetContract(contractId)
    if not contract then return false, "Contract not found" end
    
    -- Update contract status
    contract.status = "cancelled"
    contract.cancelledAt = os.time()
    contract.cancelReason = reason or "No reason provided"
    
    -- Refund contractor if they paid upfront
    if not contract.isAnonymous and not rHitman.Config.PaymentOnCompletion then
        local contractor = player.GetBySteamID64(contract.contractor)
        if IsValid(contractor) then
            contractor:addMoney(contract.reward)
        end
    end
    
    -- Notify hitman if assigned
    if contract.hitman then
        local hitman = player.GetBySteamID64(contract.hitman)
        if IsValid(hitman) then
            rHitman.Util.notify(hitman, "Your contract has been cancelled: " .. contract.cancelReason, NOTIFY_ERROR)
        end
    end
    
    -- Run hook
    hook.Run("rHitman.ContractCancelled", contract, reason)
    
    return true
end

-- Check if a player can accept a contract
function rHitman.canAcceptContract(ply, contract)
    if not IsValid(ply) then return false, "Invalid player" end
    if not contract then return false, "Invalid contract" end
    
    -- Check if contract is active
    if contract.status != "active" then
        return false, "Contract is not active"
    end
    
    -- Check if player is a hitman
    if not rHitman.Core:CanCompleteHits(ply) then
        return false, "You are not authorized to accept contracts"
    end
    
    -- Check if player is the target
    if contract.target == ply:SteamID64() then
        return false, "You cannot accept a contract on yourself"
    end
    
    -- Check if player is the contractor
    if not contract.isAnonymous and contract.contractor == ply:SteamID64() then
        return false, "You cannot accept your own contract"
    end
    
    -- Check if contract is premium and player has access
    if contract.premium and not rHitman.Core:HasPremiumAccess(ply) then
        return false, "This is a premium contract"
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
