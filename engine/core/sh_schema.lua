--[[
    Schema system functions.
]]

--
-- Local storage.
--

local bash = bash;

--
-- Global storage.
--

bash.Schema         = bash.Schema or {};
bash.Schema.Started = bash.Schema.Started or false;

--
-- Schema functions.
--

-- Things that should be done on schema start.
function bash.StartSchema()
    if GM.FolderName == BASE_FOLDER then
        bash.Util.MsgErr("SchemaOnBase");
        return;
    end

    SCHEMA = SCHEMA or {
        UniqueID = GM.FolderName,
        Name = "Schema Skeleton",
        Author = "LilSumac",
        FolderName = GM.FolderName,
        IntroTitle = "Schema Skeleton",
        IntroDesc = "A barebones schema framework.",
        StartTime = SysTime()
    };
    SCHEMA.RefreshTime = SysTime();

    -- Hooks for init process.
    bash.Util.MsgLog(LOG_INIT, "Creating schema preliminary structures...");
    hook.Run("CreateStructures");
    bash.Util.MsgLog(LOG_INIT, "Starting schema sub-systems...");
    hook.Run("StartSystems");

    -- Report startup time.
    local len = math.Round(SysTime() - (bash.Schema.Started and SCHEMA.RefreshTime or SCHEMA.StartTime), 8);
    bash.Util.MsgLog(LOG_INIT, "Successfully started schema server-side. Startup: %fs", len);
    bash.Schema.Started = true;

    bash.Util.MsgLog(LOG_INIT, "Calling schema post-init hooks...");
    hook.Run("PostInit");

    -- Load schema plugins.
    bash.Util.MsgLog(LOG_INIT, "Loading schema plugins...");
    bash.Plugin.Process();

    MsgC(color_purple, "======================== SCHEMA COMPLETE ========================\n");
end

-- Checks to see if a schema has been loaded.
function bash.Schema.IsLoaded()
    return bash.Schema.Started;
end
