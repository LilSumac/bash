defineService_start("CPlayer");

-- Service info.
SVC.Name = "Core Player";
SVC.Author = "LilSumac";
SVC.Desc = "The main player functions for /bash/.";
SVC.Depends = {"CDatabase"};

-- Service storage.
SVC.PlyVars = {};

function SVC:AddPlyVar(var)
    if !var then
        MsgErr("NilArgs", "var");
        return;
    end
    if !var.ID then
        MsgErr("NilField", "ID", "var");
        return;
    end
    if self.PlyVars[var.ID] then
        MsgErr("DupEntry", var.ID);
        return;
    end

    -- Plyvar fields.
    -- var.ID = var.ID; (Redundant, no default)
    var.Type = var.Type or "string";
    var.Public = var.Public or false;
    var.InSQL = var.InSQL or false;
    var.CanThink = var.CanThink or false;
    var.ThinkInterval = var.ThinkInterval or 0;

    -- Charvar functions/hooks.
    var.OnGenerate = var.OnGenerate or DEFAULTS[var.Type];
    -- var.Think = var.Think; (Redundant, no default)
    -- var.OnGet = var.OnGet; (Redundant, no default)
    -- var.OnSet = var.OnSet; (Redundant, no default)

    MsgCon(color_green, "Registering charvar: %s", var.ID);
    self.PlyVars[var.ID] = var;
end

------------------------------------------------------
-- Local functions for specific DB operations.
------------------------------------------------------
local function createPlyData(ply)
    MsgCon(color_sql, "Creating new entry for '%s'...", ply:Name());

    local data = {};
    -- SteamID column always required for player-referencing tables.
    data["SteamID"] = ply:SteamID();

    for id, var in pairs(self.PlyVars) do
        data[id] = handleFunc(var.OnGenerate, var, ply);
    end

    local db = getService("CDatabase");
    db:InsertRow(
        "bash_plys",            -- Table to query.
        data,                   -- Data to insert.

        function(_ply, results) -- Callback function upon completion.
            MsgCon(color_sql, "INSERT DONE!");
            -- do other shit
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
                -- do other shit
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

-- Add default plyvars.
SVC:AddPlyVar{
    ID = "Name",
    Type = "string",
    OnGenerate = function(self, ply)
        return ply:Name();
    end
};

SVC:AddPlyVar{
    ID = "NewPlayer",
    Type = "boolean",
    Default = true
};

SVC:AddPlyVar{
    ID = "FirstLogin",
    Type = "number",
    OnGenerate = function()
        return os.time();
    end
};

SVC:AddPlyVar{
    ID = "Addresses",
    Type = "table",
    OnGenerate = function(self, ply)
        return {[ply:IPAddress()] = true};
    end
};

-- Hooks.
hook.Add("EditDatabase", "CPlayer_AddTables", function()
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
end);

hook.Add("OnPlayerInit", "CPlayer_OnPlayerInit", function(ply)
    getPlyData(ply);
end);

defineService_end();
