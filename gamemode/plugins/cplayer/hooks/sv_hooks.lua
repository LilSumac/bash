--[[
    CPlayer server hooks.
]]

-- Gamemode hooks.
gameevent.Listen("player_disconnect");
hook.Add("player_disconnect", "CPlayer_RemovePlayer", function(ply)
    if ply.RegistryID then
        local tabnet = getService("CTableNet");
        tabnet:RemoveTable(ply.RegistryID, "CPlayer");
    end
end);

hook.Add("bash_GatherPrelimData_Base", "CPlayer_AddTaskFunctions", function()
    local ctask = getService("CTask");
    ctask:AddTask("bash_PlayerPreInit");
    ctask:AddTask("bash_PlayerOnInit");
    ctask:AddTask("bash_PlayerPostInit");
    ctask:AddNextTask("bash_PlayerPreInit", "bash_PlayerOnInit");
    ctask:AddNextTask("bash_PlayerOnInit", "bash_PlayerPostInit");

    -- PreInit
    ctask:AddTaskCondition("bash_PlayerPreInit", "WaitForSQL", TASK_NUMERIC, 0, 1);
    ctask:AddTaskOnBorn("bash_PlayerPreInit", function(task)
        local data = task:GetPassedData();
        if !isplayer(data["Player"]) then return; end
        data["Player"].PreInitTask = task;
    end);
    ctask:AddTaskOnStart("bash_PlayerPreInit", function(task)
        local data = task:GetPassedData();
        if !isplayer(data["Player"]) then return; end
        getPlyData(data["Player"]);
    end);
    ctask:AddTaskOnFinish("bash_PlayerPreInit", function(status, task)
        if status == STATUS_FAILED then return; end
        local data = task:GetPassedData();
        if !isplayer(data["Player"]) or !data["SQLData"] then return; end

        local ply = data["Player"];
        local tabnet = getService("CTableNet");
        local cplayer = getService("CPlayer");

        -- Handle player affairs.
        tabnet:NewTable("CPlayer", data["SQLData"], data["Player"]);
        cplayer:Initialize(ply);

        ply:AddListener("CPlayer", player.GetInitialized(), LISTEN_PUBLIC); -- Add everyone else as public listeners.
        ply:AddListener("CPlayer", ply, LISTEN_PRIVATE, true);              -- Add player as private listener.

        tabnet:NetworkTable(ply.RegistryID, "CPlayer");

        ply.PreInitTask = nil;
    end);

    -- OnInit
    ctask:AddTaskCondition("bash_PlayerOnInit", "WaitForTableNet", TASK_NUMERIC, 0, 1);
    ctask:AddTaskOnBorn("bash_PlayerOnInit", function(task)
        local data = task:GetPassedData();
        if !isplayer(data["Player"]) then return; end
        data["Player"].OnInitTask = task;
    end);
    ctask:AddTaskOnStart("bash_PlayerOnInit", function(task)
        local data = task:GetPassedData();
        if !isplayer(data["Player"]) then return; end
        sendPlyTables(data["Player"]);
    end);
    ctask:AddTaskOnFinish("bash_PlayerOnInit", function(status, task)
        if status == STATUS_FAILED then return; end
        local data = task:GetPassedData();
        if !isplayer(data["Player"]) then return; end

        local ply = data["Player"];
        local cplayer = getService("CPlayer");

        -- Handle player affairs.
        cplayer:PostInitialize(ply);
        ply.OnInitTask = nil;
    end);

    -- PostInit
    ctask:AddTaskOnBorn("bash_PlayerPostInit", function(task)
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
        MsgDebug(LOG_INIT, "Initialize process finished for player '%s'.", ply:Name());
        ply.PostInitTask = nil;
    end);
end);

hook.Add("bash_OnReceiveClientData", "CPlayer_StartPlyTasks", function(ply, data)
    if !isplayer(ply) then return; end
    if ply.Initialized then return; end

    local ctask = getService("CTask");
    local preinit = ctask:NewTask("bash_PlayerPreInit");
    -- add listener to task
    preinit:PassData("Player", ply);
    preinit:Start();
end);
