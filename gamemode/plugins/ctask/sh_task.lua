--[[
    CTask shared functionality.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local bash      = bash;
local ipairs    = ipairs;
local MsgDebug  = MsgDebug;
local MsgErr    = MsgErr;
local pairs     = pairs;

--
-- Service storage.
--

-- Task objects.
local tasks = {};
local activeTasks = bash.Util.GetNonVolatileEntry("CTask_ActiveTasks", EMPTY_TABLE);

--
-- Service functions.
--

-- Add a new task struct.
function PLUG:AddTask(id)

    local task = {};
    task.ID = id;
    task.Conditions = {};
    task.OnBorn = nil;
    task.OnStarts = {};
    task.OnFinishes = {};
    task.OnDeath = nil;
    task.NextTasks = {};

    tasks[id] = task;

end

-- Get a task struct.
function PLUG:GetTask(id)
    return tasks[id];
end

-- Add a condition to a task struct.
function PLUG:AddTaskCondition(id, cond, type, begin, finish)
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

-- Add an OnBorn callback to a task struct.
function PLUG:AddTaskOnBorn(id, func)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    task.OnBorn = func;
end

-- Add an OnStart callback to a task struct.
function PLUG:AddTaskOnStart(id, func)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    task.OnStarts[#task.OnStarts + 1] = func;
end

-- Add an OnFinish callback to a task struct.
function PLUG:AddTaskOnFinish(id, func)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    task.OnFinishes[#task.OnFinishes + 1] = func;
end

-- Add an OnDeath callback to a task struct.
function PLUG:AddTaskOnDeath(id, func)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    task.OnDeath = func;
end

-- Add a task to be executed after another task struct.
function PLUG:AddNextTask(id, nextID)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end
    if !tasks[nextID] then
        MsgErr("NilEntry", nextID);
        return;
    end

    local task = tasks[id];
    task.NextTasks[#task.NextTasks + 1] = nextID;
end

-- Create an instance of a new task.
function PLUG:NewTask(id, passed)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    local tabnet = bash.Util.GetPlugin("CTableNet");
    local newTask = tabnet:NewTable("Task");
    newTask.TaskID = id;
    newTask.InScope = true;
    newTask:Initialize();
    activeTasks[newTask.RegistryID] = newTask;
    return newTask;
end

-- Get an active task object.
function PLUG:GetActiveTask(id)
    if !activeTasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    return activeTasks[id];
end

-- Remove an active task object.
function PLUG:RemoveActiveTask(id)
    local task = self:GetActiveTask(id);
    local regID = task.RegistryID;
    local taskID = task.TaskID;
    local status = task:GetNetVar("Task", "Status");
    local passed = task:GetNetVar("Task", "PassedData");
    MsgDebug(LOG_TASK, "Task '%s->%s' has finished with status %d! Finishing up...", regID, taskID, status);

    local taskInfo = tasks[taskID];
    for _, func in ipairs(taskInfo.OnFinishes) do
        func(status, task);
    end

    if taskInfo.OnDeath then
        taskInfo.OnDeath(status, task);
    end

    local tabnet = bash.Util.GetPlugin("CTableNet");
    tabnet:RemoveTable(regID, "Task");
    activeTasks[regID] = nil;

    if status == STATUS_SUCCESS then
        local newTask;
        for _, nextID in pairs(taskInfo.NextTasks) do
            newTask = self:NewTask(nextID);
            newTask:SetNetVar("Task", "PassedData", passed);
            newTask:Start();
        end
    end
end
