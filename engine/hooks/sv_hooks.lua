--[[
    Server engine hooks.
]]

--
-- Local storage.
--

local bash = bash;
local hook = hook;

--
-- Engine hook helpers.
--

-- Handle basis of player pre-init process.
function bash.PlayerPreInit(ply)
    bash.Util.MsgDebug(LOG_DEF, "Pre-init for %s!", ply:Name());
    hook.Run("PlayerPreInit", ply);

    -- ...

    bash.PlayerInit(ply);
end

-- Handle basis of player init process.
function bash.PlayerInit(ply)
    bash.Util.MsgDebug(LOG_DEF, "Init for %s!", ply:Name());
    ply.Initialized = true;
    hook.Run("PlayerInit", ply);
end

--
-- Engine hooks.
--

-- Remove client data when client disconnects.
gameevent.Listen("player_disconnect");
hook.Add("player_disconnect", "bash_RemoveClientData", function(data)
    if data.bot == 0 then
        bash.ClientData[data.networkid] = nil;
    end
end);

-- Override the base DoPlayerDeath.
function GM:DoPlayerDeath(ply, attacker, dmgInfo) end

--
-- Network hooks.
--

-- Receive client data from client.
vnet.Watch("bash_Net_SendClientData", function(pck)
    local ply = pck.Source;
    local data = pck:Table();
    local first = pck:Bool();
    bash.ClientData = bash.ClientData or {};
    bash.ClientData[ply:SteamID()] = data;

    bash.Util.MsgDebug(LOG_DEF, "Received client data from %s!", ply:Name());
    PrintTable(data);

    if first then
        bash.PlayerPreInit(ply);
    end
end);
