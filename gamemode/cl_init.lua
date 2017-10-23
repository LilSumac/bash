-- Things that should be done, regardless of restart or JIT or whatever.
local function miscInit()
    -- Random seed!
    math.randomseed(os.time());

    -- Get rid of useless sandbox notifications.
    timer.Remove("HintSystem_OpeningMenu");
    timer.Remove("HintSystem_Annoy1");
    timer.Remove("HintSystem_Annoy2");
end

-- Base relies on sandbox elements.
DeriveGamemode("sandbox");

-- For now, we wil not be supporting JIT updates. However,
-- there is an OnReload hook to use.
if bash and bash.started then
    miscInit();
    hook.Run("bash_OnReload", bash);
    return;
end

MsgC(Color(0, 255, 255), "======================== BASE STARTED ========================\n");

-- Global table for bash elements.
bash = bash or {};
bash.IsValid = function() return true; end
bash.startTime = SysTime();
bash.nonVolatile = bash.nonVolatile or {};

-- Refresh global table on restart.
bash.meta = {};
bash.services = {};
bash.plugins = {};

-- Include required base files.
include("core/cl_util.lua");
include("core/sh_const.lua");
include("core/sh_util.lua");
include("shared.lua");

-- Add default client data.
addClientData("Country", system.GetCountry);
addClientData("OS", function()
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
MsgLog(LOG_INIT, "Gathering base preliminary data...");
hook.Run("bash_GatherPrelimData_Base");
MsgLog(LOG_INIT, "Initializing base services...");
hook.Run("bash_InitService_Base");

-- Report startup time.
local len = math.Round(SysTime() - bash.startTime, 8);
MsgLog(LOG_INIT, "Successfully initialized base client-side. Startup: %fs", len);
bash.started = true;

MsgLog(LOG_DEF, "Doing base post-init calls...");
hook.Run("bash_PostInit_Base");

MsgC(color_cyan, "======================== BASE COMPLETE ========================\n");
