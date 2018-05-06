--[[
    Inventory management functionality.
]]

--
-- Local storage.
--

local bash = bash;

local LOG_INV = {pre = "[INV]", col = color_limegreen};

local Entity = FindMetaTable("Entity");

--
-- Global storage.
--

INV_CHAR = "Char";
INV_ITEM = "Item";
INV_STORE = "Storage";

bash.Inventory          = bash.Inventory or {};
bash.Inventory.IDs      = bash.Inventory.IDs or {};
bash.Inventory.Types    = bash.Inventory.Types or {};

--
-- Entity functions.
--

-- Get an entity's associated inventory, if any.
function Entity:GetInventory()
    if !isent(self) then return; end

    local lookup = bash.Inventory.GetLookup();
    if !lookup then return; end

    local entInd = self:EntIndex();
    local invID = lookup:GetField(entInd);
    return tabnet.GetTable(invID);
end

-- Check if an entity has an inventory associated with it.
function Entity:IsInventory()
    return self:GetInventory() != nil;
end

-- Check if an entity has a certain inventory associated with it.
function Entity:IsSpecificInventory(invID)
    return self:IsInventory() and self:GetInventory():GetField("InvID") == invID;
end

if SERVER then

    -- Attach an inventory to an entity.
    function Entity:AttachInventory(inv)
        if !inv or !inv:GetField("InvID") then return; end 
        if !isent(self) then return; end

        self:DetachInventory();

        local id = inv:GetField("InvID");
        local lookup = bash.Inventory.GetLookup();
        local index = self:EntIndex();
        local oldIndex = lookup:GetField(id);
        local oldOwner = (oldIndex and ents.GetByIndex(oldIndex)) or nil;

        if isent(oldOwner) then oldOwner:DetachInventory(true); end

        bash.Util.MsgDebug(LOG_INV, "Attaching inventory '%s' to entity '%s'...", id, tostring(self));

        lookup:SetFields{
            [id] = index,
            [index] = id
        };
        inv:ClearListeners();
        hook.Run("OnInventoryAttach", inv, self);
    end

    -- Detach an entity from its current inventory.
    function Entity:DetachInventory(keep)
        if !isent(self) then return; end
        if !self:IsInventory() then return; end

        local lookup = bash.Inventory.GetLookup();
        local inv = ent:GetInventory();
        local id = inv:GetField("InvID");
        local index = ent:EntIndex();

        bash.Util.MsgDebug(LOG_INV, "Detaching inventory '%s' from entity '%s'...", id, tostring(self));

        lookup:ClearField(id, index);
        hook.Run("OnInventoryDetach", inv, self);

        if !keep then tabnet.DeleteTable(id); end
    end 

end

--
-- Inventory functions.
--

-- Get the inventory lookup table.
function bash.Inventory.GetLookup()
    return tabnet.GetTable("bash_InvLookup");
end

-- Get an entity who is associated with a certain inventory.
function bash.Inventory.GetActiveEntity(invID)
    local lookup = bash.Inventory.GetLookup();
    if !lookup then return; end

    local curEnt = lookup:GetField(invID);
    local ent = (curEnt and ents.GetByIndex(curEnt)) or nil;
    return ent;
end

-- Get the player whose character 'owns' a certain inventory.
function bash.Inventory.GetPlayerOwner(invID)
    local inv = tabnet.GetTable(invID);
    if !inv then return; end

    local ownerID = inv:GetField("Owner");
    if ownerID:sub(1, 5) != "char_" then return; end

    local lookup = bash.Character.GetLookup();
    local curUser = lookup:GetField(ownerID);
    local ent = (curUser and ents.GetByIndex(curUser)) or nil;
    return ent;
end

-- Check to see if an inventory is currently associated with an entity.
function bash.Inventory.HasActiveEntity(invID)
    return bash.Inventory.GetActiveEntity(invID) != nil;
end

-- Check to see if an inventory contains a specific item.
function bash.Inventory.HasSpecificItem(invID, itemID)
    local inv, invLoaded;
    if CLIENT then
        inv = tabnet.GetTable(invID);
    elseif SERVER then
        inv, invLoaded = bash.Inventory.Load(invID);
    end

    if !inv then return; end

    local invCont = inv:GetField("Contents", {});
    local hasItem = (invCont[itemID] != nil);

    if SERVER and invLoaded then
        bash.Inventory.Unload(invID);
    end

    return hasItem;
end 

-- Checks to see if an inventory contains an item of a certain type.
function bash.Inventory.HasItemType(invID, itemTypeID, getList)
    local inv, invLoaded;
    if CLIENT then
        inv = tabnet.GetTable(invID);
    elseif SERVER then
        inv, invLoaded = bash.Inventory.Load(invID);
    end
    
    if !inv then return; end

    local invCont = inv:GetField("Contents", {});
    local itemList, itemIsType, itemStack = {}, false, 0;
    for itemID, _ in pairs(invCont) do
        itemIsType, itemStack = bash.Item.IsType(itemID, itemTypeID, true);
        if itemIsType then
            if getList then
                itemList[itemID] = itemStack;
            else
                if SERVER and invLoaded then
                    bash.Inventory.Unload(invID);
                end

                return true;
            end
        end
    end

    if SERVER and invLoaded then
        bash.Inventory.Unload(invID);
    end

    return !table.IsEmpty(itemList), itemList;
end

-- Checks to see if an inventory is of a certain type.
function bash.Inventory.IsType(invID, invTypeID)
    local inv, invLoaded;
    if CLIENT then
        inv = tabnet.GetTable(invID);
    else
        inv, invLoaded = bash.Inventory.Load(invID);
    end

    if !inv then return; end 

    local isType = invTypeID == inv:GetField("InvType");

    if SERVER and invLoaded then
        bash.Inventory.Unload(invID);
    end

    return isType;
end

--[[ TODO: Remove.
-- Get the size of an inventory's contents.
function bash.Inventory.GetContentSize(invID)
    local inv, invLoaded;
    if CLIENT then
        inv = tabnet.GetTable(invID);
    elseif SERVER then
        inv, invLoaded = bash.Inventory.Load(invID);
    end

    if !inv then return -1; end

    local size = 0;
    local curItem, curItemTypeID, curItemType;
    for itemID, _ in pairs(inv:GetField("Contents", {})) do
        if CLIENT then
            curItem = tabnet.GetTable(itemID);
        elseif SERVER then 
            curItem, curItemLoaded = bash.Item.Load(itemID);
        end 

        if !curItem then continue; end

        curItemTypeID = curItem:GetField("ItemType");
        curItemType = bash.Item.GetType(curItemTypeID);
        if !curItemType then
            if SERVER and curItemLoaded then
                bash.Item.Unload(itemID);
            end
    
            continue;
        end 

        size = size + curItemType.Static.Size;
    end

    return size;
end
]]

-- Check to see if an inventory has space for an item type.
function bash.Inventory.HasSpace(invID, itemTypeID, amount)
    local inv, invLoaded;
    if CLIENT then
        inv = tabnet.GetTable(invID);
    elseif SERVER then
        inv, invLoaded = bash.Inventory.Load(invID);
    end
    if !inv then return false; end

    local invTypeID = inv:GetField("InvType");
    local invType = bash.Inventory.GetType(invTypeID);
    if !invType then
        if SERVER and invLoaded then
            bash.Inventory.Unload(invID);
        end

        return false;
    end

    if itemTypeID and amount then

    else
        local positions = {};
        local curItem, curItemLoaded, curItemPos;
        for itemID, _ in pairs(inv:GetField("Contents", {})) do
            if CLIENT then
                curItem = tabnet.GetTable(itemID);
            elseif SERVER then
                curItem, curItemLoaded = bash.Item.Load(itemID);
            end
            if !curItem then continue; end

            curItemPos = curItem:GetField("Position", {});
            if curItemPos.x and curItemPos.y then
                positions[#positions + 1] = curItemPos;
            end

            if curItemLoaded then
                bash.Item.Unload(itemID);
            end
        end

        
    end

    if SERVER and invLoaded then
        bash.Inventory.Unload(invID);
    end

    return true;
end

-- Add a new inventory type struct.
function bash.Inventory.RegisterType(invType)
    bash.Inventory.Types[invType.ID] = {
        ID = invType.ID,
        Name = invType.Name,
        SizeX = invType.SizeX,
        SizeY = invType.SizeY,
        MaxItemSize =invType.MaxItemSize
    };
end

-- Get an inventory type struct.
function bash.Inventory.GetType(invTypeID)
    return bash.Inventory.Types[invTypeID];
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

        bash.Util.MsgDebug(LOG_INV, "Creating a new inventory with the ID '%s'...", invID);

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

    -- Load an inventory from the database.
    function bash.Inventory.Load(invID, loadContents)
        bash.Util.MsgDebug(LOG_INV, "Loading inventory '%s'...", invID);

        local loadedFromDB = false;
        local inv = tabnet.GetTable(invID);
        if !inv then
            inv = tabnet.GetDBProvider():LoadTable("bash_Inventory", invID);
            loadedFromDB = true;
        end 

        if !inv then
            bash.Util.MsgErr("InvNotFound", invID);
            return;
        end

        if loadContents then
            local contents = inv:GetField("Contents", {});
            local item;
            for itemID, _ in pairs(contents) do
                item = bash.Item.Load(itemID);
                -- TODO: Remove invalid items?
            end
        end

        return inv, loadedFromDB;
    end

    -- Unload an inventory and all of its contents.
    function bash.Inventory.Unload(invID)
        local inv = tabnet.GetTable(invID);
        if !inv then return; end

        local contents = inv:GetField("Contents", {});
        for itemID, _ in pairs(contents) do
            bash.Item.Unload(itemID);
        end

        hook.Run("OnInventoryUnload", inv);
        tabnet.DeleteTable(invID);
    end

    -- Delete an inventory from the database.
    function bash.Inventory.Delete(invID)
        local inv = bash.Inventory.Load(invID);
        local curEnt = bash.Inventory.GetActiveEntity(invID);
        if isent(curEnt) then
            curEnt:DetachInventory(true);
            curEnt:Remove();
        end

        hook.Run("OnInventoryDelete", inv);
        tabnet.GetDBProvider().EraseTable(inv);
    end

    -- Add an item to an inventory.
    function bash.Inventory.AddItem(invID, itemID, newPos)
        if invID == "!WORLD!" then return; end 

        local inv, invLoaded = bash.Inventory.Load(invID);
        if !inv then return false; end 
        local item, itemLoaded = bash.Item.Load(itemID);
        if !item then
            if invLoaded then
                bash.Inventory.Unload(invID);
            end

            return false;
        end

        local oldInvID = item:GetField("Owner");
        if oldInvID == invID then
            if invLoaded then
                bash.Inventory.Unload(invID);
            end
            if itemLoaded then
                bash.Item.Unload(itemID);
            end 

            return false;
        elseif oldInvID != "" and oldInvID != "!WORLD!" then
            bash.Inventory.RemoveItem(oldInvID, itemID, true);
        end

        bash.Util.MsgDebug(LOG_INV, "Adding item '%s' to inventory '%s'...", itemID, invID);

        local oldItemEnt = bash.Item.GetActiveEntity(itemID);
        if isent(oldItemEnt) then
            oldItemEnt:DetachItem(true);
            oldItemEnt:Remove();
        end

        local contents = inv:GetField("Contents", {}, true);
        contents[itemID] = true;
        inv:SetField("Contents", contents);

        if newPos and newPos.x and newPos.y then
            item:SetFields{
                ["Owner"] = invID,
                ["Position"] = newPos
            };
        else
            item:SetField("Owner", invID);
        end

        local ply = bash.Inventory.GetPlayerOwner(invID);
        if isplayer(ply) then
            item:AddListener(ply, tabnet.SCOPE_PRIVATE);
        end 

        return true;
    end

    -- Remove an item from an inventory.
    function bash.Inventory.RemoveItem(invID, itemID, keepListener)
        if invID == "!WORLD!" then return; end 

        local inv, invLoaded = bash.Inventory.Load(invID);
        if !inv then return; end
        local item, itemLoaded = bash.Item.Load(itemID);
        if !item then
            if invLoaded then
                bash.Inventory.Unload(invID);
            end
            
            return;
        end

        bash.Util.MsgDebug(LOG_INV, "Removing item '%s' from inventory '%s'.", itemID, invID);

        local contents = inv:GetField("Contents", {}, true);
        contents[itemID] = nil;
        inv:SetField("Contents", contents);
        item:SetField("Owner", "");
    
        if !keepListener then
            local ply = bash.Inventory.GetPlayerOwner(invID);
            item:RemoveListener(ply);
        end

        if invLoaded then
            bash.Inventory.Unload(invID);
        end
        if itemLoaded then
            bash.Item.Unload(itemID);
        end 
    end

    -- Add a player to an inventory's (and its items') listeners.
    function bash.Inventory.AddPlayerListener(invID, ply)
        local inv = tabnet.GetTable(invID);
        if !inv or !isplayer(ply) then return; end

        local contents = inv:GetField("Contents", {});

        bash.Util.MsgDebug(LOG_INV, "Adding '%s' to listeners for inventory '%s'...", tostring(ply), invID);

        local curItem;
        for itemID, _ in pairs(contents) do
            curItem = tabnet.GetTable(itemID);
            if !curItem then continue; end

            curItem:AddListener(ply, tabnet.SCOPE_PRIVATE);
        end

        inv:AddListener(ply, tabnet.SCOPE_PUBLIC);
    end

    -- Remove a player from an inventory's (and its items') listeners.
    function bash.Inventory.RemovePlayerListener(invID, ply, unload)
        local inv = tabnet.GetTable(invID);
        if !inv or !isplayer(ply) then return; end

        local contents = inv:GetField("Contents", {});

        bash.Util.MsgDebug(LOG_INV, "Removing '%s' from listeners for inventory '%s'...", tostring(ply), invID);


        local curItem;
        for itemID, _ in pairs(contents) do
            curItem = bash.Item.Load(itemID);
            if !curItem then continue; end

            curItem:RemoveListener(ply);
            if unload then bash.Item.Unload(itemID); end
        end

        inv:RemoveListener(ply);
        if unload then bash.Inventory.Unload(invID); end 
    end 

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
        local inv;
        for slot, invID in pairs(invs) do 
            inv = bash.Inventory.Load(invID, true);
            if !inv then continue; end

            bash.Inventory.AddPlayerListener(invID, ent);
        end
    end);

    -- Detach a character's inventory from owner.
    hook.Add("OnCharacterDetach", "bash_InventoryDetachChar", function(char, ent)
        if !isplayer(ent) then return; end

        local invs = char:GetField("Inventory", {});
        local inv;
        for slot, invID in pairs(invs) do 
            bash.Inventory.RemovePlayerListener(invID, ent);
        end
    end);

    -- Unload a character's inventories.
    hook.Add("OnCharacterUnload", "bash_InventoryUnloadChar", function(char)
        local invs = char:GetField("Inventory", {});
        for slot, invID in pairs(invs) do
            bash.Inventory.Unload(invID);
        end 
    end);

    -- Delete a character's inventories.
    hook.Add("OnCharacterDelete", "bash_InventoryDeleteChar", function(char)
        local invs = char:GetField("Inventory", {});
        for slot, invID in pairs(invs) do
            bash.Inventory.Delete(invID);
        end
    end);

elseif CLIENT then

    --
    -- Engine hooks.
    --

    -- Watch for inventory attaches.
    -- TODO: See if this is necessary.
    hook.Add("OnUpdateTable", "bash_InventoryWatchForAttach", function(tab, name, newVal, oldVal)
        if tab._RegistryID != "bash_InvLookup" then return; end
        if type(name) != "number" then return; end

        local entInd = name;
        local invID = newVal;
        local ent = ents.GetByIndex(entInd);
        if !isent(ent) then return; end

        local inv = tabnet.GetTable(invID);
        if !inv then return; end

        bash.Util.MsgDebug(LOG_INV, "Attaching inventory '%s' to entity '%s'...", invID, tostring(ent));
        hook.Run("OnInventoryAttach", inv, ent);
    end);

    -- Watch for inventory detaches.
    -- TODO: See if this is necessary.
    hook.Add("OnClearTable", "bash_InventoryWatchForDetach", function(tab, name, val)
        if tab._RegistryID != "bash_InvLookup" then return; end
        if type(name) != "number" then return; end

        local entInd = name;
        local invID = val;
        local ent = ents.GetByIndex(name);
        if !isent(ent) then return; end

        local inv = tabnet.GetTable(invID);
        if !inv then return; end

        bash.Util.MsgDebug(LOG_INV, "Detaching inventory '%s' from entity '%s'...", invID, tostring(ent));
        hook.Run("OnInventoryDetach", inv, ent);
    end);

end

--
-- Engine hooks.
--

-- Create character structures.
hook.Add("CreateStructures_Engine", "bash_InventoryStructures", function()
    if SERVER then
        if !tabnet.GetTable("bash_InvLookup") then
            tabnet.CreateTable(nil, tabnet.LIST_GLOBAL, nil, "bash_InvLookup");
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
