--[[
    rHitman - Core Server Functions
    Handles the main contract system functionality
]]--

rHitman.Contracts = rHitman.Contracts or {}
local activeContracts = {}

-- Money handling functions
local function addMoney(ply, amount)
    if not IsValid(ply) or not isnumber(amount) then return false end
    if amount < 0 then return false end
    return ply:addMoney(amount)
end

local function takeMoney(ply, amount)
    if not IsValid(ply) or not isnumber(amount) then return false end
    if amount < 0 then return false end
    if not ply:canAfford(amount) then return false end
    return ply:addMoney(-amount)
end

-- Validate contract price
local function validatePrice(price)
    if not isnumber(price) then return false end
    return price >= rHitman.Config.MinimumHitPrice and price <= rHitman.Config.MaximumHitPrice
end

-- Create a new contract
function rHitman.createContract(contractor, target, price, description)
    if not IsValid(contractor) or not IsValid(target) then 
        return false, "Invalid player" 
    end
    
    if not rHitman.Util.canPlaceContract(contractor) then
        return false, "You are not authorized to place contracts"
    end
    
    if contractor == target and not rHitman.Config.AllowSelfContracts then
        return false, "You cannot place a contract on yourself"
    end
    
    if not validatePrice(price) then
        return false, "Invalid contract price"
    end
    
    -- Take payment if configured
    if not rHitman.Config.PaymentOnCompletion then
        if not takeMoney(contractor, price) then
            return false, "Insufficient funds"
        end
    end
    
    -- Generate contract
    local contractID = rHitman.Util.generateContractID()
    local contract = {
        id = contractID,
        contractor = contractor:SteamID64(),
        contractorName = contractor:Nick(),
        target = target:SteamID64(),
        targetName = target:Nick(),
        price = price,
        description = description,
        timeCreated = os.time(),
        timeExpires = os.time() + rHitman.Config.ContractDuration,
        status = "active",
        evidence = nil,
        hitman = nil,
        paid = not rHitman.Config.PaymentOnCompletion,
        placedWhen = CurTime()
    }
    
    -- Add to active contracts
    activeContracts[contractID] = contract
    
    -- Set cooldown
    contractor:SetNWFloat("rHitman_LastContract", CurTime())
    
    -- Notify hitmen if enabled
    if rHitman.Config.NotifyHitmanNewContract then
        for _, ply in ipairs(player.GetAll()) do
            if rHitman.Util.canCompleteHits(ply) and ply != contractor then
                rHitman.Util.notify(ply, "A new contract worth " .. rHitman.Util.formatCurrency(price) .. " is available!", NOTIFY_HINT)
            end
        end
    end
    
    return true, contractID
end

-- Check and remove contracts when a player changes team
hook.Add("OnPlayerChangedTeam", "rHitman_CheckTeamChange", function(ply, oldTeam, newTeam)
    if not IsValid(ply) then return end
    
    local settings = rHitman.Config.getJobSettings(team.GetName(newTeam))
    
    -- If player can't use system in new team, remove their active contracts
    if not settings.canUseSystem then
        for id, contract in pairs(activeContracts) do
            if contract.contractor == ply:SteamID64() then
                rHitman.cancelContract(id, ply)
            end
        end
    end
    
    -- If player is now a hitman, remove their active hits
    if rHitman.Config.isHitmanJob(team.GetName(newTeam)) then
        for id, contract in pairs(activeContracts) do
            if contract.target == ply:SteamID64() then
                rHitman.cancelContract(id, ply)
                rHitman.Util.notify(ply, "Your contracts have been cancelled as you are now a hitman", NOTIFY_GENERIC)
            end
        end
    end
end)

-- Prevent hitmen from completing their own hits
local function canCompleteHit(ply, contract)
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
    if rHitman.Config.isHitmanJob(team.GetName(ply:Team())) then
        -- Additional check for hits placed before becoming a hitman
        if contract.placedWhen and (contract.placedWhen > (ply.lastTeamChange or 0)) then
            return true
        else
            return false, "You cannot complete hits that existed before you became a hitman"
        end
    end
    
    return true
end

-- Complete a contract
function rHitman.completeContract(contractID, ply, evidence)
    if not IsValid(ply) then return false, "Invalid player" end
    
    local contract = activeContracts[contractID]
    if not contract then return false, "Contract not found" end
    
    -- Check if player can complete this specific hit
    local canComplete, reason = canCompleteHit(ply, contract)
    if not canComplete then
        return false, reason
    end
    
    if not rHitman.Util.canCompleteHits(ply) then
        return false, "You are not authorized to complete contracts"
    end
    
    if contract.status != "active" then
        return false, "Contract is not active"
    end
    
    if rHitman.Config.RequireEvidence and (not evidence or evidence == "") then
        return false, "Evidence is required"
    end
    
    -- Handle payment
    if rHitman.Config.PaymentOnCompletion then
        local contractor = player.GetBySteamID64(contract.contractor)
        if not IsValid(contractor) then
            return false, "Contractor not found"
        end
        
        if not takeMoney(contractor, contract.price) then
            return false, "Contractor cannot afford the contract"
        end
    end
    
    -- Pay the hitman
    if not addMoney(ply, contract.price) then
        -- If payment fails and we took money from contractor, refund them
        if rHitman.Config.PaymentOnCompletion then
            local contractor = player.GetBySteamID64(contract.contractor)
            if IsValid(contractor) then
                addMoney(contractor, contract.price)
            end
        end
        return false, "Failed to pay hitman"
    end
    
    -- Update contract
    contract.status = "completed"
    contract.hitman = ply:SteamID64()
    contract.hitmanName = ply:Nick()
    contract.evidence = evidence
    contract.timeCompleted = os.time()
    
    -- Sync contracts
    rHitman.syncContracts()
    
    return true
end

-- Cancel a contract
function rHitman.cancelContract(contractID, ply)
    local contract = activeContracts[contractID]
    if not contract then return false, "Contract not found" end
    
    if not IsValid(ply) or ply:SteamID64() != contract.contractor then
        return false, "You did not place this contract"
    end
    
    if contract.status != "active" then
        return false, "Contract cannot be cancelled"
    end
    
    -- Refund payment if it was taken upfront
    if not rHitman.Config.PaymentOnCompletion and not contract.paid then
        local refundAmount = math.floor(contract.price * (rHitman.Config.RefundPercentage / 100))
        if not addMoney(ply, refundAmount) then
            return false, "Failed to process refund"
        end
    end
    
    -- Update contract
    contract.status = "cancelled"
    contract.timeCancelled = os.time()
    
    -- Sync contracts
    rHitman.syncContracts()
    
    return true
end

-- Accept a contract
function rHitman.acceptContract(contractID, ply)
    local contract = activeContracts[contractID]
    if not contract then return false, "Contract not found" end
    
    if not IsValid(ply) then return false, "Invalid player" end
    if not rHitman.Util.canCompleteHits(ply) then
        return false, "You are not authorized to accept contracts"
    end
    
    if contract.status != "active" then
        return false, "Contract is not available"
    end
    
    if contract.timeExpires <= os.time() then
        return false, "Contract has expired"
    end
    
    -- Update contract
    contract.hitman = ply:SteamID64()
    contract.hitmanName = ply:Nick()
    contract.timeAccepted = os.time()
    
    -- Sync contracts
    rHitman.syncContracts()
    
    return true
end

-- Get all active contracts
function rHitman.getActiveContracts()
    return activeContracts
end

--[[
    rHitman - Server Core
    Core server-side functionality
]]--

-- Store last team change time when player changes team
hook.Add("PlayerInitialSpawn", "rHitman_InitTeamChange", function(ply)
    ply.lastTeamChange = CurTime()
end)

hook.Add("OnPlayerChangedTeam", "rHitman_TrackTeamChange", function(ply)
    ply.lastTeamChange = CurTime()
end)

-- Check for expired contracts periodically
timer.Create("rHitman_ContractExpireCheck", 60, 0, function()
    local contracts = rHitman.Contracts:GetAll()
    for _, contract in pairs(contracts) do
        if contract.status == "active" and contract.expireTime and contract.expireTime <= os.time() then
            rHitman.Contracts:ExpireContract(contract.id)
        end
    end
end)
