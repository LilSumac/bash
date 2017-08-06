-- Base relies on sandbox elements.
DeriveGamemode("sandbox");

-- Global table for bash elements.
bash = bash or {};
bash.startTime = SysTime();
bash.nonVolatile = bash.nonVolatile or {};

-- Refresh global table on restart.
do
    bash.meta = {};
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
MsgCon(color_green, "Successfully initialized base server-side.  Startup: %fs", len);



local cchar = getService("CCharacter");
local test = cchar:Instantiate("testing");
MsgN(test)
PrintTable(test);
test:Set{
    ["Name"] = "Search",
    ["Desc"] = "asdfasdfasfdasdf",
    ["Bing"] = "test1",
    ["Bong"] = "fugg"
};

PrintTable(test);

local name, desc = test:Get{"Name", "Bing"};
MsgN(name .. " " .. desc);
