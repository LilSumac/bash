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
bash.Character.Digest       = (CLIENT and bash.Character.Digest or {}) or nil;

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

if SERVER then

    -- Get a small summary of character data for a player.
    function bash.Character.GetDigest(ply)
        if !isplayer(ply) then return; end

        bash.Database.Query("SELECT 1+1;", function(resultsTab)
            PrintTable(resultsTab);
        end);
    end

    -- Create a new character.
    function bash.Character.Create(data)
        -- TODO: Finish this function.

        local charData, var = {};
        for id, var in pairs(bash.Character.Vars) do
            charData[var.Scope] = charData[var.Scope] or {};
            charData[var.Scope][id] = data[id] or var.Default;
        end

        bash.Character.Cache[data.CharID] = charData;
    end

    -- Create a new instance of a character.
    function bash.Character.Load(id, ent, deleteOld)
        -- TODO: Finish this function.

        if !bash.Character.Cache[id] then
            -- TODO: Create the character from data.
            return;
        end

        bash.Util.MsgLog(LOG_CHAR, "Loading character '%s'...", id);
        local charData = bash.Character.Cache[id];
        local list = {};
        list.Public = NET_GLOBAL;
        if isplayer(ent) then list.Private = {[ent] = true}; end

        local newChar = bash.TableNet.NewTable(charData, list,id);

        if ent then
            local oldChar = ent:GetCharacter();
            bash.Character.AttachTo(ent, id, deleteOld);
        end
    end

    -- Associate a character with an entity.
    function bash.Character.AttachTo(ent, charID, deleteOld)
        bash.Util.MsgDebug(LOG_CHAR, "Attaching character '%s' to entity '%s'...", charID, tostring(ent));

        local reg = bash.Character.GetRegistry();
        local char = bash.TableNet.Get(charID);
        local index = ent:EntIndex();
        local oldIndex = reg:GetKey(charID);
        local oldOwner = (oldIndex and ents.GetByIndex(oldIndex)) or nil;
        local prevCharID = reg:Get(index);

        MsgN(tostring(ent));
        MsgN(tostring(oldOwner));

        reg:Set(index, charID);
        reg:Delete(oldIndex);
        char:AddListener(ent, NET_PRIVATE);
        char:RemoveListener(oldOwner, NET_PRIVATE);
        PrintTable(char);

        if deleteOld and prevCharID then
            bash.TableNet.DeleteTable(prevCharID);
        end
    end

end

--
-- Engine hooks.
--

hook.Add("CreateStructures_Engine", "bash_CharacterStructures", function()
    if SERVER then
        if !bash.TableNet.IsRegistered("bash_CharRegistry") then
            bash.TableNet.NewTable({}, NET_GLOBAL, "bash_CharRegistry");
        end
    end

    bash.Character.AddVar("CharID", "bash_charID", NET_PUBLIC);
    bash.Character.AddVar("Name", "John Doe", NET_PUBLIC);
    bash.Character.AddVar("Desc", "A real character.", NET_PUBLIC);
    bash.Character.AddVar("Inv", "somestring", NET_PRIVATE);
end);
