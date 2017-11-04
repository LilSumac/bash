--[[
    CTask shared hooks.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local bash = bash;

--
-- bash hooks.
--

-- Add task variables to TableNet.
hook.Add("GatherPrelimData_Base", "CTask_AddPlyTasks", function()
    local tabnet = bash.Util.GetPlugin("CTableNet");
    -- Task domain.
    tabnet:AddDomain{
        ID = "Task",
        ParentMeta = bash.Util.GetMeta("CTask")
    };

    -- Task variables.
    tabnet:AddVariable{
        Domain = "Task",
        ID = "Status",
        Type = "number",
        Public = true,
        OnGenerate = STATUS_PAUSED
    };
    tabnet:AddVariable{
        Domain = "Task",
        ID = "StartTime",
        Type = "number",
        Public = true,
        OnGenerate = -1
    };
    tabnet:AddVariable{
        Domain = "Task",
        ID = "Values",
        Type = "table",
        Public = true
    };
    tabnet:AddVariable{
        Domain = "Task",
        ID = "SavedValues",
        Type = "table",
        Public = true
    };
    tabnet:AddVariable{
        Domain = "Task",
        ID = "PassedData",
        Type = "table",
        Public = true
    };
end);
