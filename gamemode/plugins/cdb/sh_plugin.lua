--[[
    CDatabase plugin file.
]]

definePlugin_start("CDatabase");

-- Plugin info.
PLUG.Name = "Core Database";
PLUG.Author = "LilSumac";
PLUG.Desc = "A framework that interfaces with an external SQL database.";

-- Process plugin contents.
processDir("hooks");
processService();

definePlugin_end();
