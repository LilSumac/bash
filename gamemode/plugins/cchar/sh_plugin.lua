definePlugin_start("CChar");

PLUG.Name = "Core Character";
PLUG.Author = "LilSumac";
PLUG.Desc = "";
PLUG.Depends = {};

-- Constants.
LOG_CHAR = {pre = "[CHAR]", col = Color(151, 0, 151, 255)};

-- Process plugin files.
processDir("meta");
processDir("services");

definePlugin_end();
