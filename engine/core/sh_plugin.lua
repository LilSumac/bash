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

bash.Plugins            = bash.Plugins or {};
bash.Plugins.Registered = bash.Plugins.Registered or {};

--
-- Plugin functions.
--

-- Process all plugins located in the working directory.
function bash.Plugins.ProcessAll()
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
            bash.Util.MsgErr("NoPluginFile", plugin);
        end
    end

    bash.Plugins.CheckDependencies();
end

-- Make sure all plugins have their dependencies met.
local function bash.Plugins.CheckDependencies()
    local allMet, count, total = true, 0, 0;
    for id, plug in pairs(bash.Plugins.Registered) do
        for _, dep in pairs(plug.Depends) do
            if !bash.Plugins.Registered[dep] then
                bash.Util.MsgLog(LOG_WARN, "Plugin %s is missing dependency %s! This may cause errors! Resolve this immediately!", plug.Name, dep);
                allMet = false;
                count = count + 1;
            end

            total = total + 1;
        end
    end

    if !allMet then
        bash.Util.MsgLog(LOG_WARN, "There was %d/%d plugin(s) with unmet dependencies. Please see earlier errors for more info.", count, total);
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
