local bash = bash;

function addErrType(name, str)
    if !name or !str or ERR_TYPES[name] then return; end
    ERR_TYPES[name] = str;
end

function MsgCon(color, text, ...)
    if type(color) != "table" then return; end
    if !text then text = ""; end

    text = Format(text, unpack({...})) .. '\n';
    MsgC(color, text);

    -- if verbose logging enabled, log text
end

function MsgErr(errType, ...)
    if !errType then
        MsgErr("NilErrType");
        return;
    end
    if !ERR_TYPES[errType] then
        MsgErr("UndefErrType", errType);
        return;
    end

    local args = {...};
    local funcInfo = debug.getinfo(2);
    local fromInfo;
    if funcInfo.what == "main" then
        fromInfo = funcInfo;
    else
        fromInfo = debug.getinfo(3);
    end

    local src = fromInfo.short_src;
    local srcFile = string.GetFileFromFilename(src);
    local srcFunc = (funcInfo.name != "" and funcInfo.name) or "In File";
    local srcStr;
    if _G["PLUGIN"] then
        srcStr = Format("%s -> %s (%s) (%s line %d)", srcFunc, GM.Name, "Plugin: " .. _G["PLUGIN"].Name, srcFile, fromInfo.currentline);
    else
        srcStr = Format("%s -> %s (%s line %d)", srcFunc, GM.Name, srcFile, fromInfo.currentline);
    end

    MsgCon(color_red, "[%s] %s", srcStr, Format(ERR_TYPES[errType], unpack(args)));
end

function getID(len, pre)
    local id = math.Round(os.time() + (math.random(10000000, 99999999)) + (math.cos(SysTime()) * 26293888));
    id = tostring(id);
    MsgN(id)
    len = len or math.Min(id:len(), len);
    id = id:sub(id:len() - len + 1);

    return pre .. id;
end

function processFile(file)
    if !file then
        MsgErr("NilArgs", "file");
        return;
    end

    local pre = file:GetFileFromFilename();
    pre = pre:sub(1, pre:find('_', 1));
    MsgN(pre);
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

function addNonVolatileEntry(id, value)

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
end

function defineMeta_end()
    local meta = _G["META"];
    if !meta then
        MsgErr("NoDefStarted");
        return;
    end

    MsgCon(color_green, "Registering metatable: %s", meta.ID);
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
    svc.Name = id;
    svc.Author = "Unknown";
    svc.Desc = "A bash service.";
end

function defineService_end()
    local svc = _G["SVC"];
    if !svc then
        MsgErr("NoDefStarted");
        return;
    end

    MsgCon(color_green, "Registering service: %s", svc.ID);
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

function definePlugin_start(id, singleFile)
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
end

function definePlugin_end()
    local plug = _G["PLUG"];
    if !plug then
        MsgErr("NoDefStarted");
        return;
    end

    MsgCon(color_green, "Registering plugin: %s", plug.ID);
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
