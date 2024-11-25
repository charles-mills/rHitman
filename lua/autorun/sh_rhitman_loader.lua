--[[
    rHitman - A simple hitman system for Garry's Mod
    Author: Charles Mills

    File Structure and Purpose:

    /config
        sh_config.lua      - Shared configuration file containing all adjustable settings and job configurations
    
    /core
        -- Shared Files
        sh_util.lua        - Shared utility functions for permission checks and common operations
        sh_contracts.lua   - Core contract functionality shared between client and server
        
        -- Server Files
        sv_networking.lua  - Server-side networking and command handling
        sv_contracts.lua   - Server-side contract management (creation, completion, deletion)
        sv_core.lua        - Core server functionality and hook management
        sv_debug.lua       - Debug tools and bot testing functionality
        sv_random_hits.lua - Automatic random hit generation system
        
        -- Client Files
        cl_networking.lua  - Client-side networking and command handling
        cl_hud.lua        - HUD elements for displaying active contract info
        cl_stats.lua      - Client-side statistics tracking and management
        
    /ui
        -- Client UI Files
        cl_fonts.lua          - Font definitions and management
        cl_ui_utils.lua       - Shared UI utilities and helper functions
        cl_menu.lua           - Main menu framework and navigation
        cl_contractlist.lua   - Available contracts list view
        cl_contractcreate.lua - Contract creation interface
        cl_contractdetails.lua- Individual contract details view
        cl_statslist.lua      - Statistics and leaderboard interface
]]--

rHitman = rHitman or {}
rHitman.Version = "0.0.0"

-- File groups
local files = {
    ["shared"] = {
        "config/sh_config.lua",
        "core/sh_util.lua",
        "core/sh_contracts.lua"
    },
    
    ["server"] = {
        "core/sv_networking.lua",
        "core/sv_contracts.lua",
        "core/sv_core.lua",
        "core/sv_debug.lua",
        "core/sv_random_hits.lua"
    },
    
    ["client"] = {
        "core/cl_networking.lua",
        "ui/cl_fonts.lua",
        "ui/cl_ui_utils.lua",
        "core/cl_hud.lua",
        "core/cl_stats.lua",
        "ui/cl_menu.lua",
        "ui/cl_contractlist.lua",
        "ui/cl_contractcreate.lua",
        "ui/cl_contractdetails.lua",
        "ui/cl_statslist.lua"
    }
}

-- Print loading message
local function printLoadMsg(realm, file)
    MsgC(Color(220, 50, 50), "[rHitman] ", Color(255, 255, 255), "Loading " .. realm .. " file: " .. file .. "\n")
end

-- Load shared files first
for _, file in ipairs(files.shared) do
    local path = "rhitman/" .. file
    if SERVER then
        printLoadMsg("shared", file)
        AddCSLuaFile(path)
        include(path)
    end
    if CLIENT then
        printLoadMsg("shared", file)
        include(path)
    end
end

-- Then load realm-specific files
if SERVER then
    for _, file in ipairs(files.server) do
        printLoadMsg("server", file)
        include("rhitman/" .. file)
    end
    
    for _, file in ipairs(files.client) do
        printLoadMsg("client", file)
        AddCSLuaFile("rhitman/" .. file)
    end
end

if CLIENT then
    -- Ensure config is loaded before UI
    hook.Add("InitPostEntity", "rHitman_LoadUI", function()
        -- Small delay to ensure config is fully loaded
        timer.Simple(0.1, function()
            for _, file in ipairs(files.client) do
                printLoadMsg("client", file)
                include("rhitman/" .. file)
            end
            
            -- Notify that UI is ready
            hook.Run("rHitman_UIReady")
        end)
    end)
end

-- Initialize the addon
hook.Add("Initialize", "rHitman_Initialize", function()
    print("[rHitman] Loaded successfully!")
end)

if CLIENT then
    -- Add console command to open menu
    concommand.Add("rhitman_menu", function()
        if not rHitman.Util.canUseSystem(LocalPlayer()) then
            rHitman.Util.notify(LocalPlayer(), "You are not authorized to use the hitman system!", NOTIFY_ERROR)
            return
        end
        
        -- Close existing menu if it exists
        if IsValid(rHitman.Menu) then
            rHitman.Menu:Remove()
        end
        
        -- Create new menu
        rHitman.Menu = vgui.Create("rHitman_Menu")
    end)
else
    -- Add chat commands
    hook.Add("PlayerSay", "rHitman_ChatCommands", function(ply, text)
        local cmd = string.lower(text)
        
        if cmd == "!hits" or cmd == "!rhits" or cmd == "/hits" then
            if not rHitman.Util.canUseSystem(ply) then
                rHitman.Util.notify(ply, "You are not authorized to use the hitman system!", NOTIFY_ERROR)
                return ""
            end
            
            -- Use timer to ensure command runs after chat message
            timer.Simple(0, function()
                if IsValid(ply) then
                    net.Start("rHitman_RequestContracts")
                    net.Send(ply)
                end
            end)
            
            return ""
        end
    end)
end

print("[rHitman] Addon loaded successfully! Version: " .. rHitman.Version)
