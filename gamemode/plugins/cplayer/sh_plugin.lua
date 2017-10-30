--[[
    CPlayer plugin file.
]]

definePlugin_start("CPlayer");

-- Plugin info.
PLUG.Name = "Core Player";
PLUG.Author = "LilSumac";
PLUG.Desc = "A framework that handles all player-related functionalities.";
PLUG.Depends = {"CDatabase", "CTableNet", "CTask"};

if SERVER then
    -- Network pool.
    util.AddNetworkString("CPlayer_Net_RespondClient");
end

-- Process plugin contents.
processDir("hooks");
processService();

definePlugin_end();
