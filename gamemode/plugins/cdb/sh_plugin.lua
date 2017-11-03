--[[
    CDatabase plugin file.
]]

-- Start plugin definition.
definePlugin_start("CDatabase");

-- Plugin info.
PLUG.Name = "Core Database";
PLUG.Author = "LilSumac";
PLUG.Desc = "A framework that interfaces with an external SQL database.";

-- Process plugin contents.
bash.Util.ProcessDir("config");
bash.Util.ProcessFile("sv_db.lua");
bash.Util.ProcessDir("hooks");

-- End plugin definition.
definePlugin_end();
