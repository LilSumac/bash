--[[
    Client-side boot procedure.
]]

-- Things that should be done on start, regardless of refresh or not.
local function miscInit()
    -- Random seed!
    math.randomseed(os.time());

    -- Get rid of useless sandbox notifications.
    timer.Remove("HintSystem_OpeningMenu");
    timer.Remove("HintSystem_Annoy1");
    timer.Remove("HintSystem_Annoy2");

    -- Create default fonts.
    -- TODO: Replace with a function. Utility?
    surface.CreateFont("bash-regular", {
		font = "Aileron Thin",
		size = 24,
        shadow = true,
        antialias = true
        --weight = 300
	});
end

-- If there's a refresh, let 'em know.
if bash and bash.Started then
    bash.Util.MsgLog(LOG_WARN, "Gamemode is reloading!");
    hook.Call("OnReload");
end

-- Report engine startup.
MsgC(Color(0, 255, 255), "======================== ENGINE STARTED ========================\n");
miscInit();

-- Global table for bash elements.
bash = bash or {StartTime = SysTime()};
local bash = bash;
bash.RefreshTime = SysTime();
-- bash.Dev.DevMode = true;

-- Include required util/global table.
include("sh_const.lua");
include("sh_util.lua");
include("cl_util.lua");

-- Things that should be done on engine start.
function bash.EngineStart()
    -- Include all other engine components.
    bash.Util.ProcessFile("sh_hook.lua");
    bash.Util.ProcessFile("sh_plugin.lua");
    bash.Util.ProcessFile("sh_schema.lua");
    bash.Util.ProcessDir("engine/external");
    bash.Util.ProcessDir("engine/config");
    bash.Util.ProcessDir("engine/hooks");
    bash.Util.ProcessDir("engine/libraries");

    -- Materials should persist.
    bash.Materials = bash.Materials or {};

    -- Add default client data.
    bash.Util.AddClientData("Country", system.GetCountry);
    bash.Util.AddClientData("OS", function()
        if system.IsWindows() then
            return OS_WIN;
        elseif system.IsWindows() then
            return OS_OSX;
        elseif system.IsLinux() then
            return OS_LIN;
        else
            return OS_UNK;
        end
    end);

    -- Hooks for init process.
    bash.Util.MsgLog(LOG_INIT, "Creating engine preliminary structures...");
    hook.Call("CreateStructures_Engine");
    bash.Util.MsgLog(LOG_INIT, "Starting engine sub-systems...");
    hook.Call("StartSystems_Engine");

    -- Report startup time.
    local len = math.Round(SysTime() - (bash.Started and bash.RefreshTime or bash.StartTime), 8);
    bash.Util.MsgLog(LOG_INIT, "Successfully %s engine server-side. Startup: %fs", (bash.Started and "refreshed" or "started"), len);
    bash.Started = true;

    bash.Util.MsgLog(LOG_INIT, "Calling engine post-init hooks...");
    hook.Call("PostInit_Engine");

    -- Load engine plugins.
    bash.Util.MsgLog(LOG_INIT, "Loading engine plugins...");
    bash.Plugin.Process();
end

-- Start the engine.
bash.EngineStart();
MsgC(color_cyan, "======================== ENGINE COMPLETE ========================\n");






--
-- TESTING
--



--[[
local str = "The quick brown fox jumps over the lazy dog.";
local font = "bash-regular";
hook.Remove("HUDPaint", "asdf");
hook.Add("HUDPaint", "asdf", function()
    surface.SetFont(font);
    local x, y = surface.GetTextSize(str);
    draw.RoundedBox(0, CENTER_X, CENTER_Y, x + 8, y + 8, color_grey);
    draw.SimpleText(
        str, font,
        CENTER_X + 4, CENTER_Y + 4, color_white,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_white
    );
end);
]]

concommand.Add("printreg", function(ply, cmd, args)
    PrintTable(bash.TableNet.Registry);
end);

concommand.Add("printchar", function(ply, cmd, args)
    MsgN(ply);
    local char = ply:GetCharacter();
    if !char then
        MsgN("No character.");
    else
        PrintTable(char);
    end
end);

hook.Add("HUDPaint", "somebullshit", function()
    local traceInfo = {
        start = LocalPlayer():EyePos(),
        endpos = LocalPlayer():EyePos() + LocalPlayer():GetAimVector() * 2000,
        filter = LocalPlayer()
    };
    local trace = util.TraceLine(traceInfo);
    local traceEnt = trace.Entity;
    local traceIndex = traceEnt:EntIndex();

    if traceEnt:GetCharacter() then
        local char = traceEnt:GetCharacter();
        draw.SimpleText(char:Get("Name"), "ChatFont", CENTER_X, CENTER_Y, color_red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
    end
end);
