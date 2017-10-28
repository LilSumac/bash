--[[
    CTableNet client hooks.
]]

-- Network hooks.
vnet.Watch("CTableNet_Net_ObjRequest", function(pck)
    local ply = pck.Source;
    local regID = pck:String();
    local domain = pck:String();
    local data = pck:Table();

    local tabnet = getService("CTableNet");
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
