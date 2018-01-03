--[[
    Database system functions.
]]

--
-- Local storage.
--

local bash = bash;

local LOG_DB = {pre = "[DB]", col = Color(0, 151, 151, 255)};

local castIn = {
    ["boolean"] = function(bool)
        if bool then return 1;
        else return 0; end
    end,
    ["number"] = tonumber,
    ["counter"] = tonumber,
    ["string"] = function(str)
        return Format("\'%s\'", bash.Database.EscapeStr(tostring(str or "")));
    end,
    ["table"] = function(tab)
        return Format("\'%s\'", bash.Database.EscapeStr(pon.encode(tab or {})));
    end
};
local castOut = {
    ["boolean"] = tobool,
    ["number"] = tonumber,
    ["counter"] = tonumber,
    ["string"] = tostring,
    ["table"] = function(str)
        if str == "" then str = PON_EMPTY; end
        return pon.decode(tostring(str or PON_EMPTY));
    end
};

local SQL_DEF = {};
SQL_DEF["boolean"] = false;
SQL_DEF["number"] = 0;
SQL_DEF["counter"] = 1;
SQL_DEF["string"] = "";
SQL_DEF["table"] = {};

local SQL_TYPE = {};
SQL_TYPE["counter"] = "INT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE";
SQL_TYPE["boolean"] = "BIT"
SQL_TYPE["number"] = "DECIMAL(%d)";
SQL_TYPE["string"] = "VARCHAR(%d)";
SQL_TYPE["table"] = "VARCHAR(%d)";

--
-- Global storage.
--

CAST_IN = 1;
CAST_OUT = 2;

bash.Database           = bash.Database or {};
bash.Database.Tables    = bash.Database.Tables or {};
bash.Database.Object    = bash.Database.Object or {};
bash.Database.Connected = bash.Database.Connected or false;

--
-- Database functions.
--

-- tmysql4 is the required SQL module.
if !tmysql4 then
    local status, mod = pcall(require, "tmysql4");
    if !status then
        bash.Util.MsgErr("NoDBModule");
        return;
    else
        bash.Util.MsgLog(LOG_INIT, "tmysql4 module loaded.");
    end
end

-- Connect to the database.
function bash.Database.Connect()
    local obj, err = tmysql.initialize(
        DB_HOST, DB_USER, DB_PASS, DB_DATA,
        DB_PORT, nil, CLIENT_MULTI_STATEMENTS
    );
    if obj then
        bash.Database.Object = obj;
        bash.Database.Connected = true;

        bash.Util.MsgLog(LOG_DB, "Successfully connected to MySQL server!");
    else
        bash.Util.MsgErr("NoDBConnect", err);
        return;
    end

    bash.Database.CheckTables();
end

-- Add a column to a table in the database struct.
function bash.Database.AddColumn(tab, col, primary)
    local tabData = bash.Database.Tables[tab];
    if !tabData then
        tabData = {
            Name = tab,
            Columns = {},
            PrimaryKey = ""
        };

        bash.Database.Tables[tab] = tabData;
        bash.Util.MsgDebug(LOG_DB, "Database table registered with name '%s'.", tab);
    end

    -- col.Name = col.Name;
    col.Type = col.Type or "string";
    --col.MaxLength = col.MaxLength;
    --col.Default = col.Default;

    bash.Util.MsgDebug(LOG_DB, "Database column '%s' registered in table '%s'.", col.Name, tab);

    if primary then
        tabData.PrimaryKey = col.Name;
        bash.Util.MsgDebug(LOG_DB, "Primary key in table '%s' set to column '%s'.", tabData.Name, col.Name);
    end

    tabData.Columns[col.Name] = col;
end

-- Execute a query on the database.
function bash.Database.Query(query, callback, ...)
    if bash.Database.Connected then
        local args = {...};
        bash.Database.Object:Query(query, function(resultsTab)
            if #resultsTab == 1 then
                if !resultsTab[1].status then
                    bash.Util.MsgErr("QueryFailed", query, resultsTab[1].error);
                end
            else
                for index, results in ipairs(resultsTab) do
                    if !results.status then
                        bash.Util.MsgErr("QueryNumFailed", index, query, results.error);
                    end
                end
            end

            if callback then
                args[#args + 1] = resultsTab;
                callback(unpack(args));
            end
        end);

        return true;
    else
        bash.Util.MsgErr("DBNotConnected");
        return false;
    end
end

-- Handle casting in and out of the database.
function bash.Database.CastData(tab, data, inout)
    local tabData = bash.Database.Tables[tab];
    if !tabData then return; end

    inout = inout or CAST_IN;
    local castFuncs = (inout == CAST_IN and castIn) or castOut;
    local colData;
    for id, val in pairs(data) do
        colData = tabData.Columns[id];
        if !colData then continue; end
        if !castFuncs[colData.Type] then continue; end

        data[id] = castFuncs[colData.Type](val);
    end
end

-- Escape all special characters in a string.
function bash.Database.EscapeStr(str)
    if bash.Database.Connected then
        return bash.Database.Object:Escape(str);
    else
        return sql.SQLStr(str);
    end
end

-- Check to see if all tables in database struct exist in the database.
function bash.Database.CheckTables()
    if table.IsEmpty(bash.Database.Tables) then
        bash.Util.MsgDebug(LOG_DB, "No tables registered in database. Skipping...");
        return;
    end

    local query, cols, sqlType = "";
    for name, tab in pairs(bash.Database.Tables) do
        if table.IsEmpty(tab.Columns) then continue; end

        query = query .. Format("CREATE TABLE IF NOT EXISTS %s(", name);
        cols = {};
        for _name, col in pairs(tab.Columns) do
            if col.Type == "counter" or col.Type == "boolean" then
                sqlType = SQL_TYPE[col.Type];
            else
                sqlType = Format(SQL_TYPE[col.Type], (col.MaxLength or (col.Type != "number" and 8000 or 20)));
            end

            cols[#cols + 1] = Format(
                "`%s` %s, ",
                _name,
                sqlType
            );
        end
        query = query .. table.concat(cols) .. Format("PRIMARY KEY(%s)); ", tab.PrimaryKey);
    end

    bash.Database.Query(query, function(results)
        bash.Util.MsgDebug(LOG_DB, "Table check complete.");
        bash.Database.CheckColumns();
    end);
end

-- Check to see if all columns in database struct exist in the database.
function bash.Database.CheckColumns()
    -- TODO: Finish this function.
end

-- Select a row from the database with certain conditions.
function bash.Database.SelectRow(tab, cols, conds, callback, ...)
    cols = cols or "*";
    local query = Format("SELECT %s FROM %s", cols, tab);
    if conds and conds != "" then
        query = query .. Format(" %s;", cond);
    else
        query = query .. ";";
    end

    local args = {...};
    bash.Database.Query(query, function(results)
        bash.Util.MsgDebug(LOG_DB, "Selected row from table '%s'.", tab);
        PrintTable(results);

        for _, subQuery in pairs(results) do
            if !subQuery.status then return; end

            for _, row in pairs(subQuery.data) do
                bash.Database.CastData(tab, row, CAST_OUT);
            end
        end

        if callback then
            args[#args + 1] = results;
            callback(unpack(args));
        end
    end);
end

-- Insert a new row into the database with data.
function bash.Database.InsertRow(tab, data, callback, ...)
    if !bash.Database.Tables[tab] then return; end

    bash.Database.CastData(tab, data, CAST_IN);
    local tabData = bash.Database.Tables[tab];
    local query = Format("INSERT INTO %s(", tab);
    local vars = {};
    local vals = {};
    for col, val in pairs(data) do
        -- Exclude invalid data.
        if !tabData.Columns[col] then continue; end
        vars[#vars + 1] = col;
        vals[#vals + 1] = val;
    end

    query = query .. table.concat(vars, ", ") .. ") ";
    query = query .. "VALUES(" .. table.concat(vals, ", ") .. ");";
    bash.Database.Query(query, callback, ...);
end

-- Update an existing row in the database.
function bash.Database.UpdateRow(tab, data, cond, callback, ...)
    bash.Database.CastData(tab, data, CAST_IN);
    local query = Format("UPDATE %s SET ", tab);
    local vals = {};
    for col, val in pairs(data) do
        vals[#vals + 1] = Format("%s = %s", col, val);
    end
    query = query .. table.concat(vals, ", ");

    if cond and cond != "" then
        query = Format("%s WHERE %s;", query, cond);
    else
        query = query .. ";";
    end

    bash.Database.Query(query, callback, ...);
end

-- Delete a row from the database.
function bash.Database.DeleteRow(tab, cond, callback, ...)
    -- TODO: Finish this function.
    local query = Format("DELETE FROM %s WHERE %s;", tab, cond);
    bash.Database.Query(query, callback, ...);
end

--
-- Engine hooks.
--

-- Connect to the database when loaded.
hook.Add("PostInit_Engine", "bash_DatabaseConnect", bash.Database.Connect);
