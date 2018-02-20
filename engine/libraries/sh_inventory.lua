--[[
    Inventory management functionality.
]]

--
-- Local storage.
--

local bash = bash;

local LOG_INV = {pre = "[INV]", col = color_limegreen};

--
-- Global storage.
--

INV_CHAR = "Char";
INV_ITEM = "Item";
INV_STORE = "Storage";

bash.Inventory          = bash.Inventory or {};
bash.Inventory.IDs      = bash.Inventory.IDs or {};
bash.Inventory.Types    = bash.Inventory.Types or {};
bash.Inventory.Viewing  = (CLIENT and (bash.Inventory.Viewing or {})) or nil;

--
-- Inventory functions.
--

-- Add a new inventory type struct.
function bash.Inventory.RegisterType(inv)
    bash.Inventory.Types[inv.ID] = {
        ID = inv.ID,
        Name = inv.Name,
        SizeX = inv.SizeX,
        SizeY = inv.SizeY
    };
end

-- Get an inventory type struct.
function bash.Inventory.GetType(invID)
    return bash.Inventory.Types[invID];
end

-- Get the inventory registry.
function bash.Inventory.GetRegistry()
    return tabnet.GetTable("bash_InvRegistry");
end

-- Check to see if an inventory is currently attached to an entity.
function bash.Inventory.IsInUse(id)
    return bash.Inventory.GetRegistry():Get(id);
end

-- Checks to see if an inventory contains an item in a certain quantity.
function bash.Inventory.HasItem(inv, id, amount)
    amount = amount or 1;
    if !inv then return; end

    local invCont = inv:GetField("Contents", {});
    local count, curItem = 0;
    for itemID, _ in pairs(invCont) do
        curItem = tabnet.GetTable(itemID);
        -- TODO: Remove invalid items?
        if !curItem then continue; end
        if curItem:GetField("ItemType") != id then continue; end

        count = count + curItem:GetField("Stack");
        if count >= amount then return true, curItem; end
    end

    return false;
end

-- Checks to see if an inventory contains a unique item.
function bash.Inventory.HasUniqueItem(inv, id)
    if !inv then return; end

    local invCont = inv:GetField("Contents", {});
    local curItem;
    for itemID, _ in pairs(invCont) do
        curItem = tabnet.GetTable(itemID);
        -- TODO: Remove invalid items?
        if !curItem then continue; end
        if curItem:GetField("ItemID") == id then return true; end
    end

    return false;
end

-- Get a table structure representing the grid of an inventory.
function bash.Inventory.GetContentGrid(inv)
    if !inv then return; end
    local invTypeID = inv:GetField("InvType", "");
    local invType = bash.Inventory.GetType(invTypeID);
    if !invType then return; end
    
    local occupied = {};
    for xIndex = 1, invType.SizeX do
        occupied[xIndex] = occupied[xIndex] or {};
        for yIndex = 1, invType.SizeY do
            occupied[xIndex][yIndex] = 0;
        end
    end

    local curItem, itemPos, itemTypeID, itemType;
    for itemID, _ in pairs(inv:GetField("Contents", {})) do
        curItem = tabnet.GetTable(itemID);
        if !curItem then continue; end

        itemPos = curItem:GetField("PosInInv", {});
        if !itemPos.X or !itemPos.Y then continue; end

        itemTypeID = curItem:GetField("ItemType", "");
        itemType = bash.Item.Types[itemTypeID];
        if !itemType then continue; end

        for xIndex = itemPos.X, itemPos.X + (itemType.SizeX - 1) do
            for yIndex = itemPos.Y, itemPos.Y + (itemType.SizeY - 1) do
                occupied[xIndex][yIndex] = itemID;
            end
        end
    end

    return occupied;
end 

if SERVER then

    -- Get an ununused InvID.
    function bash.Inventory.GetUnusedID()
        local id;
        repeat
            id = string.random(12, CHAR_ALPHANUM, "inv_");
        until !bash.Inventory.IDs[id];
        return id;
    end

    -- Create a new inventory from scratch.
    function bash.Inventory.Create(data, forceID, temp)
        local invDefaults = tabnet.GetSchemaDefaults("bash_Inventory");
        for fieldName, def in pairs(invDefaults) do
            if data[fieldName] == nil then
                data[fieldName] = def;
            end 
        end 

        local invID = forceID or bash.Inventory.GetUnusedID();
        bash.Inventory.IDs[invID] = true;
        data.InvID = invID;
        data.IsTemp = temp;

        if !bash.Inventory.Types[data.InvType] then
            bash.Util.MsgErr("InvCreateFailed", invID);
            bash.Inventory.IDs[invID] = nil;
            return false;
        end

        bash.Util.MsgLog(LOG_INV, "Creating a new inventory with the ID '%s'...", invID);

        local newInv;
        if temp then
            newInv = tabnet.CreateTable(data, nil, "bash_Inventory", invID);
        else
            newInv = tabnet.GetDBProvider():CreateTable("bash_Inventory", data, true);
        end

        if !newInv then
            bash.Util.MsgErr("InvCreateFailed", invID);
            bash.Inventory.IDs[invID] = nil;
            return;
        end

        hook.Run("OnInventoryCreate", newInv, temp);
        return newInv;
    end

    -- Find the first available open spot in an inventory for a certain item type.
    function bash.Inventory.GetOpenSpot(inv, addItemID, canMerge)
        if !inv then return; end

        local invTypeID = inv:GetField("InvType");
        local invType = bash.Inventory.GetType(invTypeID);
        if !invType then return; end

        local addItemType = bash.Item.GetType(addItemID);
        if !addItemType then return; end
        local addItemW = addItemType.Static.SizeX;
        local addItemH = addItemType.Static.SizeY;

        local occupied = bash.Inventory.GetContentGrid(inv);
        local canFit;
        for xIndex = 1, invType.SizeX - (addItemW - 1) do
            for yIndex = 1, invType.SizeY - (addItemH - 1) do
                -- TODO: Add stacking.
                
                canFit = true;

                for wIndex = 0, (addItemW - 1) do
                    for hIndex = 0, (addItemH - 1) do
                        if occupied[xIndex + wIndex][yIndex + hIndex] != 0 then
                            canFit = false;
                            break;
                        end
                    end

                    if !canFit then break; end
                end

                if canFit then
                    return {X = xIndex, Y = yIndex};
                end

            end
        end 
    end

    -- Create a new instance of an inventory.
    function bash.Inventory.Load(id)
        bash.Util.MsgLog(LOG_INV, "Loading inventory '%s'...", id);

        local inv = tabnet.GetTable(id);
        if !inv then
            inv = tabnet.GetDBProvider():LoadTable("bash_Inventory", id);
        end 

        if !inv then
            bash.Util.MsgErr("InvNotFound", id);
            return;
        end

        return inv;

        --[[
        local owner = forceOwner;
        if !owner then
            local ownerID = inv:GetField("Owner");
            if !ownerID then
                bash.Util.MsgErr("InvNoOwnerSet", id);
                return;
            end

            owner = bash.Character.GetPlayerOwner(ownerID);
            -- TODO: Add NPC functionality.
            if !owner then
                bash.Util.MsgErr("InvNoOwnerAvailable", id);
                return;
            end 
        end

        bash.Inventory.AttachTo(char, owner, deleteOld);


        -- TODO: Finish this function.
        if !bash.Inventory.Cache[id] then
            bash.Util.MsgDebug(LOG_INV, "Request to load inventory '%s' is waiting on data.", id);

            bash.Inventory.Waiting[id] = true;
            bash.Inventory.Fetch(id);
            return;
        end

        bash.Util.MsgLog(LOG_INV, "Loading inventory '%s'...", id);

        local invData = bash.Inventory.Cache[id];
        if !tabnet.GetTable(id) then
            -- TODO: Fix this.
            --tabnet.CreateTable(invData, nil, id);
        end

        bash.Inventory.LoadContents(id, ent);
        bash.Inventory.AttachTo(id, ent, deleteOld);
        ]]
    end

    --[[
    -- Create all containing items in an inventory.
    function bash.Inventory.LoadContents(id, ent)
        local inv = tabnet.GetTable(id);
        if !inv then return; end

        for itemID, _ in pairs(inv:Get("Contents", {})) do
            -- TODO: What did he mean by this?
            --bash.Item.Load(itemID, ent, );
        end
    end

    -- Attempts to insert an item into an inventory (changes owner and position).
    function bash.Inventory.InsertItem(invID, itemID)
        -- TODO: Handle non-registered inventories.
        local inv = tabnet.GetTable(invID);
        local item = tabnet.GetTable(itemID);
        if !inv then return; end
        if !item then return; end

        local contents = inv:GetField("Contents", {});
        if contents[itemID] then return; end

        local invTypeID = inv:GetField("InvType", "");
        local invType = bash.Inventory.Types[invTypeID];
        if !invType then return; end

        local occupied = {};
        for xIndex = 1, invType.SizeX do
            occupied[xIndex] = occupied[xIndex] or {};
            for yIndex = 1, invType.SizeY do
                occupied[xIndex][yIndex] = 0;
            end
        end

        local curItem, itemPos, itemTypeID, itemType;
        for _itemID, _ in pairs(contents) do
            curItem = tabnet.GetTable(_itemID);
            if !curItem then continue; end

            itemPos = curItem:GetField("PosInInv", {});
            if !itemPos.X or !itemPos.Y then continue; end

            itemTypeID = curItem:GetField("ItemType", "");
            itemType = bash.Item.Types[itemTypeID];
            if !itemType then continue; end

            for xIndex = itemPos.X, itemPos.X + (itemType.SizeX - 1) do
                for yIndex = itemPos.Y, itemPos.Y + (itemType.SizeY - 1) do
                    occupied[xIndex][yIndex] = _itemID;
                end
            end
        end

        itemPos = item:GetField("PosInInv", {});
        if !itemPos.X or !itemPos.Y then return; end

        itemTypeID = item:GetField("ItemType", "");
        itemType = bash.Item.Types[itemTypeID];
        if !itemType then return; end


    end
    ]]

    -- Add an item to an inventory.
    function bash.Inventory.AddItem(inv, item, forcePos)
        -- TODO: Handle non-registered inventories.
        if !inv or !item then return false; end
        local invID = inv:GetField("InvID");
        local itemID = item:GetField("ItemID");

        local pos = forcePos or bash.Inventory.GetOpenSpot(inv, item:GetField("ItemType"));
        if !pos or !pos.X or !pos.Y then return false; end

        local contents = inv:GetField("Contents", {}, true);
        local oldInvID = item:GetField("Owner");
        MsgN(oldInvID);
        local oldOwner = bash.Inventory.GetPlayerOwner(oldInvID);
        MsgN(tostring(oldOwner));

        bash.Util.MsgDebug(LOG_INV, "Adding item '%s' to inventory '%s'...", itemID, invID);

        contents[itemID] = true;
        inv:SetField("Contents", contents);
        item:SetFields{
            ["Owner"] = invID,
            ["Position"] = {
                X = pos.X,
                Y = pos.Y
            }
        };

        local ply = bash.Inventory.GetPlayerOwner(invID);
        if !ply then return false; end
        item:AddListener(ply, tabnet.SCOPE_PRIVATE);

        if oldInvID != "" and invID != oldInvID then
            local oldInv = tabnet.GetTable(oldInvID);
            if oldInv then
                local oldContents = oldInv:GetField("Contents", {}, true);
                oldContents[itemID] = nil;
                oldInv:SetField("Contents", oldContents);

                if isplayer(oldOwner) and ply != oldOwner then
                    MsgN("REMOVING ODL!");
                    MsgN(ply);
                    MsgN(oldOwner);
                    item:RemoveListener(oldOwner);
                end
            end
        end

        return true;
    end

    -- Remove an item from an inventory.
    function bash.Inventory.RemoveItem(inv, item)
        -- TODO: Handle non-registered inventories.
        if !inv or !item then return; end

        local itemID = item:GetField("ItemID");
        local invID = inv:GetField("InvID");
        local contents = inv:GetField("Contents", {}, true);
        contents[itemID] = nil;
        inv:SetField("Contents", contents);
        item:SetField("Owner", "");

        local ply = bash.Inventory.GetPlayerOwner(invID);
        item:RemoveListener(ply);

        bash.Util.MsgDebug(LOG_INV, "Removing item '%s' from inventory '%s'.", itemID, invID);
    end

    -- Get an inventory's player owner, if any.
    function bash.Inventory.GetPlayerOwner(id)
        local inv = tabnet.GetTable(id);
        if !inv then return; end

        local ownerID = inv:GetField("Owner");
        if ownerID:sub(1, 5) != "char_" then return; end

        local reg = bash.Character.GetRegistry();
        local curUser = reg:GetField(ownerID);
        local ent = (curUser and ents.GetByIndex(curUser)) or nil;
        return ent;
    end

    -- Add a player to an inventory's (and its items') listeners.
    function bash.Inventory.AddPlayerListener(inv, ply)
        if !inv or !isplayer(ply) then return; end

        local invID = inv:GetField("InvID");
        local contents = inv:GetField("Contents", {});

        bash.Util.MsgDebug(LOG_INV, "Adding '%s' to listeners for inventory '%s'...", tostring(ply), invID);

        inv:AddListener(ply, tabnet.SCOPE_PUBLIC);
        local curItem;
        for itemID, _ in pairs(contents) do
            curItem = bash.Item.Load(itemID);
            if !curItem then continue; end

            curItem:AddListener(ply, tabnet.SCOPE_PRIVATE);
        end
    end

    -- Remove a player from an inventory's (and its items') listeners.
    function bash.Inventory.RemovePlayerListener(inv, ply, delete)
        if !inv or !isplayer(ply) then return; end

        local invID = inv:GetField("InvID");
        local contents = inv:GetField("Contents", {});
        local curItem;

        bash.Util.MsgDebug(LOG_INV, "Removing '%s' from listeners for inventory '%s'...", tostring(ply), invID);

        for itemID, _ in pairs(contents) do
            curItem = bash.Item.Load(itemID);
            if !curItem then continue; end

            curItem:RemoveListener(ply);
            if delete then tabnet.DeleteTable(itemID); end
        end

        inv:RemoveListener(ply);
        if delete then tabnet.DeleteTable(invID); end 
    end 

    --[[
    -- Associate an inventory with the given owner.
    function bash.Inventory.AttachTo(id, ent, deleteOld)
        if !isent(ent) then return; end
        bash.Inventory.DetachFrom()


        -- TODO: Finish this function.
        local inv = bash.TableNet.Get(id);
        if !inv then return; end
        if ownerID == "" then return; end

        local invType, ent;
        if ownerID:sub(1, 5) == "char_" then
            invType = INV_CHAR;

            local reg = bash.Character.GetRegistry();
            local curUser = reg:Get(ownerID);
            ent = (curUser and ents.GetByIndex(curUser)) or nil;
        elseif ownerID:sub(1, 5) == "item_" then
            invType = INV_ITEM;

            local reg = bash.Item.GetRegistry();
            local curItem = reg:Get(ownerID);
            ent = (curUser and ents.GetByIndex(curUser)) or nil;
        elseif ownerID:sub(1, 6) == "store_" then
            invType = INV_STORE;
            -- TODO: Find active storage entity.
        end

        if !isent(ent) and !isplayer(ent) then
            bash.Util.MsgDebug(LOG_INV, "No owner '%s' available for inventory '%s'.", ownerID, id);
            return;
        end

        bash.Util.MsgDebug(LOG_INV, "Attaching inventory '%s' to owner '%s'.", id, ownerID);

        if invType == INV_CHAR then
            if !isplayer(ent) then return; end
            inv:AddListener(ent, NET_PUBLIC);
            local curItem;
            for itemID, _ in pairs(inv:Get("Contents", {})) do
                curItem = bash.TableNet.Get(itemID);
                if !curItem then continue; end
                curItem:AddListener(ent, NET_PUBLIC);
            end
        end

        local reg = bash.Item.GetRegistry();
        local index = ent:EntIndex();
        reg:SetData{
            Public = {
                [index] = id,
                [id] = index
            }
        };

        local inv = bash.TableNet.Get(id);
        hook.Run("OnInventoryAttach", inv, ent);
    end

    -- Dissociate an inventory associated with an entity.
    function bash.Inventory.DetachFrom(id, ent, delete)
        local inv = bash.TableNet.Get(id);
        if !inv then return; end
        if !isent(ent) and !isplayer(ent) then return; end

        bash.Util.MsgDebug(LOG_INV, "Detaching inventory '%s' from entity '%s'...", id, tostring(ent));

        if isplayer(ent) then
            inv:RemoveListener(ent, NET_PUBLIC);
            local curItem;
            for itemID, _ in pairs(inv:Get("Contents", {})) do
                curItem = bash.TableNet.Get(itemID);
                curItem:RemoveListener(ent, NET_PUBLIC);
            end
        end

        local reg = bash.Inventory.GetRegistry();
        local index = ent:EntIndex();
        reg:Delete(index, id);
        hook.Run("OnInventoryDetach", inv, ent);

        if delete then
            bash.TableNet.DeleteTable(id);
        end
    end
    ]]

    --
    -- Engine hooks.
    --

    -- Fetch all used IDs.
    hook.Add("InitPostEntity", "bash_InventoryFetchIDs", function()
        bash.Util.MsgDebug(LOG_INV, "Fetching used InvIDs...");

        tabnet.GetDBProvider():GetTableData(
            "bash_Inventory",
            {"InvID"},
            nil,

            function(data)
                for _, inv in pairs(data) do
                    bash.Inventory.IDs[inv.InvID] = true;
                end

                bash.Util.MsgDebug(LOG_INV, "Cached %d InvIDs.", #data);
            end
        );
    end);

    -- Attach a character's inventory to owner.
    hook.Add("OnCharacterAttach", "bash_InventoryAttachChar", function(char, ent)
        if !isplayer(ent) then return; end

        local invs = char:GetField("Inventory", {});
        local inv, invCont, item;
        for slot, invID in pairs(invs) do 
            inv = bash.Inventory.Load(invID);
            if !inv then continue; end

            bash.Inventory.AddPlayerListener(inv, ent);
        end
    end);

    -- Detach a character's inventory from owner.
    hook.Add("OnCharacterDetach", "bash_InventoryDetachChar", function(char, ent)
        if !isplayer(ent) then return; end

        local invs = char:GetField("Inventory", {});
        local inv;
        for slot, invID in pairs(invs) do 
            inv = tabnet.GetTable(invID);
            if !inv then continue; end

            bash.Inventory.RemovePlayerListener(inv, ent, true);
        end
    end);

end

--
-- Engine hooks.
--

-- Create character structures.
hook.Add("CreateStructures_Engine", "bash_InventoryStructures", function()
    if SERVER then
        if !tabnet.GetTable("bash_InvRegistry") then
            tabnet.CreateTable(nil, tabnet.LIST_GLOBAL, nil, "bash_InvRegistry");
        end
    end

    bash.Util.ProcessDir("engine/inventories", false, "SHARED");

    -- InvID: Unique ID for an inventory.
    tabnet.EditSchemaField{
        SchemaName = "bash_Inventory",
        FieldName = "InvID",
        FieldDefault = "",
        FieldScope = tabnet.SCOPE_PUBLIC,
        IsInSQL = true,
        FieldType = "string",
        IsPrimaryKey = true
    };

    -- Owner: Unique ID for the 'owner' of the inventory. CharID for characters.
    tabnet.EditSchemaField{
        SchemaName = "bash_Inventory",
        FieldName = "Owner",
        FieldDefault = "",
        FieldScope = tabnet.SCOPE_PUBLIC,
        IsInSQL = true,
        FieldType = "string"
    };

    -- InvType: Type structure that the inventory follows.
    tabnet.EditSchemaField{
        SchemaName = "bash_Inventory",
        FieldName = "InvType",
        FieldDefault = "",
        FieldScope = tabnet.SCOPE_PUBLIC,
        IsInSQL = true,
        FieldType = "string"
    };

    -- Contents: Table of items within the inventory.
    tabnet.EditSchemaField{
        SchemaName = "bash_Inventory",
        FieldName = "Contents",
        FieldDefault = EMPTY_TABLE,
        FieldScope = tabnet.SCOPE_PUBLIC,
        IsInSQL = true,
        FieldType = "table"
    };

    -- IsTemp: Whether or not the inventory is temporary (not saved in SQL).
    tabnet.EditSchemaField{
        SchemaName = "bash_Inventory",
        FieldName = "IsTemp",
        FieldDefault = false,
        FieldScope = tabnet.SCOPE_PUBLIC,
        IsInSQL = false,
        FieldType = "boolean"
    };
end);

-- Register inventory types (schema).
hook.Add("CreateStructures", "bash_InventoryRegisterTypes", function()
    bash.Util.ProcessDir("schema/inventories", false, "SHARED");
end);
