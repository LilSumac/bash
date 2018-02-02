--[[
    Item management functionality.
]]

--
-- Local storage.
--

local bash = bash;

local LOG_ITEM = {pre = "[ITEM]", col = color_limegreen};

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

-- Get an entity's assigned character, if any.
function Entity:GetItem()
    local reg = bash.Item.GetRegistry();
    if !reg then return; end

    local index = self:EntIndex();
    local itemID = reg:Get(index);

    return bash.TableNet.Get(itemID);
end

-- Check if an entity has a certain item attached.
function Entity:IsItem(id)
    return self:GetItem() and self:GetItem():Get("ItemID") == id;
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
function bash.Item.Register(item)
    bash.Util.MsgDebug(LOG_ITEM, "Registering item type with ID '%s'...", item.Static.ID);

    local itemData = {};

    -- Static fields.
    itemData.Static             = item.Static or {};
    itemData.Static.ID          = item.Static.ID or "bash_itemid";
    itemData.Static.Name        = item.Static.Name or "Item";
    itemData.Static.SizeX       = item.Static.SizeX or 1;
    itemData.Static.SizeY       = item.Static.SizeY or 1;
    itemData.Static.CanStack    = item.Static.CanStack or false;
    itemData.Static.MaxStack    = item.Static.MaxStack or 1;

    -- Dynamic fields.
    itemData.Dynamic = item.Dynamic or {};
    itemData.Dynamic.Stack = item.Dynamic.Stack or 1;

    bash.Item.Types[itemData.Static.ID] = itemData;
end

-- Get the item registry.
function bash.Item.GetRegistry()
    return bash.TableNet.Get("bash_ItemRegistry");
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
    function bash.Item.Create(data, forceID, silent)
        -- TODO: This function.
        local itemID = forceID or bash.Item.GetUnusedID();
        data.ItemID = itemID;

        local itemData = {};
        for id, var in pairs(bash.Item.Vars) do
            if !var.InSQL or var.Type == "counter" then continue; end
            itemData[id] = data[id] or handleFunc(var.Default);
        end

        if !bash.Item.Types[itemData.ItemType] then return; end

        data.DynamicData = data.DynamicData or {};
        local dynData = itemData.DynamicData;
        local itemStruct = bash.Item.Types[itemData.ItemType];
        for id, def in pairs(itemStruct.Dynamic) do
            dynData[id] = data.DynamicData[id] or handleFunc(def);
        end

        bash.Util.MsgLog(LOG_ITEM, "Creating a new item with the ID '%s'...", itemID);
        bash.Item.IDs[itemID] = true;

        bash.Database.InsertRow("bash_items", itemData, function(resultsTab)
            local results = resultsTab[1];
            if !results.status then
                bash.Util.MsgErr("ItemCreateFailed", itemID);
                bash.Item.IDs[itemID] = nil;
                return;
            end

            bash.Util.MsgLog(LOG_ITEM, "Successfully created new item '%s'.", itemID);
            if !silent then bash.Item.Load(itemID); end
        end);

        return itemID;
    end

    -- Fetch all data from the database tied to an item ID.
    function bash.Item.Fetch(id)
        bash.Util.MsgDebug(LOG_ITEM, "Fetching item '%s' from database...", id);

        bash.Database.Query(F("SELECT * FROM `bash_items` WHERE ItemID = \'%s\';", id), function(resultsTab)
            local results = resultsTab[1];
            if !results.status then return; end
            if results.affected == 0 then
                bash.Util.MsgErr("ItemNotFound", id);
                return;
            end

            local fetchData, itemData = results.data[1], {};
            if !fetchData then return; end
            for id, var in pairs(bash.Item.Vars) do
                itemData[var.Scope] = itemData[var.Scope] or {};
                itemData[var.Scope][id] = fetchData[id] or handleFunc(var.Default);
            end
            bash.Item.Cache[fetchData.ItemID] = itemData;
            bash.Util.MsgDebug(LOG_ITEM, "Item '%s' fetched from database.", id);

            local wait = bash.Item.Waiting[id];
            if wait then
                bash.Item.Waiting[id] = nil;
                bash.Item.Load(id, wait._ent, false, wait._deleteOld);
            end
        end);
    end

    -- Create a new instance of an item.
    function bash.Item.Load(id, ent, forceFetch, deleteOld)
        -- TODO: Finish this function.
        if !bash.Item.Cache[id] or forceFetch then
            bash.Util.MsgDebug(LOG_ITEM, "Request to load item '%s' is waiting on data.", id);

            bash.Item.Waiting[id] = {
                _ent = ent,
                _deleteOld = deleteOld
            };
            bash.Item.Fetch(id);
            return;
        end

        bash.Util.MsgLog(LOG_ITEM, "Loading item '%s'...", id);

        if !bash.TableNet.IsRegistered(id) then
            local itemData = bash.Item.Cache[id];
            bash.TableNet.NewTable(itemData, nil, id);
        end

        bash.Item.AttachTo(id, ent, deleteOld);
    end

    -- Associate an item with an entity.
    function bash.Item.AttachTo(id, ent, deleteOld)
        if !isent(ent) then return; end
        bash.Item.DetachFrom(ent, deleteOld);

        local reg = bash.Item.GetRegistry();
        local index = ent:EntIndex();
        local oldIndex = reg:Get(id);
        local oldOwner = (oldIndex and ents.GetByIndex(oldIndex)) or nil;
        bash.Item.DetachFrom(oldOwner, false);

        bash.Util.MsgLog(LOG_ITEM, "Attaching item '%s' to entity '%s'...", id, tostring(ent));

        -- Add both for two-way lookup.
        reg:SetData{
            Public = {
                [index] = id,
                [id] = index
            }
        };

        local item = bash.TableNet.Get(id);
        hook.Run("OnItemAttach", item, ent);
    end

    -- Disassociate an item from an entity.
    function bash.Item.DetachFrom(ent, delete)
        if !isent(ent) then return; end
        if !ent:GetItem() then return; end

        local reg = bash.Item.GetRegistry();
        local item = ent:GetItem();
        local itemID = item:Get("ItemID");
        local index = ent:EntIndex();
        bash.Util.MsgLog(LOG_ITEM, "Detaching item '%s' from entity '%s'...", itemID, tostring(ent));

        reg:Delete(index, itemID);
        hook.Run("OnItemDetach", item, ent);

        if delete then
            bash.TableNet.DeleteTable(itemID);
        end
    end

    --
    -- Engine hooks.
    --

    -- Fetch all used IDs.
    hook.Add("OnDatabaseConnected", "bash_ItemFetchIDs", function()
        bash.Util.MsgDebug(LOG_ITEM, "Fetching used ItemIDs...");

        bash.Database.Query("SELECT ItemID FROM `bash_items`;", function(resultsTab)
            local results = resultsTab[1];
            if !results.status then return; end

            local index = 0;
            for _, tab in pairs(results.data) do
                bash.Item.IDs[tab.ItemID] = true;
                index = index + 1;
            end

            bash.Util.MsgDebug(LOG_ITEM, "Fetched %d ItemIDs from the database.", index);
        end);
    end);

    -- Push changes to SQL.
    hook.Add("TableUpdate", "bash_ItemPushToDatabase", function(regID, data)
        local item = bash.TableNet.Get(regID);
        if !item then return; end
        local itemID = item:Get("ItemID");
        if !itemID then return; end
        MsgN("ITEM UPDATE");

        local sqlData, var = {};
        for id, val in pairs(data) do
            var = bash.Item.Vars[id];
            if !var or !var.InSQL then continue; end
            sqlData[id] = val;
        end
        PrintTable(sqlData);

        if table.IsEmpty(sqlData) then return; end
        bash.Database.UpdateRow("bash_items", sqlData, F("ItemID = \'%s\'", itemID), function(results)
            bash.Util.MsgDebug(LOG_ITEM, "Updated item '%s' in database.", itemID);
        end);
    end);

    --
    -- Network hooks.
    --

    -- Watch for item move requests.
    vnet.Watch("bash_Net_ItemMoveRequest", function(pck)
        -- TODO: Clean this up.
        local droppedItemID = pck:String();
        local currentItemID = pck:String();
        local droppedInvID = pck:String();
        local currentInvID = pck:String();
        local droppedItemPos = pck:Table();
        local currentItemPos = pck:Table();

        local droppedItem = bash.TableNet.Get(droppedItemID);
        if !droppedItem then return; end
        local currentItem = bash.TableNet.Get(currentItemID);

        if currentItem then
            -- TODO: Try to combine, else swap.
            MsgN("Combine/swap two items.")

            if droppedInvID != currentInvID then
                -- Change owners and swap.
                local oldInv = bash.TableNet.Get(droppedInvID);
                if !oldInv then return; end
                local newInv = bash.TableNet.Get(currentInvID);
                if !newInv then return; end

                local oldContents = oldInv:Get("Contents", {});
                oldContents[droppedItemID] = nil;
                oldContents[currentItemID] = true;
                oldInv:Set("Contents", oldContents);

                local newContents = newInv:Get("Contents", {});
                newContents[droppedItemID] = true;
                newContents[currentItemID] = nil;
                newInv:Set("Contents", newContents);

                droppedItem:SetData{
                    Public = {
                        ["Owner"] = currentInvID,
                        ["PosInInv"] = currentItemPos
                    }
                };
                currentItem:SetData{
                    Public = {
                        ["Owner"] = droppedInvID,
                        ["PosInInv"] = droppedItemPos
                    }
                };
            else
                droppedItem:Set("PosInInv", currentItemPos);
                currentItem:Set("PosInInv", droppedItemPos);
            end
        else
            if droppedInvID == currentInvID then
                -- TODO: Just move the item.
                MsgN("Move one item to empty spot.");
                droppedItem:Set("PosInInv", currentItemPos);
            else
                -- TODO: See if the item can hold the item.
                --       If so, move.
                MsgN("Move one item to another inventory.");

                local oldInv = bash.TableNet.Get(droppedInvID);
                if !oldInv then return; end
                local newInv = bash.TableNet.Get(currentInvID);
                if !newInv then return; end

                local oldContents = oldInv:Get("Contents", {});
                oldContents[droppedItemID] = nil;
                oldInv:Set("Contents", oldContents);

                local newContents = newInv:Get("Contents", {});
                newContents[droppedItemID] = true;
                newInv:Set("Contents", newContents);

                droppedItem:SetData{
                    Public = {
                        ["Owner"] = currentInvID,
                        ["PosInInv"] = currentItemPos
                    }
                };
            end
        end
    end);

end

--
-- Engine hooks.
--

-- Create item structures.
hook.Add("CreateStructures_Engine", "bash_ItemStructures", function()
    bash.Util.ProcessDir("engine/items", false, "SHARED");

    bash.Item.AddVar{
        ID = "ItemNum",
        Type = "counter",
        Default = -1,
        Scope = NET_PUBLIC,
        InSQL = true,
        PrimaryKey = true
    };
    bash.Item.AddVar{
        ID = "ItemID",
        Type = "string",
        Default = "",
        Scope = NET_PUBLIC,
        InSQL = true,
        MaxLength = 17
    };
    bash.Item.AddVar{
        ID = "ItemType",
        Type = "string",
        Default = "",
        Scope = NET_PUBLIC,
        InSQL = true,
        MaxLength = 64
    };
    bash.Item.AddVar{
        ID = "Owner",
        Type = "string",
        Default = "",
        Scope = NET_PUBLIC,
        InSQL = true,
        MaxLength = 64
    };
    bash.Item.AddVar{
        ID = "PosInInv",
        Type = "table",
        Default = EMPTY_TABLE,
        Scope = NET_PUBLIC,
        InSQL = true,
        MaxLength = 64
    };
    bash.Item.AddVar{
        ID = "PosInWorld",
        Type = "table",
        Default = EMPTY_TABLE,
        Scope = NET_PUBLIC,
        InSQL = true,
        MaxLength = 64
    };
    bash.Item.AddVar{
        ID = "DynamicData",
        Type = "table",
        Default = EMPTY_TABLE,
        Scope = NET_PUBLIC,
        InSQL = true,
        MaxLength = 512
    };
end);

-- Register inventory types (schema).
hook.Add("CreateStructures", "bash_ItemRegisterTypes", function()
    bash.Util.ProcessDir("schema/items", false, "SHARED");
end);
