definePlugin_start("CPlayer");

PLUG.Name = "Core Player";
PLUG.Author = "LilSumac";
PLUG.Desc = "A framework that handles all player-related functionalities.";
PLUG.Depends = {"CDatabase", "CTableNet"};

processDir("hooks");
processFile("services/sh_ply.lua");

definePlugin_end();
