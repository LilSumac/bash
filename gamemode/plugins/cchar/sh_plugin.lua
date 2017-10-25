definePlugin_start("CChar");

PLUG.Name = "Core Character";
PLUG.Author = "LilSumac";
PLUG.Desc = "";
PLUG.Depends = {"CDatabase", "CTableNet"};

-- Constants.
LOG_CHAR = {pre = "[CHAR]", col = Color(151, 0, 151, 255)};

-- Process plugin files.
processDir("hooks");
processDir("meta");
processFile("services/sh_char.lua");

definePlugin_end();
