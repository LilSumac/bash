-- Base relies on sandbox elements.
DeriveGamemode("sandbox");

-- Global table for bash elements.
bash = bash or {};
bash.startTime = SysTime();
bash.nonVolatile = bash.nonVolatile or {};

-- Refresh global table on restart.
do
    bash.services = {};
    bash.plugins = {};
    bash.volatile = {};
end

-- Random seed!
math.randomseed(os.time());

-- Send required base files to client.
AddCSLuaFile("cl_init.lua");
AddCSLuaFile("core/sh_const.lua");
AddCSLuaFile("core/sh_util.lua");
AddCSLuaFile("shared.lua");

-- Include required base files.
include("core/sh_const.lua");
include("core/sh_util.lua");
include("shared.lua");

-- Report startup time.
local len = math.Round(SysTime() - bash.startTime, 8);
MsgCon(color_green, "Successfully initialized server-side. Startup: %fs", len);
