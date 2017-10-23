-- Server-side Gamemode Hooks

-- Network hooks.
vnet.Watch("bash_Net_SendClientData", function(pck)
    local ply = pck.Source;
    local data = pck:Table();
    bash.clientData = bash.clientData or {};
    bash.clientData[ply:EntIndex()] = data;

    hook.Run("bash_OnReceiveClientData", ply, data);
end);
