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

    MsgCon(color_red, "[%s] %s", srcStr, Format(ERR_TYPES[errType], table.concat(args, ", ")));
end

function getID(len, pre)
    local id = math.Round(os.time() + (system.AppTime() or os.clock()) + (math.cos(SysTime()) * 26293888));
    id = tostring(id);
    MsgN(id)
    len = len or math.Min(id:len(), len);
    id = id:sub(id:len() - len + 1);

    return pre .. id;
end

function defineService_start(name)
    if !name then
        MsgErr("NilArgs", "name");
        return;
    end

    bash.services = bash.services or {};
end

function defineService_end()

end

function getService(svc)
    local bool = true;
end

function definePlugin_start(name, singleFile)
    if !name then
        MsgErr("NilArgs", "name");
        return;
    end
    if _G["PLUGIN"] then
        MsgErr("PlgStarted", _G["Plugin"].Name, name);
        return;
    end

    bash.plugins = bash.plugins or {};

    _G["PLUGIN"] = {};
    local plug = _G["PLUGIN"];
    plug.Author = "Unknown";
end

function definePlugin_end()
    local plug = _G["PLUGIN"];
    if !plug then
        MsgErr("NoPlgStarted");
        return;
    end
end

function getPlugin(name)

end
