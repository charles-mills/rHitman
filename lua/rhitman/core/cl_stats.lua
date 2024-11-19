--[[
    rHitman - Client Statistics
    Handles player statistics tracking and persistence
]]--

rHitman = rHitman or {}
rHitman.Stats = rHitman.Stats or {}

-- Default stats template
local defaultStats = {
    contractor = {
        contractsPlaced = 0,
        contractsCompleted = 0,
        totalSpent = 0,
        successRate = 0,
        lastContract = 0
    },
    hitman = {
        contractsAccepted = 0,
        contractsCompleted = 0,
        contractsFailed = 0,
        totalEarned = 0,
        successRate = 0,
        lastHit = 0,
        fastestHit = 0,
        longestHit = 0
    }
}

-- Load stats from file
function rHitman.Stats:Load()
    local path = "rhitman/stats/" .. LocalPlayer():SteamID64() .. ".json"
    
    if not file.Exists("rhitman/stats", "DATA") then
        file.CreateDir("rhitman/stats")
    end
    
    if file.Exists(path, "DATA") then
        local data = file.Read(path, "DATA")
        self.cache = util.JSONToTable(data) or table.Copy(defaultStats)
    else
        self.cache = table.Copy(defaultStats)
    end
    
    -- Calculate success rates
    if self.cache.contractor.contractsPlaced > 0 then
        self.cache.contractor.successRate = math.Round((self.cache.contractor.contractsCompleted / self.cache.contractor.contractsPlaced) * 100, 1)
    end
    
    if self.cache.hitman.contractsAccepted > 0 then
        self.cache.hitman.successRate = math.Round((self.cache.hitman.contractsCompleted / self.cache.hitman.contractsAccepted) * 100, 1)
    end
    
    hook.Run("rHitman.StatsUpdated", self.cache)
end

-- Save stats to file
function rHitman.Stats:Save()
    local path = "rhitman/stats/" .. LocalPlayer():SteamID64() .. ".json"
    file.Write(path, util.TableToJSON(self.cache, true))
end

-- Update contractor stats
function rHitman.Stats:UpdateContractor(contract, completed)
    self.cache.contractor.contractsPlaced = self.cache.contractor.contractsPlaced + 1
    self.cache.contractor.totalSpent = self.cache.contractor.totalSpent + contract.reward
    self.cache.contractor.lastContract = os.time()
    
    if completed then
        self.cache.contractor.contractsCompleted = self.cache.contractor.contractsCompleted + 1
    end
    
    -- Update success rate
    if self.cache.contractor.contractsPlaced > 0 then
        self.cache.contractor.successRate = math.Round((self.cache.contractor.contractsCompleted / self.cache.contractor.contractsPlaced) * 100, 1)
    end
    
    self:Save()
    hook.Run("rHitman.StatsUpdated", self.cache)
end

-- Update hitman stats
function rHitman.Stats:UpdateHitman(contract, result)
    self.cache.hitman.contractsAccepted = self.cache.hitman.contractsAccepted + 1
    
    if result == "completed" then
        self.cache.hitman.contractsCompleted = self.cache.hitman.contractsCompleted + 1
        self.cache.hitman.totalEarned = self.cache.hitman.totalEarned + contract.reward
        
        -- Calculate hit duration
        local duration = os.time() - contract.acceptedAt
        if self.cache.hitman.fastestHit == 0 or duration < self.cache.hitman.fastestHit then
            self.cache.hitman.fastestHit = duration
        end
        if duration > self.cache.hitman.longestHit then
            self.cache.hitman.longestHit = duration
        end
    else
        self.cache.hitman.contractsFailed = self.cache.hitman.contractsFailed + 1
    end
    
    -- Update success rate
    if self.cache.hitman.contractsAccepted > 0 then
        self.cache.hitman.successRate = math.Round((self.cache.hitman.contractsCompleted / self.cache.hitman.contractsAccepted) * 100, 1)
    end
    
    self.cache.hitman.lastHit = os.time()
    self:Save()
    hook.Run("rHitman.StatsUpdated", self.cache)
end

-- Calculate player rank based on completed hits
function rHitman.Stats:GetRank()
    if not self.cache then return rHitman.Config.Ranks[1] end -- Return lowest rank if no stats
    
    local completedHits = self.cache.hitman.contractsCompleted
    for _, rank in ipairs(rHitman.Config.Ranks) do
        if completedHits >= rank.minHits and completedHits <= rank.maxHits then
            return rank
        end
    end
    
    return rHitman.Config.Ranks[#rHitman.Config.Ranks] -- Return highest rank if above all thresholds
end

-- Get rank progress (percentage to next rank)
function rHitman.Stats:GetRankProgress()
    if not self.cache then return 0 end
    
    local completedHits = self.cache.hitman.contractsCompleted
    local currentRank = self:GetRank()
    local nextRankIndex = 0
    
    -- Find the next rank
    for i, rank in ipairs(rHitman.Config.Ranks) do
        if rank.name == currentRank.name then
            nextRankIndex = i + 1
            break
        end
    end
    
    -- If we're at max rank, return 100%
    if nextRankIndex > #rHitman.Config.Ranks then
        return 100
    end
    
    local nextRank = rHitman.Config.Ranks[nextRankIndex]
    local hitsNeeded = nextRank.minHits - currentRank.minHits
    local hitsProgress = completedHits - currentRank.minHits
    
    return math.Clamp(math.Round((hitsProgress / hitsNeeded) * 100), 0, 100)
end

-- Hook into contract events
hook.Add("rHitman.ContractCreated", "rHitman_StatsContractCreated", function(contract)
    if contract.contractor == LocalPlayer():SteamID64() then
        rHitman.Stats:UpdateContractor(contract, false)
    end
end)

hook.Add("rHitman.ContractUpdated", "rHitman_StatsContractUpdated", function(contract)
    -- Handle contractor stats
    if contract.contractor == LocalPlayer():SteamID64() and contract.status == "completed" then
        rHitman.Stats:UpdateContractor(contract, true)
    end
    
    -- Handle hitman stats
    if contract.hitman == LocalPlayer():SteamID64() and (contract.status == "completed" or contract.status == "failed") then
        rHitman.Stats:UpdateHitman(contract, contract.status)
    end
end)

-- Load stats when player spawns
hook.Add("InitPostEntity", "rHitman_LoadStats", function()
    rHitman.Stats:Load()
end)
