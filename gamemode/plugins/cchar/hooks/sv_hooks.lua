--[[
    CChar server hooks.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local bash      = bash;
local MsgDebug  = MsgDebug;
local pairs     = pairs;
local table     = table;

--
-- bash hooks.
--

-- Calculate all used CharIDs.
hook.Add("CDatabase_OnConnected", "CChar_OnDBConnected", function()
    local db = bash.Util.GetPlugin("CDatabase");
    db:SelectRow("bash_chars", "CharID", "", function(results)
        results = results[1];

        local cachedIDs = bash.Util.GetNonVolatileEntry("CChar_IDCache", EMPTY_TABLE);
        local cchar = bash.Util.GetPlugin("CChar");
        local ids, count = {}, 0;
        for index, data in pairs(results.data) do
            ids[data.CharID] = true;
            count = count + 1;
        end

        MsgDebug(LOG_CHAR, "Fetched Character IDs. (%d entries)", count);
        cachedIDs = ids;
    end);
end);

-- Add a new CharID to the total ID cache when a character is created.
hook.Add("CTableNet_OnTableCreate", "CChar_CacheCharID", function(tab, domain)
    if domain != "Char" then return; end

    local cachedIDs = bash.Util.GetNonVolatileEntry("CChar_IDCache", EMPTY_TABLE);
    cachedIDs[tab:GetNetVar("Char", "CharID")] = true;
end);
