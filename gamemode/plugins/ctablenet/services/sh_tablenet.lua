defineService_start("CTableNet");

-- Service info.
SVC.Name = "Core TableNet";
SVC.Author = "LilSumac";
SVC.Desc = "A framework for creating, networking, and adding persistant variables to tables and objects.";

-- Constants.
LOG_TABNET = {pre = "[TABNET]", col = color_darkgreen};
LISTEN_PUBLIC = 1;
LISTEN_PRIVATE = 2;

-- Custom errors.
addErrType("TableNotRegistered", "This table has not been registered in TableNet! (%s)");
addErrType("NoDomainInTable", "No domain with that ID exists in that table! (%s -> %s)");
addErrType("UnauthorizedSend", "Tried sending a table to an unauthorized recipient! To force, use the 'force' argument. (%s:%s -> %s)");
addErrType("MultiSingleTable", "Tried to create a single table when one already exists! (%s)");

processFile("sv_tablenet.lua");

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

local function checkListenerTable(tab, domain)
    if !tab.TableNet then
        MsgErr("TableNotRegistered", tostring(tab));
        return;
    end
    if !tab.TableNet[domain] then
        MsgErr("NoDomainInTable", tostring(tab), domain);
        return;
    end

    local list = tab.TableNet[domain].Listeners;
    if !list then
        tab.TableNet[domain].Listeners = {};
        tab.TableNet[domain].Listeners.Public = {};
        tab.TableNet[domain].Listeners.Private = {};
        list = tab.TableNet[domain].Listeners;
    end

    return list;
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
        meta.AddListener = function(_self, domain, listener, mode)
            local list = checkListenerTable(_self, domain);

            if mode == LISTEN_PUBLIC then
                if type(listener) == "table" then
                    for key, val in pairs(listener) do
                        if isplayer(key) then
                            list.Public[key] = true;
                        end
                        if isplayer(val) then
                            list.Public[val] = true;
                        end
                    end
                else
                    list.Public[listener] = true;
                end
            elseif mode == LISTEN_PRIVATE then
                if type(listener) == "table" then
                    for key, val in pairs(listener) do
                        if isplayer(key) then
                            list.Private[key] = true;
                        end
                        if isplayer(val) then
                            list.Private[val] = true;
                        end
                    end
                else
                    list.Public[listener] = true;
                end
            end
        end
        meta.GetListeners = function(_self, domain)
            return checkListenerTable(_self, domain);
        end
        meta.RemoveListener = function(_self, domain, listener)
            local list = checkListenerTable(_self, domain);
            list.Public[listener] = nil;
            list.Private[listener] = nil;
        end
        meta.ClearListeners = function(_self, domain)
            if !domain then
                local list;
                for _domain, _ in pairs(_self.TableNet) do
                    list = checkListenerTable(_self, _domain);
                    list.Public = {};
                    list.Private = {};
                end

                return;
            end

            local list = checkListenerTable(_self, domain);
            list.Public = {};
            list.Private = {};
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

    MsgDebug(LOG_TABNET, "Registered domain: %s", domain.ID);
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

    MsgDebug(LOG_TABNET, "Registered netvar %s in domain %s.", var.ID, var.Domain);
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

    MsgDebug(LOG_TABNET, "Registered table in TableNet with domain %s. (%s)", domain, tab.RegistryID);

    runInits(tab, domain);
    --if SERVER then self:NetworkTable(tab.RegistryID, domain); end
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

    MsgDebug(LOG_TABNET, "Removing '%s' from registry.", id);

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

defineService_end();
