--[[
    Server base gamemode hooks.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local bash = bash;
local hook = hook;

--
-- Gamemode hooks.
--

-- Remove client data when client disconnects.
gameevent.Listen("player_disconnect");
hook.Add("player_disconnect", "bash_RemoveClientData", function(data)
    if data.bot == 0 then
        bash.ClientData[data.networkid] = nil;
    end
end);

--
-- Network hooks.
--

-- Receive client data from client.
vnet.Watch("bash_Net_SendClientData", function(pck)
    local ply = pck.Source;
    local data = pck:Table();
    bash.ClientData = bash.ClientData or {};
    bash.ClientData[ply:SteamID()] = data;

    hook.Run("OnReceiveClientData", ply, data);
end);
