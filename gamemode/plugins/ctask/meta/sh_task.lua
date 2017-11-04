--[[
    CTask main metatable.
]]

-- Start meta definition.
defineMeta_start("CTask");

--
-- Local storage.
--

-- Micro-optimizations.
local bash      = bash;
local Format    = Format;
local MsgDebug  = MsgDebug;
local MsgErr    = MsgErr;
local os        = os;
local pairs     = pairs;
local table     = table;
local timer     = timer;
local tostring  = tostring;

--
-- Meta functions.
--

-- Initialize a new task.
function META:Initialize()
    if !self.RegistryID then
        MsgErr("TaskNotValid", tostring(self));
        return;
    end

    self:SetNetVar("Task", "Status", STATUS_PAUSED);

    local task = bash.Util.GetPlugin("CTask");
    local taskInfo = task:GetTask(self.TaskID);
    self.TaskInfo = taskInfo;

    self.Timers = {};

    local timerID;
    if table.IsEmpty(self.TaskInfo.Conditions) then
        MsgDebug(LOG_WARN, "The task '%s->%s' has no conditions! Starting it will automatically complete it in 0.1s.", self.RegistryID, self.TaskID);
    else
        local startVals = {};
        for condID, cond in pairs(self.TaskInfo.Conditions) do
            if cond.Type == TASK_TIMED then
                startVals[condID] = 0;
                timerID = Format("CTask_%s_%d", self.RegistryID, #self.Timers + 1);
                self.Timers[timerID] = true;
                timer.Create(timerID, cond.Finish, 0, self.Update, self, condID, cond.Finish);
                timer.Stop(timerID);
            else
                startVals[condID] = cond.Begin;
            end
        end
        self:SetNetVar("Task", "Values", startVals);
    end
end

-- Start a waiting task.
function META:Start()
    MsgDebug(LOG_TASK, "Starting task '%s->%s'...", self.RegistryID, self.TaskID);
    self:SetNetVars("Task", {
        ["Status"] = STATUS_RUNNING,
        ["StartTime"] = os.time()
    });

    if self.TaskInfo.OnBorn then
        self.TaskInfo.OnBorn(self);
    end

    for timerID, _ in pairs(self.Timers) do
        timer.Start(timerID);
    end

    for _, func in ipairs(self.TaskInfo.OnStarts) do
        func(self);
    end

    if table.IsEmpty(self.TaskInfo.Conditions) then
        timer.Simple(0.1, function()
            self:Finish(STATUS_SUCCESS);
        end);
    end
end

-- Pause a running task.
function META:Pause()
    if self:GetNetVar("Task", "Status") == STATUS_PAUSED then return; end
    self:SetNetVar("Task", "Status", STATUS_PAUSED);

    for timerID, _ in pairs(self.Timers) do
        timer.Pause(timerID);
    end
end

-- Unpause a paused task.
function META:Unpause()
    if self:GetNetVar("Task", "Status") != STATUS_PAUSED then return; end
    self:SetNetVar("Task", "Status", STATUS_RUNNING);

    for timerID, _ in pairs(self.Timers) do
        timer.UnPause(timerID);
    end

    local saved = self:GetNetVar("Task", "SavedValues");
    if table.IsEmpty(saved) then return; end

    local newVals = {};
    for cond, val in pairs(self:GetNetVar("Task", "Values")) do
        if saved[cond] != nil then
            newVals[cond] = saved[cond];
        else
            newVals[cond] = val;
        end
    end
    self:SetNetVars("Task", {
        ["Values"] = newVals,
        ["SavedValues"] = {}
    });
end

-- Restart a task.
function META:Restart()
    local newVals = {};
    for condID, cond in pairs(self.TaskInfo.Conditions) do
        newVals[condID] = cond.Begin;
    end
    self:SetNetVars("Task", {
        ["Status"] = STATUS_RUNNING,
        ["Values"] = newVals
    });

    for timerID, _ in pairs(self.Timers) do
        timer.Stop(timerID);
        timer.Start(timerID);
    end
end

-- Get status of a task.
function META:GetStatus()
    return self:GetNetVar("Task", "Status");
end

-- Pass data to a task.
function META:PassData(id, data)
    local passed = self:GetPassedData();
    passed[id] = data;
    self:SetNetVar("Task", "PassedData", passed);
end

-- Get passed data from a task.
function META:GetPassedData()
    return self:GetNetVar("Task", "PassedData");
end

-- Update a condition of the task.
function META:Update(cond, value)
    if !self.InScope then return; end

    local status = self:GetNetVar("Task", "Status");
    if status == STATUS_SUCCESS or status == STATUS_FAILED then return; end

    local condInfo = self.TaskInfo.Conditions[cond];
    if !condInfo then
        MsgErr("NilEntry", cond);
        return;
    end

    if status == STATUS_PAUSED then
        local saved = self:GetNetVar("Task", "SavedValues");
        saved[cond] = value;
        self:SetNetVar("Task", "SavedValues", saved);
        return;
    end

    local values = self:GetNetVar("Task", "Values");
    if condInfo.Type == TASK_NUMERIC then
        values[cond] = values[cond] + value;
    else
        values[cond] = value;
    end
    self:SetNetVar("Task", "Values", values);

    if status <= 1 and self:CheckConditions() then
        self:Finish(STATUS_SUCCESS);
    end
end

-- Finish a task with a failed status.
function META:Fail()
    self:Finish(STATUS_FAILED);
end

-- Finish a task.
function META:Finish(status, force)
    local curStatus = self:GetNetVar("Task", "Status");
    if curStatus >= 2 then return; end
    self:SetNetVar("Task", "Status", status);

    local ctask = bash.Util.GetPlugin("CTask");
    ctask:RemoveActiveTask(self.RegistryID);
end

-- Check to see if all conditions have been met.
function META:CheckConditions()
    local values = self:GetNetVar("Task", "Values");
    for condID, cond in pairs(self.TaskInfo.Conditions) do
        if cond.Type == TASK_NUMERIC or cond.Type == TASK_TIMED then
            if values[condID] < cond.Finish then
                return false;
            end
        else
            if values[condID] != cond.Finish then
                return false;
            end
        end
    end
    return true;
end

-- End meta definition.
defineMeta_end();
