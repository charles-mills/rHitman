--[[
    rHitman - Font Definitions
    Defines all fonts used in the UI
]]--

-- Font definitions
local fontDefs = {
    -- Title fonts
    ["rHitman.Title"] = {
        size = 24,
        weight = "Bold"
    },
    
    -- Text fonts
    ["rHitman.Text"] = {
        size = 16,
        weight = "Medium"
    },
    ["rHitman.Text.Small"] = {
        size = 14,
        weight = "Normal"
    },
    ["rHitman.Text.Large"] = {
        size = 18,
        weight = "Medium"
    },
    
    -- HUD fonts
    ["rHitman.HUD.Header"] = {
        size = 22,
        weight = "Bold"
    },
    ["rHitman.HUD.Title"] = {
        size = 20,
        weight = "Medium"
    },
    ["rHitman.HUD.Small"] = {
        size = 14,
        weight = "Normal"
    },
    ["rHitman.HUD.Complete"] = {
        size = 32,
        weight = "ExtraBold"
    }
}

-- Track created fonts to avoid recreation
local createdFonts = {}

-- Function to create all fonts
local function CreateFonts()
    -- Get font family from UI utils
    local fontFamily = rHitman.UI.GetFontFamily()
    
    -- Create each font
    for fontName, def in pairs(fontDefs) do
        -- Generate a unique key for this font configuration
        local configKey = string.format("%s_%s_%d_%s", 
            fontName, 
            fontFamily, 
            def.size, 
            def.weight
        )
        
        -- Only create if not already created with this exact configuration
        if not createdFonts[configKey] then
            surface.CreateFont(fontName, {
                font = fontFamily,
                size = def.size,
                weight = rHitman.UI.Fonts.Weights[def.weight],
                antialias = true
            })
            
            createdFonts[configKey] = true
            print("[rHitman] Created font:", fontName)
        end
    end
end

-- Create fonts when the file is loaded
timer.Simple(0, function()
    -- Make sure UI utils are loaded first
    if not rHitman.UI or not rHitman.UI.GetFontFamily then
        ErrorNoHalt("[rHitman] Failed to create fonts: UI utilities not loaded\n")
        return
    end
    
    CreateFonts()
end)

-- Recreate fonts when screen resolution changes
hook.Add("OnScreenSizeChanged", "rHitman.RecreateUIFonts", function()
    -- Clear the cache so fonts will be recreated with new screen size
    table.Empty(createdFonts)
    CreateFonts()
end)
