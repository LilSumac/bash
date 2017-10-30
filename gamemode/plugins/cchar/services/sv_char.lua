--[[
    CChar server service.
]]

-- Service storage.
local cachedData = getNonVolatileEntry("CChar_DataCache", EMPTY_TABLE);
local cachedChars = getNonVolatileEntry("CChar_CharCache", EMPTY_TABLE);
local cachedIDs = getNonVolatileEntry("CChar_IDCache", EMPTY_TABLE);

-- Service functions.
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
        MsgDebug(LOG_CHAR, "Hooking character fetch: %s", id);

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

        MsgDebug(LOG_CHAR, "Instantiating character: %s", id);

        local tablenet = getService("CTableNet");
        local char = tablenet:NewTable("CChar", cachedData[id]);
        cachedChars[id] = char;
        return char;
    end

    MsgDebug(LOG_CHAR, "Removing character fetch hook: %s", id);
    local name = "CChar_Hook_CharFetch_" .. id;
    hook.Remove(name, id);
end

function SVC:DBFetch(id)

end

function SVC:PostDBFetch(data)
    MsgDebug(LOG_CHAR, "Completed character fetch: %s", data.CharID);

    cachedData[data.CharID] = data;
    local name = "CChar_Hook_CharFetch_" .. data.CharID;
    hook.Run(name, data.CharID);
end
