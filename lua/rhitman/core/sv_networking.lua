--[[
    rHitman - Server Networking
    Handles all network communications between server and clients
]]--

-- Register network strings
util.AddNetworkString("rHitman_SyncContracts")
util.AddNetworkString("rHitman_PlaceContract")
util.AddNetworkString("rHitman_AcceptContract")
util.AddNetworkString("rHitman_CancelContract")
util.AddNetworkString("rHitman_CompleteContract")
util.AddNetworkString("rHitman_ContractUpdate")
util.AddNetworkString("rHitman_RequestContracts")

-- Sync contracts with all players
function rHitman:SyncContracts(ply)
    -- If ply is specified, only sync with that player
    local targets = ply and {ply} or player.GetAll()
    
    -- Start network message
    net.Start("rHitman_SyncContracts")
    
    -- Write number of contracts
    local contracts = self.Contracts or {}
    net.WriteUInt(table.Count(contracts), 16)
    
    -- Write each contract
    for id, contract in pairs(contracts) do
        net.WriteString(id)
        net.WriteString(contract.contractor)
        net.WriteString(contract.target)
        net.WriteInt(contract.targetEnt or -1, 32)
        net.WriteUInt(contract.reward, 32)
        net.WriteUInt(contract.timeCreated, 32)
        net.WriteUInt(contract.expireTime or 0, 32)
        net.WriteString(contract.status)
        net.WriteString(contract.hitman or "")
    end
    
    -- Send to targets
    for _, target in ipairs(targets) do
        if IsValid(target) then
            net.Send(target)
        end
    end
end

-- Handle contract requests
net.Receive("rHitman_RequestContracts", function(len, ply)
    if not IsValid(ply) then return end
    rHitman:SyncContracts(ply)
end)

-- Handle contract placement
net.Receive("rHitman_PlaceContract", function(len, ply)
    if not IsValid(ply) then return end
    
    local targetSteamID = net.ReadString()
    local reward = net.ReadUInt(32)
    local reason = net.ReadString()
    
    local target = player.GetBySteamID64(targetSteamID)
    if not IsValid(target) then
        DarkRP.notify(ply, 1, 4, "Invalid target player")
        return
    end
    
    local success, contractId = rHitman:CreateContract(ply, target, reward)
    if success then
        DarkRP.notify(ply, 0, 4, "Contract placed successfully!")
        rHitman:SyncContracts()
    end
end)

-- Handle contract acceptance
net.Receive("rHitman_AcceptContract", function(len, ply)
    if not IsValid(ply) then return end
    
    local contractId = net.ReadString()
    local success = rHitman:AcceptContract(contractId, ply)
    
    if success then
        DarkRP.notify(ply, 0, 4, "Contract accepted!")
        -- Sync contracts immediately after acceptance
        timer.Simple(0.1, function()
            if IsValid(ply) then
                rHitman:SyncContracts()
            end
        end)
    end
end)

-- Handle contract cancellation
net.Receive("rHitman_CancelContract", function(len, ply)
    if not IsValid(ply) then return end
    
    local contractId = net.ReadString()
    local success = rHitman:CancelContract(contractId, "Cancelled by " .. ply:Nick())
    
    if success then
        DarkRP.notify(ply, 0, 4, "Contract cancelled!")
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
