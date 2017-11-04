--[[
    CTableNet plugin file.
]]

-- Start plugin definition.
definePlugin_start("CTableNet");

-- Plugin info.
PLUG.Name = "Core TableNet";
PLUG.Author = "LilSumac";
PLUG.Desc = "A framework for networking data tied to metatables across multiple variable domains.";
PLUG.Depends = {"CDatabase"};

--
-- Constants.
--

-- Logging option.
LOG_TABNET = {pre = "[TABNET]", col = color_darkgreen};

-- Table status flags.
TAB_INIT = 1;
TAB_DEINIT = 2;

--
-- Misc. operations.
--

-- Custom errors.
bash.Util.AddErrType("TableNotRegistered", "This table has not been registered in TableNet! (%s)");
bash.Util.AddErrType("NoDomainInTable", "No domain with that ID exists in that table! (%s -> %s)");
bash.Util.AddErrType("MultiSingleTable", "Tried to create a single table when one already exists! (%s)");

if SERVER then
    -- Network pool.
    util.AddNetworkString("CTableNet_Net_RegSend");
    util.AddNetworkString("CTableNet_Net_RegSendAck");
    util.AddNetworkString("CTableNet_Net_ObjUpdate");
    util.AddNetworkString("CTableNet_Net_ObjRequest");
    util.AddNetworkString("CTableNet_Net_ObjOutOfScope");
end

-- Add main payloads.
bash.Util.ProcessDir("hooks");
bash.Util.ProcessFile("sh_tablenet.lua");
bash.Util.ProcessFile("sv_tablenet.lua");

-- End plugin definition.
definePlugin_end();
