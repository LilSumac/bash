--[[
    Server-side boot procedure.
]]

-- Things that should be done on start, regardless of refresh or not.
local function miscInit()
    -- Random seed!
    math.randomseed(os.time());

    -- Gamemode info.
    GM.Name = "/bash/";
    GM.Author = "LilSumac";
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

-- Send files to server.
AddCSLuaFile("sh_const.lua");
AddCSLuaFile("sh_util.lua");
AddCSLuaFile("cl_util.lua");

-- Include required util/global table.
include("sh_const.lua");
include("sh_util.lua");
include("sv_util.lua");
include("sv_netpool.lua");

-- Things that should be done on engine start.
function bash.StartEngine()
    -- Include all other engine components.
    bash.Util.ProcessFile("cl_skin.lua");
    bash.Util.ProcessFile("sh_hook.lua");
    bash.Util.ProcessFile("sh_plugin.lua");
    bash.Util.ProcessFile("sh_schema.lua");
    bash.Util.ProcessFile("sv_resources.lua");
    bash.Util.ProcessDir("engine/external");
    bash.Util.ProcessDir("engine/config");
    bash.Util.ProcessDir("engine/hooks");
    bash.Util.ProcessDir("engine/libraries");
    bash.Util.ProcessDir("engine/derma");

    -- Hooks for init process.
    bash.Util.MsgLog(LOG_INIT, "Creating engine preliminary structures...");
    hook.Run("CreateStructures_Engine");
    bash.Util.MsgLog(LOG_INIT, "Starting engine sub-systems...");
    hook.Run("StartSystems_Engine");

    -- Report startup time.
    local len = math.Round(SysTime() - (bash.Started and bash.RefreshTime or bash.StartTime), 8);
    bash.Util.MsgLog(LOG_INIT, "Successfully %s engine server-side. Startup: %fs", (bash.Started and "refreshed" or "started"), len);
    bash.Started = true;

    bash.Util.MsgLog(LOG_INIT, "Calling engine post-init hooks...");
    hook.Run("PostInit_Engine");

    -- Load engine plugins.
    bash.Util.MsgLog(LOG_INIT, "Loading engine plugins...");
    bash.Plugin.Process();
end

-- Start the engine.
bash.StartEngine();
MsgC(color_cyan, "======================== ENGINE COMPLETE ========================\n");



--
-- TESTING
--



if !bash.Tested then

    bash.Testing = bash.TableNet.NewTable({
        Public = {
            ["pub1"] = "heyo!",
            ["pub2"] = "bye!"
        },
        Private = {
            ["priv1"] = "shhh",
            ["priv2"] = "quiet"
        }
    }, NET_GLOBAL);

    hook.Add("PlayerInit", "asdfasdf", function(ply)
        if bash.box then return; end

        bash.box = ents.Create("prop_physics");
        bash.box:SetModel("models/dav0r/buttons/button.mdl");
        local pos = ply:GetPos();
        pos.x = pos.x + 100;
        pos.z = pos.z + 100;
        bash.box:SetPos(pos);
        bash.box:Spawn();
        bash.box:Activate();
    end);


    concommand.Add("setglobal", function(ply, cmd, args)
        local glob = tobool(args[1]);
        bash.Testing:SetGlobal(glob);
        PrintTable(bash.Testing);
    end);

    concommand.Add("addlist", function(ply, cmd, args)
        local scope = args[1];
        bash.Testing:AddListener(ply, scope);
        PrintTable(bash.Testing);
    end);

    concommand.Add("removelist", function(ply, cmd, args)
        local scope = args[1];
        bash.Testing:RemoveListener(ply, scope);
        PrintTable(bash.Testing);
    end);

    concommand.Add("removeall", function(ply, cmd, args)
        bash.Testing:RemoveListeners();
        PrintTable(bash.Testing);
    end);

    local index = 1;
    concommand.Add("updatetab", function(ply, cmd, args)
        local scope = args[1];
        bash.Testing:Set(tostring(index), index, scope);
        index = index + 1;
        PrintTable(bash.Testing);
    end);

    concommand.Add("invalidate", function(ply, cmd, args)
        bash.Testing.Listeners = {Public = {}, Private = {}};
    end);

    concommand.Add("switchchar", function(ply, cmd, args)
        if !ply:GetCharacter() then return; end
        bash.Character.AttachTo(ply:GetCharacter():Get("CharID"), bash.box, true);
    end);

    --[[
    concommand.Add("createchar", function(ply, cmd, args)
        local data = {
            CharID = string.random(3, CHAR_ALPHANUM, "char_"),
            Name = args[1]
        };
        bash.Character.Create(data);
    end);
    ]]

    concommand.Add("fetchchar", function(ply, cmd, args)
        bash.Character.Fetch(args[1]);
    end);

    concommand.Add("loadchar", function(ply, cmd, args)
        bash.Character.Load(args[1], ply, true);
    end);

    concommand.Add("testselect", function(ply, cmd, args)
        bash.Database.SelectRow("bash_chars", "*", F("SteamID = \'%s\'", ply:SteamID()));
    end);

    concommand.Add("testinsert", function(ply, cmd, args)
        bash.Database.InsertRow("bash_chars", {
            CharID = string.random(12, CHAR_ALPHANUM, "char_"),
            SteamID = ply:SteamID(),
            Name = args[1] or "John Doe",
            Description = "A real character.",
            Inventory = "someinvdef"
        });
    end);

    concommand.Add("testupdate", function(ply, cmd, args)
        bash.Database.UpdateRow("bash_chars", {
            Inventory = string.random(32)
        }, F("SteamID = \'%s\'", ply:SteamID()));
    end);

    concommand.Add("testdelete", function(ply, cmd, args)
        bash.Database.DeleteRow("bash_chars", F("CharID = \'%s\'", args[1]));
    end);

    concommand.Add("createinv", function(ply, cmd, args)
        bash.Database.InsertRow("bash_invs", {
            InvID = "inv_asdf",
            Contents = {["item_asdf"] = true, ["item_lala"] = true}
        });
    end);

    concommand.Add("loadinv", function(ply, cmd, args)
        bash.Inventory.Load("inv_asdf");
        --bash.Inventory.FetchItems("inv_asdf");
    end);

    concommand.Add("addtoinv", function(ply, cmd, args)
        bash.TableNet.NewTable({
            Public = {
                ItemNum = 999,
                ItemID = "item_testing",
                InvID = "inv_asdf"
            }
        }, nil, "item_testing");
        bash.Inventory.AddItem("inv_asdf", "item_testing");
    end);

    concommand.Add("removefrominv", function(ply, cmd, args)
        bash.Inventory.RemoveItem("inv_asdf", "item_testing");
    end);


    concommand.Add("printreg", function(ply, cmd, args)
        PrintTable(bash.TableNet.Registry);
    end);

    concommand.Add("changename", function(ply, cmd, args)
        local char = ply:GetCharacter();
        if !char then return; end
        char:Set("Name", args[1] or "John Doe");
    end);

    bash.Tested = true;

    MsgN(pon.encode({X = 1, Y = 1}))

end
