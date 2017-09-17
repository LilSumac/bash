defineService_start("CCharacter");

-- Service info.
SVC.Name = "Core Character";
SVC.Author = "LilSumac";
SVC.Desc = "The main character functions for /bash/.";
SVC.Depends = {"CDatabase"};

-- Service storage.
SVC.CachedData = getNonVolatileEntry("CCharacter_DataCache", EMPTY_TABLE);
SVC.CachedChars = getNonVolatileEntry("CCharacter_CharCache", EMPTY_TABLE);
SVC.CachedIDs = {};

function SVC:Instantiate(id, refresh)
    -- look for data from id in cache
    -- if there, create new char obj and return
    -- else, fetch and hook to id
    -- call hook for finishing instantiate

    if !id then
        MsgErr("NilArgs", "id");
        return;
    end

    local data;
    if refresh or (!self.CachedChars[id] and !self.CachedData[id]) then
        MsgCon(color_orange, "Hooking character fetch: %s", id);

        local name = "CCharacter_Fetch_" .. id;
        hook.Add(name, self, self.Instantiate);

        self:DBFetch(id);
        return;
    elseif self.CachedChars[id] then
        -- a char instance already exists

        return self.CachedChars[id];
    elseif self.CachedData[id] then
        -- data has already been fetched
        -- take data and push to new instance

        MsgCon(color_green, "Instantiating character: %s", id);

        local metanet = getService("CMetaNet");
        local char = metanet:NewMetaNet("Char", self.CachedData[id]);
        self.CachedChars[id] = char;
        return char;
    end

    MsgCon(color_orange, "Removing character fetch hook: %s", id);
    local name = "CCharacter_Fetch_" .. id;
    hook.Remove(name, self);
end

function SVC:DBFetch(id)

end

function SVC:PostDBFetch(data)
    MsgCon(color_green, "Completed character fetch: %s", data.CharID);

    self.CachedData[data.CharID] = data;
    local name = "CCharacter_Fetch_" .. data.CharID;
    hook.Call(name, self, data.CharID);
end

-- Hooks.
hook.Add("GatherPrelimData_Base", "CCharacter_DefaultVars", function()
    local metanet = getService("CMetaNet");
    metanet:AddDomain{
        ID = "Char",
        ParentMeta = getMeta("Character"),
        StoredInSQL = true,
        SQLTable = "bash_chars"
    };

    metanet:AddVariable{
        ID = "CharID",
        Domain = "Char",
        Type = "string",
        Public = true,
        InSQL = true
    };
    metanet:AddVariable{
        ID = "Name",
        Domain = "Char",
        Type = "string",
        Public = true,
        InSQL = true
    };
end);

if SERVER then

    -- Hooks.
    hook.Add("OnDBConnected", "CCharacter_OnDBConnected", function()
        local db = getService("CDatabase");
        db:GetRow("bash_chars", "*", "", function(results)
            local ids = {};
            local cchar = getService("CCharacter");

            results = results[1];
            for index, data in pairs(results.data) do
                ids[data.CharID] = true;
            end
            cchar.CachedIDs = ids;
        end);
    end);

elseif CLIENT then



end

defineService_end();
