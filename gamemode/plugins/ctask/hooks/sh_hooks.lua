--[[
    CTask shared hooks.
]]

-- Gamemode hooks.
hook.Add("bash_GatherPrelimData_Base", "bash_Hook_AddPlyTasks", function()
    local tabnet = getService("CTableNet");
    tabnet:AddDomain{
        ID = "Task",
        ParentMeta = getMeta("CTask")
    };

    tabnet:AddVariable{
        ID = "Status",
        Domain = "Task",
        Type = "number",
        Public = true,
        OnGenerate = STATUS_PAUSED
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
end);
