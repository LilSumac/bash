--[[
    Character management functionality.
]]

--
-- Local storage.
--

local bash = bash;

local LOG_CHAR = {pre = "[CHAR]", col = color_limegreen};

local Entity = FindMetaTable("Entity");

--
-- Global storage.
--

bash.Character              = bash.Character or {};
bash.Character.IDs          = bash.Character.IDs or {};
bash.Character.Digest       = (CLIENT and (bash.Character.Digest or {})) or nil;

--
-- Entity functions.
--

-- Get an entity's assigned character, if any.
function Entity:GetCharacter()
    if self._CharCached then return self._CharCached; end

    local reg = bash.Character.GetRegistry();
    if !reg then return; end

    local index = self:EntIndex();
    local charID = reg:GetField(index);

    self._CharCached = tabnet.GetTable(charID);
    return self._CharCached;
end

-- Check if an entity has a certain character loaded.
function Entity:IsCharacter(id)
    return self:GetCharacter() and self:GetCharacter():GetField("CharID") == id;
end

--
-- Character functions.
--

-- Get the character registry.
function bash.Character.GetRegistry()
    return tabnet.GetTable("bash_CharRegistry");
end

-- Get an entity who is playing as a certain character.
function bash.Character.GetEntityOwner(id)
    local reg = bash.Character.GetRegistry();
    if !reg then return; end

    local curUser = reg:GetField(id);
    local ent = (curUser and ents.GetByIndex(curUser)) or nil;
    return ent;
end

-- Check to see if a character is currently in use.
function bash.Character.IsInUse(id)
    return bash.Character.GetEntityOwner(id) != nil;
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

        if loadOnCreate then bash.Character.Load(charID);
        else tabnet.DeleteTable(charID); end
    end

    -- Create a new instance of a character.
    function bash.Character.Load(id, forceOwner, deleteOld)
        bash.Util.MsgLog(LOG_CHAR, "Loading character '%s'...", id);

        local char = tabnet.GetTable(id);
        if !char then
            char = tabnet.GetDBProvider():LoadTable("bash_Character", id, tabnet.LIST_GLOBAL);
        end 

        if !char then
            bash.Util.MsgErr("CharNotFound", id);
            return;
        end

        char:SetGlobal(true);
        local owner = forceOwner;
        if !owner then
            local ownerID = char:GetField("Owner");
            if !ownerID then
                bash.Util.MsgErr("CharNoOwnerSet", id);
                return;
            end

            owner = player.GetBySteamID(ownerID);
            -- TODO: Add NPC functionality.
            if !owner then
                bash.Util.MsgErr("CharNoOwnerAvailable", id);
                return;
            end 
        end

        bash.Character.AttachTo(char, owner, deleteOld);
    end

    -- Associate a character with an entity.
    function bash.Character.AttachTo(char, ent)
        if !char then return; end 
        if !isent(ent) and !isplayer(ent) then return; end

        bash.Character.DetachCurrent(ent);

        local id = char:GetField("CharID");
        local reg = bash.Character.GetRegistry();
        local index = ent:EntIndex();
        local oldIndex = reg:GetField(id);
        local oldOwner = (oldIndex and ents.GetByIndex(oldIndex)) or nil;
        bash.Character.DetachCurrent(oldOwner, true);

        bash.Util.MsgLog(LOG_CHAR, "Attaching character '%s' to entity '%s'...", id, tostring(ent));

        -- Add both for two-way lookup.
        reg:SetFields{
            [index] = id,
            [id] = index
        };

        char:AddListener(ent, tabnet.SCOPE_PRIVATE);
        hook.Run("OnCharacterAttach", char, ent);
    end

    -- Dissociate the current character associated with an entity.
    function bash.Character.DetachCurrent(ent, keep)
        if !isent(ent) and !isplayer(ent) then return; end
        if !ent:GetCharacter() then return; end

        local reg = bash.Character.GetRegistry();
        local char = ent:GetCharacter();
        local charID = char:GetField("CharID");
        local index = ent:EntIndex();
        bash.Util.MsgLog(LOG_CHAR, "Detaching character '%s' from entity '%s'...", charID, tostring(ent));

        reg:ClearField(index, charID);
        char:RemoveListener(ent, tabnet.SCOPE_PRIVATE);
        ent._CharCached = nil;
        hook.Run("OnCharacterDetach", char, ent);

        if !keep then tabnet.DeleteTable(charID); end
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

        if SERVER then
            tabnet.GetDBProvider():SaveTable(char);
            bash.Character.DetachCurrent(ent);
        end
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
        bash.Character.Load(id, ply, true, true);
    end, {1});

    -- Watch for character creation requests.
    vnet.Watch("bash_Net_CharacterCreateRequest", function(pck)
        local ply = pck.Source;
        local name = pck:String();
        bash.Character.Create({
            Owner = ply:SteamID(),
            Name = name
        }, nil, true);
    end, {1});

elseif CLIENT then

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
        if tab._RegistryID != "bash_CharRegistry" then return; end

        -- Kinda hacky. Meh.
        local entInd = (isnumber(name) and name) or newVal;
        local ent = ents.GetByIndex(entInd);
        if !isent(ent) and !isplayer(ent) then return; end

        local char = tabnet.GetTable(newVal);
        if !char then return; end

        bash.Util.MsgDebug(LOG_CHAR, "Attaching character '%s' to entity '%s'...", newVal, tostring(ent));
        hook.Run("OnCharacterAttach", char, ent);
    end);

    -- Watch for character detaches.
    hook.Add("OnClearTable", "bash_CharacterWatchForDetach", function(tab, name, val)
        if tab._RegistryID != "bash_CharRegistry" then return; end

        -- Kinda hacky. Meh.
        local entInd = (isnumber(name) and name) or val;
        local oldCharID = (isstring(name) and name) or val;
        local ent = ents.GetByIndex(entInd);
        if !isent(ent) and !isplayer(ent) then return; end

        local char = tabnet.GetTable(oldCharID);
        if !char then return; end

        bash.Util.MsgDebug(LOG_CHAR, "Detaching character '%s' from entity '%s'...", oldCharID, tostring(ent));
        hook.Run("OnCharacterDetach", char, ent);
        ent._CharCached = nil;
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
        if !tabnet.GetTable("bash_CharRegistry") then
            tabnet.CreateTable(nil, tabnet.LIST_GLOBAL, nil, "bash_CharRegistry");
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
