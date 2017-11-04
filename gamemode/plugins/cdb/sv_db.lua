--[[
    CDatabase server functionality.
]]

--
-- Constants.
--

-- Logging option.
LOG_DB = {pre = "[DB]", col = Color(0, 151, 151, 255)};

-- Casting flags.
CAST_IN = 1;
CAST_OUT = 2;

-- SQL default values.
SQL_DEF = {};
SQL_DEF["boolean"] = false;
SQL_DEF["number"] = 0;
SQL_DEF["string"] = "";
SQL_DEF["table"] = {};

-- SQL type values.
SQL_TYPE = {};
SQL_TYPE["counter"] = "INT";
SQL_TYPE["boolean"] = "BIT"
SQL_TYPE["number"] = "DECIMAL(%d)";
SQL_TYPE["string"] = "VARCHAR(%d)";
SQL_TYPE["table"] = "VARCHAR(%d)";

--
-- Local storage.
--

-- Micro-optimizations.
local bash      = bash;
local Format    = Format;
local hook      = hook;
local MsgDebug  = MsgDebug;
local MsgErr    = MsgErr;
local MsgLog    = MsgLog;
local pairs     = pairs;
local pon       = pon;
local sql       = sql;
local table     = table;
local tobool    = tobool;
local tonumber  = tonumber;
local tostring  = tostring;
local unpack    = unpack;

-- Casting tables.
local castIn = {
    ["boolean"] = function(bool)
        if bool then return 1;
        else return 0; end
    end,
    ["number"] = tonumber,
    ["string"] = function(str)
        return Format("\'%s\'", PLUG:EscapeStr(tostring(str)));
    end,
    ["table"] = function(tab)
        return Format("\'%s\'", PLUG:EscapeStr(pon.encode(tab)));
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

--
-- Service storage.
--

-- Database objects.
local dbObject = bash.Util.GetNonVolatileEntry("CDatabase_DBObject", EMPTY_TABLE);
local connected = bash.Util.GetNonVolatileEntry("CDatabase_Connected", false);
local tables = {};

--
-- Misc. operations.
--

-- Add custom errors.
bash.Util.AddErrType("NoDBModule", "No tmysql4 module found! This is required and must be resolved.");
bash.Util.AddErrType("NoDBConnect", "Unable to connect to MySQL server! (%s)");
bash.Util.AddErrType("QueryFailed", "The SQL query failed!\nQuery: %s\nError: %s");
bash.Util.AddErrType("QueryNumFailed", "The #%d SQL query in the statement failed!\nQuery: %s\nError: %s");
bash.Util.AddErrType("KeyExists", "A key already exists in this table! (Column %s in table %s)");

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

--
-- Plugin functions.
--

-- Connected to the external database.
function PLUG:Connect()
    local obj, err = tmysql.initialize(
        DB_HOST, DB_USER, DB_PASS, DB_DATA,
        DB_PORT, nil, CLIENT_MULTI_STATEMENTS
    );
    if obj then
        bash.Util.SetNonVolatileEntry("CDatabase_DBObject", obj);
        bash.Util.SetNonVolatileEntry("CDatabase_Connected", true);
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
    hook.Run("CDatabase_OnConnected");
end

-- Check to see if the database is connected.
function PLUG:IsConnected()
    return dbObject and connected;
end

-- Add a new table to the database struct.
function PLUG:AddTable(name)
    if tables[name] then return; end

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

-- Add a column to a table in the database struct.
function PLUG:AddColumn(tab, col, primary)
    if !tables[tab] then
        MsgErr("NilEntry", tab);
        return;
    end
    if !col.Name then
        MsgErr("NilField", "Name", "col");
        return;
    end

    local tabData = tables[tab];
    if tabData.Columns[col.Name] then return; end

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

-- Execute a query on the database.
function PLUG:Query(query, callback, ...)
    if self:IsConnected() then
        local args = {...};
        dbObject:Query(query, function(resultsTab)
            if #resultsTab == 1 then
                if !resultsTab[1].status then
                    MsgErr("QueryFailed", query, resultsTab[1].error);
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

        return true;
    else
        MsgErr("DBNotConnected");
        return false;
    end
end

-- Escape all special characters in a string.
function PLUG:EscapeStr(str)
    if self:IsConnected() then
        return dbObject:Escape(str);
    else
        return sql.SQLStr(str);
    end
end

-- Casts a value to/from the correct query form.
function PLUG:CastValue(col, val, inout)
    if !castIn[col.Type] and !castOut[col.Type] then
        return val;
    end

    inout = inout or CAST_IN;
    local castFuncs = (inout == CAST_IN and castIn) or castOut;

    if val == nil then return castFuncs[col.Type](SQL_DEF[col.Type]); end
    return castFuncs[col.Type](val);
end

-- Check to see if all tables in database struct exist in the database.
function PLUG:CheckTables()
    if !self:IsConnected() then
        MsgErr("DBNotConnected");
        return false;
    end

    if table.IsEmpty(tables) then
        MsgDebug(LOG_DB, "No tables registered in database. Skipping...");
        return false;
    end

    local query, cols, sqlType = "";
    for name, tab in pairs(tables) do
        query = query .. Format("CREATE TABLE IF NOT EXISTS %s(", name);
        cols = {};
        for _name, col in pairs(tab.Columns) do
            if col.Type == "boolean" then
                sqlType = SQL_TYPE[col.Type];
            else
                sqlType = Format(SQL_TYPE[col.Type], (col.MaxLength or 8000));
            end

            cols[#cols + 1] = Format(
                "`%s` %s %s %s, ",
                _name,
                sqlType,
                col.Default != nil and ("DEFAULT " .. self:CastValue(col.Type, col.Default, CAST_IN)) or "",
                col.Field or ""
            );
        end
        query = query .. table.concat(cols) .. Format("PRIMARY KEY(%s)); ", tab.PrimaryKey);
    end

    self:Query(query, function(results)
        MsgDebug(LOG_DB, "Table check complete.");
        self:CheckColumns();
    end);

    return true;
end

-- Check to see if all columns in database struct exist in the database.
function PLUG:CheckColumns()
    if !self:IsConnected() then
        MsgErr("DBNotConnected");
        return false;
    end

end

-- Select a row from the database with certain conditions.
function PLUG:SelectRow(tab, cols, conds, callback, ...)
    if !self:IsConnected() then
        MsgErr("DBNotConnected");
        return false;
    end

    if !tables[tab] then
        MsgErr("NilEntry", tab);
        return false;
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
        --MsgDebug(LOG_DB, "Selected row from table '%s'.", tab);

        for _, subQuery in pairs(results) do
            if !subQuery.status then return; end
            for _, row in pairs(subQuery.data) do
                for id, val in pairs(row) do
                    row[id] = self:CastValue(tables[tab].Columns[id], val, CAST_OUT) or val;
                end
            end
        end

        if callback then
            args[#args + 1] = results;
            callback(unpack(args));
        end
    end);

    return true;
end

-- Insert a new row into the database with data.
function PLUG:InsertRow(tab, data, callback, ...)
    if !self:IsConnected() then
        MsgErr("DBNotConnected");
        return false;
    end

    if !tables[tab] then
        MsgErr("NilEntry", tab);
        return false;
    end

    local query = Format("INSERT INTO %s(", tab);
    local vars = {};
    local vals = {};
    for col, val in pairs(data) do
        vars[#vars + 1] = col;
        vals[#vals + 1] = self:CastValue(tables[tab].Columns[col], val, CAST_IN);
    end

    query = query .. table.concat(vars, ", ") .. ") ";
    query = query .. "VALUES(" .. table.concat(vals, ", ") .. ");";
    local args = {...};
    self:Query(query, function(results)
        --MsgDebug(LOG_DB, "New row inserted into table '%s'.", tab);

        if callback then
            args[#args + 1] = results;
            callback(unpack(args));
        end
    end);

    return true;
end

-- Update an existing row in the database.
function PLUG:UpdateRow(tab, data, cond, callback, ...)
    if !self:IsConnected() then
        MsgErr("DBNotConnected");
        return false;
    end

    if !tables[tab] then
        MsgErr("NilEntry", tab);
        return false;
    end
    if table.IsEmpty(data) then
        MsgErr("EmptyTable", "data");
        return false;
    end

    local query = Format("UPDATE %s SET ", tab);
    local vals = {};
    for col, val in pairs(data) do
        vals[#vals + 1] = Format("%s = %s", col, self:CastValue(tables[tab].Columns[col], val, CAST_IN));
    end
    query = query .. table.concat(vals, ", ");

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

    return true;
end

function PLUG:RemoveRow()
    if !self:IsConnected() then
        MsgErr("DBNotConnected");
        return false;
    end

    -- todo
end
