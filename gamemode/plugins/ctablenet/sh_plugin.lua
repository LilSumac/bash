definePlugin_start("CTableNet");

PLUG.Name = "Core TableNet";
PLUG.Author = "LilSumac";
PLUG.Desc = "A framework for networking data tied to metatables across multiple variable domains.";
PLUG.Depends = {"CDatabase"};

processFile("services/sh_tablenet.lua");

definePlugin_end();
