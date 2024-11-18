--[[
    rHitman - Configuration
    Contains all configurable options for the addon
]]--

rHitman.Config = {
    -- System defaults
    DefaultCanUseSystem = true,
    DefaultCanPlaceContracts = true,
    DefaultCanCompleteHits = false,

    -- Contract settings
    MinimumHitPrice = 1000,
    MaximumHitPrice = 1000000,
    ContractDuration = 3600, -- 1 hour in seconds
    ContractCooldown = 300, -- 5 minutes between contracts
    PaymentOnCompletion = true,
    RequireEvidence = true,

    -- HUD Settings
    HUDEnabled = true,
    ShowHealth = true,
    ShowArmor = true,
    ShowCompass = true,
    CompassSize = 200,
    HUDScale = 1,
    HUDColor = Color(255, 100, 100),
    HUDPosition = {
        x = 20,
        y = 20
    },
    
    -- HUD Animation Settings
    HUDFadeSpeed = 5, -- Speed at which HUD fades out
    HUDCompletionAnimTime = 3, -- Duration of completion animation in seconds
    HUDCompletionHoldTime = 2, -- How long to show completion message before fading
    HUDFastFadeSpeed = 15, -- Speed for quick fade outs (like on death)

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

    }
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
