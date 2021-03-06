--[[
    Shared utility functions.
]]

--
-- Local storage.
--

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
-- Global storage.
--

bash.Util = bash.Util or {};

--
-- Utility functions.
--

-- Interpret a variable as either its value or function return value.
function handleFunc(var, ...)
    if var == nil then return; end

    local _type = type(var);
    if _type == "function" then
        return var(unpack({...}));
    elseif _type == "table" then
        if var.Func and var.Args then
            local args = {};
            for index, arg in ipairs(var.Args) do
                args[index] = handleFunc(arg);
            end

            return var.Func(unpack(args));
        else
            return var;
        end
    else
        return var;
    end
end

-- Check to see if a variable is an entity and a valud one.
function isent(ent)
    return ent != nil and type(ent) == "Entity" and ent.IsValid and ent:IsValid();
end

-- Check to see if a variable is a player and a valid one.
function isplayer(ply)
    return ply != nil and type(ply) == "Player" and ply.IsPlayer and ply:IsPlayer();
end

-- Send something to the output and log if verbose mode is enabled.
function bash.Util.MsgLog(log, text, ...)
    log = log or LOG_DEF;
    if !text then text = ""; end

    text = Format("%s " .. text, log.pre or "", unpack({...})) .. '\n';
    MsgC(log.col or color_con, text);

    -- if verbose logging enabled, log text
end

-- Send something to the output if debug mode is enabled.
function bash.Util.MsgDebug(log, text, ...)
    --if 1 == 1 then return; end 
    -- TODO: Add the real debug mode condition.
    --if !bash.DebugMode then return; end

    bash.Util.MsgLog(log, text, ...);
end

-- Send something to the output as an error with a trace and log.
function bash.Util.MsgErr(errType, ...)
    errType = errType or "Generic";
    local errMsg = ERR_TYPES[errType] or ERR_TYPES["Generic"];
    local args = {...};
    local _, count = errMsg:gsub("%%", "");
    if #args != count and errType != "Generic" then
        bash.Util.MsgErr("InvalidVarArgs");
        return;
    end

    local funcInfo = debug.getinfo(2);
    local fromInfo;
    if funcInfo.what == "main" then
        fromInfo = funcInfo;
    else
        fromInfo = debug.getinfo(3);
    end

    local gm = (GM and GM.FolderName) or (GAMEMODE and GAMEMODE.FolderName);
    if PLUGIN then
        gm = gm .. " > " .. PLUGIN.Name;
    end

    local src = fromInfo.short_src;
    local srcFile = string.GetFileFromFilename(src);
    local srcFunc = (funcInfo.name != "" and funcInfo.name) or "In File";
    local srcStr = Format("%s (%s line %d) ", srcFunc, srcFile, fromInfo.currentline);

    bash.Util.MsgLog(LOG_ERR, "[%s > %s] %s", gm, srcStr, Format(errMsg, unpack(args)));

    -- TODO: Log to file.
end

-- Add/edit an error message struct.
function bash.Util.AddErrType(name, str)
    ERR_TYPES[name] = str;
end

-- Process a file based on its prefix or the given argument.
function bash.Util.ProcessFile(file, forceScope)
    local pre = file:GetFileFromFilename();
    pre = pre:sub(1, pre:find('_', 1));
    if PREFIXES_CLIENT[pre] or forceScope == "CLIENT" then
        if CLIENT then include(file);
        else AddCSLuaFile(file); end
    elseif PREFIXES_SERVER[pre] or forceScope == "SERVER" then
        if SERVER then include(file); end
    elseif PREFIXES_SHARED[pre] or forceScope == "SHARED" then
        if CLIENT then include(file);
        else AddCSLuaFile(file); include(file); end
    end
end

-- Process all files in a directory relative to the root gamemode folder or CWD.
function bash.Util.ProcessDir(dir, relative, forceScope)
    local src;
    if relative then
        local from = debug.getinfo(2);
        src = from.short_src;
        src = src:GetPathFromFilename();
        src = src:Replace("gamemodes/", "");
    else
        src = (SCHEMA and SCHEMA.FolderName or GM.FolderName) .. "/";
    end
    src = src .. dir .. "/";

    local files, dirs = file.Find(src .. "*.lua", "LUA", nameasc);
    for _, file in pairs(files) do
        file = src .. file;
        bash.Util.ProcessFile(file, forceScope);
    end
end

