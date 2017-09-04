-- tmysql4 is the required SQL module.
if !tmysql4 then
    local status, mod = pcall(require, "tmysql4");
    if !status then
        MsgErr("NoDBModule");
        return;
    else
        MsgCon(color_green, "tmysql4 module loaded.");
    end
end

defineService_start("CDatabase");

SVC.Name = "Core Database";
SVC.Author = "LilSumac";
SVC.Desc = "The core interface between /bash/ and the external database.";
SVC.Depends = {"CPlayer", "CCharacter"};

-- Service storage.
SVC.DBObject = getNonVolatileEntry("CDatabase_DBObject", EMPTY_TABLE);
SVC.Connected = getNonVolatileEntry("CDatabase_Connected", false);
SVC.Tables = {};
SVC.Columns = {};

local color_sql = Color(0, 151, 151, 255);
local CAST_IN = 1;
local CAST_OUT = 2;
-- DB connection info.
local host = "45.55.218.30";
local user = "tester";
local pass = "testpass";
local data = "srp_db";
local port = 3306;

function SVC:Connect()
    local obj, err = tmysql.initialize(
        host, user, pass, data,
        port, nil, CLIENT_MULTI_STATEMENTS
    );
    if obj then
        setNonVolatileEntry("CDatabase_DBObject", obj);
        setNonVolatileEntry("CDatabase_Connected", true);
        self.DBObject = getNonVolatileEntry("CDatabase_DBObject", EMPTY_TABLE);
        self.Connected = getNonVolatileEntry("CDatabase_Connected", false);

        MsgCon(color_sql, "Successfully connected to MySQL server!");
    else
        MsgErr("NoDBConnect", err);
        return;
    end

    -- Table/column edit hook.
    hook.Call("EditDatabase");

    -- Perform database existance checks.
    self:CheckTables();

    -- CALL THIS AFTER ALL CHECKS
    -- Post-connection hook.
    --hook.Call("OnDBConnected");
end

function SVC:AddTable(name, ref)
    if !name then
        MsgErr("NilArgs", "name");
        return;
    end
    if self.Tables[name] then
        MsgErr("DupEntry", name);
        return;
    end

    -- Table fields.
    local tab = {};
    self.Tables[name] = tab;

    tab.Name = name;
    tab.Columns = {};
    -- EntryNum will always be the key. If you don't like it then TOUGH.
    tab.Columns["EntryNum"] = {
        Name = "EntryNum",
        Type = "number",
        Default = "NOT NULL",
        Query = tostring(SQL_TYPE["number"]) .. " NOT NULL AUTO_INCREMENT UNIQUE"
    };
    tab.Key = "EntryNum";
    if ref == REF_PLY then
        tab.Columns["SteamID"] = {
            Name = "SteamID",
            Type = "string",
            Default = SQL_DEF["string"]
        };
    elseif ref == REF_CHAR then
        tab.Columns["SteamID"] = {
            Name = "SteamID",
            Type = "string",
            Default = SQL_DEF["string"]
        };
        tab.Columns["CharID"] = {
            Name = "CharID",
            Type = "string",
            Default = SQL_DEF["string"]
        };
    end

    MsgCon(color_sql, "SQL table registered with name '%s'.", name);
end

function SVC:AddColumn(tab, col)
    if !tab then
        MsgErr("NilArgs", "tab");
        return;
    end
    if !self.Tables[tab] then
        MsgErr("NilEntry", tab);
        return;
    end

    if !col then
        MsgErr("NilArgs", "col");
        return;
    end
    if !col.Name then
        MsgErr("NilField", "Name", "col");
        return;
    end

    local tabData = self.Tables[tab];
    if tabData.Columns[col.Name] then
        MsgErr("DupEntry", col.Name);
        return;
    end

    tabData.Columns[col.Name] = col;

    -- col.Name = col.Name;
    col.Type = col.Type or "string";
    col.Default = (col.Default != nil and col.Default) or SQL_DEF[col.Type];

    MsgCon(color_sql, "Column with name '%s' registered in table '%s'.", col.Name, tab);
end

function SVC:Query(query, callback, ...)
    if self.DBObject and self.Connected then
        local args = {...};
        self.DBObject:Query(query, function(resultsTab)
            if #resultsTab == 1 then
                if !resultsTab[1].status then
                    MsgErr("QueryFailed", query, resultsTab[1].error);
                    return;
                end
            else
                for index, results in ipairs(resultsTab) do
                    if !results.status then
                        MsgErr("QueryNumFailed", index, query, results.error);
                    end
                end
            end

            args[#args + 1] = resultsTab;
            callback(unpack(args));
        end);
    end
end

local castIn = {
    ["boolean"] = function(bool)
        if bool then return 1;
        else return 0; end
    end,
    ["number"] = tonumber,
    ["string"] = function(str)
        local db = getService("CDatabase");
        return Format("\'%s\'", db.DBObject:Escape(tostring(str)));
    end,
    ["table"] = function(tab)
        local db = getService("CDatabase");
        return Format("\'%s\'", db.DBObject:Escape(pon.encode(tab)));
    end
};
local castOut = {
    ["boolean"] = tobool,
    ["number"] = tonumber,
    ["string"] = tostring,
    ["table"] = function(tab)
        return pon.decode(tostring(str));
    end
};
function SVC:CastValue(tab, col, val, inout)
    if !tab then
        MsgErr("NilArgs", "tab");
        return;
    end
    if !self.Tables[tab] then
        MsgErr("NilEntry", tab);
        return;
    end

    local tab = self.Tables[tab];
    if !col then
        MsgErr("NilArgs", "col");
        return;
    end
    if !tab.Columns[col] then
        MsgErr("NilEntry", col);
        return;
    end

    local t = type(val);
    if !castIn[t] and castOut[t] then
        MsgErr("InvalidDataType", t);
        return;
    end

    inout = inout or CAST_IN;
    local castFuncs = (inout == CAST_IN and castIn) or castOut;

    if val == nil then return castFuncs[t](SQL_DEF[tab.Type]); end
    return castFuncs[t](val);
end

function SVC:CheckTables()
    if table.IsEmpty(self.Tables) then
        MsgCon(color_sql, "No tables registered in database. Skipping...");
        return;
    end

    local query = "";
    for name, tab in pairs(self.Tables) do
        query = query .. Format("CREATE TABLE IF NOT EXISTS %s(", name);
        for _name, col in pairs(tab.Columns) do
            if _name == "EntryNum" then
                query = query .. "`EntryNum` BIGINT NOT NULL AUTO_INCREMENT UNIQUE, ";
            elseif col.Type == "string" or col.Type == "table" then
                query = query .. Format("`%s` %s, ", _name, SQL_TYPE[col.Type]);
            else
                query = query .. Format("`%s` %s DEFAULT %s, ", _name, SQL_TYPE[col.Type], self:CastValue(name, _name, col.Default, CAST_IN));
            end
        end
        query = query .. "PRIMARY KEY(EntryNum)); ";
    end

    self:Query(query, function(results)
        MsgCon(color_sql, "Table check complete.");
        local db = getService("CDatabase");
        db:CheckColumns();
    end);
end

function SVC:CheckColumns()

end

function SVC:InsertRow(tab, data, callback, ...)
    if !tab then
        MsgErr("NilArgs", "tab");
        return;
    end
    if !data then
        MsgErr("NilArgs", "data");
        return;
    end
    if !self.Tables[tab] then
        MsgErr("NilEntry", tab);
        return;
    end

    local query = Format("INSERT INTO %s(", tab);
    local vals = "VALUES(";
    for col, val in pairs(data) do
        query = query .. Format("%s, ", col);
        vals = vals .. Format("%s, ", self:CastValue(tab, col, val, CAST_IN));
    end
    query = query:sub(1, #query - 2);
    vals = vals:sub(1, #vals - 2);

    query = Format("%s) %s);", query, vals);
    self:Query(query, callback or function(results)
        MsgCon(color_sql, "New row inserted into table '%s'.", tab);
    end, unpack({...}));
end

function SVC:GetRow(tab, cols, cond, callback, ...)
    if !tab then
        MsgErr("NilArgs", "tab");
        return;
    end
    if !self.Tables[tab] then
        MsgErr("NilEntry", tab);
        return;
    end

    cols = cols or "*";
    local query = Format("SELECT %s FROM %s", cols, tab);
    if cond and cond != "" then
        query = query .. Format(" WHERE %s;", cond);
    else
        query = query .. ";";
    end

    self:Query(query, callback or function(results)
        MsgCon(color_sql, "Fetched from row in table '%s'.", tab);
    end, unpack({...}));
end

function SVC:UpdateRow(tab, data, cond, callback, ...)
    if !tab then
        MsgErr("NilArgs", "tab");
        return;
    end
    if !data then
        MsgErr("NilArgs", "data");
        return;
    end
    if !self.Tables[tab] then
        MsgErr("NilEntry", tab);
        return;
    end

    local query = Format("UPDATE %s SET ", tab);
    local vals = "";
    for col, val in pairs(data) do
        vals = vals .. Format("%s = %s, ", col, self:CastValue(tab, col, val, CAST_IN));
    end
    vals = vals:sub(1, #vals - 2);
    query = query .. vals;

    if cond and cond != "" then
        query = Format("%s WHERE %s;", query, cond);
    else
        query = query .. ";";
    end

    self:Query(query, callback or function(results)
        MsgCon(color_sql, "Row updated in table '%s'.", tab);
    end, unpack({...}));
end

-- Custom errors.
addErrType("NoDBModule", "No tmysql4 module found! This is required and must be resolved.");
addErrType("NoDBConnect", "Unable to connect to MySQL server! (%s)");
addErrType("QueryFailed", "The SQL query failed!\nQuery: %s\nError: %s");
addErrType("QueryNumFailed", "The #%d SQL query in the statement failed!\nQuery: %s\nError: %s");
addErrType("KeyExists", "A key already exists in this table! (Column %s in table %s)");

-- Hooks.
hook.Add("OnInit", "CDatabase_OnInit", function()
    local db = getService("CDatabase");
    if db.DBObject and db.Connected then
        MsgCon(color_sql, "Database still connected, skipping.");
        return;
    end

    db:Connect();
end);

--[[
hook.Add("OnPlayerInit", "CDatabase_OnPlayerInit", function(ply)
    local db = getService("CDatabase");
    local steamID = ply:SteamID();
    local name = "PlyFetch_" .. steamID;
    hook.Add(name, db, db.FinalizePlayer);

    db:FetchPlayer(ply);
end);
]]

defineService_end();
