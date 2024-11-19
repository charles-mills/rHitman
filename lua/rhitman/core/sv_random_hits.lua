--[[
    rHitman - Random Hits System
    Handles automatic creation of random hits
]]--

local Config = rHitman.Config
local nextRandomHit = 0
local nextPremiumHit = 0

-- Debug print function
local function debugPrint(...)
    if Config.Debug then
        print("[rHitman Debug] Random Hits:", ...)
    end
end

-- Get count of active random hits
local function getActiveRandomHits()
    local count = 0
    local contracts = rHitman.Contracts:GetAll()
    debugPrint("Checking active random hits. Total contracts:", table.Count(contracts))
    
    for _, contract in pairs(contracts) do
        if contract.contractorName == "Anonymous" and not contract.premium then
            count = count + 1
        end
    end
    debugPrint("Found", count, "active random hits")
    return count
end

-- Get count of active premium random hits
local function getActivePremiumHits()
    local count = 0
    local contracts = rHitman.Contracts:GetAll()
    debugPrint("Checking active premium hits. Total contracts:", table.Count(contracts))
    
    for _, contract in pairs(contracts) do
        if contract.contractorName == "Anonymous" and contract.premium then
            count = count + 1
        end
    end
    debugPrint("Found", count, "active premium hits")
    return count
end

-- Get a random target from online players
local function getRandomTarget(premium)
    local players = player.GetAll()
    local validTargets = {}
    debugPrint("Finding random target from", #players, "players")
    
    for _, ply in ipairs(players) do
        -- Don't target hitmen or disallowed jobs
        local jobName = team.GetName(ply:Team())
        local isHitman = rHitman.Util.isHitman(ply)
        local isDisallowed = rHitman.Config.randomHitsDisallowedTeams[jobName]
        
        debugPrint("Checking player", ply:Nick(), "Job:", jobName, "Hitman:", isHitman, "Disallowed:", isDisallowed)
        
        if not isHitman and not isDisallowed then
            table.insert(validTargets, ply)
            debugPrint("Added", ply:Nick(), "as valid target")
        end
    end
    
    debugPrint("Found", #validTargets, "valid targets")
    
    if #validTargets > 0 then
        local target = validTargets[math.random(1, #validTargets)]
        debugPrint("Selected target:", target:Nick())
        return target
    end
    debugPrint("No valid targets found")
    return nil
end

-- Get random payout amount
local function getRandomPayout()
    local min = Config.randomHitPayoutRange[1]
    local max = Config.randomHitPayoutRange[2]
    return math.random(min, max)
end

-- Create a random hit
local function createRandomHit(premium)
    if not Config.randomHitsEnabled then return end
    if premium and not Config.randomHitsPremiumEnabled then return end
    
    -- Get valid target
    local target = getRandomTarget(premium)
    if not target then 
        debugPrint("Failed to create hit: No valid target found")
        return 
    end
    
    -- Generate reward
    local reward = premium and Config.randomHitsPremiumPayout or getRandomPayout()
    debugPrint("Creating contract with reward:", reward)
    
    -- Create the contract
    local success, contractId = rHitman.Contracts:Create(
        nil,  -- No contractor for random hits
        target,
        reward,
        premium and "PREMIUM" or nil,
        true  -- isAnonymous
    )
    
    if not success then
        debugPrint("Failed to create contract:", contractId) -- Error message is in contractId
    else
        debugPrint("Created random hit:", contractId)
    end
end

-- Think hook for random hit creation
hook.Add("Think", "rHitman.RandomHits", function()
    local curTime = os.time()
    
    -- Check regular random hits
    if curTime >= nextRandomHit then
        debugPrint("Regular hit check - Current time:", curTime, "Next hit time:", nextRandomHit)
        local activeHits = getActiveRandomHits()
        debugPrint("Active random hits:", activeHits, "Max allowed:", Config.randomHitsMaxActive)
        
        if activeHits < Config.randomHitsMaxActive then
            createRandomHit(false)
        else
            debugPrint("Skipping regular hit creation: Max hits active")
        end
        nextRandomHit = curTime + Config.randomHitsInterval
        debugPrint("Next regular hit check at:", nextRandomHit)
    end
    
    -- Check premium random hits
    if Config.randomHitsPremiumEnabled and curTime >= nextPremiumHit then
        debugPrint("Premium hit check - Current time:", curTime, "Next hit time:", nextPremiumHit)
        local activeHits = getActivePremiumHits()
        debugPrint("Active premium hits:", activeHits, "Max allowed:", Config.randomHitsPremiumMaxActive)
        
        if activeHits < Config.randomHitsPremiumMaxActive then
            createRandomHit(true)
        else
            debugPrint("Skipping premium hit creation: Max hits active")
        end
        nextPremiumHit = curTime + Config.randomHitsPremiumInterval
        debugPrint("Next premium hit check at:", nextPremiumHit)
    end
end)

-- Initialize next hit times
hook.Add("Initialize", "rHitman.RandomHits", function()
    debugPrint("Initializing random hits system")
    nextRandomHit = os.time() + Config.randomHitsInterval
    nextPremiumHit = os.time() + Config.randomHitsPremiumInterval
    debugPrint("First regular hit check at:", nextRandomHit)
    debugPrint("First premium hit check at:", nextPremiumHit)
end)

-- Check if a player can place premium hits
function rHitman.Util.canPlacePremiumHits(ply)
    if not IsValid(ply) then return false end
    if not Config.randomHitsPremiumEnabled then return false end
    
    for _, group in ipairs(Config.randomPremiumHitUserGroups) do
        if ply:IsUserGroup(group) then
            return true
        end
    end
    return false
end
