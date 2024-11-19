--[[
    rHitman - Client Networking
    Handles all network communications between client and server
]]--

-- Initialize contract system
rHitman.Contracts = {
    cache = {},
    
    -- Get all contracts
    GetAll = function(self)
        local contracts = {}
        for id, contract in pairs(self.cache) do
            contracts[id] = contract
        end
        return contracts
    end,
    
    -- Get specific contract
    GetContract = function(self, id)
        return self.cache[id]
    end,
    
    -- Update contract cache
    UpdateCache = function(self, contracts)
        print("[rHitman] Updating contract cache with", table.Count(contracts), "contracts")
        self.cache = {}
        for id, contract in pairs(contracts) do
            print("[rHitman] Caching contract:", id, "Contractor:", contract.contractorName, "Target:", contract.targetName)
            self.cache[id] = contract
        end
        print("[rHitman] Contract cache updated, total contracts:", table.Count(self.cache))
        hook.Run("rHitman.ContractsUpdated")
    end
}

rHitman.ActiveContract = nil

-- Request contracts from server
function rHitman.requestContracts()
    net.Start("rHitman_RequestContracts")
    net.SendToServer()
end

-- Handle contract sync
net.Receive("rHitman_ContractSync", function()
    local contracts = net.ReadTable()
    print("[rHitman] Received contract sync with", table.Count(contracts), "contracts")
    for id, contract in pairs(contracts) do
        print("[rHitman] Received contract:", id, "Contractor:", contract.contractorName, "Target:", contract.targetName)
    end
    rHitman.Contracts:UpdateCache(contracts)
    
    -- Run the update hook after a short delay to ensure everything is set up
    timer.Simple(0.1, function()
        hook.Run("rHitman.ContractsUpdated")
    end)
end)

-- Network receiver for contract updates
net.Receive("rHitman_ContractUpdate", function()
    local contractId = net.ReadString()
    local status = net.ReadString()
    local hitmanId = net.ReadString()
    local hitmanName = net.ReadString()
    
    print("[rHitman] Received contract update for:", contractId, "Status:", status, "Hitman:", hitmanName)
    
    local contract = rHitman.Contracts:GetContract(contractId)
    if contract then
        local oldStatus = contract.status
        contract.status = status
        contract.hitman = hitmanId
        contract.hitmanName = hitmanName
        
        -- If this was our active contract and it's no longer active
        if rHitman.ActiveContract and rHitman.ActiveContract.id == contractId and status ~= "active" then
            rHitman.ActiveContract = nil
            print("[rHitman] Active contract updated:", contractId, oldStatus, "->", status)
        end
        
        -- Update contract in cache
        rHitman.Contracts.cache[contractId] = contract
        
        -- Set as active contract if we're the hitman and it's active
        if status == "active" and hitmanId == LocalPlayer():SteamID64() then
            rHitman.ActiveContract = contract
            print("[rHitman] Set active contract:", contractId)
        end
        
        -- Trigger the contract update hook
        hook.Run("rHitman.ContractUpdated", contract)
        
        -- Trigger contract accepted hook if relevant
        if status == "accepted" and hitmanId == LocalPlayer():SteamID64() then
            hook.Run("rHitman.ContractAccepted", contract)
        end
    end
end)

-- Network receiver for contract creation response
net.Receive("rHitman_ContractResponse", function()
    local success = net.ReadBool()
    local message = net.ReadString()
    
    print("[rHitman] Contract response:", success, message)
    
    if success then
        notification.AddLegacy(message, NOTIFY_GENERIC, 4)
    else
        notification.AddLegacy(message, NOTIFY_ERROR, 4)
    end
    
    -- Run the contract created hook
    hook.Run("rHitman.ContractCreated", success, message)
    
    -- Show notification
    surface.PlaySound(success and "buttons/button15.wav" or "buttons/button10.wav")
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
