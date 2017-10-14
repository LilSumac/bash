defineMeta_start("Task");

function META:Initialize()
    if !self.TaskID or !self.UniqueID then
        MsgErr("TaskNotValid", tostring(self));
        return;
    end

    self.Paused = true;
    self.Finished = false;

    local task = getService("CTask");
    local taskInfo = task:GetTask(self.TaskID);
    self.TaskInfo = taskInfo;

    self.StartTime = -1;
    self.Conditions = {};
    self.Timers = {};
    self.SavedValues = {};
    self.PassedData = {};

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
end

function META:Start()
    MsgCon(color_blue, "Starting task '%s'...", self.TaskInfo.ID);
    self.Paused = false;
    self.Finished = false;
    self.StartTime = SysTime();

    if table.IsEmpty(self.TaskInfo.Conditions) then
        MsgCon(color_lightblue, "The task '%s' has no conditions! Automatically completed.", self.TaskInfo.ID);
        self:Finish();
    end
end

function META:Pause()
    if self.Paused then return; end
    self.Paused = true;

    for timerID, _ in pairs(self.Timers) do
        timer.Pause(timerID);
    end
end

function META:Unpause()
    if !self.Paused then return; end
    self.Paused = false;

    for timerID, _ in pairs(self.Timers) do
        timer.UnPause(timerID);
    end

    for cond, val in pairs(self.SavedValues) do
        self:Update(cond, val);
    end
    self.SavedValues = {};
end

function META:Restart()
    self.Paused = false;
    self.Finished = false;

    for condID, cond in pairs(self.TaskInfo.Conditions) do
        self.Conditions[condID] = cond.Begin;
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
    local condInfo = self.TaskInfo.Conditions[cond];
    if !condInfo then
        MsgErr("NilEntry", cond);
        return;
    end

    if self.Paused then
        self.SavedValues[cond] = value;
        return;
    end

    if condInfo.Type == TASK_NUMERIC then
        self.Conditions[cond] = self.Conditions[cond] + value;
    elseif confInfo.Type == TASK_TIMED then
        self.Conditions[cond] = value or SysTime();
    else
        self.Conditions[cond] = value;
    end

    if self:IsFinished() then
        self:Finish();
    end
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

function META:Finish()
    self.Paused = false;
    self.Finished = true;

    MsgCon(color_blue, "Task '%s' has finished! Calling callbacks...", self.TaskInfo.ID);
    for index, func in ipairs(self.TaskInfo.Callbacks) do
        func(self.PassedData);
    end

    if self.TaskInfo.OnFinish then
        self.TaskInfo.OnFinish(self.PassedData);
    end
end

function META:IsFinished()
    for condID, cond in pairs(self.TaskInfo.Conditions) do
        if cond.Type == TASK_NUMERIC or cond.Type == TASK_TIMED then
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
