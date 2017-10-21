defineService_start("CTask");

-- Service info.
SVC.Name = "CTask";
SVC.Author = "LilSumac";
SVC.Desc = "Simple framework for implementing code-based tasks with progress, feedback, and callbacks.";

-- Constants.
color_task = Color(151, 0, 151, 255);

TASK_NUMERIC = 0;
TASK_TIMED = 1;
TASK_OTHER = 2;

STATUS_PAUSED = 0;
STATUS_RUNNING = 1;
STATUS_SUCCESS = 2;
STATUS_FAILED = 3;

-- Service storage.
local tasks = {};
local activeTasks = getNonVolatileEntry("CTask_ActiveTasks", EMPTY_TABLE);

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

function SVC:RemoveActiveTask(id)
    activeTasks[id] = nil;
end

-- Custom errors.
addErrType("TaskNotActive", "No task with that ID is active! (%s)");
addErrType("TaskNotValid", "This task does not have a TaskID/UniqueID! Use the library create function! (%s)");
addErrType("TaskAlreadyRunning", "Only one instance of this task can be active at a time! (%s running on %s)");

-- Hooks.
-- GatherPrelimData: create task

if SERVER then

    -- Network pool.
    util.AddNetworkString("CTask_Net_SendTask");
    util.AddNetworkString("CTask_Net_UpdateTask");

    -- Hooks.
    -- GatherPrelimData: add sv onfinishes
    hook.Add("GatherPrelimData", "bash_Hook_AddPlyTasks", function()
        local tabnet = getService("CTableNet");
        tabnet:AddDomain{
            ID = "Task",
            ParentMeta = getMeta("Task"),
            Secure = false,
            GetRecipients = function(_self, task)
                return task.Listeners;
            end
        };

        tabnet:AddVariable{
            ID = "Status",
            Domain = "Task",
            Type = "number",
            Public = true,
            OnGenerate = STATUS_PAUSED,
            OnSetClient
        };

        tabnet:AddVariable{
            ID = "StartTime",
            Domain = "Task",
            Type = "number",
            Public = true,
            OnGenerate = -1
        };

        tabnet:AddVariable{
            ID = "Values",
            Domain = "Task",
            Type = "table",
            Public = true
        };

        tabnet:AddVariable{
            ID = "SavedValues",
            Domain = "Task",
            Type = "table",
            Public = true
        };

        tabnet:AddVariable{
            ID = "PassedData",
            Domain = "Task",
            Type = "table",
            Public = true
        };

        local ctask = getService("CTask");
        ctask:AddTask("bash_PlayerPreInit");
        ctask:AddTaskOnFinish("bash_PlayerPreInit", function(status, data)
            if status == STATUS_FAILED then return; end
            if !isplayer(data["Player"]) then return; end

            local ply = data["Player"];
            local ctask = getService("CTask");

            -- Handle player affairs.
            ply:Initialize();

            -- Create next task.
            local oninit = ctask:NewTask("bash_PlayerOnInit");
            oninit:PassData("Player", ply);
            oninit:Start();
            ply.OnInitTask = oninit.UniqueID;

            -- Remove completed task.
            ctask:RemoveActiveTask(ply.PreInitTask);
            ply.PreInitTask = nil;
        end);

        ctask:AddTask("bash_PlayerOnInit");
        ctask:AddTaskOnFinish("bash_PlayerOnInit", function(status, data)
            if status == STATUS_FAILED then return; end
            if !isplayer(data["Player"]) then return; end

            local ply = data["Player"];
            local ctask = getService("CTask");

            -- Handle player affairs.
            ply:PostInitialize();

            -- Create next task.
            local postinit = ctask:NewTask("bash_PlayerPostInit");
            postinit:PassData("Player", ply);
            postinit:Start();
            ply.PostInitTask = postinit.UniqueID;

            -- Remove completed task.
            ctask:RemoveActiveTask(ply.OnInitTask);
            ply.OnInitTask = nil;
        end);

        ctask:AddTask("bash_PlayerPostInit");
        ctask:AddTaskOnFinish("bash_PlayerPostInit", function(status, data)
            if status == STATUS_FAILED then return; end
            if !isplayer(data["Player"]) then return; end

            local ply = data["Player"];
            local ctask = getService("CTask");

            -- Remove completed task.
            ctask:RemoveActiveTask(ply.PostInitTask);
            ply.PostInitTask = nil;
        end);
    end);

    hook.Add("PrePlayerInit", "bash_Hook_StartPlyTasks", function(ply)
        if !isplayer(ply) then return; end

        local ctask = getService("CTask");
        local preinit = ctask:NewTask("bash_PlayerPreInit");
        -- add listener to task
        preinit:PassData("Player", ply);
        preinit:Start();
        ply.PreInitTask = preinit.UniqueID;
    end);

elseif CLIENT then

    vnet.Watch("CTask_Net_SendTask", function(pck)
        local data = pck:Table();

    end);
    -- watch for new tasks (added listener)

    -- watch for updated tasks (already listening)

end

defineService_end();
