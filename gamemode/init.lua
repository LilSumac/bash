MsgC(Color(0, 255, 255), "======================== BASE STARTED ========================\n");

-- Base relies on sandbox elements.
DeriveGamemode("sandbox");

-- Use a reload hook that calls BEFORE files have been loaded.
if bash and bash.started then
    hook.Call("PreReload", bash);
end

-- Global table for bash elements.
bash = bash or {};
bash.IsValid = function() return true; end
bash.startTime = SysTime();
bash.nonVolatile = bash.nonVolatile or {};

-- Refresh global table on restart.
bash.meta = {};
bash.services = {};
bash.plugins = {};
bash.volatile = {};

-- Random seed!
math.randomseed(os.time());

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

-- Report startup time.
local len = math.Round(SysTime() - bash.startTime, 8);
MsgCon(color_green, "Successfully initialized base server-side.  Startup: %fs", len);
MsgCon(color_cyan, "======================== BASE COMPLETE ========================");
bash.started = true;

-- Handle catching client data.
bash.clientData = getNonVolatileEntry("ClientData", EMPTY_TABLE);
vnet.Watch("bash_sendClientData", function(pck)
    local ply = pck.Source;
    local data = pck:Table();
    bash.clientData = bash.clientData or {};
    bash.clientData[ply:EntIndex()] = data;
end);

-- Hooks for post-init.
MsgCon(color_green, "Gathering preliminary data...");
hook.Call("GatherPrelimData");  -- Add network variable structures, finalize DB structure, etc.
MsgCon(color_green, "Initializing services...")
hook.Call("InitService");       -- Connect to DB, load /data files, etc.
