-- Things that should be done, regardless of refresh or not.
local function miscInit()
    -- Random seed!
    math.randomseed(os.time());

    -- Get rid of useless sandbox notifications.
    timer.Remove("HintSystem_OpeningMenu");
    timer.Remove("HintSystem_Annoy1");
    timer.Remove("HintSystem_Annoy2");

    -- Create default fonts.
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
    MsgLog(LOG_WARN, "Gamemode is reloading!");
    hook.Run("OnReload");
end

-- Report base startup.
MsgC(Color(0, 255, 255), "======================== BASE STARTED ========================\n");
miscInit();

-- Global table for bash elements.
bash = bash or {};
bash.StartTime = SysTime();
bash.DebugMode = true;
bash.NonVolatile = bash.NonVolatile or {};

-- Refresh/init util table.
bash.Util = {};
include("core/sh_const.lua");
include("core/sh_util.lua");
include("core/cl_util.lua");

-- Materials should persist.
bash.Materials = bash.Util.GetNonVolatileEntry("CachedMaterials", EMPTY_TABLE);

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

-- Refresh/init main components.
bash.Meta = {};
bash.Plugins = {};
include("shared.lua");

-- Hooks for init process.
MsgLog(LOG_INIT, "Gathering base preliminary data...");
hook.Run("GatherPrelimData_Base");
MsgLog(LOG_INIT, "Doing base init calls...");
hook.Run("InitCalls_Base");

-- Report startup time.
local len = math.Round(SysTime() - bash.StartTime, 8);
MsgLog(LOG_INIT, "Successfully initialized base client-side. Startup: %fs", len);
bash.Started = true;

MsgLog(LOG_DEF, "Doing base post-init calls...");
hook.Run("PostInitCalls_Base");

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
