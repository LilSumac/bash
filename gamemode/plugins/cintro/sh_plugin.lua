--[[
    CIntro plugin file.
]]

-- Start plugin definition.
definePlugin_start("CIntro");

-- Plugin info.
PLUG.Name = "Core Intro";
PLUG.Author = "LilSumac";
PLUG.Desc = "Implements a task-based intro sequence with multiple stages.";
PLUG.Depends = {"CTask"};

-- Process plugin contents.
bash.Util.ProcessDir("hooks");

-- End plugin definition.
definePlugin_end();
