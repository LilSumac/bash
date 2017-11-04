--[[
    CTask plugin file.
]]

-- Start plugin definition.
definePlugin_start("CTask");

-- Plugin info.
PLUG.Name = "Core Task";
PLUG.Author = "LilSumac";
PLUG.Desc = "Simple framework for implementing code-based tasks with progress, feedback, and callbacks.";
PLUG.Depends = {"CTableNet"};

--
-- Constants.
--

-- Logging option.
LOG_TASK = {pre = "[TASK]", col = Color(151, 0, 151, 255)};

-- Task types.
TASK_NUMERIC = 0;
TASK_TIMED = 1;
TASK_OTHER = 2;

-- Task statuses.
STATUS_PAUSED = 0;
STATUS_RUNNING = 1;
STATUS_SUCCESS = 2;
STATUS_FAILED = 3;

--
-- Misc. operations.
--

-- Custom errors.
bash.Util.AddErrType("TaskNotActive", "No task with that ID is active! (%s)");
bash.Util.AddErrType("TaskNotValid", "This task does not have a RegistryID! Use the library create function! (%s)");
bash.Util.AddErrType("TaskAlreadyRunning", "Only one instance of this task can be active at a time! (%s running on %s)");

-- Process plugin contents.
bash.Util.ProcessFile("sh_task.lua");
bash.Util.ProcessDir("meta");
bash.Util.ProcessDir("hooks");

-- End plugin definition.
definePlugin_end();
