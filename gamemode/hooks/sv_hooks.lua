-- Local functions.
local function initPlayer(ply)
    hook.Call("PrePlayerInit", bash, ply);
    ply.Initialized = true;
    hook.Call("OnPlayerInit", bash, ply);
    hook.Call("PostPlayerInit", bash, ply);
end

-- Server-side Gamemode Hooks

-- Network hooks.
vnet.Watch("bash_Net_SendClientData", function(pck)
    local ply = pck.Source;
    local data = pck:Table();
    bash.clientData = bash.clientData or {};
    bash.clientData[ply:EntIndex()] = data;

    if !ply.Initialized then
        ackClientData(ply);
    end
end);
