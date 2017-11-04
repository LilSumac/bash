--[[
    CTableNet server hooks.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local bash      = bash;
local hook      = hook;
local MsgLog    = MsgLog;
local pairs     = pairs;

--
-- Network hooks.
--

-- Receive a registry sending acknowledgement.
vnet.Watch("CTableNet_Net_RegSendAck", function(pck)
    local ply = pck.Source;
    hook.Run("CTableNet_RegSendAck", ply);
end);

-- Receive client requests for variable changes.
vnet.Watch("CTableNet_Net_ObjRequest", function(pck)
    local ply = pck.Source;
    local regID = pck:String();
    local domain = pck:String();
    local data = pck:Table();

    local tabnet = bash.Util.GetPlugin("CTableNet");
    if !tabnet:IsRegistered(regID) then
        MsgLog(LOG_WARN, "Client '%s' requested a change of '%s'! Not supposed to happen.", ply:Name(), regID);
        return;
    end
    local tab = tabnet:GetTable(regID);

    local safeData = {};
    local varData;
    for id, val in pairs(data) do
        varData = tabnet:GetVariable(domain, id);
        if !varData then continue; end
        if varData.Secure then
            MsgLog(LOG_WARN, "Client %s requested an insecure change of table %s! Ignoring.", ply:Name(), regID);
            continue;
        end

        safeData[id] = val;
    end

    tab:SetNetVars(domain, safeData);
end);
