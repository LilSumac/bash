defineMeta_start("Task");

function META:Initialize()
    if !self.TaskID or !self.UniqueID then
        MsgErr("TaskNotValid", tostring(self));
        return;
    end

    self.IsPaused = true;
    self.IsFinished = false;

    local task = getService("CTask");
    local taskInfo = task:GetTask(self.TaskID);
    self.TaskInfo = taskInfo;

    self.StartTime = -1;
    self.Conditions = {};
    self.Timers = {};
    local timerID;
    for condID, cond in pairs(self.TaskInfo.Conditions) do
        self.Conditions[condID] = cond.Begin;
        if cond.Type == TASK_TIMED then
            timerID = Format("CTask_%s_%d", self.UniqueID, #self.Timers + 1);
            self.Timers[timerID] = true;
            timer.Create(timerID, cond.Interval, 0, self.Update, self, condID);
            timer.Stop(timerID);
        end
    end

    self.SavedValues = {};
end

function META:Start()
    self.IsPaused = false;
    self.IsFinished = false;
    self.StartTime = SysTime();
end

function META:Pause()
    if self.IsPaused then return; end
    self.IsPaused = true;

    for timerID, _ in pairs(self.Timers) do
        timer.Pause(timerID);
    end
end

function META:Unpause()
    if !self.IsPaused then return; end
    self.IsPaused = false;

    for timerID, _ in pairs(self.Timers) do
        timer.UnPause(timerID);
    end
end

function META:Restart()
    self.IsPaused = false;
    self.IsFinished = false;

    for condID, cond in pairs(self.TaskInfo.Conditions) do
        self.Conditions[condID] = cond.Begin;
    end
    for timerID, _ in pairs(self.Timers) do
        timer.Stop(timerID);
        timer.Start(timerID);
    end
end

function META:Update(cond, value)
    local condInfo = self.TaskInfo.Conditions[cond];
    if !condInfo then
        MsgErr("NilEntry", cond);
        return;
    end

    if condInfo.Type == TASK_NUMERIC then
        self.Conditions[cond] = self.Conditions[cond] + value;
    elseif confInfo.Type == TASK_TIMED then
        self.Conditions[cond] = value or SysTime();
    else
        self.Conditions[cond] = value;
    end
end

function META:Fail()

end

function META:GetProgressTable()
    local progress = {};
    for condID, cond in pairs(self.TaskInfo.Conditions) do
        if cond.Type == TASK_NUMERIC then

        elseif cond.Type == TASK_TIMED then
            progress[condID] = (cond.Finish - self.Conditions[condID]) / cond.Length;
        else
            progress[condID] = tonumber(self.Conditions[condID] == cond.Finish);
        end
    end
end

function META:IsFinished()
    for condID, cond in pairs(self.TaskInfo.Conditions) do
        if cond.Type == TASK_NUMERIC or cond.TYPE == TASK_TIMED then
            if self.Conditions[condID] < cond.Finish then
                return false;
            end
        else
            if self.Conditions[condID] != cond.Finish then
                return false;
            end
        end
    end
    return true;
end

function META:AddListener(plys)

end

defineMeta_end();
