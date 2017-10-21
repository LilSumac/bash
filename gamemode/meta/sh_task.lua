defineMeta_start("Task");

function META:Initialize()
    if !self.TaskID or !self.UniqueID then
        MsgErr("TaskNotValid", tostring(self));
        return;
    end

    self.Status = STATUS_PAUSED;

    local task = getService("CTask");
    local taskInfo = task:GetTask(self.TaskID);
    self.TaskInfo = taskInfo;

    self.Timers = {};

    if SERVER then
        self.Listeners = {};
    end

    local timerID;
    if table.IsEmpty(self.TaskInfo.Conditions) then
        MsgLog(LOG_WARN, "The task '%s->%s' has no conditions! Starting it will automatically complete it in 0.1s.", self.TaskID, self.UniqueID);
    else
        local startVals = {};
        for condID, cond in pairs(self.TaskInfo.Conditions) do
            if cond.Type == TASK_TIMED then
                startVals[condID] = 0;
                timerID = Format("CTask_%s_%d", self.UniqueID, #self.Timers + 1);
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

function META:Start()
    MsgLog(LOG_DEF, "Starting task '%s->%s'...", self.TaskID, self.UniqueID);
    self:SetNetVars("Task", {
        ["Status"] = STATUS_RUNNING,
        ["StartTime"] = os.time()
    });

    for timerID, _ in pairs(self.Timers) do
        timer.Start(timerID);
    end

    if table.IsEmpty(self.TaskInfo.Conditions) then
        timer.Simple(0.1, function()
            self:Finish(STATUS_SUCCESS);
        end);
    end
end

function META:Pause()
    if self:GetNetVar("Task", "Status") == STATUS_PAUSED then return; end
    self:SetNetVar("Task", "Status", STATUS_PAUSED);

    for timerID, _ in pairs(self.Timers) do
        timer.Pause(timerID);
    end
end

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

function META:PassData(id, data)
    local passed = self:GetNetVar("Task", "PassedData");
    passed[id] = data;
    self:SetNetVar("Task", "PassedData", passed);
end

function META:Update(cond, value)
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

    if self:CheckConditions() then
        self:Finish(STATUS_SUCCESS);
    end
end

function META:Fail()
    self:Finish(STATUS_FAILED);
end

function META:Finish(status)
    self:SetNetVar("Task", "Status", status);

    MsgLog(LOG_DEF, "Task '%s->%s' has finished with status %d! Calling callbacks...", self.TaskID, self.UniqueID, self.Status);

    local passed = self:GetNetVar("Task", "PassedData");
    for _, func in ipairs(self.TaskInfo.Callbacks) do
        func(status, passed);
    end

    if self.TaskInfo.OnFinish then
        self.TaskInfo.OnFinish(status, passed;
    end
end

function META:CheckConditions()
    for condID, cond in pairs(self.TaskInfo.Conditions) do
        if cond.Type == TASK_NUMERIC or cond.Type == TASK_TIMED then
            if self.Values[condID] < cond.Finish then
                return false;
            end
        else
            if self.Values[condID] != cond.Finish then
                return false;
            end
        end
    end
    return true;
end

if SERVER then

    function META:AddListener(ply)
        self.Listeners[ply] = true;

        local data = {};
        data.TaskID = self.TaskID;
        data.UniqueID = self.UniqueID;
        data.StartTime = self.StartTime;
        data.Values = self.Values;
        data.SavedValues = self.SavedValues;
        data.PassedData = self.PassedData;

        local taskpck = vnet.CreatePacket("CTask_Net_SendTask");
        taskpck:Table(data);
        taskpck:AddTargets(ply);
        taskpck:Send();
    end

end

defineMeta_end();
