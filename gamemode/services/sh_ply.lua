defineService_start("CPlayer");

-- Service info.
SVC.Name = "Core Player";
SVC.Author = "LilSumac";
SVC.Desc = "The main player functions for the gamemode.";
SVC.Depends = {"CDatabase", "CTableNet"};

-- Hooks.
hook.Add("bash_GatherPrelimData_Base", "CPlayer_AddTableNet", function()
    local tablenet = getService("CTableNet");
    tablenet:AddDomain{
        ID = "CPlayer",
        ParentMeta = FindMetaTable("Player"),
        StoredInSQL = true,
        SQLTable = "bash_plys",
        GetPrivateRecipients = function(_self, ply)
            return {[ply] = true};
        end
    };

    tablenet:AddVariable{
        ID = "Name",
        Domain = "CPlayer",
        Type = "string",
        MaxLength = 32,
        Public = true,
        InSQL = true,
        OnGenerate = function(_self, ply)
            return ply:Name();
        end,
        OnInitServer = function(_self, ply, oldVal)
            return ply:Name();
        end
    };

    tablenet:AddVariable{
        ID = "SteamID",
        Domain = "CPlayer",
        Type = "string",
        MaxLength = 18,
        Public = true,
        InSQL = true,
        PrimaryKey = true,
        OnGenerate = function(_self, ply)
            return ply:SteamID();
        end
    };

    tablenet:AddVariable{
        ID = "Addresses",
        Domain = "CPlayer",
        Type = "table",
        MaxLength = 255,
        InSQL = true,
        OnGenerate = function(_self, ply)
            return {[ply:IPAddress()] = true};
        end,
        OnInitServer = function(_self, ply, oldVal)
            oldVal[ply:IPAddress()] = true;
            return oldVal;
        end
    };

    tablenet:AddVariable{
        ID = "FirstLogin",
        Domain = "CPlayer",
        Type = "number",
        MaxLength = 10,
        Public = true,
        InSQL = true,
        OnGenerate = function(_self, ply)
            return os.time();
        end
    };

    tablenet:AddVariable{
        ID = "NewPlayer",
        Domain = "CPlayer",
        Type = "boolean",
        Public = true,
        InSQL = true,
        OnGenerate = true,
        OnInitServer = function(_self, ply, oldVal)
            local playtime = ply:GetNetVar("CPlayer", "Playtime");
            if playtime > 21600 then
                ply:SetNetVar("CPlayer", "NewPlayer", false);
            end
        end
    };

    tablenet:AddVariable{
        ID = "Playtime",
        Domain = "CPlayer",
        Type = "number",
        MaxLength = 10,
        Public = true,
        InSQL = true,
        OnGenerate = 0,
        OnInitServer = function(_self, ply, oldVal)
            ply.StartTime = CurTime();
        end,
        OnDeinitServer = function(_self, ply, oldVal)
            local startTime = ply.StartTime or CurTime();
            local played = CurTime() - startTime;
            local newTime = oldVal + played;
            ply:SetNetVar("CPlayer", "Playtime", newTime);
        end
    };
end);

if SERVER then

    -- Custom errors.
    addErrType("MultiPlyRows", "Player '%s' has multiple player rows, using the first one. This can cause conflicts! Remove all duplicate rows ASAP!");

    -- Network pool.
    util.AddNetworkString("CPlayer_Net_RespondClient");

    -- Local functions.
    local function createPlyData(ply)
        MsgLog(LOG_DB, "Creating new row for '%s'...", ply:Name());

        local tablenet = getService("CTableNet");
        local vars = tablenet:GetDomainVars("CPlayer");
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

    local function getPlyData(ply)
        MsgLog(LOG_DB, "Gathering player data for '%s'...", ply:Name());

        local db = getService("CDatabase");
        db:SelectRow(
            "bash_plys",                                        -- Table to query.
            "*",                                                -- Columns to get.
            Format("WHERE SteamID = \'%s\'", ply:SteamID()),    -- Condition to compare against.

            function(_ply, results)                             -- Callback function upon completion.
                if #results > 1 then
                    MsgErr("MultiPlyRows", ply:Name());
                end

                results = results[1];
                if table.IsEmpty(results.data) then
                    createPlyData(_ply);
                else
                    for id, val in pairs(results.data[1]) do

                    end

                    MsgLog(LOG_DB, "Found row for player '%s'.", _ply:Name());
                    local preinit = ply.PreInitTask;
                    if !preinit then return; end
                    --PrintTable(results);
                    -- UPDATE THIS
                    preinit:PassData("SQLData", {});
                    preinit:Update("WaitForSQL", 1);
                end
            end,

            ply                                                 -- Argument #1 for callback.
        );
    end

    local function sendPlyTables(ply)
        local tabnet = getService("CTableNet");
        if tabnet:IsRegistryEmpty() then
            MsgN("Empty registry!");
            -- jump past this step
            return;
        end

        local delay = 0.1;
        for id, obj in pairs(tabnet:GetRegistry()) do
            if !IsValid(obj) then continue; end

            for dom, vars in pairs(obj.TableNet) do
                timer.Simple(delay, function()
                    -- Prevent sending tables that were removed during delay.
                    if !tabnet:IsRegistered(id) then return; end
                    tabnet:SendTable(ply, id, dom);
                end);
                delay = delay + 0.1;
            end
        end

        timer.Simple(delay, function()
            local oninit = ply.OnInitTask;
            oninit:Update("WaitForTableNet", 1);
        end);
    end

    -- Service functions.
    function SVC:Initialize(ply)
        if ply.Initialized then return; end

        ply.Initialized = true;

        local respondPck = vnet.CreatePacket("CPlayer_Net_RespondClient");
        respondPck:AddTargets(ply);
        respondPck:Send();

        hook.Run("bash_PlayerOnInit", ply);
    end

    function SVC:PostInitialize(ply)
        if ply.PostInitialized then return; end

        ply.PostInitialized = true;
        hook.Run("bash_PlayerPostInit", ply);
    end

    function SVC:KickPlayer(ply, reason, kicker)

    end

    function SVC:BanPlayer(ply, reason, length, banner)

    end

    -- Hooks.
    hook.Add("PlayerDisconnected", "CPlayer_RemovePlayer", function(ply)
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
            MsgLog(LOG_INIT, "Initialize process finished for player '%s'.", ply:Name());
            ply.PostInitTask = nil;
        end);
    end);

    hook.Add("bash_OnReceiveClientData", "bash_Hook_StartPlyTasks", function(ply, data)
        if !isplayer(ply) then return; end
        if ply.Initialized then return; end

        local ctask = getService("CTask");
        local preinit = ctask:NewTask("bash_PlayerPreInit");
        -- add listener to task
        preinit:PassData("Player", ply);
        preinit:Start();
    end);

elseif CLIENT then

    -- Hooks.
    vnet.Watch("CPlayer_Net_RespondClient", function(pck)
        bash.serverResponded = true;
        LocalPlayer().Initialized = true;
        MsgLog(LOG_INIT, "Received response from server! Successfully initialized.");
    end);

end

defineService_end();
