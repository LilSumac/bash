--[[
    Shared utility functions.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local AddCSLuaFile  = AddCSLuaFile;
local bash          = bash;
local debug         = debug;
local file          = file;
local Format        = Format;
local include       = include;
local MsgC          = MsgC;
local pairs         = pairs;
local string        = string;
local table         = table;
local type          = type;
local unpack        = unpack;

--
-- Local functions.
--

-- Make sure all plugins have their dependencies met.
local function checkDependencies()
    local allMet, count, total = true, 0, 0;
    for id, plug in pairs(bash.Plugins) do
        for _, dep in pairs(plug.Depends) do
            if !bash.Plugins[dep] then
                MsgLog(LOG_WARN, "Plugin %s is missing dependency %s! This WILL cause errors! Resolve this immediately!", plug.Name, dep);
                allMet = false;
                count = count + 1;
            end

            total = total + 1;
        end
    end

    if !allMet then
        MsgLog(LOG_WARN, "There was %d/%d plugin(s) with unmet dependencies. Please see earlier errors for more info.", count, total);
    else
        MsgLog(LOG_INIT, "All %s plugins have met their dependencies.", total);
    end
end

--
-- Global utility functions.
-- Functions that are simple enough that they can be their own
-- global variable.
--

-- Send something to the output and log if verbose mode is enabled.
function MsgLog(log, text, ...)
    log = log or LOG_DEF;
    if !text then text = ""; end

    text = Format("%s " .. text, log.pre or "", unpack({...})) .. '\n';
    MsgC(log.col or color_con, text);

    -- if verbose logging enabled, log text
end

-- Send something to the output if debug mode is enabled.
function MsgDebug(log, text, ...)
    if !bash.DebugMode then return; end

    local args = {...};
    MsgLog(log, text, unpack(args));
end

-- Send something to the output as an error with a trace and log.
function MsgErr(errType, ...)
    errType = errType or "Generic";
    local errMsg = ERR_TYPES[errType] or ERR_TYPES["Generic"];
    local args = {...};
    local _, count = errMsg:gsub("%%", "");
    if #args != count then
        MsgErr("InvalidVarArgs");
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
        gm = gm .. " > " .. _G["PLUG"].Name;
    end

    local src = fromInfo.short_src;
    local srcFile = string.GetFileFromFilename(src);
    local srcFunc = (funcInfo.name != "" and funcInfo.name) or "In File";
    local srcStr = Format("%s (%s line %d) ", srcFunc, srcFile, fromInfo.currentline);

    MsgLog(LOG_ERR, "[%s > %s] %s", gm, srcStr, Format(errMsg, unpack(args)));

    -- log to file
end

-- Interpret a variable as either its value or function return value.
function handleFunc(var, ...)
    if var == nil then return; end
    if type(var) == "function" then
        return var(unpack({...}));
    else
        return var;
    end
end

-- Check to see if a variable is a player and a valid one.
function isplayer(ply)
    return ply and type(ply) == "Player" and ply.IsPlayer and ply:IsPlayer();
end

-- Start a definition of a metatable struct.
function defineMeta_start(id)
    if _G["META"] then
        MsgErr("DefStarted", _G["META"].ID, id);
        return;
    end

    bash.Meta = bash.Meta or {};
    _G["META"] = {};
    local meta = _G["META"];
    meta.ID = id;
    meta.__index = meta;
end

-- End a definition of a metatable struct.
function defineMeta_end()
    local meta = _G["META"];
    if !meta then
        MsgErr("NoDefStarted");
        return;
    end

    local pre = "";
    local plug = _G["PLUG"];
    if plug then
        plug.Meta[meta.ID] = true;
        pre = Format("(In Plugin %s ->) ", plug.Name);
    end

    MsgDebug(LOG_INIT, "%sRegistered metatable: %s", pre, meta.ID);
    bash.Meta[meta.ID] = meta;
    _G["META"] = nil;
end

-- Start a definition of a plugin struct.
function definePlugin_start(id)
    if _G["PLUG"] then
        MsgErr("DefStarted", _G["PLUG"].ID, id);
        return;
    end

    bash.Plugins = bash.Plugins or {};
    _G["PLUG"] = {};
    local plug = _G["PLUG"];
    plug.ID = id;
    plug.Name = id;
    plug.Author = "Unknown";
    plug.Desc = "A custom plugin.";
    plug.Meta = {};
    plug.Depends = {};
end

-- End a definition of a plugin struct.
function definePlugin_end()
    local plug = _G["PLUG"];
    if !plug then
        MsgErr("NoDefStarted");
        return;
    end

    MsgDebug(LOG_INIT, "Registered plugin: %s", plug.ID);
    bash.Plugins[plug.ID] = plug;
    _G["PLUG"] = nil;
end

--
-- Utility functions.
--

-- Add/edit an error message struct.
function bash.Util.AddErrType(name, str)
    ERR_TYPES[name] = str;
end

-- Process a file based on its prefix.
function bash.Util.ProcessFile(file)
    local pre = file:GetFileFromFilename();
    pre = pre:sub(1, pre:find('_', 1));
    if PREFIXES_CLIENT[pre] then
        if CLIENT then include(file);
        else AddCSLuaFile(file); end
    elseif PREFIXES_SERVER[pre] then
        if SERVER then include(file); end
    elseif PREFIXES_SHARED[pre] then
        if CLIENT then include(file);
        else AddCSLuaFile(file); include(file); end
    end
end

-- Process all files in a directory based on working directory.
function bash.Util.ProcessDir(dir)
    local from = debug.getinfo(2);
    local src = from.short_src;
    src = src:GetPathFromFilename();
    src = src:Replace("gamemodes/", "");
    src = src .. dir .. "/";

    local files, dirs = file.Find(src .. "*", "LUA", nameasc);
    for _, file in pairs(files) do
        file = src .. file;
        bash.Util.ProcessFile(file);
    end
end

-- Process all plugins located in the working directory.
function bash.Util.ProcessPlugins()
    local from = debug.getinfo(2);
    local src = from.short_src;
    src = src:GetPathFromFilename();
    src = src:Replace("gamemodes/", "");
    src = src .. "plugins/";

    local singles, plugins = file.Find(src .. "*", "LUA", nameasc);
    -- Process plugins located in a single file.
    for _, file in pairs(singles) do
        file = src .. file;
        bash.Util.ProcessFile(file);
    end

    -- Process plugins located in a directory.
    local plugFiles;
    for _, plugin in pairs(plugins) do
        plugFiles = file.Find(src .. plugin .. "/*.lua", "LUA", nameasc);
        if table.HasValue(plugFiles, "sh_plugin.lua") then
            bash.Util.ProcessFile(src .. plugin .. "/sh_plugin.lua");
        else
            MsgErr("NoPluginFile", plugin);
        end
    end

    checkDependencies();
end

-- Fetch a non-volatile memory entry, or a default value.
function bash.Util.GetNonVolatileEntry(id, def)
    bash.NonVolatile = bash.NonVolatile or {};
    local val = bash.NonVolatile[id];
    if val == nil then
        val = handleFunc(def);
        bash.NonVolatile[id] = val;
        return val;
    else
        return handleFunc(val);
    end
end

-- Sets the value of a non-volatile memory entry.
function bash.Util.SetNonVolatileEntry(id, val)
    bash.NonVolatile = bash.NonVolatile or {};
    bash.NonVolatile[id] = handleFunc(val);
end

-- Check to see if a metatable struct has been registered.
function bash.Util.HasMeta(id)
    return bash.Meta[id] != nil;
end

-- Fetch a registered metatable struct.
function bash.Util.GetMeta(id)
    return bash.Meta[id];
end

-- Check to see if a plugin struct has been registered.
function bash.Util.HasPlugin(id)
    return bash.Plugins[id] != nil;
end

-- Fetch a registered plugin struct.
function bash.Util.GetPlugin(id)
    return bash.Plugins[id];
end
