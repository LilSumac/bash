--[[
    CDatabase main service.
]]

-- tmysql4 is the required SQL module.
if !tmysql4 then
    local status, mod = pcall(require, "tmysql4");
    if !status then
        MsgErr("NoDBModule");
        return;
    else
        MsgLog(LOG_INIT, "tmysql4 module loaded.");
    end
end

-- Constants.
LOG_DB = {pre = "[DB]", col = Color(0, 151, 151, 255)};

CAST_IN = 1;
CAST_OUT = 2;

SQL_DEF = {};
SQL_DEF["boolean"] = false;
SQL_DEF["number"] = 0;
SQL_DEF["string"] = "";
SQL_DEF["table"] = {};

SQL_TYPE = {};
SQL_TYPE["counter"] = "INT";
SQL_TYPE["boolean"] = "BIT"
SQL_TYPE["number"] = "DECIMAL(%d)";
SQL_TYPE["string"] = "VARCHAR(%d)";
SQL_TYPE["table"] = "VARCHAR(%d)";

-- Custom errors.
addErrType("NoDBModule", "No tmysql4 module found! This is required and must be resolved.");
addErrType("NoDBConnect", "Unable to connect to MySQL server! (%s)");
addErrType("QueryFailed", "The SQL query failed!\nQuery: %s\nError: %s");
addErrType("QueryNumFailed", "The #%d SQL query in the statement failed!\nQuery: %s\nError: %s");
addErrType("KeyExists", "A key already exists in this table! (Column %s in table %s)");

-- Local storage.
-- DB connection info.
local host = "45.55.218.30";
local user = "tester";
local pass = "testpass";
local data = "srp_db";
local port = 3306;

-- Casting tables.
local castIn = {
    ["boolean"] = function(bool)
        if bool then return 1;
        else return 0; end
    end,
    ["number"] = tonumber,
    ["string"] = function(str)
        local db = getService("CDatabase");
        return Format("\'%s\'", db:EscapeStr(tostring(str)));
    end,
    ["table"] = function(tab)
        local db = getService("CDatabase");
        return Format("\'%s\'", db:EscapeStr(pon.encode(tab)));
    end
};
local castOut = {
    ["boolean"] = tobool,
    ["number"] = tonumber,
    ["string"] = tostring,
    ["table"] = function(str)
        return pon.decode(tostring(str));
    end
};

-- Service storage.
local dbObject = getNonVolatileEntry("CDatabase_DBObject", EMPTY_TABLE);
local connected = getNonVolatileEntry("CDatabase_Connected", false);
local tables = {};

-- Service functions.
function SVC:IsConnected()
    return dbObject and connected;
end

function SVC:Connect()
    local obj, err = tmysql.initialize(
        host, user, pass, data,
        port, nil, CLIENT_MULTI_STATEMENTS
    );
    if obj then
        setNonVolatileEntry("CDatabase_DBObject", obj);
        setNonVolatileEntry("CDatabase_Connected", true);
        dbObject = obj;
        connected = true;

        MsgLog(LOG_DB, "Successfully connected to MySQL server!");
    else
        MsgErr("NoDBConnect", err);
        return;
    end

    -- Perform database existance checks.
    self:CheckTables();

    -- CALL THIS AFTER ALL CHECKS
    hook.Run("CDatabase_Hook_OnConnected");
end

function SVC:AddTable(name)
    if !name then
        MsgErr("NilArgs", "name");
        return;
    end
    if tables[name] then
        MsgErr("DupEntry", name);
        return;
    end

    local tab = {};
    -- Table fields.
    tab.Name = name;
    tab.Columns = {};
    tab.Columns["EntryNum"] = {
        Name = "EntryNum",
        Type = "counter",
        MaxLength = 5,
        -- Default = 0,
        Field = "UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE"
    };
    tab.PrimaryKey = "EntryNum";

    tables[name] = tab;

    MsgDebug(LOG_DB, "Database table registered with name '%s'.", name);
end

function SVC:AddColumn(tab, col, primary)
    if !tab then
        MsgErr("NilArgs", "tab");
        return;
    end
    if !tables[tab] then
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

    local tabData = tables[tab];
    if tabData.Columns[col.Name] then
        MsgErr("DupEntry", col.Name);
        return;
    end

    -- col.Name = col.Name;
    col.Type = col.Type or "string";
    --col.MaxLength = col.MaxLength;
    col.Default = col.Default != nil and col.Default or SQL_DEF[col.Type];
    col.NotNull = col.NotNull or false;
    col.Field = col.Field or "";

    MsgDebug(LOG_DB, "Database column '%s' registered in table '%s'.", col.Name, tab);

    if primary then
        tabData.PrimaryKey = col.Name;
        MsgDebug(LOG_DB, "Primary key in table '%s' set to column '%s'.", tabData.Name, col.Name);
    end

    tabData.Columns[col.Name] = col;
end

function SVC:Query(query, callback, ...)
    if self:IsConnected() then
        local args = {...};
        dbObject:Query(query, function(resultsTab)
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

function SVC:EscapeStr(str)
    if self:IsConnected() then
        return dbObject:Escape(str);
    else
        return str;
    end
end

function SVC:CastValue(tab, col, val, inout)
    if !tab then
        MsgErr("NilArgs", "tab");
        return;
    end
    if !tables[tab] then
        MsgErr("NilEntry", tab);
        return;
    end

    local tab = tables[tab];
    if !col then
        MsgErr("NilArgs", "col");
        return;
    end
    local colData = tab.Columns[col];
    if !colData then
        MsgErr("NilEntry", col);
        return;
    end

    if !castIn[colData.Type] and !castOut[colData.Type] then
        --MsgErr("InvalidDataType", colData.Type);
        return val;
    end

    inout = inout or CAST_IN;
    local castFuncs = (inout == CAST_IN and castIn) or castOut;

    if val == nil then return castFuncs[colData.Type](SQL_DEF[colData.Type]); end
    return castFuncs[colData.Type](val);
end

function SVC:CheckTables()
    if table.IsEmpty(tables) then
        MsgDebug(LOG_DB, "No tables registered in database. Skipping...");
        return;
    end

    local query, sqlType = "";
    for name, tab in pairs(tables) do
        query = query .. Format("CREATE TABLE IF NOT EXISTS %s(", name);
        for _name, col in pairs(tab.Columns) do
            if col.Type == "boolean" then
                sqlType = SQL_TYPE[col.Type];
            else
                sqlType = Format(SQL_TYPE[col.Type], (col.MaxLength or 8000));
            end

            query = query .. Format(
                "`%s` %s %s %s, ",
                _name,
                sqlType,
                col.Default != nil and ("DEFAULT " .. self:CastValue(name, _name, col.Default, CAST_IN)) or "",
                col.Field or ""
            );
        end
        query = query .. Format("PRIMARY KEY(%s)); ", tab.PrimaryKey);
    end

    self:Query(query, function(results)
        MsgDebug(LOG_DB, "Table check complete.");
        local db = getService("CDatabase");
        db:CheckColumns();
    end);
end

function SVC:CheckColumns()

end

function SVC:SelectRow(tab, cols, conds, callback, ...)
    if !tab then
        MsgErr("NilArgs", "tab");
        return;
    end
    if !tables[tab] then
        MsgErr("NilEntry", tab);
        return;
    end

    cols = cols or "*";
    local query = Format("SELECT %s FROM %s", cols, tab);
    if conds and conds != "" then
        query = query .. Format(" %s;", cond);
    else
        query = query .. ";";
    end

    local args = {...};
    self:Query(query, function(results)
        local db = getService("CDatabase");
        --MsgDebug(LOG_DB, "Selected row from table '%s'.", tab);

        for _, subQuery in pairs(results) do
            if !subQuery.status then return; end
            for _, row in pairs(subQuery.data) do
                for id, val in pairs(row) do
                    row[id] = db:CastValue(tab, id, val, CAST_OUT) or val;
                end
            end
        end

        if callback then
            args[#args + 1] = results;
            callback(unpack(args));
        end
    end);
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
    if !tables[tab] then
        MsgErr("NilEntry", tab);
        return;
    end
    if table.IsEmpty(data) then
        MsgErr("EmptyTable", "data");
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
    local args = {...};
    self:Query(query, function(results)
        --MsgDebug(LOG_DB, "New row inserted into table '%s'.", tab);

        if callback then
            args[#args + 1] = results;
            callback(unpack(args));
        end
    end);
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
    if !tables[tab] then
        MsgErr("NilEntry", tab);
        return;
    end
    if table.IsEmpty(data) then
        MsgErr("EmptyTable", "data");
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

    local args = {...};
    self:Query(query, function(results)
        --MsgDebug(LOG_DB, "Row updated in table '%s'.", tab);

        if callback then
            args[#args + 1] = results;
            callback(unpack(args));
        end
    end);
end

function SVC:RemoveRow()
    -- todo
end
