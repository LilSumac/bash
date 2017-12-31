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
bash.Item.Cache     = bash.Item.Cache or {};
bash.Item.Waiting   = bash.Item.Waiting or {};

--
-- Item functions.
--

if SERVER then

    -- Fetch all data from the database tied to an item ID.
    function bash.Item.Fetch(id)
        bash.Util.MsgDebug(LOG_ITEM, "Fetching item '%s' from database...", id);

        bash.Database.Query(F("SELECT * FROM `bash_items` WHERE ItemID = \'%s\';", id), function(resultsTab)
            local results = resultsTab[1];
            if !results.status then return; end

            local fetchData = results.data[1];
            bash.Item.Cache[fetchData.ItemID] = fetchData;
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
            bash.TableNet.NewTable(itemData, nil, itemData.ItemID);
        end
    end

end
