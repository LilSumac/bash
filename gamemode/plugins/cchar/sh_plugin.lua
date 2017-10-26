--[[
    CChar plugin file.
]]

definePlugin_start("CChar");

-- Plugin info.
PLUG.Name = "Core Character";
PLUG.Author = "LilSumac";
PLUG.Desc = "";
PLUG.Depends = {"CDatabase", "CTableNet"};

-- Constants.
LOG_CHAR = {pre = "[CHAR]", col = Color(151, 0, 151, 255)};

-- Process plugin contents.
processDir("hooks");
processMeta();
processService();

definePlugin_end();
