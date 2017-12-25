--[[
    Server-side boot procedure.
]]

-- Things that should be done on start, regardless of refresh or not.
local function miscInit()
    -- Random seed!
    math.randomseed(os.time());
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
local bash = bash;
bash.StartTime = SysTime();
-- bash.Dev.DevMode = true;

-- Send files to server.
AddCSLuaFile("sh_const.lua");
AddCSLuaFile("sh_util.lua");
AddCSLuaFile("cl_util.lua");
AddCSLuaFile("sh_hook.lua");
AddCSLuaFile("sh_memory.lua");
AddCSLuaFile("sh_plugin.lua");

-- Include required util/global table.
include("sh_const.lua");
include("sh_util.lua");
include("sv_util.lua");
include("sv_netpool.lua");

-- Include all other engine components.
include("sh_hook.lua");
include("sh_memory.lua");
include("sh_plugin.lua");
include("sv_resources.lua");
bash.Util.ProcessDir("external");
bash.Util.ProcessDir("hooks");
bash.Util.ProcessDir("libraries");

-- Things that should be done on engine start.
function bash.EngineStart()
    -- Client data should persist.
    bash.ClientData = bash.Memory.GetNonVolatile("ClientData", EMPTY_TABLE);

    -- Hooks for init process.
    bash.Util.MsgLog(LOG_INIT, "Creating engine preliminary structures...");
    hook.Call("CreateStructures_Engine");
    bash.Util.MsgLog(LOG_INIT, "Starting engine sub-systems...");
    hook.Call("StartSystems_Engine");

    -- Report startup time.
    local len = math.Round(SysTime() - bash.StartTime, 8);
    bash.Util.MsgLog(LOG_INIT, "Successfully started engine server-side. Startup: %fs", len);
    bash.Started = true;

    bash.Util.MsgLog(LOG_DEF, "Calling engine post-init hooks...");
    hook.Call("PostInit_Engine");
end

-- Start the engine.
bash.EngineStart();
MsgC(color_cyan, "======================== BASE COMPLETE ========================\n");
