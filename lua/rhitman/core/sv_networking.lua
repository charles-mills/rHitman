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
util.AddNetworkString("rHitman.CreateContract")
util.AddNetworkString("rHitman.SyncContract")

-- Sync contracts with all players
function rHitman:SyncContracts(ply)
    -- If ply is specified, only sync with that player
    local targets = ply and {ply} or player.GetAll()
    
    -- Get all contracts
    local contracts = self.Contracts:GetAll()
    
    -- Debug print
    print("[rHitman] Syncing", table.Count(contracts), "contracts")
    for id, contract in pairs(contracts) do
        print("[rHitman] Contract:", id, "Contractor:", contract.contractorName, "Target:", contract.targetName)
    end
    
    -- Send to each target player
    for _, target in ipairs(targets) do
        if IsValid(target) then
            net.Start("rHitman_ContractSync")
                net.WriteTable(contracts)
            net.Send(target)
            print("[rHitman] Sent", table.Count(contracts), "contracts to:", target:Nick())
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
    if table.Count(activeContracts) >= (rHitman.Config.MaxActiveContractsPerHitman or 1) then
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

-- Handle contract creation request
net.Receive("rHitman.CreateContract", function(len, ply)
    local target = net.ReadEntity()
    local reward = net.ReadInt(32)
    
    -- Basic validation
    if not IsValid(target) then
        DarkRP.notify(ply, 1, 4, "Invalid target selected!")
        return
    end
    
    -- Create contract using new method
    local success, result = rHitman.Contracts:Create(ply, target, reward)
    
    if success then
        DarkRP.notify(ply, 0, 4, "Contract placed on " .. target:Nick() .. " for $" .. reward)
        
        -- Sync contract to all clients
        net.Start("rHitman.SyncContract")
        net.WriteString(result) -- result is contract ID
        net.WriteTable(rHitman.Contracts:GetContract(result))
        net.Broadcast()
    else
        DarkRP.notify(ply, 1, 4, result) -- result is error message
    end
end)

-- Handle contract acceptance
net.Receive("rHitman_AcceptContract", function(len, ply)
    if not IsValid(ply) then return end
    
    local contractId = net.ReadString()
    if not contractId then return end
    
    -- Validate acceptance
    local canAccept, error = CanAcceptContract(ply, contractId)
    if not canAccept then
        DarkRP.notify(ply, 1, 4, "Cannot accept contract: " .. error)
        return
    end
    
    -- Get the contract
    local contract = rHitman.Contracts:GetContract(contractId)
    if not contract then return end
    
    -- Update contract status
    contract.status = "active"
    contract.hitman = ply:SteamID64()
    contract.hitmanName = ply:Nick()
    contract.acceptedAt = os.time()
    
    -- Update in main contracts table
    rHitman.Contracts.contracts[contractId] = contract
    
    -- Notify relevant players
    DarkRP.notify(ply, 0, 4, "Contract accepted successfully!")
    
    -- Notify the contractor
    local contractor = player.GetBySteamID64(contract.contractor)
    if IsValid(contractor) then
        DarkRP.notify(contractor, 0, 4, ply:Nick() .. " has accepted your contract!")
    end
    
    -- Sync the updated contract to all clients
    net.Start("rHitman_ContractUpdate")
    net.WriteString(contractId)
    net.WriteString("active")
    net.WriteString(ply:SteamID64())
    net.WriteString(ply:Nick())
    net.Broadcast()
    
    -- Run contract accepted hook
    hook.Run("rHitman_ContractAccepted", contract)
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
