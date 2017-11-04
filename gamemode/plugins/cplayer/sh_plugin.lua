--[[
    CPlayer plugin file.
]]

-- Start plugin definition.
definePlugin_start("CPlayer");

-- Plugin info.
PLUG.Name = "Core Player";
PLUG.Author = "LilSumac";
PLUG.Desc = "A framework that handles all player-related functionalities.";
PLUG.Depends = {"CDatabase", "CTableNet", "CTask"};

-- Process plugin contents.
bash.Util.ProcessFile("sv_ply.lua");
bash.Util.ProcessDir("hooks");

-- End plugin definition.
definePlugin_end();
