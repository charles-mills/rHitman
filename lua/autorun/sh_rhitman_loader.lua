--[[
    rHitman - A simple hitman system for Garry's Mod
    Author: Charles Mills
]]--

rHitman = rHitman or {}
rHitman.Version = "0.0.0"

local files = {
    ["shared"] = {
        "config/sh_config.lua",
        "core/sh_util.lua"
    },

    ["server"] = {
        "core/sv_core.lua",
        "core/sv_contracts.lua",
        "core/sv_networking.lua",
        "core/sv_debug.lua",
        "core/sv_hooks.lua"
    },

    ["client"] = {
        "core/cl_networking.lua",
        "core/cl_hud.lua",
        "ui/cl_menu.lua"
    }
}

-- Print loading message
local function printLoadMsg(realm, file)
    print(string.format("[rHitman] Loading %s file: %s", realm, file))
end

-- Load files based on realm
local function loadFiles(realm, fileList)
    for _, file in ipairs(fileList) do
        local path = "rhitman/" .. file
        printLoadMsg(realm, file)
        
        if realm == "shared" then
            AddCSLuaFile(path)
            include(path)
        elseif realm == "server" and SERVER then
            include(path)
        elseif realm == "client" then
            if SERVER then
                AddCSLuaFile(path)
            else
                include(path)
            end
        end
    end
end

-- Load all files
for realm, fileList in pairs(files) do
    loadFiles(realm, fileList)
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
