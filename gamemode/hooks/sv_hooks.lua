-- Local functions.
local function initPlayer(ply)
    hook.Run("PrePlayerInit", ply);
end

-- Server-side Gamemode Hooks

-- Network hooks.
vnet.Watch("bash_Net_SendClientData", function(pck)
    local ply = pck.Source;
    local data = pck:Table();
    bash.clientData = bash.clientData or {};
    bash.clientData[ply:EntIndex()] = data;

    if !ply.Initialized then
        initPlayer(ply);
    end
end);
