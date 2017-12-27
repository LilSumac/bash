--[[
    Database system functions.
]]

--
-- Local storage.
--

local bash = bash;

local LOG_DB = {pre = "[DB]", col = Color(0, 151, 151, 255)};

--
-- Global storage.
--

bash.Database           = bash.Database or {};
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

    -- Other stuff.
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

            args[#args + 1] = resultsTab;
            callback(unpack(args));
        end);

        return true;
    else
        bash.Util.MsgErr("DBNotConnected");
        return false;
    end
end

--
-- Engine hooks.
--

-- Connect to the database when loaded.
hook.Add("PostInit_Engine", "bash_ConnectToDB", bash.Database.Connect);
