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
