defineService_start("CPlayer");

-- Service info.
SVC.Name = "Core Player";
SVC.Author = "LilSumac";
SVC.Desc = "The main player functions for the gamemode.";
SVC.Depends = {"CDatabase", "CTableNet"};

------------------------------------------------------
-- Local functions for specific DB operations.
------------------------------------------------------
local function createPlyData(ply)
    MsgCon(color_sql, "Creating new entry for '%s'...", ply:Name());

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
            MsgCon(color_sql, "INSERT DONE!");
            PrintTable(data);
        end,

        ply                     -- Argument #1 for callback.
    );
end

local function getPlyData(ply)
    MsgCon(color_sql, "Gathering player data for '%s'...", ply:Name());

    local db = getService("CDatabase");
    db:GetRow(
        "bash_plys",                                -- Table to query.
        "*",                                        -- Columns to get.
        Format("SteamID = \'%s\'", ply:SteamID()),  -- Condition to compare against.

        function(_ply, results)                     -- Callback function upon completion.
            if #results > 1 then
                MsgErr("MultiPlyRows", ply:Name());
            end

            results = results[1];
            if table.IsEmpty(results.data) then
                createPlyData(_ply);
            else
                MsgCon(color_sql, "GET DONE!");
                PrintTable(results.data);
            end
        end,

        ply                                         -- Argument #1 for callback.
    );
end
------------------------------------------------------
--
------------------------------------------------------

-- Custom errors.
addErrType("MultiPlyRows", "Player '%s' has multiple player rows, using the first one. This can cause conflicts! Remove all duplicate rows ASAP!");

if SERVER then

    -- Network pool.
    util.AddNetworkString("bash_test");

    -- Hooks.
    hook.Add("PrePlayerInit", "CPlayer_CreatePlyNet", function(ply)
        getPlyData(ply);
        local tablenet = getService("CTableNet");
        tablenet:NewTable("Player", {}, ply);


        /*
        MsgN("Meta for player...");
        MsgN(tostring(getmetatable(ply)));
        MsgN("Player meta...")
        MsgN(tostring(FindMetaTable("Player")));

        local netvar = getService("CTableNet");
        local newData = {};
        newData["SteamID"] = ply:SteamID();
        local plyVars = netvar:GetDomainVars("CPlayer");
        for id, var in pairs(plyVars) do
            newData[id] = handleFunc(var.OnGenerate, var, ply);
        end
        ply.PlyData = newData;

        getPlyData(ply);


        local test = setmetatable({}, getMeta("Character"));
        MsgN("Data table: " .. tostring(test));
        MsgN("Data metatable: " .. tostring(getmetatable(test)));
        MsgN("Character metatable: " .. tostring(getMeta("Character")));
        local testPck = vnet.CreatePacket("bash_test");
        testPck:Table(test);
        testPck:AddTargets(ply);
        testPck:Send();
        */
    end);

end

-- Hooks.
hook.Add("GatherPrelimData_Base", "CPlayer_AddTables", function()
    if SERVER then
        local db = getService("CDatabase");
        db:AddTable("bash_plys", REF_PLY);

        -- automate this with vars
        db:AddColumn("bash_plys", {
            ["Name"] = "Name",
            ["Type"] = "string",
            ["Default"] = "Steam Name"
        });
        db:AddColumn("bash_plys", {
            ["Name"] = "NewPlayer",
            ["Type"] = "boolean",
            ["Default"] = true
        });
        db:AddColumn("bash_plys", {
            ["Name"] = "FirstLogin",
            ["Type"] = "number"
        });
        db:AddColumn("bash_plys", {
            ["Name"] = "Addresses",
            ["Type"] = "table"
        });
    end

    local tablenet = getService("CTableNet");
    tablenet:AddDomain{
        ID = "Player",
        ParentMeta = FindMetaTable("Player"),
        StoredInSQL = true,
        SQLTable = "bash_plys"
    };

    tablenet:AddVariable{
        ID = "Name",
        Domain = "Player",
        Public = true,
        InSQL = true,
        OnGenerate = function(_self, ply)
            return self:OnInitialize(ply);
        end,
        OnInitialize = function(_self, ply, oldVal)
            return ply:Name();
        end
    };

    tablenet:AddVariable{
        ID = "SteamID",
        Domain = "Player",
        Public = true,
        InSQL = true,
        OnGenerate = function(_self, ply)
            return ply:SteamID();
        end
    };

    tablenet:AddVariable{
        ID = "Addresses",
        Domain = "Player",
        Type = "table",
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
        Domain = "Player",
        Type = "number",
        Public = true,
        InSQL = true,
        OnGenerate = function(_self, ply)
            return os.time();
        end
    };

    tablenet:AddVariable{
        ID = "NewPlayer",
        Domain = "Player",
        Type = "boolean",
        Public = true,
        InSQL = true,
        OnGenerate = true,
        OnInitServer = function(_self, ply, oldVal)
            local playtime = ply:GetNetVar("Player", "Playtime");
            if playTime > 21600 then
                ply:SetNetVar("Player", "NewPlayer", false);
            end
        end
    };

    tablenet:AddVariable{
        ID = "Playtime",
        Domain = "Player",
        Type = "number",
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
            ply:SetNetVar("Player", "Playtime", newTime);
        end
    };

    /*
    tablenet:AddVariable{
        ID = "Flags",
        Domain = "Player",
        Type = "string",
        Public = true,
        InSQL = true
    };
    */
end);

defineService_end();
