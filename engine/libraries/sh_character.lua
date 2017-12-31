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
bash.Character.Vars         = bash.Character.Vars or {};
bash.Character.Cache        = bash.Character.Cache or {};
bash.Character.Waiting      = bash.Character.Waiting or {};
bash.Character.Digest       = (CLIENT and (bash.Character.Digest or {})) or nil;

--
-- Entity functions.
--

-- Get an entity's assigned character, if any.
function Entity:GetCharacter()
    local reg = bash.Character.GetRegistry();
    if !reg then return; end

    local index = self:EntIndex();
    local charID = reg:Get(index);

    return bash.TableNet.Get(charID);
end

-- Check if an entity has a certain character loaded.
function Entity:IsCharacter(id)
    return self:GetCharacter() and self:GetCharacter():Get("CharID") == id;
end

--
-- Character functions.
--

-- Add a new character variable struct.
function bash.Character.AddVar(id, def, scope)
    bash.Character.Vars[id] = {
        ID = id,
        Default = def,
        Scope = scope
    };
end

-- Get the character registry.
function bash.Character.GetRegistry()
    return bash.TableNet.Get("bash_CharRegistry");
end

-- Check to see if a character is currently in use.
function bash.Character.IsInUse(id)
    return bash.Character.GetRegistry():Get(id);
end

if SERVER then

    -- Get a small summary of character data for a player.
    function bash.Character.GetDigest(ply)
        if !isplayer(ply) then return; end
        bash.Util.MsgDebug(LOG_CHAR, "Fetching character digest for '%s' from database...", ply:Name());

        bash.Database.Query(F("SELECT CharNum, CharID, Name FROM `bash_chars` WHERE SteamID = \'%s\';", ply:SteamID()), function(resultsTab)
            local results = resultsTab[1];
            if !results.status then return; end

            local chars = {};
            for _, charData in pairs(results.data) do
                bash.Database.CastData("bash_chars", charData, CAST_OUT);
                chars[charData.CharNum] = charData;
            end

            local sendDigest = vnet.CreatePacket("bash_Net_CharacterDigestReturn");
            sendDigest:Table(chars);
            sendDigest:AddTargets(ply);
            sendDigest:Send();
        end);
    end

    function bash.Character.Create(data, ent)

    end

    -- Fetch all data from the database tied to a character ID.
    function bash.Character.Fetch(id)
        bash.Util.MsgDebug(LOG_CHAR, "Fetching character '%s' from database...", id);

        bash.Database.Query(F("SELECT * FROM `bash_chars` WHERE CharID = \'%s\';", id), function(resultsTab)
            local results = resultsTab[1];
            if !results.status then return; end

            local fetchData, charData, var = results.data[1], {};
            for id, var in pairs(bash.Character.Vars) do
                charData[var.Scope] = charData[var.Scope] or {};
                charData[var.Scope][id] = fetchData[id] or handleFunc(var.Default);
            end

            bash.Character.Cache[fetchData.CharID] = charData;
            bash.Util.MsgDebug(LOG_CHAR, "Character '%s' fetched from database.", id);

            local wait = bash.Character.Waiting[id];
            if wait then
                bash.Character.Waiting[id] = nil;
                bash.Character.Load(id, wait._ent, wait._deleteOld);
            end
        end);
    end

    -- Create a new instance of a character.
    function bash.Character.Load(id, ent, deleteOld)
        -- TODO: Finish this function.
        if ent:GetCharacter() and ent:GetCharacter():Get("CharID") == id then return; end

        if !bash.Character.Cache[id] then
            bash.Util.MsgDebug(LOG_CHAR, "Request to load character '%s' is waiting on data.", id);

            bash.Character.Waiting[id] = {
                _ent = ent,
                _deleteOld = deleteOld
            };
            bash.Character.Fetch(id);
            return;
        end

        bash.Util.MsgLog(LOG_CHAR, "Loading character '%s'...", id);

        if !bash.TableNet.IsRegistered(id) then
            local charData = bash.Character.Cache[id];
            local list = {};
            list.Public = NET_GLOBAL;
            if isplayer(ent) then list.Private = {[ent] = true}; end

            bash.TableNet.NewTable(charData, list, id);
        end

        bash.Character.AttachTo(id, ent, deleteOld);
    end

    -- Associate a character with an entity.
    function bash.Character.AttachTo(id, ent, deleteOld)
        if !isent(ent) and !isplayer(ent) then return; end
        bash.Character.DetachFrom(ent, deleteOld);

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
    end

    -- Dissociate the current character associated with an entity.
    function bash.Character.DetachFrom(ent, delete)
        if !isent(ent) and !isplayer(ent) then return; end
        if !ent:GetCharacter() then return; end

        local reg = bash.Character.GetRegistry();
        local char = ent:GetCharacter();
        local charID = char:Get("CharID");
        local index = ent:EntIndex();
        bash.Util.MsgDebug(LOG_CHAR, "Detaching character '%s' from entity '%s'...", charID, tostring(ent));

        reg:Delete(index, charID);
        char:RemoveListener(ent, NET_PRIVATE);
        hook.Run("OnCharacterDetach", char, ent);

        if delete then
            bash.TableNet.DeleteTable(charID);
        end
    end

    --
    -- Network hooks.
    --

    -- Watch for character digest requests.
    vnet.Watch("bash_Net_CharacterDigestRequest", function(pck)
        local ply = pck.Source;
        bash.Character.GetDigest(ply);
    end);

    -- Watch for character loading requests.
    vnet.Watch("bash_Net_CharacterLoadRequest", function(pck)
        local ply = pck.Source;
        local id = pck:String();
        bash.Character.Load(id, ply, true);
    end);

elseif CLIENT then

    function bash.Character.RequestDigest()
        if bash.CharMenu then
            bash.CharMenu.WaitingOnDigest = true;
        end

        local digestReq = vnet.CreatePacket("bash_Net_CharacterDigestRequest");
        digestReq:AddServer();
        digestReq:Send();
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
    hook.Add("TableUpdate", "bash_CharacterWatchForAttach", function(regID, data)
        if regID != "bash_CharRegistry" then return; end

        local ent;
        for entID, charID in pairs(data) do
            if isstring(entID) then continue; end
            ent = ents.GetByIndex(entID);
            if !isent(ent) and !isplayer(ent) then continue; end

            bash.Util.MsgDebug(LOG_CHAR, "Attaching character '%s' to entity '%s'...", charID, tostring(ent));
            hook.Run("OnCharacterAttach", bash.TableNet.Get(charID), ent);
        end
    end);

    -- Watch for character detaches.
    hook.Add("TableDeleteEntry", "bash_CharacterWatchForDetach", function(regID, deleted)
        if regID != "bash_CharRegistry" then return; end

        local handled, ent, entInd, oldCharID = {};
        PrintTable(deleted);
        for key, val in pairs(deleted) do
            if isstring(key) then
                oldCharID = key;
                entInd = val;
            elseif isnumber(key) then
                entInd = key;
                oldCharID = val;
            else continue; end
            if handled[entInd] then continue; end
            ent = ents.GetByIndex(entInd);
            MsgN(ent);
            if !isent(ent) and !isplayer(ent) then continue; end

            bash.Util.MsgDebug(LOG_CHAR, "Detaching character '%s' from entity '%s'...", oldCharID, tostring(ent));
            hook.Run("OnCharacterDetach", bash.TableNet.Get(oldCharID), ent);
            handled[entInd] = true;
        end
    end);

    --
    -- Network hooks.
    --

    -- Watch for character digest.
    vnet.Watch("bash_Net_CharacterDigestReturn", function(pck)
        local digest = pck:Table();
        bash.Character.Digest = digest;

        bash.Util.MsgDebug(LOG_CHAR, "Received character digest! Entries: %d", table.Count(digest));

        -- TODO: Refresh character menu.
        if bash.CharMenu then
            bash.CharMenu.WaitingOnDigest = false;
            bash.CharMenu:RepopulateList();
            return;
        end
    end);

end

--
-- Engine hooks.
--

-- Create character structures.
hook.Add("CreateStructures_Engine", "bash_CharacterStructures", function()
    if SERVER then
        if !bash.TableNet.IsRegistered("bash_CharRegistry") then
            bash.TableNet.NewTable({}, NET_GLOBAL, "bash_CharRegistry");
        end
    end

    bash.Character.AddVar("CharNum", -1, NET_PUBLIC);
    bash.Character.AddVar("CharID", "bash_charID", NET_PUBLIC);
    bash.Character.AddVar("Name", "John Doe", NET_PUBLIC);
    bash.Character.AddVar("Desc", "A real character.", NET_PUBLIC);
    bash.Character.AddVar("BaseModel", "models/breen.mdl", NET_PUBLIC);
    bash.Character.AddVar("Inv", "somestring", NET_PRIVATE);
end);

-- Watch for entity removals.
hook.Add("EntityRemoved", "bash_CharacterDeleteOnRemoved", function(ent)
    local char = ent:GetCharacter();
    if !char then return; end

    if SERVER then
        bash.Character.DetachFrom(ent, true);
        -- TODO: Push changes to SQL?
    elseif CLIENT then
        local charID = char:Get("CharID");
        bash.Util.MsgDebug(LOG_CHAR, "Detaching character '%s' from entity '%s'...", charID, tostring(ent));
        hook.Run("OnCharacterDetach", bash.TableNet.Get(charID), ent);
    end
end);
