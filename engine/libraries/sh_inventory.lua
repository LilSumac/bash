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
bash.Inventory.Cache    = bash.Inventory.Cache or {};
bash.Inventory.Waiting  = bash.Inventory.Waiting or {};
bash.Inventory.Viewing  = (CLIENT and (bash.Inventory.Viewing or {})) or nil;

--
-- Inventory functions.
--

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

        bash.Database.Query(F("SELECT * FROM `bash_invs` WHERE InvID = \'%s\'; SELECT * FROM `bash_items` WHERE InvID = \'%s\';", id, id), function(resultsTab)
            PrintTable(resultsTab);
            local invResults = resultsTab[1];
            if !invResults.status then return; end
            local itemResults = resultsTab[2];
            if !itemResults.status then return; end

            local invData = invResults.data[1];
            bash.Database.CastData("bash_invs", invData, CAST_OUT);
            bash.Inventory.Cache[invData.InvID] = invData;

            for _, itemData in pairs(itemResults.data) do
                bash.Database.CastData("bash_items", itemData, CAST_OUT);
                bash.Item.Cache[itemData.ItemID] = itemData;
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
        for itemID, _ in pairs(invData.Contents) do
            bash.Item.Load(itemID);
        end

        if !bash.TableNet.IsRegistered(id) then
            bash.TableNet.NewTable(invData, nil, invData.InvID);
        end
    end

    -- Associate an inventory with an entity.
    function bash.Inventory.AttachTo(id, invType, ent)
        if !isent(ent) and !isplayer(ent) then return; end

        if invType == INV_CHAR then

        elseif invType == INV_ITEM then

        elseif invType == INV_STORE then

        end


        --[[
        bash.Inventory.DetachFrom(ent, deleteOld);

        local reg = bash.Character.GetRegistry();
        local index = ent:EntIndex();
        local oldIndex = reg:Get(id);
        local oldOwner = (oldIndex and ents.GetByIndex(oldIndex)) or nil;
        bash.Character.DetachFrom(oldOwner, false);

        bash.Util.MsgDebug(LOG_CHAR, "Attaching character '%s' to entity '%s'...", id, tostring(ent));
        -- Add both for two-way lookup.
        reg:SetData{
            Public = {
                [index] = id,
                [id] = index
            }
        };

        local char = bash.TableNet.Get(id);
        char:AddListener(ent, NET_PRIVATE);
        hook.Run("OnCharacterAttach", char, ent);
        ]]
    end

end
