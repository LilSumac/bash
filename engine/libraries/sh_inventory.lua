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
bash.Inventory.Vars     = bash.Inventory.Vars or {};
bash.Inventory.Types    = bash.Inventory.Types or {};
bash.Inventory.Cache    = bash.Inventory.Cache or {};
bash.Inventory.Waiting  = bash.Inventory.Waiting or {};
bash.Inventory.Viewing  = (CLIENT and (bash.Inventory.Viewing or {})) or nil;

--
-- Inventory functions.
--

-- Add a new inventory variable struct.
function bash.Inventory.AddVar(data)
    bash.Inventory.Vars[data.ID] = {
        ID = data.ID,
        Type = data.Type,
        Default = data.Default,
        Scope = data.Scope,
        InSQL = data.InSQL
    };

    if SERVER and data.InSQL then
        bash.Database.AddColumn("bash_invs", {
            Name = data.ID,
            Type = data.Type,
            MaxLength = data.MaxLength
        }, data.PrimaryKey);
    end
end

-- Add a new inventory type struct.
function bash.Inventory.AddType(id, name, x, y)
    bash.Inventory.Types[id] = {
        ID = id,
        Name = name,
        SizeX = x,
        SizeY = y
    };
end

-- Get the inventory registry.
function bash.Inventory.GetRegistry()
    return bash.TableNet.Get("bash_InvRegistry");
end

-- Checks to see if an inventory contains an item in a certain quantity.
function bash.Inventory.HasItem(invID, id, amount)
    amount = amount or 1;
    if !bash.TableNet.Registered(invID) then return; end

    local inv = bash.TableNet.Get(invID);
    local invContStr = inv:Get("Contents", PON_EMPTY);
    local invCont = pon.decode(invContStr);

    local count, curItem = 0;
    for itemID, _ in pairs(invCont) do
        curItem = bash.TableNet.Get(itemID);
        -- TODO: Remove invalid items?
        if !curItem then continue; end
        if curItem:Get("ItemID") != id then continue; end

        count = count + curItem:Get("Stack");
        if count >= amount then return true; end
    end

    return false;
end

-- Checks to see if an inventory contains a unique item.
function bash.Inventory.HasUniqueItem(invID, id)

end

if SERVER then

    -- Fetch all data from the database tied to an inventory ID.
    function bash.Inventory.Fetch(id)
        bash.Util.MsgDebug(LOG_INV, "Fetching inventory '%s' and related items from database...", id);

        bash.Database.Query(F("SELECT * FROM `bash_invs` WHERE InvID = \'%s\'; SELECT * FROM `bash_items` WHERE Owner = \'%s\';", id, id), function(resultsTab)
            local invResults = resultsTab[1];
            if !invResults.status then return; end
            local itemResults = resultsTab[2];
            if !itemResults.status then return; end

            local invFetchData, invData = invResults.data[1], {};
            if invFetchData then
                bash.Database.CastData("bash_invs", invFetchData, CAST_OUT);
                for id, var in pairs(bash.Inventory.Vars) do
                    invData[var.Scope] = invData[var.Scope] or {};
                    invData[var.Scope][id] = invFetchData[id] or handleFunc(var.Default);
                end
                bash.Inventory.Cache[invFetchData.InvID] = invData;
            end

            local itemData;
            for _, itemFetchData in pairs(itemResults.data) do
                itemData = {};
                bash.Database.CastData("bash_items", itemFetchData, CAST_OUT);
                for id, var in pairs(bash.Item.Vars) do
                    itemData[var.Scope] = itemData[var.Scope] or {};
                    itemData[var.Scope][id] = itemFetchData[id] or handleFunc(var.Default);
                end
                bash.Item.Cache[itemFetchData.ItemID] = itemData;
            end

            bash.Util.MsgDebug(LOG_INV, "Inventory '%s' and %d items fetched from database.", id, #itemResults.data);

            if bash.Inventory.Waiting[id] then
                bash.Inventory.Waiting[id] = nil;
                bash.Inventory.Load(id);
            end
        end);
    end

    -- Create a new instance of an inventory.
    function bash.Inventory.Load(id)
        -- TODO: Finish this function.
        if !bash.Inventory.Cache[id] then
            bash.Util.MsgDebug(LOG_INV, "Request to load inventory '%s' is waiting on data.", id);

            bash.Inventory.Waiting[id] = true;
            bash.Inventory.Fetch(id);
            return;
        end

        bash.Util.MsgLog(LOG_INV, "Loading inventory '%s'...", id);

        local invData = bash.Inventory.Cache[id];
        if !bash.TableNet.IsRegistered(id) then
            bash.TableNet.NewTable(invData, nil, id);
        end

        bash.Inventory.LoadContents(id);
        bash.Inventory.AttachTo(id, invData.Public.Owner);
    end

    -- Create all containing items in an inventory.
    function bash.Inventory.LoadContents(id)
        local inv = bash.TableNet.Get(id);
        if !inv then return; end

        for itemID, _ in pairs(inv:Get("Contents", {})) do
            bash.Item.Load(itemID);
        end
    end

    -- Add an item to an inventory.
    function bash.Inventory.AddItem(invID, itemID)
        -- TODO: Handle non-registered inventories.
        if !bash.TableNet.IsRegistered(invID) then return; end
        if !bash.TableNet.IsRegistered(itemID) then return; end

        local inv = bash.TableNet.Get(invID);
        local item = bash.TableNet.Get(itemID);
        local contents = inv:Get("Contents", {});
        local oldInvID = item:Get("Owner");

        contents[itemID] = true;
        inv:Set("Contents", contents);
        item:Set("Owner", invID);
        bash.Util.MsgDebug(LOG_INV, "Adding item '%s' to inventory '%s'.", itemID, invID);

        local ply = bash.Inventory.GetPlayerOwner(invID);
        item:AddListener(ply, NET_PUBLIC);

        if invID != oldInvID then
            local oldInv = bash.TableNet.Get(oldInvID);
            if !oldInv then return; end
            local oldContents = oldInv:Get("Contents", {});

            oldContents[itemID] = nil;
            oldInv:Set("Contents", oldContents);
            --bash.Inventory.RemoveItem(oldInvID, itemID);
        end
    end

    -- Remove an item from an inventory.
    function bash.Inventory.RemoveItem(invID, itemID)
        -- TODO: Handle non-registered inventories.
        if !bash.TableNet.IsRegistered(invID) then return; end
        if !bash.TableNet.IsRegistered(itemID) then return; end

        local inv = bash.TableNet.Get(invID);
        local item = bash.TableNet.Get(itemID);
        local contents = inv:Get("Contents", {});
        contents[itemID] = nil;
        inv:Set("Contents", contents);
        item:Set("Owner", "");

        local ply = bash.Inventory.GetPlayerOwner(invID);
        item:RemoveListener(ply, NET_PUBLIC);

        bash.Util.MsgDebug(LOG_INV, "Removing item '%s' from inventory '%s'.", itemID, invID);
    end

    -- Get an inventory's player owner, if any.
    function bash.Inventory.GetPlayerOwner(id)
        local inv = bash.TableNet.Get(id);
        if !inv then return; end

        local ownerID = inv:Get("Owner");
        if ownerID:sub(1, 5) != "char_" then return; end

        local reg = bash.Character.GetRegistry();
        local curUser = reg:Get(ownerID);
        local ent = (curUser and ents.GetByIndex(curUser)) or nil;
        return ent;
    end

    -- Associate an inventory with the given owner.
    function bash.Inventory.AttachTo(id, ownerID)
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
        elseif invType == INV_ITEM then

        elseif invType == INV_STORE then
            -- TODO: Link to storage entity.
        end
    end

    -- Dissociate an inventory associated with an entity.
    function bash.Inventory.DetachFrom(id, ent)
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
        elseif isent(ent) then
            -- TODO: Remove link to storage entity/item.
        end
    end

    --
    -- Engine hooks.
    --

    -- Attach a character's inventory to owner.
    hook.Add("OnCharacterAttach", "bash_InventoryAttachChar", function(char, ent)
        local invs = char:Get("Inventory", {});
        for slot, inv in pairs(invs) do
            bash.Inventory.Load(inv);
        end
    end);

    -- Detach a character's inventory from owner.
    hook.Add("OnCharacterDetach", "bash_InventoryDetachChar", function(char, ent)
        local invs = char:Get("Inventory", {});
        for slot, inv in pairs(invs) do
            bash.Inventory.DetachFrom(inv, ent);
        end
    end);

    -- Push changes to SQL.
    hook.Add("TableUpdate", "bash_InventoryPushToDatabase", function(regID, data)
        local inv = bash.TableNet.Get(regID);
        if !inv then return; end
        local invID = inv:Get("InvID");
        if !invID then return; end
        MsgN("INV UPDATE");

        local sqlData, var = {};
        for id, val in pairs(data) do
            var = bash.Inventory.Vars[id];
            if !var or !var.InSQL then continue; end
            sqlData[id] = val;
        end
        PrintTable(sqlData);

        if table.IsEmpty(sqlData) then return; end
        bash.Database.UpdateRow("bash_invs", sqlData, F("InvID = \'%s\'", invID), function(results)
            bash.Util.MsgDebug(LOG_INV, "Updated inventory '%s' in database.", invID);
        end);
    end);

    -- Delete a character's inventory and items on character removal/unload.
    hook.Add("TableDelete", "bash_InventoryRemoveChar", function(id, tab)
        local charID = tab:Get("CharID");
        if !charID then return; end

        local invs = tab:Get("Inventory", {});
        local curInv, contents, curItem;
        for slot, invID in pairs(invs) do
            curInv = bash.TableNet.Get(invID);
            if !curInv then continue; end
            -- TODO: Figure out why this would ever be a thing.
            if curInv:Get("Owner", "") != charID then continue; end

            contents = curInv:Get("Contents", {});
            for itemID, _ in pairs(contents) do
                curItem = bash.TableNet.Get(itemID);
                if !curItem then continue; end

                if curItem:Get("Owner", "") == invID then
                    bash.TableNet.DeleteTable(itemID);
                end
            end

            bash.TableNet.DeleteTable(invID);
        end
    end);

end

--
-- Engine hooks.
--

-- Create character structures.
hook.Add("CreateStructures_Engine", "bash_InventoryStructures", function()
    if SERVER then
        if !bash.TableNet.IsRegistered("bash_InvRegistry") then
            bash.TableNet.NewTable(nil, NET_GLOBAL, "bash_InvRegistry");
        end
    end

    bash.Inventory.AddType("invtype_basic", "Basic", 5, 5);

    bash.Inventory.AddVar{
        ID = "InvNum",
        Type = "counter",
        Default = -1,
        Scope = NET_PUBLIC,
        InSQL = true,
        PrimaryKey = true
    };
    bash.Inventory.AddVar{
        ID = "InvID",
        Type = "string",
        Default = "INVID",
        Scope = NET_PUBLIC,
        InSQL = true,
        MaxLength = 16
    };
    bash.Inventory.AddVar{
        ID = "InvType",
        Type = "string",
        Default = "invtype_basic",
        Scope = NET_PUBLIC,
        InSQL = true,
        MaxLength = 32
    };
    bash.Inventory.AddVar{
        ID = "Contents",
        Type = "table",
        Default = EMPTY_TABLE,
        Scope = NET_PUBLIC,
        InSQL = true
    };
    bash.Inventory.AddVar{
        ID = "Owner",
        Type = "string",
        Default = "",
        Scope = NET_PUBLIC,
        InSQL = true
    };
    bash.Inventory.AddVar{
        ID = "Spaces",
        Type = "table",
        Default = EMPTY_TABLE,
        Scope = NET_PUBLIC
    };
end);
