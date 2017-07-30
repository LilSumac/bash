-- Base relies on sandbox elements.
DeriveGamemode("sandbox");
-- Global table for bash elements.
bash = bash or {};
bash.startTime = SysTime();

-- Random seed!
math.randomseed(os.time());

-- Include required base files.
include("core/sh_const.lua");
include("core/sh_util.lua");
include("shared.lua");

-- Get rid of useless sandbox notifications.
timer.Remove("HintSystem_OpeningMenu");
timer.Remove("HintSystem_Annoy1");
timer.Remove("HintSystem_Annoy2");

-- Report startup time.
local len = math.Round(SysTime() - bash.startTime, 8);
MsgCon(color_green, "Successfully initialized client-side. Startup: %fs", len);
