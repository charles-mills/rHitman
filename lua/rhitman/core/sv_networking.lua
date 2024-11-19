--[[
    rHitman - Server Networking
    Handles all network communications between server and clients
]]--

-- Register network strings
util.AddNetworkString("rHitman_ContractSync")
util.AddNetworkString("rHitman_PlaceContract")
util.AddNetworkString("rHitman_AcceptContract")
util.AddNetworkString("rHitman_CancelContract")
util.AddNetworkString("rHitman_CompleteContract")
util.AddNetworkString("rHitman_ContractUpdate")
util.AddNetworkString("rHitman_RequestContracts")
util.AddNetworkString("rHitman_ContractResponse")

-- Sync contracts with all players
function rHitman:SyncContracts(ply)
    -- If ply is specified, only sync with that player
    local targets = ply and {ply} or player.GetAll()
    
    -- Get all active contracts
    local contracts = {}
    for id, contractData in pairs(self.Contracts) do
        if type(contractData) == "table" then
            -- Ensure all required fields are present
            local contract = {
                id = contractData.id,
                contractor = contractData.contractor,
                contractorName = contractData.contractorName,
                target = contractData.target,
                targetName = contractData.targetName,
                targetJob = contractData.targetJob,
                reward = contractData.reward,
                status = contractData.status,
                created = contractData.created,
                expires = contractData.expires,
                hitman = contractData.hitman
            }
            
            -- Update names if players are still on server
            local contractorPly = player.GetBySteamID64(contractData.contractor)
            if IsValid(contractorPly) then
                contract.contractorName = contractorPly:Nick()
            end
            
            local targetPly = player.GetBySteamID64(contractData.target)
            if IsValid(targetPly) then
                contract.targetName = targetPly:Nick()
                contract.targetJob = targetPly:getDarkRPVar("job") or "Unknown"
            end
            
            table.insert(contracts, contract)
        end
    end
    
    -- Send to each target player
    for _, target in ipairs(targets) do
        if IsValid(target) then
            net.Start("rHitman_ContractSync")
                net.WriteTable(contracts)
            net.Send(target)
            print("[rHitman] Sent", #contracts, "contracts to:", target:Nick())
        end
    end
end

-- Validate contract placement permissions
local function CanPlaceContract(ply, target, reward)
    if not IsValid(ply) or not IsValid(target) then return false, "Invalid player or target" end
    if ply == target then return false, "You cannot place a contract on yourself" end
    if not ply:canAfford(reward) then return false, "You cannot afford this contract" end
    if reward < rHitman.Config.MinimumHitPrice then return false, "Reward is below minimum price" end
    if reward > rHitman.Config.MaximumHitPrice then return false, "Reward exceeds maximum price" end
    
    -- Rate limiting
    if not ply.LastContractPlace then ply.LastContractPlace = 0 end
    if (CurTime() - ply.LastContractPlace) < rHitman.Config.ContractCooldown then
        return false, "Please wait before placing another contract"
    end
    
    -- Check max active contracts
    local activeContracts = 0
    for _, contract in pairs(rHitman.Contracts:GetAll()) do
        if contract.contractor == ply:SteamID64() and contract.status == "active" then
            activeContracts = activeContracts + 1
        end
    end
    
    if activeContracts >= rHitman.Config.MaxActiveContractsPerContractor then
        return false, "You have reached the maximum number of active contracts"
    end
    
    return true
end

-- Validate contract acceptance permissions
local function CanAcceptContract(ply, contractId)
    if not IsValid(ply) then return false, "Invalid player" end
    
    local contract = rHitman.Contracts:GetContract(contractId)
    if not contract then return false, "Invalid contract" end
    if contract.status ~= "active" then return false, "Contract is not active" end
    if contract.contractor == ply:SteamID64() then return false, "You cannot accept your own contract" end
    if contract.target == ply:SteamID64() then return false, "You cannot accept a contract on yourself" end
    
    -- Check if player already has an active contract
    local activeContracts = rHitman.Contracts:GetActiveContractsForHitman(ply:SteamID64())
    if #activeContracts >= rHitman.Config.MaxActiveContracts then
        return false, "You have too many active contracts"
    end
    
    return true
end

-- Handle contract requests
net.Receive("rHitman_RequestContracts", function(len, ply)
    if not IsValid(ply) then return end
    print("[rHitman] Contract request from:", ply:Nick())
    rHitman:SyncContracts(ply)
end)

-- Handle contract placement
net.Receive("rHitman_PlaceContract", function(len, ply)
    if len > 1000 then return end  -- Prevent oversized packets
    
    local targetSteamID = net.ReadString()
    if #targetSteamID > 30 then return end  -- SteamID64 length check
    
    local reward = net.ReadUInt(32)
    local target = player.GetBySteamID64(targetSteamID)
    
    -- Validate contract placement
    local canPlace, error = CanPlaceContract(ply, target, reward)
    if not canPlace then
        DarkRP.notify(ply, 1, 4, "Contract Error: " .. error)
        return
    end
    
    -- Create the contract
    local contract = rHitman.Contracts:Create(ply, target, reward)
    if not contract then
        DarkRP.notify(ply, 1, 4, "Failed to create contract")
        return
    end
    
    print("[rHitman] Created contract:", contract.id, "for", reward)
    
    -- Take money from player
    ply:addMoney(-reward)
    DarkRP.notify(ply, 0, 4, "Contract placed successfully")
    
    -- Update last contract time
    ply.LastContractPlace = CurTime()
    
    -- Sync after a short delay to ensure everything is set up
    timer.Simple(0.1, function()
        rHitman:SyncContracts()
    end)
end)

-- Handle contract acceptance
net.Receive("rHitman_AcceptContract", function(len, ply)
    if len > 100 then return end  -- Prevent oversized packets
    
    local contractId = net.ReadString()
    if #contractId > 30 then return end  -- Contract ID length check
    
    local canAccept, message = CanAcceptContract(ply, contractId)
    if not canAccept then
        DarkRP.notify(ply, 1, 4, message)
        return
    end
    
    local success = rHitman:AcceptContract(contractId, ply)
    if success then
        DarkRP.notify(ply, 0, 4, "Contract accepted!")
        timer.Simple(0.1, function()
            if IsValid(ply) then
                rHitman:SyncContracts()
            end
        end)
    end
end)

-- Handle contract cancellation
net.Receive("rHitman_CancelContract", function(len, ply)
    if len > 100 then return end  -- Prevent oversized packets
    
    local contractId = net.ReadString()
    if #contractId > 30 then return end  -- Contract ID length check
    
    local contract = rHitman.Contracts:GetContract(contractId)
    if not contract then return end
    
    -- Only contractor can cancel their own contracts
    if contract.contractor ~= ply:SteamID64() then
        DarkRP.notify(ply, 1, 4, "You can only cancel your own contracts!")
        return
    end
    
    local success = rHitman:CancelContract(contractId, "Cancelled by " .. ply:Nick())
    if success then
        -- Refund a portion of the contract money
        local refundAmount = math.floor(contract.reward * rHitman.Config.CancelRefundPercent)
        ply:addMoney(refundAmount)
        DarkRP.notify(ply, 0, 4, "Contract cancelled! Refunded: " .. DarkRP.formatMoney(refundAmount))
        rHitman:SyncContracts()
    end
end)

-- Handle contract completion
net.Receive("rHitman_CompleteContract", function(len, ply)
    if not IsValid(ply) then return end
    
    local contractId = net.ReadString()
    local success = rHitman:CompleteContract(contractId, ply)
    
    if success then
        DarkRP.notify(ply, 0, 4, "Contract completed!")
        rHitman:SyncContracts()
    end
end)

-- Update contract status
function rHitman:UpdateContractStatus(contractId, status)
    net.Start("rHitman_ContractUpdate")
        net.WriteString(contractId)
        net.WriteString(status)
    net.Broadcast()
end
