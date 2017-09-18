defineService_start("CTask");

-- Service info.
SVC.Name = "CTask";
SVC.Author = "LilSumac";
SVC.Desc = "Simple framework for implementing code-based tasks with progress, feedback, and callbacks.";

-- Service storage.
SVC.Tasks = {};
SVC.ActiveTasks = getNonVolatileEntry("CTask_ActiveTasks", EMPTY_TABLE);

function SVC:AddTask(task)

end

function SVC:AddTaskCondition(id, cond, begin, thresh)

end

function SVC:StartTask(id)

end

defineService_end();
