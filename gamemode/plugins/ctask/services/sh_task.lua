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

function SVC:NewTask(id)
    if !tasks[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local task = tasks[id];
    local tabnet = getService("CTableNet");
    local newTask = tabnet:NewTable("Task");
    newTask.TaskID = id;
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
    MsgLog(LOG_DEF, "Task '%s->%s' has finished with status %d! Finishing up...", regID, taskID, status);

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

-- Hooks.
hook.Add("GatherPrelimData_Base", "bash_Hook_AddPlyTasks", function()
    local tabnet = getService("CTableNet");
    tabnet:AddDomain{
        ID = "Task",
        ParentMeta = getMeta("CTask"),
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
    ctask:AddTask("bash_PlayerOnInit");
    ctask:AddTask("bash_PlayerPostInit");
    ctask:AddNextTask("bash_PlayerPreInit", "bash_PlayerOnInit");
    ctask:AddNextTask("bash_PlayerOnInit", "bash_PlayerPostInit");

    if SERVER then
        ctask:AddTaskOnBorn("bash_PlayerPreInit", function(task)
            local data = task:GetPassedData();
            if !isplayer(data["Player"]) then return; end
            data["Player"].PreInitTask = task;
        end);
        ctask:AddTaskOnFinish("bash_PlayerPreInit", function(status, task)
            if status == STATUS_FAILED then return; end
            local data = task:GetPassedData();
            if !isplayer(data["Player"]) then return; end

            local ply = data["Player"];
            -- Handle player affairs.
            ply:Initialize();
            ply.PreInitTask = nil;
        end);

        ctask:AddTaskOnBorn("bash_PlayerOnInit", function(task)
            local data = task:GetPassedData();
            if !isplayer(data["Player"]) then return; end
            data["Player"].OnInitTask = task;
        end);
        ctask:AddTaskOnFinish("bash_PlayerOnInit", function(status, task)
            if status == STATUS_FAILED then return; end
            local data = task:GetPassedData();
            if !isplayer(data["Player"]) then return; end

            local ply = data["Player"];
            -- Handle player affairs.
            ply:PostInitialize();
            ply.OnInitTask = nil;
        end);

        ctask:AddTaskOnBorn("bash_PlayerOnInit", function(task)
            local data = task:GetPassedData();
            if !isplayer(data["Player"]) then return; end
            data["Player"].PostInitTask = task;
        end);
        ctask:AddTaskOnFinish("bash_PlayerPostInit", function(status, task)
            if status == STATUS_FAILED then return; end
            local data = task:GetPassedData();
            if !isplayer(data["Player"]) then return; end

            local ply = data["Player"];
            -- Handle player affairs.
            MsgCon(color_def, "Initialize process finished for player '%s'.", ply:Name());
            ply.PostInitTask = nil;
        end);
    end
end);

if SERVER then

    -- Hooks.
    hook.Add("PrePlayerInit", "bash_Hook_StartPlyTasks", function(ply)
        if !isplayer(ply) then return; end

        local ctask = getService("CTask");
        local preinit = ctask:NewTask("bash_PlayerPreInit");
        -- add listener to task
        preinit:PassData("Player", ply);
        preinit:Start();
    end);

elseif CLIENT then

    vnet.Watch("CTask_Net_SendTask", function(pck)
        local data = pck:Table();

    end);
    -- watch for new tasks (added listener)

    -- watch for updated tasks (already listening)

end

defineService_end();
