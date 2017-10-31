--[[
    Global shared utility functions.
]]

local bash = bash;

function handleFunc(var, ...)
    if var == nil then return; end
    if type(var) == "function" then
        return var(unpack({...}));
    else
        return var;
    end
end

function isplayer(ply)
    return ply and type(ply) == "Player" and ply.IsPlayer and ply:IsPlayer();
end

function MsgLog(log, text, ...)
    log = log or LOG_DEF;
    if !text then text = ""; end

    text = Format("%s " .. text, log.pre or "", unpack({...})) .. '\n';
    MsgC(log.col or color_con, text);

    -- if verbose logging enabled, log text
end

function MsgDebug(log, text, ...)
    if !bash.debug then return; end

    local args = {...};
    MsgLog(log, text, unpack(args));
end

function MsgErr(errType, ...)
    if !errType then
        MsgErr("NilArgs", "errType");
        return;
    end
    if !ERR_TYPES[errType] then
        MsgErr("NilEntry", errType);
        return;
    end

    local args = {...};
    local errMsg = ERR_TYPES[errType];
    local _, count = errMsg:gsub("%%", "");
    if #args < count then
        MsgErr("InsufVarArgs");
        return;
    end

    local funcInfo = debug.getinfo(2);
    local fromInfo;
    if funcInfo.what == "main" then
        fromInfo = funcInfo;
    else
        fromInfo = debug.getinfo(3);
    end

    local gm = (GM and GM.Name) or (GAMEMODE and GAMEMODE.Name);
    if _G["PLUG"] then
        gm = gm .. " Plugin: " .. _G["PLUG"].Name;
    end

    local src = fromInfo.short_src;
    local srcFile = string.GetFileFromFilename(src);
    local srcFunc = (funcInfo.name != "" and funcInfo.name) or "In File";
    local srcStr = Format("%s -> %s line %d", srcFunc, srcFile, fromInfo.currentline);

    MsgLog(LOG_ERR, "[From %s] (%s) %s", gm, srcStr, Format(errMsg, unpack(args)));

    -- log to file
end

function addErrType(name, str)
    if !name or !str or ERR_TYPES[name] then return; end
    ERR_TYPES[name] = str;
end

function processFile(file)
    if !file then
        MsgErr("NilArgs", "file");
        return;
    end

    local pre = file:GetFileFromFilename();
    pre = pre:sub(1, pre:find('_', 1));
    if PREFIXES_CLIENT[pre] then
        if CLIENT then include(file);
        else AddCSLuaFile(file); end
    elseif PREFIXES_SERVER[pre] then
        if SERVER then include(file); end
    elseif PREFIXES_SHARED[pre] then
        if CLIENT then include(file)
        else AddCSLuaFile(file); include(file); end
    end
end

function processDir(dir)
    local from = debug.getinfo(2);
    local src = from.short_src;
    src = src:GetPathFromFilename();
    src = src:Replace("gamemodes/", "");
    src = src .. dir .. "/";

    local files, dirs = file.Find(src .. "*", "LUA", nameasc);
    for _, file in pairs(files) do
        file = src .. file;
        processFile(file);
    end
end

function processPlugins()
    local from = debug.getinfo(2);
    local src = from.short_src;
    src = src:GetPathFromFilename();
    src = src:Replace("gamemodes/", "");
    src = src .. "plugins/";

    local singles, plugins = file.Find(src .. "*", "LUA", nameasc);
    for _, file in pairs(singles) do
        file = src .. file;
        processFile(file);
    end

    local plugFiles;
    for _, plugin in pairs(plugins) do
        plugFiles = file.Find(src .. plugin .. "/*.lua", "LUA", nameasc);
        if table.HasValue(plugFiles, "sh_plugin.lua") then
            processFile(src .. plugin .. "/sh_plugin.lua");
        else
            MsgErr("NoPluginFile", plugin);
        end
    end

    checkDependencies();
end

function checkDependencies()
    for id, plug in pairs(bash.plugins) do
        for _, dep in pairs(plug.Depends) do
            if !bash.plugins[dep] then
                MsgLog(LOG_WARN, "Plugin %s is missing dependency %s! This WILL cause errors! Resolve this immediately!", plug.Name, dep);
            end
        end
    end

    MsgLog(LOG_INIT, "All %s plugins have met their dependencies.", table.Count(bash.plugins));
end

function processMeta(id)
    local from = debug.getinfo(2);
    local src = from.short_src;
    src = src:GetPathFromFilename();
    src = src:Replace("gamemodes/", "");
    src = src .. "meta/";

    if _G["PLUG"] then
        id = id or _G["PLUG"].ID;
    end

    defineMeta_start(id);
    local singles, plugins = file.Find(src .. "*", "LUA", nameasc);
    for _, file in pairs(singles) do
        file = src .. file;
        processFile(file);
    end
    defineMeta_end();
end

function processService(id)
    local from = debug.getinfo(2);
    local src = from.short_src;
    src = src:GetPathFromFilename();
    src = src:Replace("gamemodes/", "");
    src = src .. "services/";

    if _G["PLUG"] then
        id = id or _G["PLUG"].ID;
    end

    defineService_start(id);
    local singles, plugins = file.Find(src .. "*", "LUA", nameasc);
    for _, file in pairs(singles) do
        file = src .. file;
        processFile(file);
    end
    defineService_end();
end

function getClientData(ply, id)
    if CLIENT then
        if ply then
            return bash.clientData[ply];
        else
            return bash.clientData;
        end
    end

    if !isplayer(ply) then
        MsgErr("InvalidPlayer", "ply");
        return;
    end

    local index = ply:EntIndex();
    if !bash.clientData[index] then
        MsgErr("NilEntry", index);
        return;
    end

    if id then
        if bash.clientData[index][id] == nil then
            MsgErr("NilEntry", id);
            return;
        end

        return bash.clientData[index][id];
    else
        return bash.clientData[index];
    end
end

function getNonVolatileEntry(id, def)
    if !id then
        MsgErr("NilArgs", "id");
        return;
    end

    bash.nonVolatile = bash.nonVolatile or {};
    local val = bash.nonVolatile[id];
    if val == nil then
        val = handleFunc(def);
        if val == nil then
            MsgErr("NilNVEntry", id);
            return;
        end

        bash.nonVolatile[id] = val;
        return val;
    else
        return handleFunc(val);
    end
end

function setNonVolatileEntry(id, val)
    if !id then
        MsgErr("NilArgs", "id");
        return;
    end
    if val == nil then
        MsgErr("UnsafeNVEntry", id);
        return;
    end

    bash.nonVolatile = bash.nonVolatile or {};
    bash.nonVolatile[id] = handleFunc(val);
end

function removeNonVolatileEntry(id)
    if !id then
        MsgErr("NilArgs", "id");
        return;
    end

    bash.nonVolatile = bash.nonVolatile or {};
    bash.nonVolatile[id] = nil;
end

function defineMeta_start(id)
    if !id then
        MsgErr("NilArgs", "id");
        return;
    end
    if _G["META"] then
        MsgErr("DefStarted", _G["META"].ID, id);
        return;
    end

    bash.meta = bash.meta or {};

    if bash.meta[id] then
        MsgErr("DupEntry", id);
        return;
    end

    _G["META"] = {};
    local meta = _G["META"];
    meta.ID = id;
    meta.__index = meta;
    meta.IsValid = function() return true; end
end

function defineMeta_end()
    local meta = _G["META"];
    if !meta then
        MsgErr("NoDefStarted");
        return;
    end

    local pre = "";
    local plug = _G["PLUG"];
    if plug then
        plug.Metas[meta.ID] = meta;
        pre = Format("(In Plugin %s ->) ", plug.Name);
    end

    MsgDebug(LOG_INIT, "%sRegistered metatable: %s", pre, meta.ID);
    bash.meta[meta.ID] = meta;
    _G["META"] = nil;
end

function getMeta(id)
    if !id then
        MsgErr("NilArgs", "id");
        return;
    end
    if !bash.meta[id] then
        MsgErr("NilEntry", id);
        return;
    end

    return bash.meta[id];
end

function hasMeta(id)
    return bash.meta[id] != nil;
end

function defineService_start(id)
    if !id then
        MsgErr("NilArgs", "id");
        return;
    end
    if _G["SVC"] then
        MsgErr("DefStarted", _G["SVC"].ID, id);
        return;
    end

    bash.services = bash.services or {};

    if bash.services[id] then
        MsgErr("DupEntry", id);
        return;
    end

    _G["SVC"] = {};
    local svc = _G["SVC"];
    svc.ID = id;
    --svc.Name = id;
    --svc.Author = "Unknown";
    --svc.Desc = "A bash service.";
    svc.IsValid = function() return true; end
end

function defineService_end()
    local svc = _G["SVC"];
    if !svc then
        MsgErr("NoDefStarted");
        return;
    end

    local pre = "";
    local plug = _G["PLUG"];
    if plug then
        plug.Services[svc.ID] = svc;
        pre = Format("(In Plugin %s ->) ", plug.Name);
    end

    MsgDebug(LOG_INIT, "%sRegistered service: %s", pre, svc.ID);
    bash.services[svc.ID] = svc;
    _G["SVC"] = nil;
end

function getService(id)
    if !id then
        MsgErr("NilArgs", "id");
        return;
    end
    if !bash.services[id] then
        MsgErr("NilEntry", id);
        return;
    end

    return bash.services[id];
end

function hasService(id)
    return bash.services[id] != nil;
end

function definePlugin_start(id)
    if !id then
        MsgErr("NilArgs", "id");
        return;
    end
    if _G["PLUG"] then
        MsgErr("DefStarted", _G["PLUG"].ID, id);
        return;
    end

    bash.plugins = bash.plugins or {};

    if bash.plugins[id] then
        MsgErr("DupEntry", id);
        return;
    end

    _G["PLUG"] = {};
    local plug = _G["PLUG"];
    plug.ID = id;
    plug.Name = id;
    plug.Author = "Unknown";
    plug.Desc = "A custom plugin.";
    plug.Metas = {};
    plug.Services = {};
    plug.Depends = {};
    plug.IsValid = function() return true; end
end

function definePlugin_end()
    local plug = _G["PLUG"];
    if !plug then
        MsgErr("NoDefStarted");
        return;
    end

    MsgDebug(LOG_INIT, "Registered plugin: %s", plug.ID);
    bash.plugins[plug.ID] = plug;
    _G["PLUG"] = nil;
end

function getPlugin(id)
    if !id then
        MsgErr("NilArgs", "id");
        return;
    end
    if !bash.plugins[id] then
        MsgErr("NilEntry", id);
        return;
    end

    return bash.plugins[id];
end

function hasPlugin(id)
    return bash.plugins[id] != nil;
end
