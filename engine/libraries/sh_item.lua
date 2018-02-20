--[[
    Item management functionality.
]]

--
-- Local storage.
--

local bash = bash;

local LOG_ITEM = {pre = "[ITEM]", col = color_limegreen};

local Entity = FindMetaTable("Entity");

--
-- Global storage.
--

bash.Item           = bash.Item or {};
bash.Item.Vars      = bash.Item.Vars or {};
bash.Item.IDs       = bash.Item.IDs or {};
bash.Item.Types     = bash.Item.Types or {};
bash.Item.Cache     = bash.Item.Cache or {};
bash.Item.Waiting   = bash.Item.Waiting or {};

--
-- Entity functions.
--

-- Get an entity's assigned item, if any.
function Entity:GetItem()
    local reg = bash.Item.GetRegistry();
    if !reg then return; end

    local index = self:EntIndex();
    local itemID = reg:GetField(index);

    return tabnet.GetTable(itemID);
end

-- Check if an entity has an item attached.
function Entity:IsItem()
    return self:GetItem() != nil;
end

-- Check if an entity has a certain item attached.
function Entity:IsSpecificItem(id)
    return self:IsItem() and self:GetItem():GetField("ItemID") == id;
end

--
-- Item functions.
--

-- Add a new character variable struct.
function bash.Item.AddVar(data)
    bash.Item.Vars[data.ID] = {
        ID = data.ID,
        Type = data.Type,
        Default = data.Default,
        Scope = data.Scope,
        InSQL = data.InSQL
    };

    if SERVER and data.InSQL then
        bash.Database.AddColumn("bash_items", {
            Name = data.ID,
            Type = data.Type,
            MaxLength = data.MaxLength
        }, data.PrimaryKey);
    end
end

-- Add a new item type struct.
function bash.Item.RegisterType(item)
    bash.Util.MsgDebug(LOG_ITEM, "Registering item type with ID '%s'...", item.Static.ID);

    local itemData = {};

    -- Static fields.
    itemData.Static             = item.Static or {};
    itemData.Static.ID          = item.Static.ID or "bash_itemid";
    itemData.Static.Name        = item.Static.Name or "Item";
    itemData.Static.WorldModel  = item.Static.WorldModel or "models/props_lab/box01a.mdl"
    itemData.Static.SizeX       = item.Static.SizeX or 1;
    itemData.Static.SizeY       = item.Static.SizeY or 1;
    itemData.Static.CanStack    = item.Static.CanStack or false;
    itemData.Static.MaxStack    = item.Static.MaxStack or 1;

    -- Dynamic fields.
    itemData.Dynamic = item.Dynamic or {};
    itemData.Dynamic.Stack = item.Dynamic.Stack or 1;

    -- Function fields.
    itemData.Functions = itemData.Functions or {};
    itemData.Functions.Drop = {

        ShowInInv = true,
        ShowInWorld = false,

        CanShow = function(item)
            -- TODO: Add if player is viewing another inventory, return false.
            -- Can basically replace all of this func.
            if !item then return false; end

            local char = LocalPlayer():GetCharacter();
            if !char then return false; end

            local itemID = item:GetField("ItemID");
            local inv, invCont;
            for slot, invID in pairs(char:GetField("Inventory", {})) do
                inv = tabnet.GetTable(invID);
                if !inv then continue; end

                invCont = inv:GetField("Contents", {});
                if invCont[itemID] then return true; end
            end

            return false;
        end,

        MenuName = "Drop",

        RunOnClient = false,
        RunOnServer = true,

        GetSendData = function(item)
            local traceTab = {};
            traceTab.start = LocalPlayer():EyePos();
            traceTab.endpos = traceTab.start + LocalPlayer():GetAimVector() * 90;
            traceTab.filter = LocalPlayer();
            local trace = util.TraceLine(traceTab);
            local itemPos = trace.HitPos;
            itemPos.z = itemPos.z + 2;

            return {
                ItemPos = itemPos
            };
        end,

        Run = function(ply, item, sendData)
            if !item then MsgN("NO ITEM") return; end

            local invID = item:GetField("Owner");
            local owner = bash.Inventory.GetPlayerOwner(invID);
            if owner != ply then MsgN("NOT SAME OWNER") return; end

            bash.Item.Drop(item, sendData.ItemPos);
        end

    };
    itemData.Functions.PickUp = {

        ShowInInv = false,
        ShowInWorld = true,

        CanShow = function(item, ent)
            -- TODO: Add if player is viewing another inventory, return false.
            -- Can basically replace all of this func.
            if !item then return false; end
            if !isent(ent) then return false; end

            local char = LocalPlayer():GetCharacter();
            if !char then return false; end

            return true;
        end,

        MenuName = "Pick Up",

        RunOnClient = false,
        RunOnServer = true,

        Run = function(ply, item, sendData)
            if !item then MsgN("NO ITEM") return; end

            local invID = item:GetField("Owner");
            if invID != "!WORLD!" then MsgN("NOT IN WORLD") return; end

            local char = ply:GetCharacter();
            if !char then MsgN("NO CHAR") return; end

            bash.Item.PickUp(item, char);
        end

    };

    bash.Item.Types[itemData.Static.ID] = itemData;
end

-- Get an item type.
function bash.Item.GetType(itemID)
    return bash.Item.Types[itemID];
end

-- Get the item registry.
function bash.Item.GetRegistry()
    return tabnet.GetTable("bash_ItemRegistry");
end

-- Get an entity who is emulating a certain item.
function bash.Item.GetEntityOwner(id)
    local reg = bash.Item.GetRegistry();
    if !reg then return; end

    local curUser = reg:GetField(id);
    local ent = (curUser and ents.GetByIndex(curUser)) or nil;
    return ent;
end

-- Check to see if an item is currently attached to an entity.
function bash.Item.IsInUse(id)
    return bash.Item.GetRegistry():Get(id);
end

if SERVER then

    -- Get an ununused ItemID.
    function bash.Item.GetUnusedID()
        local id;
        repeat
            id = string.random(12, CHAR_ALPHANUM, "item_");
        until !bash.Item.IDs[id];
        return id;
    end

    -- Create a new item from scratch.
    function bash.Item.Create(data, forceID, temp)
        local itemDefaults = tabnet.GetSchemaDefaults("bash_Item");
        for fieldName, def in pairs(itemDefaults) do
            if data[fieldName] == nil then
                data[fieldName] = def;
            end 
        end 

        local itemID = forceID or bash.Item.GetUnusedID();
        bash.Item.IDs[itemID] = true;
        data.ItemID = itemID;
        data.IsTemp = temp;

        local itemType = bash.Item.Types[data.ItemType];
        if !itemType then
            bash.Util.MsgErr("ItemCreateFailed", itemID);
            bash.Item.IDs[itemID] = nil;
            return false;
        end
        
        data.DynamicData = data.DynamicData or {};

        for name, val in pairs(itemType.Dynamic) do
            if data.DynamicData[name] == nil then
                data.DynamicData[name] = val;
            end
        end

        bash.Util.MsgLog(LOG_ITEM, "Creating a new item with the ID '%s'...", itemID);

        local newItem;
        if temp then
            newItem = tabnet.CreateTable(data, nil, "bash_Item", itemID);
        else
            newItem = tabnet.GetDBProvider():CreateTable("bash_Item", data, true);
        end

        if !newItem then
            bash.Util.MsgErr("ItemCreateFailed", itemID);
            bash.Item.IDs[itemID] = nil;
            return;
        end

        hook.Run("OnItemCreate", newItem, temp);
        return newItem;
    end

    -- Create a new instance of an item.
    function bash.Item.Load(id)
        bash.Util.MsgLog(LOG_ITEM, "Loading item '%s'...", id);

        local item = tabnet.GetTable(id);
        if !item then
            item = tabnet.GetDBProvider():LoadTable("bash_Item", id);
        end 

        if !item then
            bash.Util.MsgErr("ItemNotFound", id);
            return;
        end

        return item;
    end

    -- Drop an item at a position.
    function bash.Item.Drop(item, pos)
        if !item or !pos then MsgN("NO DROP ARGS") return; end

        local itemID = item:GetField("ItemID");
        local itemTypeID = item:GetField("ItemType");
        local itemType = bash.Item.Types[itemTypeID];
        if !itemType then MsgN("NO DROP TYPE") return; end

        local invID = item:GetField("Owner");
        local inv = tabnet.GetTable(invID);
        if !inv then return; end

        bash.Inventory.RemoveItem(inv, item);

        item:SetFields{
            ["Owner"] = "!WORLD!",
            ["Position"] = {
                X = pos.x,
                Y = pos.y,
                Z = pos.z
            }
        };
        item:SetGlobal(true);

        local newItemEnt = ents.Create("prop_physics");
        newItemEnt:SetModel(itemType.Static.WorldModel);
        newItemEnt:SetPos(pos);
        newItemEnt:Spawn();
        newItemEnt:Activate();

        bash.Item.AttachTo(itemID, newItemEnt);
    end

    -- Pickup an item and give it to a character.
    function bash.Item.PickUp(item, char)
        if !item or !char then MsgN("NO PICKUP ARGS") return; end

        local itemID = item:GetField("ItemID");
        local itemTypeID = item:GetField("ItemType");
        local itemType = bash.Item.Types[itemTypeID];
        if !itemType then MsgN("NO PICKUP TYPE") return; end

        local charID = char:GetField("CharID");
        local invs = char:GetField("Inventory", {});
        local addedToInv = false;
        local inv;
        for slot, invID in pairs(invs) do
            inv = tabnet.GetTable(invID);
            if !inv then continue; end

            if bash.Inventory.AddItem(inv, item) then
                addedToInv = true;
                break;
            end
        end

        if !addedToInv then
            -- TODO: Send error to player.
            MsgN("No room for item IDIOT!");
            return;
        end 

        item:SetGlobal(false);

        local oldEnt = bash.Item.GetEntityOwner(itemID);
        bash.Item.DetachFrom(oldEnt);
        oldEnt:Remove();
    end

    -- Associate an item with an entity.
    function bash.Item.AttachTo(id, ent, deleteOld)
        if !isent(ent) then return; end
        bash.Item.DetachFrom(ent, deleteOld);

        local reg = bash.Item.GetRegistry();
        local index = ent:EntIndex();
        local oldIndex = reg:GetField(id);
        local oldOwner = (oldIndex and ents.GetByIndex(oldIndex)) or nil;
        bash.Item.DetachFrom(oldOwner, false);

        bash.Util.MsgLog(LOG_ITEM, "Attaching item '%s' to entity '%s'...", id, tostring(ent));

        -- Add both for two-way lookup.
        reg:SetFields{
            [index] = id,
            [id] = index
        };

        local item = tabnet.GetTable(id);
        hook.Run("OnItemAttach", item, ent);
    end

    -- Disassociate an item from an entity.
    function bash.Item.DetachFrom(ent, delete)
        if !isent(ent) then return; end
        if !ent:GetItem() then return; end

        local reg = bash.Item.GetRegistry();
        local item = ent:GetItem();
        local itemID = item:GetField("ItemID");
        local index = ent:EntIndex();
        bash.Util.MsgLog(LOG_ITEM, "Detaching item '%s' from entity '%s'...", itemID, tostring(ent));

        reg:ClearField(index, itemID);
        hook.Run("OnItemDetach", item, ent);

        if delete then
            tabnet.DeleteTable(itemID);
        end
    end

    --
    -- Engine hooks.
    --

    -- Fetch all used IDs.
    hook.Add("InitPostEntity", "bash_ItemFetchIDs", function()
        bash.Util.MsgDebug(LOG_ITEM, "Fetching used ItemIDs...");

        tabnet.GetDBProvider():GetTableData(
            "bash_Item",
            {"ItemID"},
            nil,

            function(data)
                for _, item in pairs(data) do
                    bash.Item.IDs[item.ItemID] = true;
                end

                bash.Util.MsgDebug(LOG_ITEM, "Cached %d ItemIDs.", #data);
            end
        );
    end);

    --
    -- Network hooks.
    --

    -- Watch for item move requests.
    vnet.Watch("bash_Net_ItemMoveRequest", function(pck)
        -- TODO: Clean this up.
        local data = pck:Table();

        local droppedItem = tabnet.GetTable(data.DroppedItemID);
        if !droppedItem then return; end
        local currentItem = tabnet.GetTable(data.CurrentItemID);

        if currentItem then
            -- TODO: Try to combine, else swap.
            MsgN("Combine/swap two items.")

            if data.DroppedInvID != data.CurrentInvID then
                -- Change owners and swap.
                local oldInv = tabnet.GetTable(data.DroppedInvID);
                if !oldInv then return; end
                local newInv = tabnet.GetTable(data.CurrentInvID);
                if !newInv then return; end

                local oldContents = oldInv:GetField("Contents", {}, true);
                oldContents[data.DroppedItemID] = nil;
                oldContents[data.CurrentItemID] = true;
                oldInv:SetField("Contents", oldContents);

                local newContents = newInv:GetField("Contents", {}, true);
                newContents[data.DroppedItemID] = true;
                newContents[data.CurrentItemID] = nil;
                newInv:SetField("Contents", newContents);

                droppedItem:SetFields{
                    ["Owner"] = data.CurrentInvID,
                    ["Position"] = data.CurrentItemPos
                };
                currentItem:SetFields{
                    ["Owner"] = data.DroppedInvID,
                    ["Position"] = data.DroppedItemPos
                };
            else
                droppedItem:SetField("Position", data.CurrentItemPos);
                currentItem:SetField("Position", data.DroppedItemPos);
            end
        else
            if data.DroppedInvID == data.CurrentInvID then
                -- TODO: Just move the item.
                MsgN("Move one item to empty spot.");
                droppedItem:SetField("Position", data.CurrentItemPos);
            else
                -- TODO: See if the item can hold the item.
                --       If so, move.
                MsgN("Move one item to another inventory.");

                local oldInv = tabnet.GetTable(data.DroppedInvID);
                if !oldInv then return; end
                local newInv = tabnet.GetTable(data.CurrentInvID);
                if !newInv then return; end

                local oldContents = oldInv:GetField("Contents", {}, true);
                oldContents[data.DroppedItemID] = nil;
                oldInv:SetField("Contents", oldContents);

                local newContents = newInv:GetField("Contents", {}, true);
                newContents[data.DroppedItemID] = true;
                newInv:SetField("Contents", newContents);

                droppedItem:SetFields{
                    ["Owner"] = data.CurrentInvID,
                    ["Position"] = data.CurrentItemPos
                };
            end
        end
    end, {1});

    -- Watch for item function requests.
    vnet.Watch("bash_Net_ItemFuncRequest", function(pck)
        local requester = pck.Source;
        local data = pck:Table();

        local item = tabnet.GetTable(data.ItemID);
        if !item then return; end 

        local itemType = bash.Item.Types[item:GetField("ItemType")];
        if !itemType or !itemType.Functions[data.UseFunc] then MsgN("NO FUNC") return; end

        local func = itemType.Functions[data.UseFunc];
        if !func.RunOnServer then MsgN("NO RUN ON SERVER") return; end
        
        local item = tabnet.GetTable(data.ItemID);
        func.Run(requester, item, data.SendData);
    end, {1});

elseif CLIENT then

    --
    -- Engine hooks.
    --

    -- Wait for 'use' on entity key presses.
    hook.Add("KeyPress", "bash_ItemUseOnEntity", function(lp, key)
        if key != IN_USE then return; end

        local traceTab = {};
        traceTab.start = LocalPlayer():EyePos();
        traceTab.endpos = traceTab.start + LocalPlayer():GetAimVector() * 90;
        traceTab.filter = LocalPlayer();
        local trace = util.TraceLine(traceTab);
        local ent = trace.Entity;
        if !ent:IsItem() then return; end

        if bash.Item.CurrentMenu then
            bash.Item.CurrentMenu:Remove();
            bash.Item.CurrentMenu = nil;
        end 

        local item = ent:GetItem();
        if !item then return; end 
        local itemID = item:GetField("ItemID");
        local itemTypeID = item:GetField("ItemType");
        local itemType = bash.Item.Types[itemTypeID];
        if !itemType then return; end

        local opts = DermaMenu();
        local added = 0;

        for name, func in pairs(itemType.Functions) do 
            if !func.ShowInWorld then continue; end
            if !func.CanShow(item, ent) then continue; end

            opts:AddOption(func.MenuName or name, function()
                if func.RunOnClient then
                    func.Run(LocalPlayer(), item, {});
                else
                    local sendData = (func.GetSendData and func.GetSendData(item)) or {};
                    local sendUse = vnet.CreatePacket("bash_Net_ItemFuncRequest");
                    sendUse:Table({
                        ItemID = itemID,
                        UseFunc = name,
                        SendData = sendData
                    });
                    sendUse:AddServer();
                    sendUse:Send();
                end
            end);

            added = added + 1;
        end

        if added > 0 then
            opts:Open();
            opts.CurrentEntity = ent;
            bash.Item.CurrentMenu = opts;
        else
            opts:Remove();
        end 
        
    end);

    -- Watch for entity deletions so context menus can be deleted.
    hook.Add("EntityRemoved", "bash_ItemDeleteOldContextMenu", function(ent)
        if !bash.Item.CurrentMenu then return; end
        if bash.Item.CurrentMenu.CurrentEntity != ent then return; end

        bash.Item.CurrentMenu:Remove();
        bash.Item.CurrentMenu = nil;
    end);

end

--
-- Engine hooks.
--

-- Create item structures.
hook.Add("CreateStructures_Engine", "bash_ItemStructures", function()
    if SERVER then
        if !tabnet.GetTable("bash_ItemRegistry") then
            tabnet.CreateTable(nil, tabnet.LIST_GLOBAL, nil, "bash_ItemRegistry");
        end
    end

    bash.Util.ProcessDir("engine/items", false, "SHARED");

    -- ItemID: Unique ID for an item.
    tabnet.EditSchemaField{
        SchemaName = "bash_Item",
        FieldName = "ItemID",
        FieldDefault = "",
        FieldScope = tabnet.SCOPE_PUBLIC,
        IsInSQL = true,
        FieldType = "string",
        IsPrimaryKey = true
    };

    -- Owner: Unique ID of the 'owner' of the item.
    tabnet.EditSchemaField{
        SchemaName = "bash_Item",
        FieldName = "Owner",
        FieldDefault = "",
        FieldScope = tabnet.SCOPE_PRIVATE,
        IsInSQL = true,
        FieldType = "string"
    };

    -- Position: Table containing the coordinates of the item in its owning container.
    -- X Y for inventory, X Y Z for world.
    tabnet.EditSchemaField{
        SchemaName = "bash_Item",
        FieldName = "Position",
        FieldDefault = EMPTY_TABLE,
        FieldScope = tabnet.SCOPE_PRIVATE,
        IsInSQL = true,
        FieldType = "table"
    };

    -- ItemType: Type structure that the item follows.
    tabnet.EditSchemaField{
        SchemaName = "bash_Item",
        FieldName = "ItemType",
        FieldDefault = "",
        FieldScope = tabnet.SCOPE_PUBLIC,
        IsInSQL = true,
        FieldType = "string"
    };

    -- Contents: Table of items within the inventory.
    tabnet.EditSchemaField{
        SchemaName = "bash_Item",
        FieldName = "DynamicData",
        FieldDefault = EMPTY_TABLE,
        FieldScope = tabnet.SCOPE_PUBLIC,
        IsInSQL = true,
        FieldType = "table"
    };

    -- IsTemp: Whether or not the inventory is temporary (not saved in SQL).
    tabnet.EditSchemaField{
        SchemaName = "bash_Item",
        FieldName = "IsTemp",
        FieldDefault = false,
        FieldScope = tabnet.SCOPE_PRIVATE,
        IsInSQL = false,
        FieldType = "boolean"
    };
end);

-- Register inventory types (schema).
hook.Add("CreateStructures", "bash_ItemRegisterTypes", function()
    bash.Util.ProcessDir("schema/items", false, "SHARED");
end);
