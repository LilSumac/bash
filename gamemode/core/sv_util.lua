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

function bash.Util.PlayerInit(ply)

end

function bash.Util.PlayerPostInit(ply)

end
