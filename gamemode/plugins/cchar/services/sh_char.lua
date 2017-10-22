defineService_start("CChar");

-- Service info.
SVC.Name = "CChar";
SVC.Author = "LilSumac";
SVC.Desc = "A collection of the main character functions.";
SVC.Depends = {"CDatabase"};

-- Service storage.
local cachedData = getNonVolatileEntry("CChar_DataCache", EMPTY_TABLE);
local cachedChars = getNonVolatileEntry("CChar_CharCache", EMPTY_TABLE);
local cachedIDs = {};

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
    if refresh or (!cachedChars[id] and !cachedData[id]) then
        MsgLog(LOG_CHAR, "Hooking character fetch: %s", id);

        local name = "CChar_Hook_CharFetch_" .. id;
        hook.Add(name, id, self.Instantiate);

        self:DBFetch(id);
        return;
    elseif cachedChars[id] then
        -- a char instance already exists

        return cachedChars[id];
    elseif cachedData[id] then
        -- data has already been fetched
        -- take data and push to new instance

        MsgLog(LOG_CHAR, "Instantiating character: %s", id);

        local tablenet = getService("CTableNet");
        local char = tablenet:NewTable("Char", cachedData[id]);
        cachedChars[id] = char;
        return char;
    end

    MsgLog(LOG_CHAR, "Removing character fetch hook: %s", id);
    local name = "CChar_Hook_CharFetch_" .. id;
    hook.Remove(name, id);
end

function SVC:DBFetch(id)

end

function SVC:PostDBFetch(data)
    MsgLog(LOG_CHAR, "Completed character fetch: %s", data.CharID);

    cachedData[data.CharID] = data;
    local name = "CChar_Hook_CharFetch_" .. data.CharID;
    hook.Run(name, data.CharID);
end

-- Hooks.
hook.Add("GatherPrelimData_Base", "CChar_DefaultVars", function()
    local tablenet = getService("CTableNet");
    tablenet:AddDomain{
        ID = "Char",
        ParentMeta = getMeta("CChar"),
        StoredInSQL = true,
        SQLTable = "bash_chars"
    };

    tablenet:AddVariable{
        ID = "CharID",
        Domain = "Char",
        Type = "string",
        MaxLength = 17,
        Public = true,
        InSQL = true,
        OnGenerate = function(_self, char)
            return string.random(12, CHAR_ALPHANUM, "char_");
        end
    };
    tablenet:AddVariable{
        ID = "Name",
        Domain = "Char",
        Type = "string",
        MaxLength = 32,
        Public = true,
        InSQL = true
    };
end);

if SERVER then

    -- Hooks.
    hook.Add("OnDBConnected", "CChar_OnDBConnected", function()
        local db = getService("CDatabase");
        db:GetRow("bash_chars", "*", "", function(results)
            results = results[1];

            local cchar = getService("CChar");
            local ids = {};
            for index, data in pairs(results.data) do
                ids[data.CharID] = true;
            end
            MsgCon(LOG_CHAR, "Fetched Character IDs. (%d entries)", table.Count(ids));
            cachedIDs = ids;
        end);
    end);



    concommand.Add("testchar", function(ply, cmd, args)
        local tabnet = getService("CTableNet");
        bash.testchar = tabnet:NewTable("Char", {
            CharID = "dood",
            Name = "dooder"
        });
    end);

end

defineService_end();
