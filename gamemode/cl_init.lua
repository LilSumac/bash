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
include("core/sh_const.lua");
include("core/sh_util.lua");
include("shared.lua");

-- Get rid of useless sandbox notifications.
timer.Remove("HintSystem_OpeningMenu");
timer.Remove("HintSystem_Annoy1");
timer.Remove("HintSystem_Annoy2");

-- Report startup time.
local len = math.Round(SysTime() - bash.startTime, 8);
MsgCon(color_green, "Successfully initialized base client-side. Startup: %fs", len);
bash.started = true

-- Handle sending client data.
hook.Add("InitPostEntity", "bash_sendClientData", function()
    local send = vnet.CreatePacket("bash_sendClientData");
    local data = {};
    for id, generate in pairs(bash.clientData) do
        if type(generate) == "function" then
            data[id] = generate();
        else
            data[id] = generate;
        end
    end

    send:Table(data);
    send:AddServer();
    send:Send();
end);
