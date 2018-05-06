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
bash.Item.IDs       = bash.Item.IDs or {};
bash.Item.Bases     = bash.Item.Bases or {};
bash.Item.Types     = bash.Item.Types or {};

-- Item size enum.
ITEM_TINY = 0;
ITEM_SMALL = 1;
ITEM_MED = 2;
ITEM_LARGE = 3;
ITEM_HUGE = 4;

--
-- Entity functions.
--

-- Get an entity's associated item, if any.
function Entity:GetItem()
    if !isent(self) then return; end

    local lookup = bash.Item.GetLookup();
    if !lookup then return; end

    local entInd = self:EntIndex();
    local itemID = lookup:GetField(entInd);
    return tabnet.GetTable(itemID);
end

-- Check if an entity has an item associated with it.
function Entity:IsItem()
    return self:GetItem() != nil;
end

-- Check if an entity has a certain item associated with it.
function Entity:IsSpecificItem(itemID)
    return self:IsItem() and self:GetItem():GetField("ItemID") == itemID;
end

if SERVER then

    -- Attach an item to an entity.
    function Entity:AttachItem(item)
        if !item or !item:GetField("ItemID") then return; end 
        if !isent(self) then return; end

        self:DetachItem();

        local id = item:GetField("ItemID");
        local lookup = bash.Item.GetLookup();
        local index = self:EntIndex();
        local oldIndex = lookup:GetField(id);
        local oldOwner = (oldIndex and ents.GetByIndex(oldIndex)) or nil;

        if isent(oldOwner) then oldOwner:DetachItem(true); end

        bash.Util.MsgDebug(LOG_ITEM, "Attaching item '%s' to entity '%s'...", id, tostring(self));

        lookup:SetFields{
            [id] = index,
            [index] = id
        };
        item:ClearListeners(tabnet.SCOPE_PRIVATE);
        item:SetGlobal(true);
        hook.Run("OnItemAttach", item, self);
    end

    -- Detach an entity from its current item.
    function Entity:DetachItem(keep, noStorePos)
        if !isent(self) then return; end
        if !self:IsItem() then return; end

        local lookup = bash.Item.GetLookup();
        local pos = self:GetPos();
        local item = self:GetItem();

        if !noStorePos then
            item:SetField("PositionInWorld", {
                x = pos.x,
                y = pos.y,
                z = pos.z
            });
        end

        local id = item:GetField("ItemID");
        local index = self:EntIndex();

        bash.Util.MsgDebug(LOG_ITEM, "Detaching item '%s' from entity '%s'...", id, tostring(self));

        lookup:ClearField(id, index);
        item:SetGlobal(false);
        hook.Run("OnItemDetach", item, self);

        if !keep then tabnet.DeleteTable(id); end
    end 

end

--
-- Item functions.
--

-- Get the item lookup table.
function bash.Item.GetLookup()
    return tabnet.GetTable("bash_ItemLookup");
end

-- Get an entity who is associated with a certain item.
function bash.Item.GetActiveEntity(itemID)
    local lookup = bash.Item.GetLookup();
    if !lookup then return; end

    local curEnt = lookup:GetField(itemID);
    local ent = (curEnt and ents.GetByIndex(curEnt)) or nil;
    return ent;
end

-- Get the player whose character 'owns' a certain item.
function bash.Item.GetPlayerOwner(itemID)
    local item = tabnet.GetTable(itemID);
    if !item then return; end

    local ownerID = item:GetField("Owner");
    if ownerID:sub(1, 4) != "inv_" then return; end

    return bash.Inventory.GetPlayerOwner(ownerID);
end

-- Check to see if an item is currently associated with an entity.
function bash.Item.HasActiveEntity(itemID)
    return bash.Item.GetActiveEntity(itemID) != nil;
end

-- Checks to see if an item is of a certain type.
function bash.Item.IsType(itemID, itemTypeID, includeStack)
    local item, itemLoaded;
    if CLIENT then
        item = tabnet.GetTable(itemID);
    else
        item, itemLoaded = bash.Item.Load(itemID);
    end

    if !item then return; end

    local isType = itemTypeID == item:GetField("ItemType");
    local amount;
    if includeStack and isType then
        amount = bash.Item.GetDynamicData(itemID, "Stack");
    end

    if SERVER and itemLoaded then
        bash.Item.Unload(itemID);
    end

    return isType, amount;
end

-- Get a field in an item's static data.
function bash.Item.GetStaticData(itemID, fieldName)
    local item, itemLoaded;
    if CLIENT then
        item = tabnet.GetTable(itemID);
    elseif SERVER then
        item, itemLoaded = bash.Item.Load(itemID);
    end 

    if !item then return; end

    local itemTypeID = item:GetField("ItemType", "");
    local itemType = bash.Item.GetType(itemTypeID);
    if !itemType then
        if SERVER and itemLoaded then
            bash.Item.Unload(itemID);
        end

        return;
    end 

    local val = itemType.Static[fieldName];

    if SERVER and itemLoaded then
        bash.Item.Unload(itemID);
    end

    return val;
end

-- Get a field in an item's dynamic data.
function bash.Item.GetDynamicData(itemID, fieldName)
    local item, itemLoaded;
    if CLIENT then
        item = tabnet.GetTable(itemID);
    elseif SERVER then
        item, itemLoaded = bash.Item.Load(itemID);
    end 

    if !item then return; end

    local dynamicData = item:GetField("DynamicData", {});
    local val = dynamicData[fieldName];

    if SERVER and itemLoaded then
        bash.Item.Unload(itemID);
    end

    return val;
end

-- Add a new item base struct.
function bash.Item.RegisterBase(itemBase)
    if !itemBase or !istable(itemBase) or 
       !itemBase.Static or !itemBase.Static.ID then
        bash.Util.MsgErr("MalformedItemBase");
        return;
    end

    itemBase.Dynamic    = itemBase.Dynamic or {};
    itemBase.Functions  = itemBase.Functions or {};

    bash.Util.MsgDebug(LOG_ITEM, "Registering item base with ID '%s'...", itemBase.Static.ID);

    local baseData      = {};
    baseData.Static     = itemBase.Static;
    baseData.Dynamic    = itemBase.Dynamic;
    baseData.Functions  = itemBase.Functions;

    bash.Item.Bases[baseData.Static.ID] = baseData;
end

-- Add a new item type struct.
function bash.Item.RegisterType(itemType)
    if !itemType or !istable(itemType) or 
       !itemType.Static or !itemType.Static.ID then
        bash.Util.MsgErr("MalformedItemType");
        return;
    end

    itemType.Dynamic    = itemType.Dynamic or {};
    itemType.Functions  = itemType.Functions or {};

    bash.Util.MsgDebug(LOG_ITEM, "Registering item type with ID '%s'...", itemType.Static.ID);

    local typeData = {};
    if itemType.Static.Base then
        local base = bash.Item.Bases[itemType.Static.Base];
        if !base then
            bash.Util.MsgErr("InvalidItemBase", itemType.Static.Base);
            return;
        end

        -- Recursive item bases!
        local bases = {};
        local currentBase;
        bases[1] = itemType.Static.Base;
        while base.Static.Base do
            currentBase = bash.Item.Bases[itemType.Static.Base];
            -- Get outta here cyclical dependencies!!!
            if !currentBase or table.HasValue(currentBase.Static.ID) then break; end

            bases[#bases + 1] = currentBase.Static.ID;
        end

        typeData.Static     = {};
        typeData.Dynamic    = {};
        typeData.Functions  = {};

        -- Kinda crappy but whatever.
        for index = #bases, 1, -1 do
            currentBase = bash.Item.Bases[bases[index]];
            if !currentBase then continue; end

            for key, val in pairs(currentBase.Static) do
                typeData.Static[key] = val;
            end
            for key, val in pairs(currentBase.Dynamic) do
                typeData.Dynamic[key] = val;
            end
            for key, val in pairs(currentBase.Functions) do
                typeData.Functions[key] = val;
            end
        end

        for key, val in pairs(itemType.Static) do
            typeData.Static[key] = val;
        end
        for key, val in pairs(itemType.Dynamic) do
            typeData.Dynamic[key] = val;
            end
        for key, val in pairs(itemType.Functions) do
            typeData.Functions[key] = val;
        end
    else
        typeData.Static     = itemType.Static;
        typeData.Dynamic    = itemType.Dynamic;
        typeData.Functions  = itemType.Functions;
        end

    bash.Item.Types[typeData.Static.ID] = typeData;
end

-- Get an item type struct.
function bash.Item.GetType(itemTypeID)
    return bash.Item.Types[itemTypeID];
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

        bash.Util.MsgDebug(LOG_ITEM, "Creating a new item with the ID '%s'...", itemID);

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
        bash.Util.MsgDebug(LOG_ITEM, "Loading item '%s'...", id);

        local loadedFromDB = false;
        local item = tabnet.GetTable(id);
        if !item then
            item = tabnet.GetDBProvider():LoadTable("bash_Item", id);
            loadedFromDB = true;
        end 

        if !item then
            bash.Util.MsgErr("ItemNotFound", id);
            return;
        end

        return item, loadedFromDB;
    end

    -- Unload an item.
    function bash.Item.Unload(itemID)
        local item = tabnet.GetTable(itemID);
        if !item then return; end

        hook.Run("OnItemUnload", item);
        tabnet.DeleteTable(itemID);
    end

    -- Delete an item from the database.
    function bash.Item.Delete(itemID)
        local item = bash.Item.Load(itemID);
        local curEnt = bash.Item.GetActiveEntity(itemID);
        if isent(curEnt) then
            curEnt:DetachItem(true);
            curEnt:Remove();
        end

        hook.Run("OnItemDelete", item);
        tabnet.GetDBProvider().EraseTable(item);
    end 

    -- Move an item between inventories.
    function bash.Item.Move(itemID, newInvID, newPos)
        local item, itemLoaded = bash.Item.Load(itemID);
        if !item then return false; end

        local sourceInvID = item:GetField("Owner");
        local targetInvID = newInvID;

        local targetInv, targetInvLoaded = bash.Inventory.Load(targetInvID);
        if !targetInv then
            if itemLoaded then
                bash.Item.Unload(itemID);
            end

            return false;
        end

        local itemTypeID = item:GetField("ItemType");
        if !bash.Inventory.HasSpace(targetInvID, itemTypeID, newPos) then
            if itemLoaded then
                bash.Item.Unload(itemID);
            end
            if targetInvLoaded then
                bash.Inventory.Unload(targetInvID);
            end

            return false;
        end 

        local result = bash.Inventory.AddItem(targetInvID, itemID, newPos);

        if itemLoaded then
            bash.Item.Unload(itemID);
        end
        if targetInvLoaded then
            bash.Inventory.Unload(targetInvID);
        end

        return result;

        --[[
        local targetInvGrid = bash.Inventory.GetContentGrid(targetInvID);
        local itemAtPosID = targetInvGrid[newPos.x][newPos.y];
        if noSwap and itemAtPosID != 0 and itemAtPosID != itemID then
            if itemLoaded then
                bash.Item.Unload(itemID);
            end
            if targetInvLoaded then
                bash.Inventory.Unload(targetInvID);
            end

            -- TODO: Send error msg.
            MsgN("NO SWAP!")
            return;
        end

        local itemAtPos, itemAtPosLoaded;
        if itemAtPosID != 0 and itemAtPosID != itemID then
            itemAtPos, itemAtPosLoaded = bash.Item.Load(itemAtPosID);
        end

        if itemAtPos then
            local curPos = item:GetField("Position");
            if sourceInvID == targetInvID then
                local grid = bash.Inventory.GetContentGrid(sourceInvID);
                if grid then
                    for xIndex = 1, #grid do
                        for yIndex = 1, #grid[xIndex] do
                            if grid[xIndex][yIndex] == itemID or grid[xIndex][yIndex] == itemAtPosID then
                                grid[xIndex][yIndex] = 0;
                            end
                        end 
                    end 
                end

                local canSwap = true;

                local itemTypeID = item:GetField("ItemType");
                local itemType = bash.Item.GetType(itemTypeID);
                if itemType then 
                    for xIndex = newPos.x, (newPos.x + itemType.Static.SizeX - 1) do
                        if grid[xIndex] == nil then
                            -- TODO: Fit error.
                            canSwap = false;
                            break;
                        end

                        for yIndex = newPos.y, (newPos.y + itemType.Static.SizeY - 1) do
                            if grid[xIndex][yIndex] != 0 then
                                -- TODO: Fit error.
                                canSwap = false;
                                break;
                            end

                            grid[xIndex][yIndex] = itemID;
                        end

                        if !canSwap then break; end 
                    end
                else canSwap = false; end

                local itemAtPosTypeID = itemAtPos:GetField("ItemType");
                local itemAtPosType = bash.Item.GetType(itemAtPosTypeID);
                if canSwap and itemAtPosType then 
                    for xIndex = curPos.x, (curPos.x + itemAtPosType.Static.SizeX - 1) do
                        if grid[xIndex] == nil then
                            -- TODO: Fit error.
                            canSwap = false;
                            break;
                        end

                        for yIndex = curPos.y, (curPos.y + itemAtPosType.Static.SizeY - 1) do
                            if grid[xIndex][yIndex] != 0 then
                                -- TODO: Fit error.
                                canSwap = false;
                                break;
                            end
                        end

                        if !canSwap then break; end
                    end
                else canSwap = false; end

                if canSwap then
                    item:SetFields{
                        ["Owner"] = sourceInvID,
                        ["Position"] = {
                            x = newPos.x,
                            y = newPos.y
                        }
                    };
                    itemAtPos:SetFields{
                        ["Owner"] = sourceInvID,
                        ["Position"] = {
                            x = curPos.x,
                            y = curPos.y
                        }
                    };
                end
            else
                if bash.Inventory.HasSpace(sourceInvID, itemAtPosID, false, curPos, itemID) and
                   bash.Inventory.HasSpace(targetInvID, itemID, false, newPos, itemAtPosID) then
                    bash.Inventory.AddItem(sourceInvID, itemAtPosID, curPos);
                    bash.Inventory.AddItem(targetInvID, itemID, newPos);
                else
                    -- TODO: Error.
                    MsgN("ITEM SWAP ERROR")
                end 
            end 
        else
            if bash.Inventory.HasSpace(targetInvID, itemID, false, newPos) then
                if sourceInvID == targetInvID then
                    item:SetFields{
                        ["Owner"] = sourceInvID,
                        ["Position"] = {
                            x = newPos.x,
                            y = newPos.y
                        }
                    };
                else
                    bash.Inventory.AddItem(targetInvID, itemID, newPos);
                end
            else 
                -- TODO: Error.
                MsgN("MOVE ERROR")
            end
        end 
        ]]
    end

    -- Spawn an item as a world prop.
    function bash.Item.SpawnInWorld(itemID, pos)
        if !pos or !pos.x or !pos.y or !pos.z then return; end
        local item, itemLoaded = bash.Item.Load(itemID);
        if !item then return; end

        local itemTypeID = item:GetField("ItemType", "");
        local itemType = bash.Item.GetType(itemTypeID);
        if !itemType then
            if itemLoaded then
                bash.Item.Unload(itemID);
            end

            return;
        end

        local oldInvID = item:GetField("Owner");
        if oldInvID != "!WORLD!" then
            bash.Inventory.RemoveItem(oldInvID, itemID);
        end

        item:SetFields{
            ["Owner"] = "!WORLD!",
            ["PositionInWorld"] = {
                x = pos.x,
                y = pos.y,
                z = pos.z
            }
        };

        local newItemEnt = ents.Create("prop_physics");
        newItemEnt:SetModel(itemType.Static.WorldModel);
        newItemEnt:SetPos(Vector(pos.x, pos.y, pos.z));
        newItemEnt:Spawn();
        newItemEnt:Activate();
        newItemEnt:AttachItem(item);
    end

    -- Set a field in an item's dynamic data.
    function bash.Item.SetDynamicData(itemID, fieldName, val)
        local item, itemLoaded = bash.Item.Load(itemID);
        if !item then return; end

        local dynamicData = item:GetField("DynamicData", {}, true);
        dynamicData[fieldName] = val;
        item:SetField("DynamicData", dynamicData);

        if SERVER and itemLoaded then
            bash.Item.Unload(itemID);
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

    -- Spawn all world items.
    hook.Add("InitPostEntity", "bash_ItemSpawnInWorld", function()
        bash.Util.MsgDebug(LOG_ITEM, "Spawning world items...");

        tabnet.GetDBProvider():GetTableData(
            "bash_Item",
            {"ItemID", "PositionInWorld"},
            {Field = "Owner", EQ = "!WORLD!"},

            function(data)
                for _, item in pairs(data) do
                    bash.Item.SpawnInWorld(item.ItemID, item.Position);
                end

                bash.Util.MsgDebug(LOG_ITEM, "Spawned %d items in world.", #data);
            end
        );
    end);

    -- Watch for entity removals.
    hook.Add("EntityRemoved", "bash_ItemDeleteOnRemoved", function(ent)
        local item = ent:GetItem();
        if !item then return; end

        local itemID = item:GetField("ItemID");
        tabnet.GetDBProvider():SaveTable(item);
        ent:DetachItem(true);
        bash.Item.Unload(itemID);
    end);

    -- Delete a character's inventories.
    hook.Add("OnInventoryDelete", "bash_ItemDeleteInventory", function(inv)
        local items = inv:GetField("Contents", {});
        for itemID, _ in pairs(items) do
            bash.Item.Delete(itemID);
        end
    end);

    --
    -- Network hooks.
    --

    -- Watch for item move requests.
    vnet.Watch("bash_Net_ItemMoveRequest", function(pck)
        local data = pck:Table();
        -- TODO: Security check.

        -- TODO: Rewrite this shit.
        if data.TargetItemOwner and data.TargetItemPos then
            bash.Item.Move(
                data.DroppedItemID,
                data.TargetItemOwner,
                data.TargetItemPos
            );
        else
            bash.Item.Move(
                data.DroppedItemID,
                (data.DroppedItemOwner == data.TargetOwner and true) or data.TargetOwner,
                data.TargetPos
            );
        end

        --[[
        local droppedItem = tabnet.GetTable(data.DroppedItemID);
        if !droppedItem then return; end
        local droppedItemTypeID = droppedItem:GetField("ItemType", "");
        local droppedItemType = bash.Item.GetType(droppedItemTypeID);
        if !droppedItemType then return; end 

        local currentItem = tabnet.GetTable(data.CurrentItemID);

        if currentItem then

            local currentItemTypeID = currentItem:GetField("ItemType", "");
            local currentItemType = bash.Item.GetType(currentItemTypeID);
            if !currentItemType then return; end 

            MsgN("Combine/swap two items.")
            
            -- TODO: Probably won't end up doing this. Combine only.
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

                if !bash.Inventory.HasSpace(data.DroppedInvID, droppedItemTypeID, true, data.CurrentItemPos) then return; end
                droppedItem:SetField("Position", data.CurrentItemPos);
            else
                -- TODO: See if the item can hold the item.
                --       If so, move.
                MsgN("Move one item to another inventory.");

                local oldInv = tabnet.GetTable(data.DroppedInvID);
                if !oldInv then return; end
                local newInv = tabnet.GetTable(data.CurrentInvID);
                if !newInv then return; end

                if !bash.Inventory.HasSpace(data.CurrentInvID, droppedItemTypeID, true, data.CurrentItemPos) then return; end

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
        ]]
    end, {1});

    -- Watch for item function requests.
    vnet.Watch("bash_Net_ItemFuncRequest", function(pck)
        local requester = pck.Source;
        local data = pck:Table();

        local item = tabnet.GetTable(data.ItemID);
        if !item then return; end 

        local currentInvID = item:GetField("Owner");
        if data.ClientInvID != currentInvID then return; end 

        local itemType = bash.Item.Types[item:GetField("ItemType")];
        if !itemType or !itemType.Functions[data.UseFunc] then return; end

        local func = itemType.Functions[data.UseFunc];
        if !func.RunOnServer then return; end
        
        local item = tabnet.GetTable(data.ItemID);
        func.Run(requester, item, data.SendData);
    end, {1});

elseif CLIENT then

    --
    -- Engine hooks.
    --

    -- Watch for item attaches.
    -- TODO: See if this is necessary.
    hook.Add("OnUpdateTable", "bash_ItemWatchForAttach", function(tab, name, newVal, oldVal)
        if tab._RegistryID != "bash_ItemLookup" then return; end
        if type(name) != "number" then return; end

        local entInd = name;
        local itemID = newVal;
        local ent = ents.GetByIndex(entInd);
        if !isent(ent) then return; end

        local item = tabnet.GetTable(itemID);
        if !item then return; end

        bash.Util.MsgDebug(LOG_ITEM, "Attaching item '%s' to entity '%s'...", itemID, tostring(ent));
        hook.Run("OnItemAttach", item, ent);
    end);

    -- Watch for item detaches.
    -- TODO: See if this is necessary.
    hook.Add("OnClearTable", "bash_ItemWatchForDetach", function(tab, name, val)
        if tab._RegistryID != "bash_ItemLookup" then return; end
        if type(name) != "number" then return; end

        local entInd = name;
        local itemID = val;
        local ent = ents.GetByIndex(name);
        if !isent(ent) then return; end

        local item = tabnet.GetTable(itemID);
        if !item then return; end

        bash.Util.MsgDebug(LOG_ITEM, "Detaching item '%s' from entity '%s'...", itemID, tostring(ent));
        hook.Run("OnItemDetach", item, ent);
    end);

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
        local itemInvID = item:GetField("Owner");
        local itemTypeID = item:GetField("ItemType");
        local itemType = bash.Item.Types[itemTypeID];
        if !itemType then return; end

        local opts = DermaMenu();
        local added = 0;

        for name, func in pairs(itemType.Functions) do 
            if !func.ShowOnUse then continue; end
            if !func.CanShow(item, ent) then continue; end

            opts:AddOption(func.MenuName or name, function()
                if func.RunOnClient then
                    func.Run(LocalPlayer(), item, {});
                else
                    local sendData = (func.GetSendData and func.GetSendData(item)) or {};
                    local sendUse = vnet.CreatePacket("bash_Net_ItemFuncRequest");
                    sendUse:Table({
                        ItemID = itemID,
                        ClientInvID = itemInvID,
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
            opts:Center();
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
        if !tabnet.GetTable("bash_ItemLookup") then
            tabnet.CreateTable(nil, tabnet.LIST_GLOBAL, nil, "bash_ItemLookup");
        end
    end

    bash.Util.ProcessDir("engine/items/bases", false, "SHARED");
    bash.Util.ProcessDir("engine/items/types", false, "SHARED");

    MsgN("BASES");
    PrintTable(bash.Item.Bases);
    MsgN("TYPES");
    PrintTable(bash.Item.Types);

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

    -- Position: Table containing the coordinates of the item in the world.
    tabnet.EditSchemaField{
        SchemaName = "bash_Item",
        FieldName = "PositionInWorld",
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
    bash.Util.ProcessDir("schema/items/bases", false, "SHARED");
    bash.Util.ProcessDir("schema/items/types", false, "SHARED");
end);
