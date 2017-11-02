--[[
    CChar server functionality.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local bash      = bash;
local hook      = hook;
local MsgDebug  = MsgDebug;
local MsgErr    = MsgErr;

-- Fetch non-volatile character caches.
local cachedData = bash.Util.GetNonVolatileEntry("CChar_DataCache", EMPTY_TABLE);
local cachedChars = bash.Util.GetNonVolatileEntry("CChar_CharCache", EMPTY_TABLE);
local cachedIDs = bash.Util.GetNonVolatileEntry("CChar_IDCache", EMPTY_TABLE);

--
-- Plugin functions.
--

-- Try to make an instance of a character from a CharID.
function PLUG:Instantiate(id, refresh)
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

        local tabnet = bash.Util.GetPlugin("CTableNet");
        local char = tabnet:NewTable("CChar", cachedData[id]);
        cachedChars[id] = char;
        return char;
    end

    MsgDebug(LOG_CHAR, "Removing character fetch hook: %s", id);
    local name = "CChar_Hook_CharFetch_" .. id;
    hook.Remove(name, id);
end

-- Fetch character data linked to CharID from database.
function PLUG:DBFetch(id)

end

-- Handle character data post-fetch from database.
function PLUG:PostDBFetch(data)
    MsgDebug(LOG_CHAR, "Completed character fetch: %s", data.CharID);

    cachedData[data.CharID] = data;
    local name = "CChar_Hook_CharFetch_" .. data.CharID;
    hook.Run(name, data.CharID);
end
