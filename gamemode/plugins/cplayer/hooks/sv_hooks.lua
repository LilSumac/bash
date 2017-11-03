--[[
    CPlayer server hooks.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local bash          = bash;
local handleFunc    = handleFunc;
local isplayer      = isplayer;
local MsgDebug      = MsgDebug;
local MsgLog        = MsgLog;
local pairs         = pairs;
local player        = player;

--
-- Local functions.
--

-- Create a row for a new player in the database.
local function createPlyData(ply)
    MsgLog(LOG_DB, "Creating new row for '%s'...", ply:Name());

    local tablenet = getService("CTableNet");
    local vars = tablenet:GetDomainVars("Player");
    local data = {};
    for id, var in pairs(vars) do
        data[id] = handleFunc(var.OnGenerate, var, ply);
    end

    local db = getService("CDatabase");
    db:InsertRow(
        "bash_plys",            -- Table to query.
        data,                   -- Data to insert.

        function(_ply, results) -- Callback function upon completion.
            local preinit = ply.PreInitTask;
            if !preinit then return; end

            MsgLog(LOG_DB, "Created row for player '%s'.", ply:Name());
            preinit:PassData("SQLData", data);
            preinit:Update("WaitForSQL", 1);
        end,

        ply                     -- Argument #1 for callback.
    );
end

-- Search for a row for a player in the database.
local function getPlyData(ply)
    MsgDebug(LOG_DB, "Gathering player data for '%s'...", ply:Name());

    local db = getService("CDatabase");
    db:SelectRow(
        "bash_plys",                                        -- Table to query.
        "*",                                                -- Columns to get.
        Format("WHERE SteamID = \'%s\'", ply:SteamID()),    -- Condition to compare against.

        function(_ply, results)
            results = results[1];                           -- Callback function upon completion.
            if #results.data > 1 then
                MsgLog(LOG_WARN, "Multiple rows found for %s [%s]! Remove duplicate rows ASAP.", ply:Name(), ply:SteamID());
            end

            if table.IsEmpty(results.data) then
                createPlyData(_ply);
            else
                MsgDebug(LOG_DB, "Found row for player '%s'.", _ply:Name());
                local preinit = ply.PreInitTask;
                if !preinit then return; end

                preinit:PassData("SQLData", results.data[1]);
                preinit:Update("WaitForSQL", 1);
            end
        end,

        ply                                                 -- Argument #1 for callback.
    );
end

-- Remove all tasks and registry traces from a player on disconnect.
local function removePly(ply)
    local tabnet = getService("CTableNet");
    if ply.RegistryID then
        tabnet:RemoveTable(ply.RegistryID, "Player");
    end
    if ply.PreInitTask then
        tabnet:RemoveTable(ply.PreInitTask.RegistryID, "Task");
        ply.PreInitTask = nil;
    end
    if ply.OnInitTask then
        tabnet:RemoveTable(ply.OnInitTask.RegistryID, "Task");
        ply.OnInitTask = nil;
    end
    if ply.PostInitTask then
        tabnet:RemoveTable(ply.PostInitTask.RegistryID, "Task");
        ply.PostInitTask = nil;
    end
end

--
-- Gamemode hooks.
--

-- Remove player on disconnect.
hook.Add("PlayerDisconnected", "CPlayer_RemovePlayer", function(ply)
    removePly(ply);
end);

-- Remove all players on shutdown.
hook.Add("ShutDown", "CPlayer_RemoveAllPlayers", function()
    for _, ply in pairs(player.GetAll()) do
        removePly(ply);
    end
end);

--
-- bash hooks.
--

-- Create initialization process tasks.
hook.Add("GatherPrelimData_Base", "CPlayer_AddTaskFunctions", function()
    local ctask = bash.Util.GetPlugin("CTask");
    -- Create initialization process.
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
        local tabnet = bash.Util.GetPlugin("CTableNet");
        local cplayer = bash.Util.GetPlugin("CPlayer");

        -- Handle player affairs.
        tabnet:NewTable("Player", data["SQLData"], data["Player"]);
        bash.Util.PlayerInit(ply);

        ply:AddListener("Player", player.GetInitialized(), LISTEN_PUBLIC);  -- Add everyone else as public listeners.
        ply:AddListener("Player", ply, LISTEN_PRIVATE);                     -- Add player as private listener.
        tabnet:NetworkTable(ply.RegistryID, "Player");

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

        local ply = data["Player"];
        local tabnet = bash.Util.GetPlugin("CTableNet");

        -- Handle player affairs.
        tabnet:SendRegistry(ply, true);
    end);
    ctask:AddTaskOnFinish("bash_PlayerOnInit", function(status, task)
        if status == STATUS_FAILED then return; end
        local data = task:GetPassedData();
        if !isplayer(data["Player"]) then return; end

        local ply = data["Player"];
        local cplayer = bash.Util.GetPlugin("CPlayer");

        -- Handle player affairs.
        bash.Util.PlayerPostInit(ply);
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

-- Start the initialization process when player is ready.
hook.Add("OnReceiveClientData", "CPlayer_StartPlyTasks", function(ply, data)
    if !isplayer(ply) then return; end
    if ply.Initialized then return; end

    local ctask = bash.Util.GetPlugin("CTask");
    local preinit = ctask:NewTask("bash_PlayerPreInit");
    -- add listener to task
    preinit:PassData("Player", ply);
    preinit:Start();
end);

-- Update OnInit when the player has received the registry.
hook.Add("CTableNet_RegSendAck", "CPlayer_UpdateOnInit", function(ply)
    if ply.OnInitTask then
        ply.OnInitTask:Update("WaitForTableNet", 1);
    end
end);
