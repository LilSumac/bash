--[[
    Plugin system functions.
]]

--
-- Local storage.
--

local bash = bash;

--
-- Global storage.
--

bash.Plugins                = bash.Plugins or {};
bash.Plugins.Registered     = bash.Plugins.Registered or {};
bash.Plugins.HookCache      = bash.Plugins.HookCache or {};
bash.Plugins.EngineLoaded   = false;

--
-- Plugin functions.
--

-- Local function to register current plugin's hooks with new hook.Call.
local function registerHooks()
    for name, func in pairs(PLUGIN) do
        if type(func) == "function" then
            bash.Plugins.HookCache[name] = bash.Plugins.HookCache[name] or {};
            bash.Plugins.HookCache[name][PLUGIN] = func;
        end
    end
end

-- Process all plugins located in the working directory.
function bash.Plugins.Process()
    local src = SCHEMA and SCHEMA.FolderName or BASE_FOLDER;
    if src == BASE_FOLDER and bash.Plugins.EngineLoaded then return; end
    src = src .. "/plugins/";

    --[[
    local from = debug.getinfo(2);
    local src = from.short_src;
    src = src:GetPathFromFilename();
    src = src:Replace("gamemodes/", "");
    src = src .. "plugins/";
    ]]

    local singles, plugins = file.Find(src .. "*", "LUA", nameasc);
    local uniqueID, plugSrc;
    -- Process plugins located in a single file.
    for _, _file in pairs(singles) do
        uniqueID = _file:GetFileFromFilename():StripExtension();
        plugSrc = src .. _file;

        PLUGIN = bash.Plugins.Get(uniqueID) or {
            UniqueID = uniqueID,
            Name = uniqueID,
            SrcPath = plugSrc,
            Depends = {},
            InSchema = SCHEMA != nil,
            IsDisabled = false,
            IsLoaded = true
        };

        bash.Util.ProcessFile(plugSrc, "SHARED");

        registerHooks();
        hook.Run("ProcessPlugin", uniqueID);

        bash.Plugins.Registered[uniqueID] = PLUGIN;
        PLUGIN = nil;
    end

    -- Process plugins located in a directory.
    local plugFiles;
    for _, plugin in pairs(plugins) do
        uniqueID = plugin;
        plugSrc = src .. plugin .. "/";
        plugFiles = file.Find(plugSrc .. "*.lua", "LUA", nameasc);

        if !table.HasValue(plugFiles, "sh_plugin.lua") then
            bash.Util.MsgErr("NoPluginFile", plugin);
            continue;
        end

        PLUGIN = bash.Plugins.Get(uniqueID) or {
            UniqueID = uniqueID,
            Name = uniqueID,
            SrcPath = plugSrc,
            Depends = {},
            InSchema = SCHEMA != nil,
            IsDisabled = false,
            IsLoaded = true
        };

        bash.Util.ProcessFile(plugSrc .. "sh_plugin.lua");
        bash.Plugins.ProcessEntities(plugSrc);
        bash.Plugins.ProcessWeapons(plugSrc);
        bash.Plugins.ProcessEffects(plugSrc);

        registerHooks();
        hook.Run("ProcessPlugin", uniqueID);

        bash.Plugins.Registered[uniqueID] = PLUGIN;
        PLUGIN = nil;
    end

    bash.Plugins.CheckDependencies();

    if src == "/bash/plugins/" then
        bash.Plugins.EngineLoaded = true;
    end
end

-- Process entity files in plugin.
function bash.Plugins.ProcessEntities(dir)
    local folderSrc = dir .. "entities/entities/";
    local files, folders = file.Find(folderSrc .. "*", "LUA");
    for _, _file in pairs(files) do
        -- Setup a barebones entity structure.
        ENT = {
            Type = "anim",
            Base = "base_gmodentity",
            ClassName = _file:StripExtension()
        };

        bash.Util.ProcessFile(folderSrc .. _file);
        scripted_ents.Register(ENT, ENT.ClassName);

        ENT = nil;
    end

    for _, _folder in pairs(folders) do
        -- Setup a barebones entity structure.
        ENT = {
            Type = "anim",
            Base = "base_gmodentity",
            ClassName = _folder
        };

        if file.Exists(folderSrc .. _folder .. "/cl_init.lua", "LUA") then
            bash.Util.ProcessFile(folderSrc .. _folder .. "/cl_init.lua");
        end

        if file.Exists(folderSrc .. _folder .. "/init.lua", "LUA") then
            bash.Util.ProcessFile(folderSrc .. _folder .. "/init.lua");
        end

        if file.Exists(folderSrc .. _folder .. "/shared.lua", "LUA") then
            bash.Util.ProcessFile(folderSrc .. _folder .. "/shared.lua");
        end

        scripted_ents.Register(ENT, ENT.ClassName);

        ENT = nil;
    end
end

-- Process weapon files in plugin.
function bash.Plugins.ProcessWeapons(dir)
    local folderSrc = dir .. "entities/weapons/";
    local files, folders = file.Find(folderSrc .. "*", "LUA");
    for _, _file in pairs(files) do
        -- Setup a barebones weapon structure.
        SWEP = {
            Base = "weapon_base",
            Primary = {},
            Secondary = {},
            ClassName = _file:StripExtension()
        };

        bash.Util.ProcessFile(folderSrc .. _file);
        weapons.Register(SWEP, SWEP.ClassName);

        SWEP = nil;
    end

    for _, _folder in pairs(folders) do
        -- Setup a barebones weapon structure.
        SWEP = {
            Base = "weapon_base",
            Primary = {},
            Secondary = {},
            ClassName = _folder
        };

        if file.Exists(folderSrc .. _folder .. "/cl_init.lua", "LUA") then
            bash.Util.ProcessFile(folderSrc .. _folder .. "/cl_init.lua");
        end

        if file.Exists(folderSrc .. _folder .. "/init.lua", "LUA") then
            bash.Util.ProcessFile(folderSrc .. _folder .. "/init.lua");
        end

        if file.Exists(folderSrc .. _folder .. "/shared.lua", "LUA") then
            bash.Util.ProcessFile(folderSrc .. _folder .. "/shared.lua");
        end

        weapons.Register(SWEP, SWEP.ClassName);

        SWEP = nil;
    end
end

-- Process effects files in plugin.
function bash.Plugins.ProcessEffects(dir)
    local folderSrc = dir .. "entities/effects/";
    local files, folders = file.Find(folderSrc .. "*", "LUA");
    for _, _file in pairs(files) do
        -- Setup a barebones effect structure.
        EFFECT = {ClassName = _file:StripExtension()};

        bash.Util.ProcessFile(folderSrc .. _file);
        if CLIENT then effects.Register(EFFECT, EFFECT.ClassName); end

        EFFECT = nil;
    end

    for _, _folder in pairs(folders) do
        -- Setup a barebones effect structure.
        EFFECT = {ClassName = _folder};

        if file.Exists(folderSrc .. _folder .. "/cl_init.lua", "LUA") then
            bash.Util.ProcessFile(folderSrc .. _folder .. "/cl_init.lua");
        end

        if file.Exists(folderSrc .. _folder .. "/init.lua", "LUA") then
            bash.Util.ProcessFile(folderSrc .. _folder .. "/init.lua");
        end

        if CLIENT then effects.Register(EFFECT, EFFECT.ClassName); end

        EFFECT = nil;
    end
end

-- TODO: Tools?

-- Make sure all plugins have their dependencies met.
function bash.Plugins.CheckDependencies()
    local allMet, count, total = true, 0, 0;
    for id, plug in pairs(bash.Plugins.Registered) do
        for _, dep in pairs(plug.Depends) do
            if !bash.Plugins.Registered[dep] then
                bash.Util.MsgLog(LOG_WARN, "Plugin '%s' is missing dependency '%s'! This may cause errors, so resolve this immediately!", plug.Name, dep);
                allMet = false;
                count = count + 1;
            end
        end

        total = total + 1;
    end

    if !allMet then
        local msg = Format("There %s %d unmet %s! Please see earlier errors for more info.", count == 1 and "was" or "were", count, count == 1 and "dependency" or "dependencies");
        bash.Util.MsgLog(LOG_WARN, msg);
    else
        bash.Util.MsgLog(LOG_INIT, "All %s plugins have met their dependencies.", total);
    end
end

-- Check to see if a plugin struct has been registered.
function bash.Plugins.IsRegistered(id)
    return bash.Plugins.Registered[id] != nil;
end

-- Fetch a registered plugin struct.
function bash.Plugins.Get(id)
    return bash.Plugins.Registered[id];
end
