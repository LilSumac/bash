--[[
    Client-side boot procedure.
]]

-- Things that should be done on start, regardless of refresh or not.
local function miscInit()
    -- Random seed!
    math.randomseed(os.time());

    -- Gamemode info.
    GM.Name = "/bash/";
    GM.Author = "LilSumac";

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
    bash.Util.ProcessFile("cl_skin.lua");
    bash.Util.ProcessFile("sh_hook.lua");
    bash.Util.ProcessFile("sh_plugin.lua");
    bash.Util.ProcessFile("sh_schema.lua");
    bash.Util.ProcessDir("engine/external");
    bash.Util.ProcessDir("engine/config");
    bash.Util.ProcessDir("engine/hooks");
    bash.Util.ProcessDir("engine/libraries");
    bash.Util.ProcessDir("engine/derma");

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

concommand.Add("printchar", function(ply, cmd, args)
    MsgN(ply);
    local char = ply:GetCharacter();
    if !char then
        MsgN("No character.");
    else
        PrintTable(char);
    end
end);

concommand.Add("openmenu", function(ply, cmd, args)
    if bash.CharMenu then return; end
    bash.CharMenu = vgui.Create("bash_CharacterMenu");
end);

concommand.Add("openinv", function(ply, cmd, args)
    if bash.CharInv then return; end
    local char = ply:GetCharacter();
    if !char then return; end

    local invs = char:Get("Inventory", {});
    bash.CharInv = vgui.Create("bash_Inventory");
    bash.CharInv:SetInventory(invs["Primary"]);
end);

concommand.Add("opentest", function(ply, cmd, args)
    if bash.inv_asdf or bash.inv_lala then return; end
    local char = ply:GetCharacter();
    if !char then return; end

    local invs = char:Get("Inventory", {});
    bash.inv_asdf = vgui.Create("bash_TestFrame");
    bash.inv_asdf:SetInventory(invs["Primary"]);
    bash.inv_lala = vgui.Create("bash_TestFrame");
    bash.inv_lala:SetInventory(invs["Secondary"]);
end);

concommand.Add("openground", function(ply, cmd, args)
    if bash.inv_ground then return; end

    bash.inv_ground = vgui.Create("bash_TestFrame");
    bash.inv_ground:SetInventory("inv_ground");
end);

concommand.Add("text", function(ply, cmd, args)
    local frame = vgui.Create("DFrame");
    frame:SetSize(500, 500);
    frame:MakePopup(true);
    frame:Center();
    frame:ShowCloseButton(false);

    local close = vgui.Create("bash_Close", frame);
    close:SetSize(16, 16);
    close:SetPos(frame:GetWide() - 20, 4);

    local dis = vgui.Create("DTextEntry", frame);
    dis:Dock(TOP);
    dis:DockMargin(10, 10, 10, 10);
    dis:SetDisabled(true);

    local act = vgui.Create("DTextEntry", frame);
    act:Dock(TOP);
    act:DockMargin(10, 10, 10, 10);
end);

concommand.Add("grid", function(ply, cmd, args)
    local char = ply:GetCharacter();
    if !char then return; end

    local frame = vgui.Create("DFrame");
    frame:SetSize(300, 300);
    frame:Center();
    frame:ShowCloseButton(false);
    frame:MakePopup(true);
    frame:SetSizable(true);

    local close = vgui.Create("bash_Close", frame);
    close:SetSize(16, 16);
    close:SetPos(frame:GetWide() - 20, 4);

    local invs = char:GetField("Inventory", {});
    local grid = vgui.Create("bash_TestInvGrid", frame);
    grid:AlignTop(24);
    PrintTable(char);
    grid:SetInv(invs["Primary"]);
    frame:SetTitle(invs["Primary"]);
end);

concommand.Add("gridground", function(ply, cmd, args)
    local char = ply:GetCharacter();
    if !char then return; end

    local frame = vgui.Create("DFrame");
    frame:SetSize(300, 300);
    frame:Center();
    frame:ShowCloseButton(false);
    frame:MakePopup(true);
    frame:SetSizable(true);

    local close = vgui.Create("bash_Close", frame);
    close:SetSize(16, 16);
    close:SetPos(frame:GetWide() - 20, 4);

    local invs = char:GetField("Inventory", {});
    local grid = vgui.Create("bash_TestInvGrid", frame);
    grid:AlignTop(24);
    grid:SetInv("inv_ground");
    frame:SetTitle("Ground");
end);

concommand.Add("invcont", function(ply, cmd, args)
    local char = ply:GetCharacter();
    if !char then return; end

    local frame = vgui.Create("DFrame");
    frame:SetSize(300, 300);
    frame:Center();
    frame:ShowCloseButton(false);
    frame:MakePopup(true);
    frame:SetSizable(true);

    local close = vgui.Create("bash_Close", frame);
    close:SetSize(16, 16);
    close:SetPos(frame:GetWide() - 20, 4);

    local invs = char:GetField("Inventory", {});
    local cont = vgui.Create("bash_InvContainer", frame);
    cont:SetWide(300);
    cont:AlignTop(24);
    cont:SetInventory(invs["Primary"]);
    frame:SetTitle(invs["Primary"]);
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

        draw.SimpleText(char:GetField("Name"), "ChatFont", CENTER_X, CENTER_Y, color_red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
    elseif traceEnt:GetItem() then
        local item = traceEnt:GetItem();
        local itemTypeID = item:GetField("ItemType");
        local itemType = bash.Item.Types[itemTypeID];
        if !itemType then return; end 

        draw.SimpleText(itemType.Static.Name, "ChatFont", CENTER_X, CENTER_Y, color_red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
    end
end);

local outerPoly, innerPoly;
local tweenData = {};
local healthTween;
hook.Remove("HUDPaint", "stencils");
hook.Add("HUDPaint", "stencils", function()
    local hp = LocalPlayer():Health();
    tweenData.Current = tweenData.Current or 0;
    tweenData.Target = tweenData.Target or 0;
    local ratio = tweenData.Current / LocalPlayer():GetMaxHealth();

    if hp != tweenData.Target then
        tweenData.Target = hp;
        healthTween = tween.new(1, tweenData, {Current = tweenData.Target}, 'outExpo');
    end
    if healthTween and !healthTween:update(FrameTime()) then
        outerPoly = bash.Util.GenerateRadial(CENTER_X, CENTER_Y, 50, ratio * 362);
    end

    if !innerPoly then
        innerPoly = bash.Util.GenerateCircle(CENTER_X, CENTER_Y, 48, 360);
    end

    render.ClearStencil();
    render.SetStencilEnable(true);

    render.SetStencilWriteMask(69); -- HAHAHAHAHAHAHAHAHAHAHA
    render.SetStencilTestMask(69);  -- HAAHAHAHAHAHAHAHAHAHAHAHAHAHAHAH
    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NEVER);
    render.SetStencilPassOperation(STENCILOPERATION_ZERO);
    render.SetStencilFailOperation(STENCILOPERATION_REPLACE);
    render.SetStencilZFailOperation(STENCILOPERATION_ZERO);
    render.SetStencilReferenceValue(1);

    -- Draw outer circle.
    --draw.NoTexture();
	surface.SetDrawColor(color_white);
	surface.DrawPoly(outerPoly);

    render.SetStencilFailOperation(STENCILOPERATION_ZERO);

    -- Draw inner circle.
    --draw.NoTexture();
	surface.SetDrawColor(color_white);
	surface.DrawPoly(innerPoly);

    render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL);
    render.SetStencilPassOperation(STENCILOPERATION_KEEP);

    -- Fill in with color.
    surface.SetDrawColor(Color(139, 183, 98));
    surface.DrawRect(CENTER_X - 50, CENTER_Y - 50, CENTER_X + 50, CENTER_Y + 50);

    render.SetStencilEnable(false);
end);
