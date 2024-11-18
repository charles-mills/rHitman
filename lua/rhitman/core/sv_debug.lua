--[[
    rHitman - Server Debug
    Debug tools and commands for testing
]]--

-- List of random names for simulated contracts
local randomNames = {
    "John Smith",
    "Jane Doe",
    "Bob Johnson",
    "Alice Williams",
    "Michael Brown",
    "Sarah Davis",
    "James Wilson",
    "Emily Taylor",
    "David Miller",
    "Lisa Anderson"
}

-- List of random contract descriptions
local randomDescriptions = {
    "Eliminate target discreetly",
    "Target must be eliminated within 24 hours",
    "No witnesses allowed",
    "Make it look like an accident",
    "Clean hit required",
    "Professional execution needed",
    "Swift and silent elimination",
    "Leave no trace behind",
    "Quick and efficient removal",
    "Stealth is paramount"
}

-- Add debug command to simulate a hit
concommand.Add("rhitman_simhit", function(ply)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() then
        DarkRP.notify(ply, 1, 4, "This command is only available to superadmins")
        return
    end

    -- Get all valid players (excluding command caller)
    local validPlayers = {}
    for _, player in ipairs(player.GetAll()) do
        if player != ply then
            table.insert(validPlayers, player)
        end
    end

    -- Check if we have enough players
    if #validPlayers < 2 then
        DarkRP.notify(ply, 1, 4, "Need at least 2 other players to create a simulated contract")
        return
    end

    -- Select random contractor and target (not command caller, not same person)
    local contractor = table.Random(validPlayers)
    local validTargets = table.Copy(validPlayers)
    
    -- Remove contractor from valid targets
    for i, player in ipairs(validTargets) do
        if player == contractor then
            table.remove(validTargets, i)
            break
        end
    end
    
    local target = table.Random(validTargets)

    if not IsValid(contractor) or not IsValid(target) then
        DarkRP.notify(ply, 1, 4, "Failed to select valid players")
        return
    end

    -- Generate random price within limits (default to 1000-10000 if config not set)
    local minReward = rHitman.Config.MinimumReward or 1000
    local maxReward = rHitman.Config.MaximumReward or 10000
    local reward = math.random(minReward, maxReward)

    -- Create test contract
    local contractId = os.time() .. "_" .. contractor:SteamID64()
    local contract = {
        id = contractId,
        contractor = contractor:SteamID64(),
        target = target:SteamID64(),
        targetEnt = target:EntIndex(), -- Add entity index for HUD
        reward = reward,
        timeCreated = os.time(),
        expireTime = os.time() + (rHitman.Config.ContractDuration or 3600),
        status = "active",
        hitman = nil -- Leave hitman empty so someone can accept it
    }

    -- Add to active contracts
    rHitman.Contracts[contractId] = contract

    -- Notify players
    DarkRP.notify(ply, 0, 4, string.format("Created simulated contract: %s placed hit on %s for %s", 
        contractor:Nick(),
        target:Nick(),
        DarkRP.formatMoney(reward)
    ))

    -- Sync contracts
    rHitman:SyncContracts()
end)
