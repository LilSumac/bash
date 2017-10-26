--[[
    CChar server hooks.
]]

-- Gamemode hooks.
hook.Add("CDatabase_Hook_OnConnected", "CChar_OnDBConnected", function()
    local db = getService("CDatabase");
    db:SelectRow("bash_chars", "CharID", "", function(results)
        results = results[1];

        local cchar = getService("CChar");
        local ids = {};
        for index, data in pairs(results.data) do
            ids[data.CharID] = true;
        end
        MsgDebug(LOG_CHAR, "Fetched Character IDs. (%d entries)", table.Count(ids));
        cachedIDs = ids;
    end);
end);


-- TESTING
concommand.Add("testchar", function(ply, cmd, args)
    local tabnet = getService("CTableNet");
    bash.testchar = tabnet:NewTable("CChar", {
        CharID = "dood",
        Name = "dooder"
    });
end);
