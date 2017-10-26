--[[
    CTableNet server service.
]]

-- Network pool.
util.AddNetworkString("CTableNet_Net_RegSend");
util.AddNetworkString("CTableNet_Net_ObjUpdate");
util.AddNetworkString("CTableNet_Net_ObjOutOfScope");

-- Service functions.
function SVC:NetworkTable(id, domain, vars)
    if !id or !domain then
        MsgErr("NilArgs", "id/domain");
        return;
    end
    if !registry[id] then
        MsgErr("NilEntry", id);
        return;
    end
    if !domains[domain] then
        MsgErr("NilEntry", "domain");
        return;
    end
    local domInfo = domains[domain];

    local tab = registry[id];
    if !tab.RegistryID or !tab.TableNet then
        MsgErr("TableNotRegistered", tostring(tab));
        return;
    end
    if !tab.TableNet[domain] then
        MsgErr("NoDomainInTable", domain, tostring(tab));
        return;
    end

    local list = tab:GetListeners(domain);
    if !list or (table.IsEmpty(list.Public) and table.IsEmpty(list.Private)) then return; end

    local pubPack, privPack;
    if !table.IsEmpty(list.Public) then
        pubPack = vnet.CreatePacket("CTableNet_Net_ObjUpdate");
        pubPack:String(tab.RegistryID);
        pubPack:String(domain);
    end
    if !table.IsEmpty(list.Private) then
        privPack = vnet.CreatePacket("CTableNet_Net_ObjUpdate");
        privPack:String(tab.RegistryID);
        privPack:String(domain);
    end

    local public = {};
    local private = {};
    local varData, val;
    if vars then
        if type(vars) == "table" then
            for _, id in ipairs(vars) do
                varData = vars[domain][id];
                if !varData then continue; end

                if privPack then
                    private[id] = tab.TableNet[domain].Private[id];
                end
                if varData.Public and pubPack then
                    public[id] = tab.TableNet[domain].Public[id];
                end
            end
        elseif type(vars) == "string" then
            varData = vars[domain][vars];
            if varData then
                if privPack then
                    private[vars] = tab.TableNet[domain].Private[vars];
                end
                if varData.Public and pubPack then
                    public[vars] = tab.TableNet[domain].Public[vars];
                end
            end
        end
    else
        if privpack then private = tab.TableNet[domain].Private; end
        if pubPack then public = tab.TableNet[domain].Public; end
    end

    if isentity(tab) or isplayer(tab) then
        if pubPack then
            pubPack:Table(public);
            pubPack:Bool(false);
            pubPack:Bool(true);
            pubPack:Entity(tab);
        end

        if privPack then
            privPack:Table(private);
            privPack:Bool(false);
            privPack:Bool(true);
            privPack:Entity(tab);
        end
    else
        if pubPack then pubPack:Bool(false); end
        if privPack then privPack:Bool(false); end
    end

    local excluded = player.GetAllAsKeys();

    if pubPack then
        pubPack:AddTargets(list.Public);
        pubPack:Send();

        for ply, _ in pairs(list.Public) do
            excluded[ply] = nil;
        end
    end

    if privPack then
        privPack:AddTargets(list.Private);
        privPack:Send();

        for ply, _ in pairs(list.Private) do
            excluded[ply] = nil;
        end
    end

    if !table.IsEmpty(excluded) then
        local scopePck = vnet.CreatePacket("CTableNet_Net_ObjOutOfScope");
        scopePck:String(tab.RegistryID);
        scopePck:String(domain);
        scopePck:AddTargets(excluded);
        scopePck:Send();
    end
end

function SVC:SendTable(ply, id, domain, _vars, force)
    if !isplayer(ply) then
        MsgErr("InvalidPly");
        return;
    end
    if !id then
        MsgErr("NilArgs", "id");
        return;
    end
    if !domain then
        MsgErr("NilArgs", "domain");
        return;
    end

    local domInfo = domains[domain];
    if !domInfo then
        MsgErr("NilEntry", "domain");
        return;
    end

    if !registry[id] then
        MsgErr("NilEntry", id);
        return;
    end

    local tab = registry[id];
    if !tab.RegistryID or !tab.TableNet then
        MsgErr("TableNotRegistered", tostring(tab));
        return;
    end
    if !tab.TableNet[domain] then
        MsgErr("NoDomainInTable", domain, tostring(tab));
        return;
    end

    local data = {};
    local list = tab:GetListeners(domain);
    if !list.Public[ply] and !list.Private[ply] and !force then
        -- DEBUG
        -- Remove old error msg.
        return;
    end

    local isPrivate = list.Private[ply] != nil;
    local varData;
    if _vars then
        if type(_vars) == "table" then
            for _, _id in pairs(_vars) do
                varData = vars[domain][_id];
                if !varData then continue; end

                if varData.Public then
                    data[_id] = tab.TableNet[domain].Public[_id];
                elseif isPrivate then
                    data[_id] = tab.TableNet[domain].Private[_id];
                end
            end
        elseif type(_vars) == "string" then
            varData = vars[domain][_vars];
            if varData then
                if varData.Public then
                    data[_vars] = tab.TableNet[domain].Public[_vars];
                elseif isPrivate then
                    data[_vars] = tab.TableNet[domain].Private[_vars];
                end
            end
        end
    else
        data = tab.TableNet[domain].Public;
        if isPrivate then
            table.Merge(data, tab.TableNet[domain].Private);
        end
    end

    local sendPck = vnet.CreatePacket("CTableNet_Net_ObjUpdate");
    sendPck:String(tab.RegistryID);
    sendPck:String(domain);
    sendPck:Table(data);
    sendPck:Bool(false);
    if isentity(tab) or isplayer(tab) then
        sendPck:Bool(true);
        sendPck:Entity(tab);
    else
        sendPck:Bool(false);
    end

    sendPck:AddTargets(ply);
    sendPck:Send();
end

function SVC:SendRegistry(ply)
    if !isplayer(ply) then
        MsgErr("InvalidPly");
        return;
    end

    if self:IsRegistryEmpty() then return; end

    local regPck = vnet.CreatePacket("CTableNet_Net_RegSend");
    local data = {};
    local list;
    for regID, tab in pairs(registry) do
        for domain, tabData in pairs(tab.TableNet) do
            list = tab:GetListeners(domain);
            if !list or (!list.Public[ply] and !list.Private[ply]) then continue; end

            data[regID] = data[regID] or {};
            data[regID][domain] = tabData.Public;
            if list.Private[ply] then
                table.Merge(data[regID][domain], tabData.Private);
            end
            if isentity(tab) or isplayer(tab) then
                data[regID]._RegObg = tab;
            end
        end
    end

    regPck:Table(data);
    regPck:AddTargets(ply);
    regPck:Send();
end
