--[[
    Character management functionality.
]]

--
-- Local storage.
--

local bash = bash;

local LOG_CHAR = {pre = "[CHAR]", col = color_limegreen};

local Entity = FindMetaTable("Entity");
local Player = FindMetaTable("Player");

--
-- Global storage.
--

bash.Character              = bash.Character or {};
bash.Character.IDs          = bash.Character.IDs or {};
bash.Character.Digest       = (CLIENT and (bash.Character.Digest or {})) or nil;

--
-- Entity functions.
--

-- Get an entity's associated character, if any.
function Entity:GetCharacter()
    if !isent(self) and !isplayer(self) then return; end
    
    local lookup = bash.Character.GetLookup();
    if !lookup then return; end

    local entInd = self:EntIndex();
    local charID = lookup:GetField(entInd);
    return tabnet.GetTable(charID);
end
Player.GetCharacter = Entity.GetCharacter;

-- Check if an entity has a character associated with it.
function Entity:IsCharacter()
    return self:GetCharacter() != nil;
end
Player.IsCharacter = Entity.IsCharacter;

-- Check if an entity has a certain character associated with it.
function Entity:IsSpecificCharacter(charID)
    return self:IsCharacter() and self:GetCharacter():GetField("CharID") == charID;
end
Player.IsSpecificCharacter = Entity.IsSpecificCharacter;

if SERVER then

    -- Attach a character to an entity.
    function Entity:AttachCharacter(char)
        if !char or !char:GetField("CharID") then return; end 
        if !isent(self) and !isplayer(self) then return; end

        self:DetachCharacter();

        local id = char:GetField("CharID");
        local lookup = bash.Character.GetLookup();
        local index = self:EntIndex();
        local oldIndex = lookup:GetField(id);
        local oldOwner = (oldIndex and ents.GetByIndex(oldIndex)) or nil;

        if isent(oldOwner) or isplayer(oldOwner) then oldOwner:DetachCharacter(true); end

        bash.Util.MsgDebug(LOG_CHAR, "Attaching character '%s' to entity '%s'...", id, tostring(self));

        char:ClearListeners(tabnet.SCOPE_PRIVATE);
        char:AddListener(self, tabnet.SCOPE_PRIVATE);
        char:SetGlobal(true);
        lookup:SetFields{
            [id] = index,
            [index] = id
        };
        hook.Run("OnCharacterAttach", char, self);
    end
    Player.AttachCharacter = Entity.AttachCharacter;


    -- Detach an entity from its current character.
    function Entity:DetachCharacter(keep)
        if !isent(self) and !isplayer(self) then return; end
        if !self:IsCharacter() then return; end

        local lookup = bash.Character.GetLookup();
        local char = self:GetCharacter();
        local id = char:GetField("CharID");
        local index = self:EntIndex();

        bash.Util.MsgDebug(LOG_CHAR, "Detaching character '%s' from entity '%s'...", id, tostring(self));

        lookup:ClearField(id, index);
        char:RemoveListener(self, tabnet.SCOPE_PRIVATE);
        hook.Run("OnCharacterDetach", char, self);

        if !keep then tabnet.DeleteTable(id); end
    end 
    Player.DetachCharacter = Entity.DetachCharacter;

end

--
-- Character functions.
--

-- Get the character lookup table.
function bash.Character.GetLookup()
    return tabnet.GetTable("bash_CharLookup");
end

-- Get an entity who is associated with a certain character.
function bash.Character.GetActiveEntity(charID)
    local lookup = bash.Character.GetLookup();
    if !lookup then return; end

    local curEnt = lookup:GetField(charID);
    local ent = (curEnt and ents.GetByIndex(curEnt)) or nil;
    return ent;
end

-- Check to see if a character is currently associated with an entity.
function bash.Character.HasActiveEntity(charID)
    return bash.Character.GetActiveEntity(charID) != nil;
end

-- Check to see if a character has a certain item equipped.
function bash.Character.HasSpecificEquipment(charID, itemID)
    local char, charLoaded;
    if CLIENT then
        char = tabnet.GetTable(charID);
    elseif SERVER then
        char, charLoaded = bash.Character.Load(charID);
    end

    if !char then return; end

    local equip = char:GetField("Equipment", {});
    local hasEquip = (equip[itemID] != nil);

    if SERVER and charLoaded then
        bash.Character.Unload(charID);
    end

    return hasEquip;
end

-- Check to see if a character has an item equipped with a specific type.
function bash.Character.HasEquipmentType(charID, itemTypeID)
    local char, charLoaded;
    if CLIENT then
        char = tabnet.GetTable(charID);
    elseif SERVER then
        char, charLoaded = bash.Character.Load(charID);
    end

    if !char then return; end

    local equip = char:GetField("Equipment", {});
    local item, itemLoaded, hasType;
    for slot, itemID in pairs(equip) do
        if CLIENT then
            item = tabnet.GetTable(itemID);
        elseif SERVER then
            item, itemLoaded = bash.Item.Load(itemID);
        end

        if !item then continue; end

        hasType = (item:GetField("ItemType") == itemTypeID);

        if SERVER and itemLoaded then
            bash.Item.Unload(itemID);
        end

        if hasType then return true, itemID; end 
    end

    if SERVER and charLoaded then
        bash.Character.Unload(charID);
    end

    return false;
end 

-- Check to see if a character possesses a specific inventory.
function bash.Character.HasSpecificInventory(charID, invID)
    local char, charLoaded;
    if CLIENT then
        char = tabnet.GetTable(charID);
    elseif SERVER then
        char, charLoaded = bash.Character.Load(charID);
    end

    if !char then return; end

    local invs = char:GetField("Inventory", {});
    local hasInv = (invs[invID] != nil);

    if SERVER and charLoaded then
        bash.Character.Unload(charID);
    end

    return hasInv;
end

-- Check to see if a character possesses an inventory with a specific type.
function bash.Character.HasInventoryType(charID, invTypeID)
    local char, charLoaded;
    if CLIENT then
        char = tabnet.GetTable(charID);
    elseif SERVER then
        char, charLoaded = bash.Character.Load(charID);
    end

    if !char then return; end

    local invs = char:GetField("Inventory", {});
    local inv, invLoaded, hasType;
    for slot, invID in pairs(invs) do
        if CLIENT then
            inv = tabnet.GetTable(invID);
        elseif SERVER then
            inv, invLoaded = bash.Inventory.Load(invID);
        end

        if !inv then continue; end

        hasType = (inv:GetField("InvType") == invTypeID);

        if SERVER and invLoaded then
            bash.Inventory.Unload(invID);
        end

        if hasType then return true, invID; end 
    end

    if SERVER and charLoaded then
        bash.Character.Unload(charID);
    end

    return hasInv;
end 

-- Check to see if a character possesses a certain item.
function bash.Character.HasSpecificItem(charID, itemID)
    local char, charLoaded;
    if CLIENT then
        char = tabnet.GetTable(charID);
    elseif SERVER then
        char, charLoaded = bash.Character.Load(charID);
    end

    if !char then return; end

    local invs = char:GetField("Inventory", {});
    for slot, invID in pairs(invs) do
        if bash.Inventory.HasSpecificItem(invID, itemID) then
            if SERVER and charLoaded then
                bash.Character.Unload(charID);
            end

            return true;
        end 
    end 

    if SERVER and charLoaded then
        bash.Character.Unload(charID);
    end

    return false;
end

-- Check to see if a character possesses an item with a specific type.
function bash.Character.HasItemType(charID, itemTypeID, amount)
    local char, charLoaded;
    if CLIENT then
        char = tabnet.GetTable(charID);
    elseif SERVER then
        char, charLoaded = bash.Character.Load(charID);
    end

    if !char then return; end

    local invs = char:GetField("Inventory", {});
    local hasType, itemFound;
    for slot, invID in pairs(invs) do
        hasType, itemFound = bash.Inventory.HasItemType(invID, itemTypeID, amount);
        if hasType then
            if SERVER and charLoaded then
                bash.Character.Unload(charID);
            end

            return true, itemFound;
        end 
    end 

    if SERVER and charLoaded then
        bash.Character.Unload(charID);
    end

    return false;
end 

if SERVER then

    -- Get a small summary of character data for a player.
    function bash.Character.GetDigest(ply)
        if !isplayer(ply) then return; end

        bash.Util.MsgDebug(LOG_CHAR, "Fetching character digest for '%s' from database...", ply:Name());

        tabnet.GetDBProvider():GetTableData(
            "bash_Character",
            {"CharID", "Name"},
            {Field = "Owner", EQ = ply:SteamID()},

            function(data)
                local sendDigest = vnet.CreatePacket("bash_Net_CharacterDigestReturn");
                sendDigest:Table(data);
                sendDigest:AddTargets(ply);
                sendDigest:Send();
            end
        );
    end

    -- Get an ununused CharID.
    function bash.Character.GetUnusedID()
        local id;
        repeat
            id = string.random(12, CHAR_ALPHANUM, "char_");
        until !bash.Character.IDs[id];
        return id;
    end

    -- Create a new character from scratch.
    function bash.Character.Create(data, forceID, loadOnCreate)
        local charDefaults = tabnet.GetSchemaDefaults("bash_Character");
        for fieldName, def in pairs(charDefaults) do
            if data[fieldName] == nil then
                data[fieldName] = def;
            end 
        end 

        local charID = forceID or bash.Character.GetUnusedID();
        bash.Character.IDs[charID] = true;
        data.CharID = charID;

        bash.Util.MsgLog(LOG_CHAR, "Creating a new character with the ID '%s' and name '%s'...", charID, data.Name);

        local newChar = tabnet.GetDBProvider():CreateTable("bash_Character", data, true);
        if !newChar then
            bash.Util.MsgErr("CharCreateFailed", charID);
            bash.Character.IDs[charID] = nil;
            return;
        end

        hook.Run("OnCharacterCreate", newChar);
        if !table.IsEmpty(newChar:GetField("Inventory", {})) then
            hook.Run("NewCharacterInventory", newChar);
        end 

        if isent(loadOnCreate) or isplayer(loadOnCreate) then
            local newChar = bash.Character.Load(charID, loadOnCreate);
            loadOnCreate:AttachCharacter(newChar);
        else tabnet.DeleteTable(charID); end
    end

    -- Load a character from the database.
    function bash.Character.Load(charID)
        bash.Util.MsgDebug(LOG_CHAR, "Loading character '%s'...", charID);

        local loadedFromDB = false;
        local char = tabnet.GetTable(charID);
        if !char then
            char = tabnet.GetDBProvider():LoadTable("bash_Character", charID, tabnet.LIST_GLOBAL);
            loadedFromDB = true;
        end 

        if !char then
            bash.Util.MsgErr("CharNotFound", charID);
            return;
        end

        return char, loadedFromDB;
    end

    -- Unload a character.
    function bash.Character.Unload(charID)
        local char = tabnet.GetTable(charID);
        if !char then return; end

        hook.Run("OnCharacterUnload", char);
        tabnet.DeleteTable(charID);
    end

    -- Delete a character from the database.
    function bash.Character.Delete(charID)
        local char = bash.Character.Load(charID);
        local curUser = bash.Character.GetActiveEntity(charID);
        if isent(curUser) or isplayer(curUser) then
            curUser:DetachCharacter(true);
            if !isplayer(curUser) then curUser:Remove(); end
        end

        bash.Util.MsgLog(LOG_CHAR, "Deleting character with ID '%s'...", charID);

        hook.Run("OnCharacterDelete", char);
        tabnet.GetDBProvider().EraseTable(char);
    end

    -- Attach a character to it's registered owner, if available.
    function bash.Character.AttachToOwner(charID, forceOwner)
        local char = bash.Character.Load(charID);
        if !char then return; end
        
        local owner = forceOwner;
        if !owner then
            local ownerID = char:GetField("Owner");
            if !ownerID then
                bash.Util.MsgErr("CharNoOwnerSet", charID);
                bash.Character.Unload(charID);
                return;
            end

            owner = player.GetBySteamID(ownerID);
            -- TODO: Add NPC functionality.
            if !owner then
                bash.Util.MsgErr("CharNoOwnerAvailable", id);
                bash.Character.Unload(charID);
                return;
            end 
        end

        owner:AttachCharacter(char);
    end

    -- Equip a character with an item.
    function bash.Character.EquipItem(charID, itemID, slot)
        -- TODO: This func.
    end

    -- Unequip an item from a character by ItemID.
    function bash.Character.UnequipItemByID(charID, itemID)
        -- TODO: This func.
    end

    -- Unequip an item from a character by slot.
    function bash.Character.UnequipItemBySlot(charID, slot)
        -- TODO: This func.
    end 

    -- Equip a character with an inventory.
    function bash.Character.EquipInventory(charID, invID, slot)
        local char, charLoaded = bash.Character.Load(charID);
        if !char then return; end

        local inv, invLoaded = bash.Inventory.Load(invID);
        if !inv then
            if charLoaded then
                bash.Character.Unload(invID);
            end 

            return; 
        end

        local checkInvs = char:GetField("Inventory", {});
        if checkInvs[slot] then
            bash.Character.UnequipInventoryBySlot(charID, slot);
        end

        local invs = char:GetField("Inventory", {}, true);
        invs[slot] = invID;
        char:SetField("Inventory", invs);

        local ply = bash.Character.GetActiveEntity(charID);
        if isplayer(ply) then
            bash.Inventory.AddPlayerListener(invID, ply);
        end

        if charLoaded then
            bash.Character.Unload(charID);
        end
    end

    -- Unequip an inventory from a character by InvID.
    function bash.Character.UnequipInventoryByID(charID, invID)
        -- TODO: This func.
    end

    -- Unequip an inventory from a character by slot.
    function bash.Character.UnequipInventoryBySlot(charID, slot)
        -- TODO: This func.
    end 

    -- Create a new item and give it to a character.
    function bash.Character.GrantItem()
        -- TODO: This func.
    end 

    -- Give a character an existing item.
    function bash.Character.GiveItem(charID, itemID)
        local char, charLoaded = bash.Character.Load(charID);
        if !char then return; end
        
        local item, itemLoaded = bash.Item.Load(itemID);
        if !item then
            if charLoaded then
                bash.Character.Unload(charID);
            end

            return;
        end

        local addedMessage;
        local invs = char:GetField("Inventory");
        for slot, invID in pairs(invs) do 
            -- TODO: Tweak messages for notifs.
            addedMessage = bash.Inventory.AddItem(invID, itemID);
            if addedMessage == true then
                if charLoaded then
                    bash.Character.Unload(charID);
                end 
                if itemLoaded then
                    bash.Item.Unload(itemID);
                end

                return true;
            end
        end 

        if charLoaded then
            bash.Character.Unload(charID);
        end 
        if itemLoaded then
            bash.Item.Unload(itemID);
        end

        return false;
    end

    -- Remove an item from a character's inventory and delete it.
    function bash.Character.RemoveItem(charID, itemID)
        local char, charLoaded = bash.Character.Load(charID);
        if !char then return; end

        local invs = char:GetField("Inventory", {});
        local inv, contents;
        for slot, invID in pairs(invs) do
            inv, invLoaded = bash.Inventory.Load(invID);
            if !inv then continue; end

            contents = inv:GetField("Contents", {});
            if !contents[itemID] then
                if SERVER and invLoaded then
                    bash.Inventory.Unload(invID);
                end

                continue;
            end

            bash.Item.Delete(itemID);

            if SERVER and invLoaded then
                bash.Inventory.Unload(invID);
            end

            return;
        end
    end

    -- Remove an item from a character's inventory and turn it into an entity.
    function bash.Character.DropItem(charID, itemID)
        local ent = bash.Character.GetActiveEntity(charID);
        if !isent(ent) and !isplayer(ent) then return; end

        local char, charLoaded = bash.Character.Load(charID);
        if !char then return; end

        local invs = char:GetField("Inventory", {});
        local inv, contents;
        for slot, invID in pairs(invs) do
            inv, invLoaded = bash.Inventory.Load(invID);
            if !inv then continue; end

            contents = inv:GetField("Contents", {});
            if !contents[itemID] then
                if SERVER and invLoaded then
                    bash.Inventory.Unload(invID);
                end

                continue;
            end

            local traceTab = {};
            traceTab.start = ent:EyePos();
            traceTab.endpos = traceTab.start + ent:GetAimVector() * 90;
            traceTab.filter = ent;
            local trace = util.TraceLine(traceTab);
            local itemPos = trace.HitPos;
            itemPos.z = itemPos.z + 2;

            bash.Item.SpawnInWorld(itemID, itemPos);

            if SERVER and invLoaded then
                bash.Inventory.Unload(invID);
            end

            return;
        end
    end

    --
    -- Engine hooks.
    --

    -- Fetch all used IDs.
    hook.Add("InitPostEntity", "bash_CharacterFetchIDs", function()
        bash.Util.MsgDebug(LOG_CHAR, "Fetching used CharIDs...");

        tabnet.GetDBProvider():GetTableData(
            "bash_Character",
            {"CharID"},
            nil,

            function(data)
                for _, char in pairs(data) do
                    bash.Character.IDs[char.CharID] = true;
                end

                bash.Util.MsgDebug(LOG_CHAR, "Cached %d CharIDs.", #data);
            end
        );
    end);

    -- Watch for entity removals.
    hook.Add("EntityRemoved", "bash_CharacterDeleteOnRemoved", function(ent)
        local char = ent:GetCharacter();
        if !char then return; end

        local charID = char:GetField("CharID");
        tabnet.GetDBProvider():SaveTable(char);
        ent:DetachCharacter(true);
        bash.Character.Unload(charID);
    end);

    --
    -- Network hooks.
    --

    -- Watch for character digest requests.
    vnet.Watch("bash_Net_CharacterDigestRequest", function(pck)
        local ply = pck.Source;
        bash.Character.GetDigest(ply);
    end, {1});

    -- Watch for character loading requests.
    vnet.Watch("bash_Net_CharacterLoadRequest", function(pck)
        local ply = pck.Source;
        local id = pck:String();
        local char = bash.Character.Load(id);

        bash.Util.MsgLog(LOG_CHAR, "Player '%s' (%s) is loading character '%s'...", ply:Name(), ply:SteamID(), id);
        ply:AttachCharacter(char);
    end, {1});

    -- Watch for character creation requests.
    vnet.Watch("bash_Net_CharacterCreateRequest", function(pck)
        local ply = pck.Source;
        local name = pck:String();

        bash.Util.MsgLog(LOG_CHAR, "Player '%s' (%s) is creating character '%s'...", ply:Name(), ply:SteamID(), name);
        bash.Character.Create({
            Owner = ply:SteamID(),
            Name = name
        }, nil, ply);
    end, {1});

elseif CLIENT then

    -- Request a character digest from the server.
    function bash.Character.RequestDigest()
        local digestReq = vnet.CreatePacket("bash_Net_CharacterDigestRequest");
        digestReq:AddServer();
        digestReq:Send();
        
        hook.Run("OnRequestCharacterDigest");
    end

    --
    -- Engine hooks.
    --

    -- Open character menu initially.
    hook.Add("InitPostEntity", "bash_CharacterOpenMenu", function()
        if bash.CharMenu then return; end
        bash.CharMenu = vgui.Create("bash_CharacterMenu");
    end);

    -- Watch for character attaches.
    hook.Add("OnUpdateTable", "bash_CharacterWatchForAttach", function(tab, name, newVal, oldVal)
        if tab._RegistryID != "bash_CharLookup" then return; end
        if type(name) != "number" then return; end

        local entInd = name;
        local charID = newVal;
        local ent = ents.GetByIndex(entInd);
        if !isent(ent) and !isplayer(ent) then return; end

        local char = tabnet.GetTable(charID);
        if !char then return; end

        bash.Util.MsgDebug(LOG_CHAR, "Attaching character '%s' to entity '%s'...", charID, tostring(ent));
        hook.Run("OnCharacterAttach", char, ent);
    end);

    -- Watch for character detaches.
    hook.Add("OnClearTable", "bash_CharacterWatchForDetach", function(tab, name, val)
        if tab._RegistryID != "bash_CharLookup" then return; end
        if type(name) != "number" then return; end

        local entInd = name;
        local charID = val;
        local ent = ents.GetByIndex(entInd);
        if !isent(ent) and !isplayer(ent) then return; end

        local char = tabnet.GetTable(charID);
        if !char then return; end

        bash.Util.MsgDebug(LOG_CHAR, "Detaching character '%s' from entity '%s'...", charID, tostring(ent));
        hook.Run("OnCharacterDetach", char, ent);
    end);

    --
    -- Network hooks.
    --

    -- Watch for character digest.
    vnet.Watch("bash_Net_CharacterDigestReturn", function(pck)
        local digest = pck:Table();
        bash.Character.Digest = digest;

        bash.Util.MsgDebug(LOG_CHAR, "Received character digest! Entries: %d", table.Count(digest));
        hook.Run("OnReceiveCharacterDigest");
    end, {1});

end

--
-- Engine hooks.
--

-- Create character structures.
hook.Add("CreateStructures_Engine", "bash_CharacterStructures", function()
    if SERVER then
        if !tabnet.GetTable("bash_CharLookup") then
            tabnet.CreateTable(nil, tabnet.LIST_GLOBAL, nil, "bash_CharLookup");
        end
    end

    -- CharID: Unique ID for a character.
    tabnet.EditSchemaField{
        SchemaName = "bash_Character",
        FieldName = "CharID",
        FieldDefault = "",
        FieldScope = tabnet.SCOPE_PUBLIC,
        IsInSQL = true,
        FieldType = "string",
        IsPrimaryKey = true
    };

    -- Owner: Unique ID for the 'owner' of the character. SteamID for players.
    tabnet.EditSchemaField{
        SchemaName = "bash_Character",
        FieldName = "Owner",
        FieldDefault = "",
        FieldScope = tabnet.SCOPE_PUBLIC,
        IsInSQL = true,
        FieldType = "string"
    };

    -- Name: Name of the character.
    tabnet.EditSchemaField{
        SchemaName = "bash_Character",
        FieldName = "Name",
        FieldDefault = "...",
        FieldScope = tabnet.SCOPE_PUBLIC,
        IsInSQL = true,
        FieldType = "string"
    };

    -- Description: Short piece of text describing the character.
    tabnet.EditSchemaField{
        SchemaName = "bash_Character",
        FieldName = "Description",
        FieldDefault = "...",
        FieldScope = tabnet.SCOPE_PUBLIC,
        FieldSecure = false,
        IsInSQL = true,
        FieldType = "string"
    };

    -- BaseModel: The model of the character when nothing is worn.
    tabnet.EditSchemaField{
        SchemaName = "bash_Character",
        FieldName = "BaseModel",
        FieldDefault = "",
        FieldScope = tabnet.SCOPE_PUBLIC,
        IsInSQL = true,
        FieldType = "string"
    };

    -- Equipment: Table of active items equipped by the character.
    tabnet.EditSchemaField{
        SchemaName = "bash_Character",
        FieldName = "Equipment",
        FieldDefault = EMPTY_TABLE,
        FieldScope = tabnet.SCOPE_PRIVATE,
        IsInSQL = true,
        FieldType = "table"
    };

    -- Inventory: Table of active inventories owned by the character.
    tabnet.EditSchemaField{
        SchemaName = "bash_Character",
        FieldName = "Inventory",
        FieldDefault = EMPTY_TABLE,
        FieldScope = tabnet.SCOPE_PRIVATE,
        IsInSQL = true,
        FieldType = "table"
    };
end);
