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
bash.Item.Cache     = bash.Item.Cache or {};
bash.Item.Waiting   = bash.Item.Waiting or {};

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

if SERVER then

    -- Fetch all data from the database tied to an item ID.
    function bash.Item.Fetch(id)
        bash.Util.MsgDebug(LOG_ITEM, "Fetching item '%s' from database...", id);

        bash.Database.Query(F("SELECT * FROM `bash_items` WHERE ItemID = \'%s\';", id), function(resultsTab)
            local results = resultsTab[1];
            if !results.status then return; end

            local fetchData, itemData = results.data[1], {};
            if !fetchData then return; end
            for id, var in pairs(bash.Item.Vars) do
                itemData[var.Scope] = itemData[var.Scope] or {};
                itemData[var.Scope][id] = fetchData[id] or handleFunc(var.Default);
            end
            bash.Item.Cache[fetchData.ItemID] = itemData;
            bash.Util.MsgDebug(LOG_ITEM, "Item '%s' fetched from database.", id);

            if bash.Item.Waiting[id] then
                bash.Item.Waiting[id] = nil;
                bash.Item.Load(id);
            end
        end);
    end

    -- Create a new instance of an item.
    function bash.Item.Load(id, forceFetch)
        -- TODO: Finish this function.
        if !bash.Item.Cache[id] or forceFetch then
            bash.Util.MsgDebug(LOG_ITEM, "Request to load item '%s' is waiting on data.", id);

            bash.Item.Waiting[id] = true;
            bash.Item.Fetch(id);
            return;
        end

        bash.Util.MsgLog(LOG_ITEM, "Loading item '%s'...", id);

        if !bash.TableNet.IsRegistered(id) then
            local itemData = bash.Item.Cache[id];
            bash.TableNet.NewTable(itemData, nil, id);
        end
    end

    --
    -- Engine hooks.
    --

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

            if droppedInv == currentInvID then
                -- Same inv.
            else
                -- Different inv.
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
        ID = "Owner",
        Type = "string",
        Default = "",
        Scope = NET_PUBLIC,
        InSQL = true,
        MaxLength = 32
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
end);
