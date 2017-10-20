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

    self.StartTime = -1;
    self.Values = {};
    self.Timers = {};
    self.SavedValues = {};
    self.PassedData = {};

    if SERVER then
        self.Listeners = {};
    end

    local timerID;
    if table.IsEmpty(self.TaskInfo.Conditions) then
        MsgLog(LOG_WARN, "The task '%s->%s' has no conditions! Starting it will automatically complete it in 0.1s.", self.TaskID, self.UniqueID);
    else
        for condID, cond in pairs(self.TaskInfo.Conditions) do
            if cond.Type == TASK_TIMED then
                self.Values[condID] = 0;
                timerID = Format("CTask_%s_%d", self.UniqueID, #self.Timers + 1);
                self.Timers[timerID] = true;
                timer.Create(timerID, cond.Finish, 0, self.Update, self, condID, cond.Finish);
                timer.Stop(timerID);
            else
                self.Values[condID] = cond.Begin;
            end
        end
    end
end

function META:Start()
    MsgLog(LOG_DEF, "Starting task '%s->%s'...", self.TaskID, self.UniqueID);
    self.Status = STATUS_RUNNING;
    self.StartTime = os.time();

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
    if self.Status == STATUS_PAUSED then return; end
    self.Status = STATUS_PAUSED;

    for timerID, _ in pairs(self.Timers) do
        timer.Pause(timerID);
    end
end

function META:Unpause()
    if self.Status != STATUS_PAUSED then return; end
    self.Status = STATUS_RUNNING;

    for timerID, _ in pairs(self.Timers) do
        timer.UnPause(timerID);
    end

    for cond, val in pairs(self.SavedValues) do
        self:Update(cond, val);
    end
    self.SavedValues = {};
end

function META:Restart()
    self.Status = STATUS_RUNNING;

    for condID, cond in pairs(self.TaskInfo.Conditions) do
        self.Values[condID] = cond.Begin;
    end

    for timerID, _ in pairs(self.Timers) do
        timer.Stop(timerID);
        timer.Start(timerID);
    end
end

function META:PassData(id, data)
    self.PassedData[id] = data;
end

function META:Update(cond, value)
    if self.Status == STATUS_SUCCESS or self.Status == STATUS_FAILED then return; end

    local condInfo = self.TaskInfo.Conditions[cond];
    if !condInfo then
        MsgErr("NilEntry", cond);
        return;
    end

    if self.Status == STATUS_PAUSED then
        self.SavedValues[cond] = value;
        return;
    end

    if condInfo.Type == TASK_NUMERIC then
        self.Values[cond] = self.Values[cond] + value;
    else
        self.Values[cond] = value;
    end

    if self:CheckConditions() then
        self:Finish(STATUS_SUCCESS);
    end
end

function META:Fail()
    self:Finish(STATUS_FAILED);
end

function META:Finish(status)
    self.Status = status;

    MsgLog(LOG_DEF, "Task '%s->%s' has finished with status %d! Calling callbacks...", self.TaskID, self.UniqueID, self.Status);
    for _, func in ipairs(self.TaskInfo.Callbacks) do
        func(status, self.PassedData);
    end

    if self.TaskInfo.OnFinish then
        self.TaskInfo.OnFinish(status, self.PassedData);
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

        local taskpck = vnet.CreatePacket();
    end

end

defineMeta_end();
