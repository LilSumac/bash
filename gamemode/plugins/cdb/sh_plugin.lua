definePlugin_start("CDatabase");

PLUG.Name = "Core Database";
PLUG.Author = "LilSumac";
PLUG.Desc = "A framework that interfaces with an external SQL database.";

processDir("hooks");
processFile("services/sv_db.lua");

definePlugin_end();
