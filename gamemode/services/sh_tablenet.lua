defineService_start("CTableNet");

-- Service info.
SVC.Name = "Core TableNet";
SVC.Author = "LilSumac";
SVC.Desc = "A framework for creating, networking, and adding persistant variables to tables and objects.";
SVC.Depends = {"CDatabase"};

-- Constants.
LOG_TABNET = {pre = "[TABNET]", col = color_darkgreen};

-- Custom errors.
addErrType("TableNotRegistered", "This table has not been registered in TableNet! (%s)");
addErrType("NoDomainInTable", "No domain with that ID exists in that table! (%s -> %s)");
addErrType("UnauthorizedSend", "Tried sending a table to an unauthorized recipient! To force, use the 'force' argument. (%s:%s -> %s)");
addErrType("MultiSingleTable", "Tried to create a single table when one already exists! (%s)");

-- Service storage.
local domains = {};
local vars = {};
local registry = getNonVolatileEntry("CTableNet_Registry", EMPTY_TABLE);
local singlesMade = {};

-- Local functions.
local function runInits(tab, domain)
    local tablenet = getService("CTableNet");
    local varInfo, initFunc;
    for id, val in pairs(tab.TableNet[domain]) do
        varInfo = vars[domain][id];
        if !varInfo then continue; end

        if CLIENT and varInfo.OnInitClient then
            initFunc = varInfo.OnInitClient;
        elseif SERVER and varInfo.OnInitServer then
            initFunc = varInfo.OnInitServer;
        else
            initFunc = nil;
        end

        if initFunc then
            initFunc(varInfo, tab, val);
        end
    end
end

-- Service functions.
function SVC:AddDomain(domain)
    if !domain then
        MsgErr("NilArgs", "domain");
        return;
    end
    if !domain.ID then
        MsgErr("NilField", "ID", "domain");
        return;
    end
    if domains[domain.ID] then
        MsgErr("DupEntry", domain.ID);
        return;
    end

    -- Domain fields.
    -- domain.ID = domain.ID; (Redundant, no default)
    -- domain.ParentMeta = domain.ParentMeta; (Redundant, no default);
    domain.Secure = domain.Secure == nil and true or domain.Secure;
    domain.StoredInSQL = domain.StoredInSQL or false;
    if SERVER and domain.StoredInSQL then
        if !domain.SQLTable then
            MsgErr("NilField", "SQLTable", "domain");
            return;
        end

        local cdb = getService("CDatabase");
        cdb:AddTable(domain.SQLTable);
    end

    domain.SingleTable = domain.SingleTable or false;

    local meta = domain.ParentMeta;
    if meta and !meta.GetNetVar then
        meta.GetNetVar = function(_self, domain, id)
            return _self:GetNetVars(domain, {id});
        end
        meta.GetNetVars = function(_self, domain, ids)
            if !domain then
                MsgErr("NilArgs", "domain");
                return;
            end
            if !ids then
                MsgErr("NilArgs", "ids");
                return;
            end

            if !_self.RegistryID or !_self.TableNet then
                MsgErr("TableNotRegistered", tostring(_self));
                return;
            end

            if !_self.TableNet[domain] then
                MsgErr("NoDomainInTable", domain, tostring(_self));
                return;
            end

            local tablenet = getService("CTableNet");
            if !tablenet:GetDomain(domain) then
                MsgErr("NilEntry", domain);
                return;
            end

            local results = {};
            for _, id in ipairs(ids) do
                if !tablenet:GetVariable(domain, id) then continue; end
                results[#results + 1] = _self.TableNet[domain][id];
            end

            return unpack(results);
        end
    end
    if (SERVER or domain.Secure) and meta and !meta.SetNetVar then
        meta.SetNetVar = function(_self, domain, id, val)
            _self:SetNetVars(domain, {[id] = val});
        end
        meta.SetNetVars = function(_self, domain, data)
            if !domain then
                MsgErr("NilArgs", "domain");
                return;
            end
            if !data then
                MsgErr("NilArgs", "data");
                return;
            end

            if !_self.RegistryID or !_self.TableNet then
                MsgErr("TableNotRegistered", tostring(_self));
                return;
            end

            if !_self.TableNet[domain] then
                MsgErr("NoDomainInTable", domain, tostring(_self));
                return;
            end

            local tablenet = getService("CTableNet");
            local domInfo = tablenet:GetDomain(domain);
            if !domInfo then
                MsgErr("NilEntry", domain);
                return;
            end

            if CLIENT then
                return;
            end

            local ids = {};
            local varData;
            for id, val in pairs(data) do
                varData = tablenet:GetVariable(domain, id);
                if !varData then continue; end

                _self.TableNet[domain][id] = val;
                ids[#ids + 1] = id;

                if SERVER and varData.OnSetServer then
                    varData:OnSetServer(_self, val);
                elseif CLIENT and varData.OnSetClient then
                    varData:OnSetClient(_self, val);
                end
            end

            tablenet:NetworkTable(_self.RegistryID, domain, ids);
        end
    end

    domain.GetRecipients = domain.GetRecipients or function(_self, tab)
        return player.GetInitializedAsKeys();
    end
    domain.GetPrivateRecipients = domain.GetPrivateRecipients or function(_self, tab)
        return {};
    end

    MsgLog(LOG_TABNET, "Registered domain: %s", domain.ID);
    domains[domain.ID] = domain;
    vars[domain.ID] = {};
end

function SVC:GetDomain(dom)
    return domains[dom];
end

function SVC:AddVariable(var)
    if !var then
        MsgErr("NilArgs", "var");
        return;
    end
    if !var.ID or !var.Domain then
        MsgErr("NilField", "ID/Domain", "var");
        return;
    end
    if !vars[var.Domain] then
        MsgErr("NilEntry", var.Domain);
        return;
    end
    if vars[var.Domain][var.ID] then
        MsgErr("DupEntry", var.ID);
        return;
    end

    -- Variable fields.
    -- var.ID = var.ID; (Redundant, no default)
    -- var.Domain = var.Domain; (Redundant, no default)
    var.Type = var.Type or "string";
    -- var.MaxLength = var.MaxLength;
    var.Public = var.Public or false;

    -- var.OnGen
    -- var.OnInit
    -- var.OnDeinit
    -- var.OnSet

    if SERVER then
        var.InSQL = var.InSQL or false;

        -- Charvar functions/hooks.
        var.OnGenerate = var.OnGenerate or DEFAULTS[var.Type];
        var.OnInitClient = nil;
        var.OnDeinitClient = nil;
        var.OnSetClient  = nil;
        -- var.OnSetServer = var.OnSetServer; (Redundant, no default)
        -- var.OnInitServer = var.OnInitServer; (Redundant, no default)
        -- var.OnDeinitServer = var.OnDeinitServer; (Redundant, no default)
    elseif CLIENT then
        var.OnGenerate = nil;
        var.OnInitServer = nil;
        var.OnDeinitServer = nil;
        var.OnSetServer = nil;
        -- var.OnSetClient = var.OnSetClient; (Redundant, no default)
        -- var.OnInitClient = var.OnInitClient; (Redundant, no default)
        -- var.OnDeinitClient = var.OnDeinitClient; (Redundant, no default)
    end

    MsgLog(LOG_TABNET, "Registered netvar %s in domain %s.", var.ID, var.Domain);
    vars[var.Domain][var.ID] = var;

    if SERVER and var.InSQL then
        local cdb = getService("CDatabase");
        local domInfo = domains[var.Domain];
        if !domInfo.StoredInSQL then return; end
        cdb:AddColumn(domInfo.SQLTable, {
            Name = var.ID,
            Type = var.Type,
            MaxLength = var.MaxLength
        }, var.PrimaryKey or false);
    end
end

function SVC:GetVariable(domain, var)
    return vars[domain][var];
end

function SVC:GetDomainVars(domain)
    if !domain then
        MsgErr("NilArgs", "domain");
        return;
    end

    if !vars[domain] then
        MsgErr("NilEntry", domain);
        return;
    end

    return vars[domain];
end

function SVC:GetRegistry()
    return registry;
end

function SVC:IsRegistered(id)
    return registry[id] != nil and registry[id] != NULL;
end

function SVC:IsRegistryEmpty()
    return table.IsEmpty(registry);
end

function SVC:NewTable(domain, data, obj, regID)
    if !domain then
        MsgErr("NilArgs", "domain");
        return;
    end

    local domInfo = domains[domain];
    if !domInfo then
        MsgErr("NilEntry", domain);
        return;
    end

    if domInfo.SingleTable and singlesMade[domain] then
        MsgErr("MultiSingleTable", domain);
        return;
    end

    local tab;
    if !obj then
        if domInfo.ParentMeta then
            tab = setmetatable({}, domInfo.ParentMeta);
        else
            tab = {};
        end
    else
        tab = obj;
    end

    data = data or {};
    local _data = {};
    for id, var in pairs(vars[domain]) do
        if data[id] != nil then
            _data[id] = data[id];
        elseif SERVER and var.OnGenerate then
            _data[id] = handleFunc(var.OnGenerate, var, tab);
        end
    end

    tab.TableNet = tab.TableNet or {};
    tab.TableNet[domain] = _data;

    if regID then
        tab.RegistryID = regID;
        registry[regID] = tab;
    elseif !tab.RegistryID then
        local id = string.random(8, CHAR_ALPHANUM);
        while registry[id] do
            id = string.random(8, CHAR_ALPHANUM);
        end
        id = domain .. "_" .. id;
        tab.RegistryID = id;
        registry[id] = tab;
    end

    if domInfo.SingleTable then
        singlesMade[domain] = tab.RegistryID;
    end

    MsgLog(LOG_TABNET, "Registered table in TableNet with domain %s. (%s)", domain, tab.RegistryID);

    if SERVER then self:NetworkTable(tab.RegistryID, domain); end
    runInits(tab, domain);
    return tab;
end

function SVC:RemoveTable(id, domain)
    if !id then
        MsgErr("NilArgs", "id");
        return;
    end
    if !domain then
        MsgErr("NilArgs", "domain");
        return;
    end

    local tab = registry[id];
    if !tab then return; end
    if !tab.TableNet then return; end
    if !tab.TableNet[domain] then return; end

    local varData;
    for id, val in pairs(tab.TableNet[domain]) do
        varData = self:GetVariable(domain, id);
        if !varData then continue; end

        if SERVER and varData.OnDeinitServer then
            varData:OnDeinitServer(tab, val);
        elseif CLIENT and varData.OnDeinitClient then
            varData:OnDeinitClient(tab, val);
        end
    end

    MsgLog(LOG_TABNET, "Removing '%s' from registry.", id);

    if SERVER then
        local removePck = vnet.CreatePacket("CTableNet_Net_ObjOutOfScope");
        removePck:String(id);
        removePck:String(domain);
        removePck:Broadcast();
    end

    tab.TableNet[domain] = nil;
    if table.IsEmpty(tab.TableNet) then
        registry[id] = nil;
    end

    if singlesMade[domain] then
        singlesMade[domain] = nil;
    end
end

function SVC:GetNetVars(domain, ids)
    if !domain then
        MsgErr("NilArgs", "domain");
        return;
    end
    if !ids then
        MsgErr("NilArgs", "ids");
        return;
    end

    local tab = singlesMade[domain];
    if !tab then
        MsgErr("TableNotRegistered", domain);
        return;
    end
    tab = registry[tab];

    if !tab.TableNet[domain] then
        MsgErr("NoDomainInTable", domain, tostring(tab));
        return;
    end

    if !domains[domain] then
        MsgErr("NilEntry", domain);
        return;
    end

    local results = {};
    for _, id in ipairs(ids) do
        if !vars[domain][id] then continue; end

        --add onget?
        results[#results + 1] = tab.TableNet[domain][id];
    end

    return unpack(results);
end

function SVC:SetNetVars(domain, data)
    if !domain then
        MsgErr("NilArgs", "domain");
        return;
    end
    if !data then
        MsgErr("NilArgs", "data");
        return;
    end

    local tab = singlesMade[domain];
    if !tab then
        MsgErr("TableNotRegistered", domain);
        return;
    end
    tab = registry[tab];

    if !tab.TableNet[domain] then
        MsgErr("NoDomainInTable", domain, tostring(tab));
        return;
    end

    if !domains[domain] then
        MsgErr("NilEntry", domain);
        return;
    end

    local ids = {};
    for id, val in pairs(data) do
        if !vars[domain][id] then continue; end

        tab.TableNet[domain][id] = val;
        ids[#ids + 1] = id;
    end

    self:NetworkTable(tab.RegistryID, domain, ids);
end

if SERVER then

    -- Network pool.
    util.AddNetworkString("CTableNet_Net_ClientInit");
    util.AddNetworkString("CTableNet_Net_ObjUpdate");
    util.AddNetworkString("CTableNet_Net_ObjOutOfScope");

    -- Functions.
    function SVC:NetworkTable(id, domain, ids)
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

        local pubRecip = domInfo:GetRecipients(tab) or {};
        local privRecip = domInfo:GetPrivateRecipients(tab) or {};
        if pubRecip and privRecip and table.IsEmpty(pubRecip) and table.IsEmpty(privRecip) then return; end

        local pubPack, privPack;
        if !table.IsEmpty(pubRecip) then
            pubPack = vnet.CreatePacket("CTableNet_Net_ObjUpdate");
            pubPack:String(tab.RegistryID);
            pubPack:String(domain);
        end
        if !table.IsEmpty(privPack) then
            privPack = vnet.CreatePacket("CTableNet_Net_ObjUpdate");
            privPack:String(tab.RegistryID);
            privPack:String(domain);
        end

        local public = {};
        local private = {};
        local val;
        if ids then
            local varData;
            if type(ids) == "table" then
                for _, id in pairs(ids) do
                    varData = vars[domain][id];
                    if !varData then
                        MsgErr("NilEntry", id);
                        continue;
                    end

                    val = tab.TableNet[domain][id];
                    if privPack then private[id] = val; end
                    if pubPack and varData.Public then
                        public[id] = val;
                    end
                end
            else
                varData = vars[domain][ids];
                if !varData then
                    MsgErr("NilEntry", ids);
                else
                    val = tab.TableNet[domain][ids];
                    if privPack then private[ids] = val; end
                    if pubPack and varData.Public then
                        public[ids] = val;
                    end
                end
            end
        else
            for _id, _var in pairs(vars[domain]) do
                val = tab.TableNet[domain][_id];
                if val != nil then
                    if privPack then private[_id] = val; end
                    if pubPack and _var.Public then
                        public[_id] = val;
                    end
                end
            end
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

        local excluded = player.GetInitializedAsKeys();

        if pubPack then
            pubPack:AddTargets(pubRecip);
            pubPack:Send();

            for ply, _ in pairs(pubRecip) do
                excluded[ply] = nil;
            end
        end

        if privPack then
            privPack:AddTargets(privRecip);
            privPack:Send();

            for ply, _ in pairs(privRecip) do
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

    function SVC:SendTable(ply, id, domain, sendVars, force)
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
        local recip;
        local isRecip, isPrivate = false, false;
        recip = domInfo:GetRecipients(tab);
        isRecip = recip and recip[ply] or false;
        if !isRecip and !force then
            --MsgErr("UnauthorizedSend", id, domain, tostring(ply));
            return;
        end

        recip = domInfo:GetPrivateRecipients(tab);
        isPrivate = recip and recip[ply] or false;
        if sendVars then
            for _, _id in pairs(sendVars) do
                if !vars[domain][_id] then continue; end
                if !tab.TableNet[domain][_id] then continue; end

                if isPrivate or vars[domain][_id].Public then
                    data[_id] = val;
                end
            end
        else
            for _id, val in pairs(tab.TableNet[domain]) do
                if isPrivate or vars[domain][_id].Public then
                    data[_id] = val;
                end
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

elseif CLIENT then

    -- Network hooks.
    vnet.Watch("CTableNet_Net_ObjUpdate", function(pck)
        local regID = pck:String();
        local domain = pck:String();
        local data = pck:Table();
        local firstSend = pck:Bool();
        local obj;
        if pck:Bool() then
            obj = pck:Entity();
        end

        local tablenet = getService("CTableNet");
        local domInfo = tablenet:GetDomain(domain);
        local tab;
        if registry[regID] then
            tab = registry[regID];
            for id, val in pairs(data) do
                tab.TableNet[domain][id] = val;
            end
        else
            tab = tablenet:NewTable(domain, data, obj, regID);
        end

        if firstSend then
            tablenet.Received = tablenet.Received + 1;
            if tablenet.Received == tablenet.WaitingOn then
                MsgLog(LOG_TABNET, "Received all networked objects!");
            end
        end
    end);

    vnet.Watch("CTableNet_Net_ObjOutOfScope", function(pck)
        local regID = pck:String();
        local domain = pck:String();
        local tablenet = getService("CTableNet");
        tablenet:RemoveTable(regID, domain);
    end);

end

defineService_end();
