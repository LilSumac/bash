--[[
    CTableNet plugin file.
]]

definePlugin_start("CTableNet");

-- Plugin info.
PLUG.Name = "Core TableNet";
PLUG.Author = "LilSumac";
PLUG.Desc = "A framework for networking data tied to metatables across multiple variable domains.";
PLUG.Depends = {"CDatabase"};

-- Constants.
LOG_TABNET = {pre = "[TABNET]", col = color_darkgreen};
LISTEN_PUBLIC = 1;
LISTEN_PRIVATE = 2;

-- Custom errors.
addErrType("TableNotRegistered", "This table has not been registered in TableNet! (%s)");
addErrType("NoDomainInTable", "No domain with that ID exists in that table! (%s -> %s)");
addErrType("MultiSingleTable", "Tried to create a single table when one already exists! (%s)");

if SERVER then
    -- Network pool.
    util.AddNetworkString("CTableNet_Net_RegSend");
    util.AddNetworkString("CTableNet_Net_RegSendAck");
    util.AddNetworkString("CTableNet_Net_ObjUpdate");
    util.AddNetworkString("CTableNet_Net_ObjRequest");
    util.AddNetworkString("CTableNet_Net_ObjOutOfScope");
end

-- Add main payloads.
processDir("hooks");
processService();

definePlugin_end();
