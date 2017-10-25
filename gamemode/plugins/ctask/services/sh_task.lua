defineService_start("CTask");

-- Service info.
SVC.Name = "CTask";
SVC.Author = "LilSumac";
SVC.Desc = "Core Task service.";

-- Service storage.
local tasks = {};
local activeTasks = getNonVolatileEntry("CTask_ActiveTasks", EMPTY_TABLE);

function SVC:AddTask(id)

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

function SVC:AddTaskOnBorn(id, func)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    task.OnBorn = func;
end

function SVC:AddTaskOnStart(id, func)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    task.OnStarts[#task.OnStarts + 1] = func;
end

function SVC:AddTaskOnFinish(id, func)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    task.OnFinishes[#task.OnFinishes + 1] = func;
end

function SVC:AddTaskOnDeath(id, func)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    task.OnDeath = func;
end

function SVC:AddNextTask(id, nextID)
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

function SVC:NewTask(id, passed)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    local tabnet = getService("CTableNet");
    local newTask = tabnet:NewTable("Task");
    newTask.TaskID = id;
    newTask.InScope = true;
    newTask:Initialize();
    activeTasks[newTask.RegistryID] = newTask;
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
    local task = self:GetActiveTask(id);
    local regID = task.RegistryID;
    local taskID = task.TaskID;
    local status = task:GetNetVar("Task", "Status");
    local passed = task:GetNetVar("Task", "PassedData");
    MsgLog(LOG_TASK, "Task '%s->%s' has finished with status %d! Finishing up...", regID, taskID, status);

    local taskInfo = tasks[taskID];
    for _, func in ipairs(taskInfo.OnFinishes) do
        func(status, task);
    end

    if taskInfo.OnDeath then
        taskInfo.OnDeath(status, task);
    end

    local tabnet = getService("CTableNet");
    tabnet:RemoveTable(regID, "Task");
    activeTasks[regID] = nil;

    local newTask;
    for _, nextID in pairs(taskInfo.NextTasks) do
        newTask = self:NewTask(nextID);
        newTask:SetNetVar("Task", "PassedData", passed);
        newTask:Start();
    end
end

defineService_end();
