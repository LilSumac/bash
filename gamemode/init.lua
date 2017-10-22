-- Things that should be done, regardless of restart or JIT or whatever.
local function miscInit()
    -- Random seed!
    math.randomseed(os.time());
end

-- Base relies on sandbox elements.
DeriveGamemode("sandbox");

-- For now, we wil not be supporting JIT updates. However,
-- there is an OnReload hook to use.
if bash and bash.started then
    MsgC(Color(0, 151, 255, 255), "Full JIT refreshes are not supported right now. Restart the server to apply any changes made.\n");
    miscInit();
    hook.Run("OnReload", bash);
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

-- Send required base files to client.
AddCSLuaFile("cl_init.lua");
AddCSLuaFile("core/cl_util.lua");
AddCSLuaFile("core/sh_const.lua");
AddCSLuaFile("core/sh_util.lua");
AddCSLuaFile("shared.lua");

-- Include required base files.
include("core/sh_const.lua");
include("core/sh_util.lua");
include("core/sv_netpool.lua");
include("shared.lua");

-- Client data should persist.
bash.clientData = getNonVolatileEntry("ClientData", EMPTY_TABLE);

-- Hooks for init process.
MsgLog(LOG_INIT, "Gathering base preliminary data...");
hook.Run("GatherPrelimData_Base");
MsgLog(LOG_INIT, "Initializing base services...");
hook.Run("InitService_Base");

-- Report startup time.
local len = math.Round(SysTime() - bash.startTime, 8);
MsgLog(LOG_INIT, "Successfully initialized base server-side.  Startup: %fs", len);
bash.started = true;

MsgLog(LOG_DEF, "Doing base post-init calls...");
hook.Run("PostInit_Base");

MsgC(color_cyan, "======================== BASE COMPLETE ========================\n");
