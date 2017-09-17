MsgC(Color(0, 255, 255), "======================== BASE STARTED ========================\n");

-- Base relies on sandbox elements.
DeriveGamemode("sandbox");

-- Use a reload hook that calls BEFORE files have been loaded.
if bash and bash.started then
    hook.Call("PreReload", bash);
end

-- Global table for bash elements.
bash = bash or {};
bash.startTime = SysTime();
bash.nonVolatile = bash.nonVolatile or {};

-- Refresh global table on restart.
bash.meta = {};
bash.services = {};
bash.plugins = {};
bash.volatile = {};
bash.clientData = {};

-- Random seed!
math.randomseed(os.time());

-- Include required base files.
include("core/cl_util.lua");
include("core/sh_const.lua");
include("core/sh_util.lua");
include("shared.lua");

-- Get rid of useless sandbox notifications.
timer.Remove("HintSystem_OpeningMenu");
timer.Remove("HintSystem_Annoy1");
timer.Remove("HintSystem_Annoy2");

-- Report startup time.
local len = math.Round(SysTime() - bash.startTime, 8);
MsgCon(color_green, "Successfully initialized base cient-side. Startup: %fs", len);
MsgCon(color_cyan, "======================== BASE COMPLETE ========================");
bash.started = true;

-- Handle sending initial client data.
hook.Add("InitPostEntity", "bash_sendClientData", function()
    sendClientData();
end);

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

-- Hooks for post-init.
MsgCon(color_green, "Gathering preliminary data...");
hook.Call("GatherPrelimData");  -- Add network variable structures, finalize DB structure, etc.
MsgCon(color_green, "Initializing services...")
hook.Call("InitService");       -- Connect to DB, load /data files, etc.

vnet.Watch("bash_test", function(pck)
    local data = pck:Table();
    MsgN("Data table: " .. tostring(data));
    MsgN("Data metatable: " .. tostring(getmetatable(data)));
    MsgN("Character metatable: " .. tostring(getMeta("Character")));
end);
