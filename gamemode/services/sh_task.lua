defineService_start("CTask");

-- Service info.
SVC.Name = "CTask";
SVC.Author = "LilSumac";
SVC.Desc = "Simple framework for implementing code-based tasks with progress, feedback, and callbacks.";

-- Service storage.
local tasks = {};
local activeTasks = getNonVolatileEntry("CTask_ActiveTasks", EMPTY_TABLE);
local inactiveTasks = getNonVolatileEntry("CTask_InactiveTasks", EMPTY_TABLE);
local uniqueTasks = getNonVolatileEntry("CTask_UniqueTasks", EMPTY_TABLE);

SVC.Tasks = {};
SVC.ActiveTasks = getNonVolatileEntry("CTask_ActiveTasks", EMPTY_TABLE);

function SVC:AddTask(task)

    task.ID = task.ID;
    task.AllowMultiple = task.AllowMultiple or false;
    task.Conditions = {};

end

function SVC:GetTask(id)
    if !id then
        MsgErr("NilArgs", "id");
        return;
    end

    return tasks[id];
end

function SVC:AddTaskCondition(id, cond, begin, finish)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    if task.Conditions[cond] then
        MsgErr("DupEntry", cond);
        return;
    end

    local newCond = {};
    newCond.__index = newCond;
    newCond.Type = TASK_NUMERIC;
    newCond.Start = begin;
    newCond.Finish = finish;
    newCond.Update = function(_self, value)
        if _self.Type == TASK_NUMERIC then
            _self.Value = _self.Value + value;
        else
            _self.Value = value;
        end
    end
    newCond.Progress = function(_self)
        if _self.Type == TASK_NUMERIC then
            return ((_self.Value - _self.Start) / (_self.Finish - _self.Start));
        else
            return _self.Value;
        end
    end
    newCond.IsFinished = function(_self)
        if _self.Type == TASK_NUMERIC then
            return _self.Value >= _self.Finish;
        else
            return _self.Value == _self.Finish;
        end
    end
end

function SVC:AddTaskCallback(id, func)

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
    newTask.Conditions = {};
    for condID, cond in pairs(task.Conditions) do
        newTask.Conditions[condID] = cond.Begin;
    end

    return newTask;
end

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

-- Custom errors.
addErrType("TaskNotActive", "No task with that ID is active! (%s)");
addErrType("TaskNotValid", "This task does not have a TaskID/UniqueID! Use the library create function! (%s)");
addErrType("TaskAlreadyRunning", "Only one instance of this task can be active at a time! (%s running on %s)");

defineService_end();
