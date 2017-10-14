defineService_start("CTask");

-- Service info.
SVC.Name = "CTask";
SVC.Author = "LilSumac";
SVC.Desc = "Simple framework for implementing code-based tasks with progress, feedback, and callbacks.";

-- Constants.
TASK_NUMERIC = 0;
TASK_TIMED = 1;
TASK_OTHER = 2;

-- Service storage.
local tasks = {};
local activeTasks = getNonVolatileEntry("CTask_ActiveTasks", EMPTY_TABLE);
local inactiveTasks = getNonVolatileEntry("CTask_InactiveTasks", EMPTY_TABLE);
local uniqueTasks = getNonVolatileEntry("CTask_UniqueTasks", EMPTY_TABLE);

function SVC:AddTask(id)

    local task = {};
    task.ID = id;
    --task.AllowMultiple = task.AllowMultiple or false;
    task.Conditions = {};
    task.Callbacks = {};
    task.CallbacksArgs = {};

    tasks[id] = task;

end

function SVC:GetTask(id)
    if !id then
        MsgErr("NilArgs", "id");
        return;
    end

    return tasks[id];
end

function SVC:AddTaskCondition(id, cond, type, begin, finish)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    if task.Conditions[cond] then
        MsgErr("DupEntry", cond);
        return;
    end

    task.Conditions[cond] = {
        Type = type,
        Begin = begin,
        Finish = finish
    };
end

function SVC:AddTaskCallback(id, func)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    task.Callbacks[#task.Callbacks + 1] = func;
end

function SVC:AddTaskOnFinish(id, func)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    task.OnFinish = func;
end

function SVC:NewTask(id)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    local newID = string.random(8, CHAR_ALPHANUM, "task_");
    while activeTasks[newID] do
        newID = string.random(8, CHAR_ALPHANUM, "task_");
    end

    local newTask = setmetatable({}, getMeta("Task"));
    newTask.TaskID = id;
    newTask.UniqueID = newID;
    newTask:Initialize();
    activeTasks[newID] = newTask;
    return newTask;
end

/*
function SVC:AddActiveTask(task)
    if !task then
        MsgErr("NilArgs", "task");
        return;
    end
    if !task.TaskID or !task.UniqueID then
        MsgErr("TaskNotValid", tostring(task));
        return;
    end
    if task.TaskInfo.IsUnique and uniqueTasks[task.TaskID] then
        MsgErr("TaskAlreadyRunning", task.TaskID, tostring(task));
        return;
    end

    if task.TaskInfo.IsUnique then
        uniqueTasks[task.TaskID] = task;
    end

    activeTasks[task.UniqueID] = task;
end
*/

function SVC:GetActiveTask(id)
    if !id then
        MsgErr("NilArgs", "id");
        return;
    end
    if !activeTasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    return activeTasks[id];
end

/*
function SVC:UpdateTask(id, cond, value)
    if !activeTasks[id] then
        MsgErr("TaskNotActive", id);
        return;
    end

    local curTask = activeTasks[id];
    if !curTask.Conds[cond] then
        MsgErr("NilEntry", cond);
        return;
    end

    curTask.Conds[cond]:Update(value);
end
*/

-- Custom errors.
addErrType("TaskNotActive", "No task with that ID is active! (%s)");
addErrType("TaskNotValid", "This task does not have a TaskID/UniqueID! Use the library create function! (%s)");
addErrType("TaskAlreadyRunning", "Only one instance of this task can be active at a time! (%s running on %s)");

if SERVER then

    -- Hooks.
    hook.Add("GatherPrelimData_Base", "bash_Hook_AddPlyTasks", function()
        local ctask = getService("CTask");
        ctask:AddTask("bash_PlayerPreInit");
        ctask:AddTaskOnFinish("bash_PlayerPreInit", function(data)
            if !isplayer(data["Player"]) then return; end

            local ctask = getService("CTask");
            local oninit = ctask:NewTask("bash_PlayerOnInit");
            oninit:PassData("Player", data["Player"]);
            oninit:Start();
            data["Player"].PreInitTask = nil;
            data["Player"].OnInitTask = oninit;
            data["Player"].Initialized = true;
            hook.Run("PlayerOnInit", data["Player"]);
        end);

        ctask:AddTask("bash_PlayerOnInit");
        ctask:AddTaskOnFinish("bash_PlayerOnInit", function(data)
            if !isplayer(data["Player"]) then return; end

            local ctask = getService("CTask");
            local postinit = ctask:NewTask("bash_PlayerPostInit");
            postinit:PassData("Player", data["Player"]);
            postinit:Start();
            data["Player"].OnInitTask = nil;
            data["Player"].PostInitTask = postinit;
            hook.Run("PlayerPostInit", data["Player"]);
        end);

        ctask:AddTask("bash_PlayerPostInit");
    end);

    hook.Add("PrePlayerInit", "bash_Hook_StartPlyTasks", function(ply)
        if !isplayer(ply) then return; end

        local ctask = getService("CTask");
        local preinit = ctask:NewTask("bash_PlayerPreInit");
        preinit:PassData("Player", ply);
        preinit:Start();
        ply.PreInitTask = preinit;
        hook.Run("PlayerPreInit", ply);
    end);

end

defineService_end();
