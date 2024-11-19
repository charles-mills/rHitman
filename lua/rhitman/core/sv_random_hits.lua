--[[
    rHitman - Random Hits System
    Handles automatic creation of random hits
]]--

local Config = rHitman.Config
local nextRandomHit = 0
local nextPremiumHit = 0

-- Get count of active random hits
local function getActiveRandomHits()
    local count = 0
    for _, contract in pairs(rHitman.Contracts) do
        if contract.placer == "Anonymous" and not contract.premium then
            count = count + 1
        end
    end
    return count
end

-- Get count of active premium random hits
local function getActivePremiumHits()
    local count = 0
    for _, contract in pairs(rHitman.Contracts) do
        if contract.placer == "Anonymous" and contract.premium then
            count = count + 1
        end
    end
    return count
end

-- Get a random target from online players
local function getRandomTarget()
    local players = player.GetAll()
    local validTargets = {}
    
    for _, ply in ipairs(players) do
        -- Don't target hitmen or disallowed jobs
        if not rHitman.Util.isHitman(ply) and not rHitman.Util.isDisallowed(ply) then
            table.insert(validTargets, ply)
        end
    end
    
    if #validTargets > 0 then
        return validTargets[math.random(1, #validTargets)]
    end
    return nil
end

-- Get a random payout amount (1-50% of max price)
local function getRandomPayout()
    local maxPrice = Config.MaxPrice or 100000
    local minPayout = maxPrice * 0.01 -- 1%
    local maxPayout = maxPrice * 0.5  -- 50%
    return math.random(minPayout, maxPayout)
end

-- Create a random hit
local function createRandomHit(premium)
    local target = getRandomTarget()
    if not target then return end
    
    local contract = {
        target = target:SteamID(),
        placer = "Anonymous",
        price = premium and Config.premiumHitPayout or getRandomPayout(),
        time = os.time(),
        premium = premium
    }
    
    -- Add contract to the system
    local id = rHitman.AddContract(contract)
    if id then
        print("[rHitman] Created " .. (premium and "premium " or "") .. "random hit on " .. target:Nick())
    end
end

-- Think hook for random hit creation
hook.Add("Think", "rHitman.RandomHits", function()
    if not Config.randomHitsEnabled then return end
    
    local curTime = os.time()
    
    -- Check regular random hits
    if curTime >= nextRandomHit then
        if getActiveRandomHits() < Config.maxRandomHitsActive then
            createRandomHit(false)
        end
        nextRandomHit = curTime + Config.randomHitInterval
    end
    
    -- Check premium random hits
    if Config.randomHitsPremiumEnabled and curTime >= nextPremiumHit then
        if getActivePremiumHits() < Config.maxPremiumRandomHits then
            createRandomHit(true)
        end
        nextPremiumHit = curTime + Config.premiumRandomHitInterval
    end
end)

-- Initialize next hit times
hook.Add("Initialize", "rHitman.RandomHits", function()
    nextRandomHit = os.time() + Config.randomHitInterval
    nextPremiumHit = os.time() + Config.premiumRandomHitInterval
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
