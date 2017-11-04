--[[
    CDatabase server hooks.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local bash      = bash;
local MsgLog    = MsgLog;

--
-- bash hooks.
--

-- Make sure the database is connected on setup/refresh.
hook.Add("InitCalls", "CDatabase_OnInit", function()
    local db = bash.Util.GetPlugin("CDatabase");
    if db:IsConnected() then
        MsgLog(LOG_DB, "Database still connected, skipping.");
        return;
    end

    db:Connect();
end);
