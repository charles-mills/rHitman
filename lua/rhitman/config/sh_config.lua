--[[
    rHitman - Configuration
    Contains all configurable options for the addon
]]--

rHitman = rHitman or {}
rHitman.Config = {
    -- System defaults
    DefaultCanUseSystem = true,
    DefaultCanPlaceContracts = true,
    DefaultCanCompleteHits = false,

    -- UI Colors
    Colors = {
        background = Color(30, 30, 30, 255),
        header = Color(40, 40, 40, 255),
        card = Color(40, 40, 40, 255),
        cardHover = Color(50, 50, 50, 255),
        text = Color(255, 255, 255, 255),
        textDark = Color(200, 200, 200, 255),
        accent = Color(220, 50, 50, 255),
        success = Color(46, 204, 113),
        warning = Color(241, 196, 15),
        error = Color(231, 76, 60),
        input = Color(40, 40, 40, 255),
        inputHover = Color(50, 50, 50, 255),
        HUDColor = Color(255, 100, 100)
    },

    -- UI Settings
    PlayerListSortMode = "job", -- "job" or "name"

    -- Contract Settings
    MinimumHitPrice = 1000,
    MaximumHitPrice = 1000000,
    ContractDuration = 3600, -- 1 hour in seconds
    ContractCooldown = 300, -- 5 minutes between contracts
    PaymentOnCompletion = true,
    RequireEvidence = true,
    MaxActiveContractsPerContractor = 1, -- Maximum number of active contracts one player can place
    MaxActiveContractsPerHitman = 1, -- Maximum number of active contracts one hitman can accept
    CurrencySymbol = "£", -- Currency symbol to use in all displays

    -- Contract End Conditions
    EndOnHitmanDeath = true, -- End contract if hitman dies
    ContractTimeLimit = 15 * 60, -- Contract time limit in seconds (15 minutes)

    -- HUD Settings
    HUDEnabled = true,
    ShowHealth = true,
    ShowArmor = true,
    ShowCompass = true,
    CompassSize = 200,
    HUDScale = 1,
    HUDPosition = {
        x = 5,
        y = 5
    },
    
    -- HUD Animation Settings
    HUDFadeSpeed = 5, -- Speed at which HUD fades out
    HUDCompletionAnimTime = 3, -- Duration of completion animation in seconds
    HUDCompletionHoldTime = 2, -- How long to show completion message before fading
    HUDFastFadeSpeed = 15, -- Speed for quick fade outs (like on death)

    -- Rank System
    Ranks = {
        {
            name = "Rookie",
            minHits = 0,
            maxHits = 4,
            color = Color(150, 150, 150) -- Gray
        },
        {
            name = "Beginner",
            minHits = 5,
            maxHits = 14,
            color = Color(102, 204, 255) -- Light Blue
        },
        {
            name = "Amateur",
            minHits = 15,
            maxHits = 24,
            color = Color(255, 215, 0) -- Gold
        },
        {
            name = "Professional",
            minHits = 25,
            maxHits = 99,
            color = Color(255, 64, 64) -- Red
        },
        {
            name = "Master",
            minHits = 100,
            maxHits = math.huge,
            color = Color(138, 43, 226) -- Purple
        }
    },

    -- Job Restrictions
    RestrictedJobs = {
        ["Citizen"] = true,
        ["Civil Protection"] = true,
        ["Mayor"] = true
    },
    
    -- Hitman jobs (these jobs can complete hits but not place them)
    HitmanJobs = {
        ["medic"] = true,
        -- ["assassin"] = true,
    },

    -- Teams that cannot use the system at all
    DisallowedTeams = {
        -- ["TEAM_POLICE"] = true,
    },

    -- Categories that cannot use the system at all
    DisallowedCategories = {
        ["Civil Protection"] = true
    },

    -- Job-specific overrides
    JobOverrides = {
        -- Format: ["TEAM_JOBNAME"] = {
        --     canUseSystem = true,
        --     canPlaceContracts = true,
        --     canCompleteHits = false
        -- }

    },

    -- Debug Settings
    Debug = true, -- Set to true to enable debug features
    DebugBotCount = 12, -- Number of bots to spawn in debug mode

}

-- Utility function to check if a job is a hitman job
function rHitman.Config.isHitmanJob(jobName)
    return rHitman.Config.HitmanJobs[jobName] or false
end

-- Function to get job settings
function rHitman.Config.getJobSettings(team)
    if rHitman.Config.DisallowedTeams[team] then
        return {
            canUseSystem = false,
            canPlaceContracts = false,
            canCompleteHits = false
        }
    end

    if rHitman.Config.JobOverrides[team] then
        return rHitman.Config.JobOverrides[team]
    end

    -- If it's a hitman job, they can complete hits but not place them
    if rHitman.Config.isHitmanJob(team) then
        return {
            canUseSystem = true,
            canPlaceContracts = false,
            canCompleteHits = true
        }
    end

    -- Default settings
    return {
        canUseSystem = rHitman.Config.DefaultCanUseSystem,
        canPlaceContracts = rHitman.Config.DefaultCanPlaceContracts,
        canCompleteHits = rHitman.Config.DefaultCanCompleteHits
    }
end
