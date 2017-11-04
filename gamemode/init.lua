--FProfiler.start();

-- Things that should be done, regardless of refresh or not.
local function miscInit()
    -- Random seed!
    math.randomseed(os.time());
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

-- Send required base files to client.
AddCSLuaFile("cl_init.lua");
AddCSLuaFile("core/cl_util.lua");
AddCSLuaFile("core/sh_const.lua");
AddCSLuaFile("core/sh_util.lua");
AddCSLuaFile("shared.lua");

-- Refresh/init util table.
bash.Util = {};
include("core/sh_const.lua");
include("core/sh_util.lua");
include("core/sv_util.lua");
include("core/sv_netpool.lua");
include("core/sv_resources.lua");

-- Client data should persist.
bash.ClientData = bash.Util.GetNonVolatileEntry("ClientData", EMPTY_TABLE);

-- Refresh/init main components.
bash.Meta = {};
bash.Plugins = {};
include("shared.lua");

-- Hooks for init process.
MsgLog(LOG_INIT, "Gathering base preliminary data...");
hook.Run("GatherPrelimData_Base");
MsgLog(LOG_INIT, "Initializing base services...");
hook.Run("InitService_Base");

-- Report startup time.
local len = math.Round(SysTime() - bash.StartTime, 8);
MsgLog(LOG_INIT, "Successfully initialized base server-side.  Startup: %fs", len);
bash.Started = true;

MsgLog(LOG_DEF, "Doing base post-init calls...");
hook.Run("PostInit_Base");

MsgC(color_cyan, "======================== BASE COMPLETE ========================\n");


// testing
concommand.Add("bench", function(ply, cmd, args)
    local tabnet = getPlugin("CTableNet");
    for i = 1, 100 do
        tabnet:NewTable("Char");
    end
end);
