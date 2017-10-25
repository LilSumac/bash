defineService_start("CTableNet");

-- Service info.
SVC.Name = "Core TableNet";
SVC.Author = "LilSumac";
SVC.Desc = "A framework for creating, networking, and adding persistant variables to tables and objects.";
SVC.Depends = {"CDatabase"};

-- Constants.
LOG_TABNET = {pre = "[TABNET]", col = color_darkgreen};
LISTEN_PUBLIC = 1;
LISTEN_PRIVATE = 2;

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
    if meta and !meta.TableNetFuncsAdded then

        -- Get functions.
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

            local tabnet = getService("CTableNet");
            if !tabnet:GetDomain(domain) then
                MsgErr("NilEntry", domain);
                return;
            end

            local results = {};
            local index = 1;
            local varData, val;
            for _, id in ipairs(ids) do
                varData = tabnet:GetVariable(domain, id);
                if !varData then continue; end

                if varData.Public then
                    results[index] = _self.TableNet[domain].Public[id];
                else
                    results[index] = _self.TableNet[domain].Private[id];
                end
                index = index + 1;
            end

            return unpack(results);
        end

        -- Set functions.
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

            --[[ Working on it.
            if CLIENT then
                local requestPck = vnet.CreatePacket("")
                return;
            end
            ]]

            local ids = {};
            local index = 1;
            local varData;
            for id, val in pairs(data) do
                varData = tablenet:GetVariable(domain, id);
                if !varData then continue; end

                if varData.Public then
                    _self.TableNet[domain].Public[id] = val;
                else
                    _self.TableNet[domain].Private[id] = val;
                end
                ids[index] = id;
                index = index + 1;

                --[[ This also needs to be changed.
                if SERVER and varData.OnSetServer then
                    varData:OnSetServer(_self, val);
                elseif CLIENT and varData.OnSetClient then
                    varData:OnSetClient(_self, val);
                end
                ]]
            end

            tablenet:NetworkTable(_self.RegistryID, domain, ids);
        end

        -- Listener functions.
        meta.AddListener = function(_self, listener, domain, mode)

        end
        meta.GetListeners = function(_self, domain)

        end
        meta.RemoveListener = function(_self, listener, domain)

        end
        meta.ClearListeners = function(_self, domain)

        end

        meta.TableNetFuncsAdded = true;
    end

    --[[ Changing to listeners.
    domain.GetRecipients = domain.GetRecipients or function(_self, tab)
        return player.GetInitializedAsKeys();
    end
    domain.GetPrivateRecipients = domain.GetPrivateRecipients or function(_self, tab)
        return {};
    end
    ]]

    MsgLog(LOG_TABNET, "Registered domain: %s", domain.ID);
    domains[domain.ID] = domain;
    vars[domain.ID] = {};
end

function SVC:GetDomain(dom)
    return domains[dom];
end

-- Do something about editing variables (adding callbacks).
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
    var.Secure = var.Secure == nil and true or var.Secure;

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

function SVC:GetTable(id)
    return registry[id];
end

function SVC:IsRegistered(id, domain)
    if domain then
        return registry[id] != nil and registry[id] != NULL and registry[id].TableNet[domain] != nil;
    else
        return registry[id] != nil and registry[id] != NULL;
    end
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
    local public = {};
    local private = {};
    local gen;
    for id, var in pairs(vars[domain]) do
        if data[id] != nil then
            if var.Public then public[id] = data[id];
            else private[id] = data[id]; end
        elseif SERVER and var.OnGenerate then
            gen = handleFunc(var.OnGenerate, var, tab);
            if var.Public then public[id] = gen;
            else private[id] = gen; end
        end
    end

    tab.TableNet = tab.TableNet or {};
    tab.TableNet[domain] = {};
    tab.TableNet[domain].Public = public;
    tab.TableNet[domain].Private = private;

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

    runInits(tab, domain);
    if SERVER then self:NetworkTable(tab.RegistryID, domain); end
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

    local data = tab.TableNet[domain].Public;
    table.Merge(data, tab.TableNet[domain].Private);
    local varData;
    for id, val in pairs(data) do
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
    tab:ClearListeners(domain);
    if table.IsEmpty(tab.TableNet) then
        registry[id] = nil;
        tab.RegistryID = nil;
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
    local index = 1;
    local varData;
    for _, id in ipairs(ids) do
        varData = vars[domain][id];
        if !varData then continue; end

        if varData.Public then
            results[index] = tab.TableNet[domain].Public[id];
        else
            results[index] = tab.TableNet[domain].Private[id];
        end
        index = index + 1;
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
    local index = 1;
    local varData;
    for id, val in pairs(data) do
        varData = vars[domain][id];
        if !varData then continue; end

        if varData.Public then
            tab.TableNet[domain].Public[id] = val;
        else
            tab.TableNet[domain].Private[id] = val;
        end
        ids[index] = id;
        index = index + 1;
    end

    if SERVER then self:NetworkTable(tab.RegistryID, domain, ids); end
end

if SERVER then

    -- Network pool.
    util.AddNetworkString("CTableNet_Net_RegSend");
    util.AddNetworkString("CTableNet_Net_ObjUpdate");
    util.AddNetworkString("CTableNet_Net_ObjOutOfScope");

    -- Functions.
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

elseif CLIENT then

    -- Network hooks.
    vnet.Watch("CTableNet_Net_RegSend", function(pck)
        local reg = pck:Table();
        local tabnet = getService("CTableNet");
        local count = 0;
        local tab, varData;
        for regID, regData in pairs(reg) do
            for domain, data in pairs(regData) do
                if domain == "_RegObg" then continue; end

                if tabnet:IsRegistered(regID, domain) then
                    tab = tabnet:GetTable(regID);
                    for id, val in pairs(data) do
                        varData = tabnet:GetVariable(domain, id);
                        if !varData then continue; end

                        if varData.Public then
                            tab.TableNet[domain].Public[id] = val;
                        else
                            tab.TableNet[domain].Private[id] = val;
                        end
                    end
                else
                    tabnet:NewTable(domain, data, regData._RegObg, regID);
                end
                count = count + 1;
            end
        end

        -- Acknowledge registry send (maybe)
        -- DEBUG
        -- Show count
    end);

    vnet.Watch("CTableNet_Net_ObjUpdate", function(pck)
        local regID = pck:String();
        local domain = pck:String();
        local data = pck:Table();
        local firstSend = pck:Bool();
        local obj;
        if pck:Bool() then
            obj = pck:Entity();
        end

        local tabnet = getService("CTableNet");
        local domInfo = tabnet:GetDomain(domain);
        local tab, varData;
        if registry[regID] then
            tab = registry[regID];
            for id, val in pairs(data) do
                varData = tabnet:GetVariable(domain, id);
                if !varData then continue; end

                if varData.Public then
                    tab.TableNet[domain].Public[id] = val;
                else
                    tab.TableNet[domain].Private[id] = val;
                end
            end
        else
            tab = tabnet:NewTable(domain, data, obj, regID);
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
