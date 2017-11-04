--[[
    Server utility functions.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local bash      = bash;
local isplayer  = isplayer;
local MsgErr    = MsgErr;

--
-- Utility functions.
--

-- Send an acknowledgement to the client after it sends data.
function bash.Util.RespondToClient(ply)
    local respondPck = vnet.CreatePacket("bash_Net_RespondToClient");
    respondPck:AddTargets(ply);
    respondPck:Send();
end

-- Retrieve client data from table.
function bash.Util.GetClientData(ply, id)
    if !isplayer(ply) then
        MsgErr("InvalidPlayer", "ply");
        return;
    end

    local index = ply:SteamID();
    if !bash.ClientData[index] then return; end

    if id then
        return bash.ClientData[index][id];
    else
        return bash.ClientData[index];
    end
end

-- Call the init stage for a player.
function bash.Util.PlayerInit(ply)
    if !isplayer(ply) or ply.Initialized then return; end

    local respondPck = vnet.CreatePacket("bash_Net_RespondToClient");
    respondPck:AddTargets(ply);
    respondPck:Send();

    ply.Initialized = true;
    hook.Run("PlayerOnInit", ply);
end

-- Call the postinit stage for a player.
function bash.Util.PlayerPostInit(ply)
    if !isplayer(ply) or ply.Initialized or ply.Initialized then return; end

    ply.PostInitialized = true;
    hook.Run("PlayerPostInit", ply);
end
