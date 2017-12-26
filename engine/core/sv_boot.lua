--[[
    Server-side boot procedure.
]]

-- Things that should be done on start, regardless of refresh or not.
local function miscInit()
    -- Random seed!
    math.randomseed(os.time());
end

-- Engine relies on sandbox elements.
DeriveGamemode("sandbox");

-- If there's a refresh, let 'em know.
if bash and bash.Started then
    bash.Util.MsgLog(LOG_WARN, "Gamemode is reloading!");
    hook.Call("OnReload");
end

-- Report engine startup.
MsgC(Color(0, 255, 255), "======================== ENGINE STARTED ========================\n");
miscInit();

-- Global table for bash elements.
bash = bash or {StartTime = SysTime()};
local bash = bash;
bash.RefreshTime = SysTime();
-- bash.Dev.DevMode = true;

-- Send files to server.
AddCSLuaFile("sh_const.lua");
AddCSLuaFile("sh_util.lua");
AddCSLuaFile("cl_util.lua");

-- Include required util/global table.
include("sh_const.lua");
include("sh_util.lua");
include("sv_util.lua");
include("sv_netpool.lua");

-- Things that should be done on engine start.
function bash.StartEngine()
    -- Include all other engine components.
    bash.Util.ProcessFile("sh_hook.lua");
    bash.Util.ProcessFile("sh_memory.lua");
    bash.Util.ProcessFile("sh_plugin.lua");
    bash.Util.ProcessFile("sh_schema.lua");
    bash.Util.ProcessFile("sv_resources.lua");
    bash.Util.ProcessDir("engine/external");
    bash.Util.ProcessDir("engine/hooks");
    bash.Util.ProcessDir("engine/libraries");

    -- Client data should persist.
    bash.ClientData = bash.Memory.GetNonVolatile("ClientData", EMPTY_TABLE);

    -- Hooks for init process.
    bash.Util.MsgLog(LOG_INIT, "Creating engine preliminary structures...");
    hook.Run("CreateStructures_Engine");
    bash.Util.MsgLog(LOG_INIT, "Starting engine sub-systems...");
    hook.Run("StartSystems_Engine");

    -- Report startup time.
    local len = math.Round(SysTime() - (bash.Started and bash.RefreshTime or bash.StartTime), 8);
    bash.Util.MsgLog(LOG_INIT, "Successfully %s engine server-side. Startup: %fs", (bash.Started and "refreshed" or "started"), len);
    bash.Started = true;

    bash.Util.MsgLog(LOG_INIT, "Calling engine post-init hooks...");
    hook.Run("PostInit_Engine");

    -- Load engine plugins.
    bash.Util.MsgLog(LOG_INIT, "Loading engine plugins...");
    bash.Plugins.Process();
end

-- Start the engine.
bash.StartEngine();
MsgC(color_cyan, "======================== ENGINE COMPLETE ========================\n");









bash.Testing = bash.TableNet.NewTable();
PrintTable(bash.Testing);
