--[[
    rHitman - Client Networking
    Handles all network communications between client and server
]]--

rHitman.Contracts = rHitman.Contracts or {}
rHitman.ActiveContract = nil

-- Request contracts from server
function rHitman.requestContracts()
    net.Start("rHitman_RequestContracts")
    net.SendToServer()
end

-- Place a contract
function rHitman.placeContract(targetSteamID, reward, reason)
    net.Start("rHitman_PlaceContract")
        net.WriteString(targetSteamID)
        net.WriteUInt(reward, 32)
        net.WriteString(reason or "")
    net.SendToServer()
end

-- Accept a contract
function rHitman.acceptContract(contractId)
    print("[rHitman] Client requesting to accept contract:", contractId)
    net.Start("rHitman_AcceptContract")
        net.WriteString(contractId)
    net.SendToServer()
end

-- Cancel a contract
function rHitman.cancelContract(contractId)
    net.Start("rHitman_CancelContract")
        net.WriteString(contractId)
    net.SendToServer()
end

-- Complete a contract
function rHitman.completeContract(contractId)
    net.Start("rHitman_CompleteContract")
        net.WriteString(contractId)
    net.SendToServer()
end

-- Get all contracts
function rHitman.getContracts()
    return rHitman.Contracts
end

-- Get a specific contract
function rHitman.getContract(contractId)
    return rHitman.Contracts[contractId]
end

-- Get active contract for local player
function rHitman.getActiveContract()
    return rHitman.ActiveContract
end

-- Network receiver for contract sync
net.Receive("rHitman_SyncContracts", function()
    local numContracts = net.ReadUInt(16)
    local contracts = {}
    local hadActiveContract = rHitman.ActiveContract != nil
    local oldActiveContract = rHitman.ActiveContract
    
    rHitman.ActiveContract = nil
    print("[rHitman] Receiving contract sync. Number of contracts:", numContracts)
    
    -- Read all contracts
    for i = 1, numContracts do
        local id = net.ReadString()
        local contract = {
            id = id,
            contractor = net.ReadString(),
            target = net.ReadString(),
            targetEnt = net.ReadInt(32),
            reward = net.ReadUInt(32),
            timeCreated = net.ReadUInt(32),
            expireTime = net.ReadUInt(32),
            status = net.ReadString(),
            hitman = net.ReadString()
        }
        contracts[id] = contract
        
        -- Update active contract if this one is ours
        if contract.hitman == LocalPlayer():SteamID64() and contract.status == "active" then
            rHitman.ActiveContract = contract
            print("[rHitman] Found active contract for local player:", contract.id)
        end
    end
    
    -- Store contracts
    rHitman.Contracts = contracts
    
    -- Trigger contract update hook if we have an active contract
    if rHitman.ActiveContract then
        print("[rHitman] Triggering contract update for active contract:", rHitman.ActiveContract.id)
        hook.Run("rHitman.ContractUpdated", rHitman.ActiveContract)
    end
end)

-- Network receiver for contract updates
net.Receive("rHitman_ContractUpdate", function()
    local contractId = net.ReadString()
    local status = net.ReadString()
    
    print("[rHitman] Received contract update for:", contractId, "Status:", status)
    
    if rHitman.Contracts[contractId] then
        local oldStatus = rHitman.Contracts[contractId].status
        rHitman.Contracts[contractId].status = status
        
        -- If this was our active contract and it's no longer active
        if rHitman.ActiveContract and rHitman.ActiveContract.id == contractId and status != "active" then
            local contract = rHitman.Contracts[contractId]
            rHitman.ActiveContract = nil
            
            -- Trigger the contract update hook with the new status
            hook.Run("rHitman.ContractUpdated", contract)
        end
    end
end)

-- Request initial contracts when player spawns
hook.Add("InitPostEntity", "rHitman_InitialContractRequest", function()
    timer.Simple(1, function()
        print("[rHitman] Requesting initial contracts")
        rHitman.requestContracts()
    end)
end)

-- Cleanup on player spawn
hook.Add("PlayerSpawn", "rHitman_CleanupContracts", function(ply)
    if ply == LocalPlayer() then
        rHitman.ActiveContract = nil
    end
end)
