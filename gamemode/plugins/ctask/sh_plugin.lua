definePlugin_start("CTask");

PLUG.Name = "Core Task";
PLUG.Author = "LilSumac";
PLUG.Desc = "Simple framework for implementing code-based tasks with progress, feedback, and callbacks.";
PLUG.Depends = {};

-- Constants.
LOG_TASK = {pre = "[TASK]", col = Color(151, 0, 151, 255)};

TASK_NUMERIC = 0;
TASK_TIMED = 1;
TASK_OTHER = 2;

STATUS_PAUSED = 0;
STATUS_RUNNING = 1;
STATUS_SUCCESS = 2;
STATUS_FAILED = 3;

-- Custom errors.
addErrType("TaskNotActive", "No task with that ID is active! (%s)");
addErrType("TaskNotValid", "This task does not have a RegistryID! Use the library create function! (%s)");
addErrType("TaskAlreadyRunning", "Only one instance of this task can be active at a time! (%s running on %s)");

if SERVER then
    -- Network pool.
    util.AddNetworkString("CTask_Net_SendTask");
    util.AddNetworkString("CTask_Net_UpdateTask");
end

-- Process plugin files.
processDir("meta");
processDir("services");

definePlugin_end();
