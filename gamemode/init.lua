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
MsgCon(color_green, "Gathering preliminary data...");
hook.Run("GatherPrelimData_Base"); -- For all prelims that MUST come first.
hook.Run("GatherPrelimData");      -- Add network variable structures, finalize DB structure, etc.
MsgCon(color_green, "Initializing services...");
hook.Run("InitService_Base");      -- For all inits that MUST come first.
hook.Run("InitService");           -- Connect to DB, load /data files, etc.
MsgCon(color_green, "Doing post-init calls...");
hook.Run("PostInit_Base");         -- For all post-inits that MUST come first.
hook.Run("PostInit");              -- Finish up.

-- Report startup time.
local len = math.Round(SysTime() - bash.startTime, 8);
MsgCon(color_green, "Successfully initialized base server-side.  Startup: %fs", len);
MsgCon(color_cyan, "======================== BASE COMPLETE ========================");
bash.started = true;
