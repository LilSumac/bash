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
bash.util.ProcessFile("sv_ply.lua");
bash.util.ProcessDir("hooks");

-- End plugin definition.
definePlugin_end();
