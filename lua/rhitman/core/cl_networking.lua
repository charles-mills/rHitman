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
        for _, contract in pairs(self.cache) do
            table.insert(contracts, contract)
        end
        return contracts
    end,
    
    -- Get specific contract
    GetContract = function(self, id)
        return self.cache[id]
    end,
    
    -- Update contract cache
    UpdateCache = function(self, contracts)
        self.cache = {}
        for _, contract in ipairs(contracts) do
            self.cache[contract.id] = contract
        end
        print("[rHitman] Updated contract cache:", #contracts, "contracts")
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
    print("[rHitman] Received contract sync:", #contracts, "contracts")
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
    
    print("[rHitman] Received contract update for:", contractId, "Status:", status)
    
    local contract = rHitman.Contracts:GetContract(contractId)
    if contract then
        local oldStatus = contract.status
        contract.status = status
        
        -- If this was our active contract and it's no longer active
        if rHitman.ActiveContract and rHitman.ActiveContract.id == contractId and status != "active" then
            rHitman.ActiveContract = nil
            print("[rHitman] Active contract updated:", contractId, oldStatus, "->", status)
        end
        
        -- Trigger the contract update hook
        hook.Run("rHitman.ContractUpdated", contract)
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
