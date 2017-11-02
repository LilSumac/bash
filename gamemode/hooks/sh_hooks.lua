--[[
    Shared base gamemode hooks.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local MsgLog = MsgLog;

--
-- Gamemode hooks.
--

-- Report when a player has connected.
gameevent.Listen("player_connect");
hook.Add("player_connect", "bash_ReportConnect", function(data)
    if data.bot == 0 then
        MsgLog(LOG_CONN, "%s [%s] has connected.", data.name, data.networkid);
    end
end);

-- Report when a player has disconnected.
gameevent.Listen("player_disconnect");
hook.Add("player_disconnect", "bash_ReportDisconnect", function(data)
    if data.bot == 0 then
        MsgLog(LOG_CONN, "%s [%s] has disconnected.", data.name, data.networkid);
    end
end);
