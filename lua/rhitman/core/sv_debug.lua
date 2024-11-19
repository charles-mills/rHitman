--[[
    rHitman - Server Debug
    Debug tools and commands for testing
]]--

if not rHitman.Config.Debug then return end

-- List of random names for bot spawns
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
    "Lisa Anderson",
    "Robert Clark",
    "Emma White"
}

-- Shuffle and prepare names
local shuffledNames = table.Copy(randomNames)
table.Shuffle(shuffledNames)
local currentNameIndex = 1

-- Function to get next name
local function GetNextName()
    local name = shuffledNames[currentNameIndex]
    currentNameIndex = (currentNameIndex % #shuffledNames) + 1
    return name
end

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

-- Function to get available jobs
local function GetAvailableJobs()
    local jobs = {}
    
    -- Check for DarkRP jobs
    if RPExtraTeams then
        for _, job in ipairs(RPExtraTeams) do
            if job.team and job.name and job.command then
                table.insert(jobs, {
                    team = job.team,
                    name = job.name,
                    command = job.command
                })
            end
        end
    end
    
    -- If no jobs found, add citizen as fallback
    if #jobs == 0 then
        table.insert(jobs, {
            team = TEAM_CITIZEN or 1,
            name = "Citizen",
            command = "citizen"
        })
    end
    
    return jobs
end

-- Function to set a bot's job
local function SetBotJob(ply)
    if not IsValid(ply) then return end
    if not DarkRP then return end
    
    local jobs = GetAvailableJobs()
    if #jobs == 0 then return end
    
    local randomJob = table.Random(jobs)
    if not randomJob then return end
    
    -- Use DarkRP's changeTeam function instead of toggleJob
    ply:changeTeam(randomJob.team, true, true)
    print("[rHitman] Set bot job:", randomJob.name)
end

-- Track debug bots
local debugBots = {}
local debugBotCount = 0
local maxDebugBots = 0

-- Handle bot initialization
hook.Add("PlayerInitialSpawn", "rHitman.DebugBotInit", function(ply)
    if not rHitman.Config.Debug then return end
    if not ply:IsBot() then return end
    if debugBotCount >= maxDebugBots then return end
    
    -- Track this bot
    debugBotCount = debugBotCount + 1
    debugBots[ply:SteamID()] = true
    
    -- Set name and job after a short delay to ensure DarkRP is ready
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        
        -- Set random name using DarkRP's functions
        local name = GetNextName()
        if DarkRP then
            DarkRP.storeRPName(ply, name) -- Store the name in the database
            ply:setDarkRPVar("rpname", name) -- Set the name variable
            print("[rHitman] Set bot name:", name)
        end
        
        -- Set random job
        SetBotJob(ply)
    end)
end)

-- Function to generate a simulated hit
local function GenerateSimHit()
    -- Get all valid players
    local validPlayers = {}
    for _, player in ipairs(player.GetAll()) do
        if IsValid(player) then
            table.insert(validPlayers, player)
        end
    end

    -- Check if we have enough players
    if #validPlayers < 2 then
        print("[rHitman] Not enough players to create a simulated contract")
        return false
    end

    -- Select random contractor and target (not same person)
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
        print("[rHitman] Failed to select valid players for simulated contract")
        return false
    end

    -- Create contract using the contract system
    local success, result = rHitman.Contracts:Create(contractor, target, math.random(rHitman.Config.MinimumHitPrice or 1000, rHitman.Config.MaximumHitPrice or 10000))
    
    if success then
        print("[rHitman] Created simulated contract:", result, "Contractor:", contractor:Nick(), "Target:", target:Nick())
        
        -- Sync contracts immediately
        timer.Simple(0.1, function()
            rHitman:SyncContracts()
        end)
        
        return true
    else
        print("[rHitman] Failed to create simulated contract:", result)
        return false
    end
end

concommand.Add("rhitman_simhit", function(ply)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() then
        DarkRP.notify(ply, 1, 4, "This command is only available to superadmins")
        return
    end

    if GenerateSimHit() then
        DarkRP.notify(ply, 0, 4, "Created simulated contract")
        -- Sync contracts after a short delay
        timer.Simple(0.1, function()
            rHitman:SyncContracts()
        end)
    else
        DarkRP.notify(ply, 1, 4, "Failed to create simulated contract")
    end
end)

-- Add debug bots when server starts
hook.Add("InitPostEntity", "rHitman.DebugBots", function()
    if not rHitman.Config.Debug then return end
    
    print("[rHitman] Debug mode enabled, spawning bots...")
    
    -- Reset bot tracking
    debugBotCount = 0
    maxDebugBots = rHitman.Config.DebugBotCount or 12
    
    -- Delay bot spawning to ensure server is fully loaded
    timer.Simple(2, function()
        -- Get current player count
        local currentPlayers = #player.GetAll()
        local botsNeeded = math.max(0, maxDebugBots - currentPlayers)
        
        print("[rHitman] Spawning", botsNeeded, "bots...")
        
        -- Spawn bots with delay between each
        for i = 1, botsNeeded do
            timer.Simple(i * 0.2, function()
                RunConsoleCommand("bot")
            end)
        end
        
        -- Generate simulated hits after all bots are spawned
        timer.Simple((botsNeeded * 0.2) + 2, function()
            print("[rHitman] Generating simulated contracts...")
            local contractsCreated = 0
            
            -- Create contracts sequentially with proper tracking
            local function createNextContract(index)
                if index > 4 then
                    print("[rHitman] Created", contractsCreated, "simulated contracts")
                    rHitman:SyncContracts()
                    return
                end
                
                if GenerateSimHit() then
                    contractsCreated = contractsCreated + 1
                    print("[rHitman] Created", contractsCreated, "simulated contracts")
                end
                
                -- Create next contract after a short delay
                timer.Simple(0.5, function()
                    createNextContract(index + 1)
                end)
            end
            
            -- Start creating contracts
            createNextContract(1)
        end)
    end)
end)

function rHitman:CreateDebugBot()
    -- Create a bot with a random name
    local bot = player.CreateNextBot("Bot" .. math.random(1000, 9999))
    if not IsValid(bot) then return end
    
    -- Set random name
    local names = {
        "John Smith", "Jane Doe", "Bob Wilson", "Alice Brown",
        "Mike Johnson", "Sarah Davis", "Tom Anderson", "Emma White",
        "David Miller", "Lisa Taylor", "James Moore", "Mary Jones"
    }
    local randomName = names[math.random(#names)]
    bot:setRPName(randomName)
    
    -- Set random job
    local jobs = RPExtraTeams or {}
    if #jobs > 0 then
        local randomJob = jobs[math.random(#jobs)]
        if randomJob then
            bot:changeTeam(randomJob.team, true, true)
        end
    end
    
    -- Set random money
    bot:setDarkRPVar("money", math.random(1000, 10000))
    
    print("[rHitman Debug] Created bot:", randomName)
    return bot
end
