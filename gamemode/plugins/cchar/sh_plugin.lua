--[[
    CChar plugin file.
]]

-- Start plugin definition.
definePlugin_start("CChar");

-- Plugin info.
PLUG.Name = "Core Character";
PLUG.Author = "LilSumac";
PLUG.Desc = "";
PLUG.Depends = {"CDatabase", "CTableNet", "CTask"};

-- Constants.
LOG_CHAR = {pre = "[CHAR]", col = Color(151, 0, 151, 255)};

-- Process plugin contents.
bash.Util.ProcessFile("sv_char.lua");
bash.Util.ProcessDir("hooks");

-- End plugin definition.
definePlugin_end();
