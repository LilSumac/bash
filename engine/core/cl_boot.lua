--[[
    Client-side boot procedure.
]]

-- Things that should be done on start, regardless of refresh or not.
local function miscInit()
    -- Random seed!
    math.randomseed(os.time());

    -- Get rid of useless sandbox notifications.
    timer.Remove("HintSystem_OpeningMenu");
    timer.Remove("HintSystem_Annoy1");
    timer.Remove("HintSystem_Annoy2");

    -- Create default fonts.
    -- TODO: Replace with a function. Utility?
    surface.CreateFont("bash-regular", {
		font = "Aileron Thin",
		size = 24,
        shadow = true,
        antialias = true
        --weight = 300
	});
end

-- Base relies on sandbox elements.
DeriveGamemode("sandbox");

-- If there's a refresh, let 'em know.
if bash and bash.Started then
    bash.Util.MsgLog(LOG_WARN, "Gamemode is reloading!");
    hook.Call("OnReload");
end

-- Report base startup.
MsgC(Color(0, 255, 255), "======================== BASE STARTED ========================\n");
miscInit();

-- Global table for bash elements.
bash = bash or {};
bash.StartTime = SysTime();
-- bash.Dev.DevMode = true;

-- Include required util/global table.
include("sh_const.lua");
include("sh_util.lua");
include("cl_util.lua");

-- Include all other engine components.
include("sh_hook.lua");
include("sh_memory.lua");
include("sh_plugin.lua");
bash.Util.ProcessDir("external");
bash.Util.ProcessDir("hooks");
bash.Util.ProcessDir("libraries");

-- Things that should be done on engine start.
function bash.EngineStart()
    -- Materials should persist.
    bash.Materials = bash.Memory.GetNonVolatile("CachedMaterials", EMPTY_TABLE);

    -- Add default client data.
    bash.Util.AddClientData("Country", system.GetCountry);
    bash.Util.AddClientData("OS", function()
        if system.IsWindows() then
            return OS_WIN;
        elseif system.IsWindows() then
            return OS_OSX;
        elseif system.IsLinux() then
            return OS_LIN;
        else
            return OS_UNK;
        end
    end);

    -- Hooks for init process.
    bash.Util.MsgLog(LOG_INIT, "Creating engine preliminary structures...");
    hook.Call("CreateStructures_Engine");
    bash.Util.MsgLog(LOG_INIT, "Starting engine sub-systems...");
    hook.Call("StartSystems_Engine");

    -- Report startup time.
    local len = math.Round(SysTime() - bash.StartTime, 8);
    bash.Util.MsgLog(LOG_INIT, "Successfully started engine client-side. Startup: %fs", len);
    bash.Started = true;

    bash.Util.MsgLog(LOG_DEF, "Calling engine post-init hooks...");
    hook.Call("PostInit_Engine");
end

-- Start the engine.
bash.EngineStart();
MsgC(color_cyan, "======================== BASE COMPLETE ========================\n");


// testing
--[[
local str = "The quick brown fox jumps over the lazy dog.";
local font = "bash-regular";
hook.Remove("HUDPaint", "asdf");
hook.Add("HUDPaint", "asdf", function()
    surface.SetFont(font);
    local x, y = surface.GetTextSize(str);
    draw.RoundedBox(0, CENTER_X, CENTER_Y, x + 8, y + 8, color_grey);
    draw.SimpleText(
        str, font,
        CENTER_X + 4, CENTER_Y + 4, color_white,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_white
    );
end);
]]
