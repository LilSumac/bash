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

    concommand.Add("switchchar", function(ply, cmd, args)
        if !ply:GetCharacter() then return; end
        bash.Character.AttachTo(ply:GetCharacter():Get("CharID"), bash.box, true);
    end);

    concommand.Add("createchar", function(ply, cmd, args)
        local data = {
            Name = args[1]
        };
        bash.Character.Create(data);
    end);

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

    --[[
    concommand.Add("addtoinv", function(ply, cmd, args)
        -- TODO: Fix thtis.
        tabnet.NewTable({
            Public = {
                ItemNum = 999,
                ItemID = "item_testing",
                InvID = "inv_asdf"
            }
        }, nil, "item_testing");
        bash.Inventory.AddItem("inv_asdf", "item_testing");
    end);
    ]]

    concommand.Add("removefrominv", function(ply, cmd, args)
        bash.Inventory.RemoveItem("inv_asdf", "item_testing");
    end);

    concommand.Add("changename", function(ply, cmd, args)
        local char = ply:GetCharacter();
        if !char then return; end
        char:Set("Name", args[1] or "John Doe");
    end);

    bash.Tested = true;

    bash.Inventory.Load("inv_ground");

    concommand.Add("addground", function(ply, cmd, args)
        local ground = tabnet.GetTable("inv_ground");
        if !ground then return; end

        local contents = ground:GetField("Contents", {});
        ground:AddListener(ply, tabnet.SCOPE_PUBLIC);
        local curItem;
        for itemID, _ in pairs(contents) do
            curItem = bash.Item.Load(itemID);
            if !curItem then continue; end
            curItem:AddListener(ply, tabnet.SCOPE_PUBLIC);
        end

        bash.Util.MsgDebug(LOG_DEF, "Added '%s' to ground inventory.", tostring(ply));
    end);

    concommand.Add("domove", function(ply, cmd, args)
        -- Move item_asdf to (4, 4) in inv_ground

        local item = tabnet.GetTable("item_asdf");
        if !item then return; end
        local oldInvID = item:GetField("Owner");
        if !oldInvID or oldInvID == "inv_ground" then return; end
        local oldInv = tabnet.GetTable(oldInvID);
        if !oldInv then return; end
        local newInv = tabnet.GetTable("inv_ground");
        if !newInv then return; end

        local oldContents = oldInv:GetField("Contents", {});
        oldContents["item_asdf"] = nil;
        oldInv:SetField("Contents", oldContents);

        local newContents = newInv:GetField("Contents", {});
        newContents["item_asdf"] = true;
        newInv:SetField("Contents", newContents);

        item:SetFields{
            ["Owner"] = "inv_ground",
            ["PosInInv"] = {X = 4, Y = 4}
        };
    end);

    concommand.Add("dointer", function(ply, cmd, args)
        timer.Simple(3, function()
            local item1 = tabnet.GetTable("item_asdf");
            if !item1 then return; end
            local item2 = tabnet.GetTable("item_lala");

            local newPos1 = {X = 2, Y = 3};
            item1:SetField("PosInInv", newPos1);
            local newPos2 = {X = 3, Y = 3};
            item2:SetField("PosInInv", newPos2);
        end);
    end);

    concommand.Add("printmem", function(ply, cmd, args)
        MsgN(tostring(collectgarbage("count") / 1024))
    end);

    concommand.Add("testhook", function(ply, cmd, args)
        local money = bash.Item.Create({
            ItemType = "money",
            DynamicData = {
                Stack = 4000
            }
        });
        MsgN(money);
    end);

    concommand.Add("testinv", function(ply, cmd, args)
        local trace = ply:GetEyeTrace();
        local pos = trace.HitPos;
        pos.z = pos.z + 20;

        local someBox = ents.Create("prop_physics");
        someBox:SetModel("models/props_junk/wood_crate001a.mdl");
        someBox:SetPos(pos);
        someBox:Spawn();
        someBox:Activate();

        bash.Inventory.AttachTo()
    end);

    hook.Add("OnCharacterCreate", "ASDFASDF", function(char)
        local charID = char:GetField("CharID");
        local invs = char:GetField("Inventory", {}, true);

        local newInv = bash.Inventory.Create({
            InvType = "invtype_basic",
            Owner = charID
        });

        if !newInv then return; end

        invs["Primary"] = newInv:GetField("InvID");
        char:SetField("Inventory", invs);
        tabnet.DeleteTable(newInv:GetField("InvID"));
    end);

    hook.Add("NewCharacterInventory", "ASDFASDFASDFASDF", function(char)
        local invs = char:GetField("Inventory", {});
        local primaryInvID = invs["Primary"];
        local primaryInv = bash.Inventory.Load(primaryInvID);
        if !primaryInv then return; end

        local openSpot = bash.Inventory.GetOpenSpot(primaryInv, "money", true);
        if !openSpot then return; end

        local money = bash.Item.Create({
            ItemType = "money",
            DynamicData = {
                Stack = 4000
            }
        });

        bash.Inventory.AddItem(primaryInv, money, openSpot);
        tabnet.DeleteTable(money:GetField("ItemID"));
        tabnet.DeleteTable(primaryInv:GetField("InvID"));
    end);

end