--[[
    CTableNet shared functionality.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local bash          = bash;
local Format        = Format;
local hook          = hook;
local ipairs        = ipairs;
local isplayer      = isplayer;
local MsgDebug      = MsgDebug;
local MsgErr        = MsgErr;
local MsgLog        = MsgLog;
local pairs         = pairs;
local setmetatable  = setmetatable;
local table         = table;
local tostring      = tostring;
local type          = type;
local unpack        = unpack;
local vnet          = vnet;

--
-- Service storage.
--

-- TableNet objects.
local domains = {};
local vars = {};
local registry = bash.Util.GetNonVolatileEntry("CTableNet_Registry", EMPTY_TABLE);
local singlesMade = {};

--
-- Local functions.
--

-- Run all appropriate init functions on a table.
local function runInits(tab, domain, init)
    if !init then return; end

    local data = tab.TableNet[domain].Public;
    table.Merge(data, tab.TableNet[domain].Private);
    local varInfo, initFunc;
    for id, val in pairs(data) do
        varInfo = vars[domain][id];
        if !varInfo then continue; end

        if init == TAB_INIT and varInfo.OnInit then
            varInfo:OnInit(tab, val);
        elseif init == TAB_DEINIT and varInfo.OnDeinit then
            varInfo:OnDeinit(tab, val);
        end
    end
end

-- Initialize a table's listeners struct.
local function checkListenerTable(tab, domain)
    if !tab.TableNet then
        MsgErr("TableNotRegistered", tostring(tab));
        return;
    end
    if !tab.TableNet[domain] then
        MsgErr("NoDomainInTable", tab.RegistryID, domain);
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

--
-- Plugin functions.
--

-- Add/edit a domain struct.
function PLUG:AddDomain(domain)
    if !domain.ID then
        MsgErr("NilField", "ID", "domain");
        return;
    end

    --[[
    if domains[domain.ID] then
        MsgErr("DupEntry", domain.ID);
        return;
    end
    ]]

    -- Domain fields.
    -- domain.ID = domain.ID; (Redundant, no default)
    -- domain.ParentMeta = domain.ParentMeta; (Redundant, no default);

    -- If the domain has elements stored in the database.
    domain.StoredInSQL = domain.StoredInSQL or false;
    if SERVER and domain.StoredInSQL then
        -- The name of the table the domain stores its fields in.
        if !domain.SQLTable then
            MsgErr("NilField", "SQLTable", "domain");
            return;
        end
        -- The function called when a table needs to know its row. (x = y)
        if !domain.GetRowCondition then
            MsgErr("NilField", "GetRowCondition", "domain");
            return;
        end

        local cdb = bash.Util.GetPlugin("CDatabase");
        cdb:AddTable(domain.SQLTable);
    end

    -- Whether or not the table can only have one instance active.
    domain.SingleTable = domain.SingleTable or false;

    local meta = domain.ParentMeta;
    if meta and !meta.TableNetFuncsAdded then
        if CLIENT then
            -- Set a table as client-only.
            meta.SetClientOnly = function(_self)
                _self.ClientOnly = true;
            end
        end

        -- Get functions.
        meta.GetNetVar = function(_self, domain, id)
            return _self:GetNetVars(domain, {id});
        end
        meta.GetNetVars = function(_self, domain, ids)
            if !_self.RegistryID or !_self.TableNet then
                MsgErr("TableNotRegistered", tostring(_self));
                return;
            end

            if !_self.TableNet[domain] then
                MsgErr("NoDomainInTable", domain, tostring(_self));
                return;
            end

            local tabnet = bash.Util.GetPlugin("CTableNet");
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
            if !_self.RegistryID or !_self.TableNet then
                MsgErr("TableNotRegistered", tostring(_self));
                return;
            end

            if !_self.TableNet[domain] then
                MsgErr("NoDomainInTable", domain, tostring(_self));
                return;
            end

            local tabnet = bash.Util.GetPlugin("CTableNet");
            local domInfo = tabnet:GetDomain(domain);
            if !domInfo then
                MsgErr("NilEntry", domain);
                return;
            end

            if CLIENT and !_self.ClientOnly then
                local requestPck = vnet.CreatePacket("CTableNet_Net_ObjRequest");
                requestPck:String(_self.RegistryID);
                requestPck:String(domain);
                requestPck:Table(data);
                requestPck:AddServer();
                requestPck:Send();

                return;
            end

            local ids = {};
            local hookData = {};
            local index = 1;
            local varData;
            local sqlData = {};
            for id, val in pairs(data) do
                varData = tabnet:GetVariable(domain, id);
                if !varData then continue; end

                if varData.Public then
                    _self.TableNet[domain].Public[id] = val;
                else
                    _self.TableNet[domain].Private[id] = val;
                end
                ids[index] = id;
                hookData[id] = val;
                index = index + 1;

                if varData.InSQL then
                    sqlData[id] = val;
                end

                --[[
                if varData.OnSet then
                    varData:OnSet(_self, val);
                end
                ]]
            end

            if SERVER then
                tabnet:NetworkTable(_self.RegistryID, domain, ids);

                if domInfo.StoredInSQL then
                    local db = bash.Util.GetPlugin("CDatabase");
                    db:UpdateRow(domInfo.SQLTable, sqlData, domInfo:GetRowCondition(_self), function(regID, results)
                        MsgLog(LOG_DB, "Updated rows for table %s.", regID);
                    end, _self.RegistryID);
                end

                for id, val in pairs(hookData) do
                    hook.Run(Format("CTableNet_OnSet_%s_%s", domain, id), _self, val);
                end
            end
        end

        if SERVER then
            -- Listener functions.
            -- Add a new listener.
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
            -- Get all listeners.
            meta.GetListeners = function(_self, domain)
                return checkListenerTable(_self, domain);
            end
            -- Remove a listener.
            meta.RemoveListener = function(_self, domain, listener)
                local list = checkListenerTable(_self, domain);
                list.Public[listener] = nil;
                list.Private[listener] = nil;
            end
            -- Clear all listeners.
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
        end

        meta.TableNetFuncsAdded = true;
    end

    MsgDebug(LOG_TABNET, "Registered domain: %s", domain.ID);
    domains[domain.ID] = domain;
    vars[domain.ID] = {};
end

-- Add/edit a variable struct.
function PLUG:AddVariable(var)
    if !var.ID or !var.Domain then
        MsgErr("NilField", "ID/Domain", "var");
        return;
    end
    if !vars[var.Domain] then
        MsgErr("NilEntry", var.Domain);
        return;
    end

    --[[
    if vars[var.Domain][var.ID] then
        MsgErr("DupEntry", var.ID);
        return;
    end
    ]]

    -- Variable fields.
    -- var.ID = var.ID; (Redundant, no default)
    -- var.Domain = var.Domain; (Redundant, no default)

    -- The variable type.
    var.Type = var.Type or "string";
    -- The access scope of the variable.
    var.Public = var.Public or false;
    -- Whether the client can request changes to the variable.
    var.Secure = var.Secure == nil and true or var.Secure;

    if SERVER then
        -- If the variable should be stored in the database.
        var.InSQL = var.InSQL or false;
        if var.InSQL then
            -- The max length (in database field) of the variable.
            var.MaxLength = var.MaxLength or 32;
        end

        -- Charvar functions/hooks.
        var.OnGenerate = var.OnGenerate or DEFAULTS[var.Type];
        -- var.OnInit = var.OnInit; (Redundant, no default)
        -- var.OnDeinit = var.OnDeinit; (Redundant, no default)
    elseif CLIENT then
        -- Client doesn't need to know about these.
        var.OnGenerate = nil;
        var.OnInit = nil;
        var.OnDeinit = nil;
    end

    MsgDebug(LOG_TABNET, "Registered netvar %s in domain %s.", var.ID, var.Domain);
    vars[var.Domain][var.ID] = var;

    if SERVER and var.InSQL then
        local domInfo = domains[var.Domain];
        if !domInfo.StoredInSQL then return; end

        local db = bash.Util.GetPlugin("CDatabase");
        db:AddColumn(domInfo.SQLTable, {
            Name = var.ID,
            Type = var.Type,
            MaxLength = var.MaxLength
        }, var.PrimaryKey or false);
    end
end

-- Get a domain struct.
function PLUG:GetDomain(dom)
    return domains[dom];
end

-- Get a variable struct.
function PLUG:GetVariable(domain, var)
    return vars[domain][var];
end

-- Get all variable structs belonging to a domain.
function PLUG:GetDomainVars(domain)
    return vars[domain];
end

-- Get the registry table.
function PLUG:GetRegistry()
    return registry;
end

-- Get a table from the registry.
function PLUG:GetTable(id)
    return registry[id];
end

-- Check to see if a RegistryID is still registered.
function PLUG:IsRegistered(id, domain)
    if domain then
        return registry[id] != nil and registry[id] != NULL and registry[id].TableNet[domain] != nil;
    else
        return registry[id] != nil and registry[id] != NULL;
    end
end

-- Check to see if the registry is empty.
function PLUG:IsRegistryEmpty()
    return table.IsEmpty(registry);
end

-- Create a new instance of a networked table.
function PLUG:NewTable(domain, data, obj, regID)
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

    if SERVER then runInits(tab, domain, TAB_INIT); end
    hook.Run("CTableNet_OnTableCreate", tab, domain);
    return tab;
end

-- Remove a table from the registry.
function PLUG:RemoveTable(id, domain)
    local tab = registry[id];
    if !tab then return; end
    if !tab.TableNet then return; end
    if !tab.TableNet[domain] then return; end

    MsgDebug(LOG_TABNET, "Removing table from TableNet with domain %s. (%s)", domain, id);

    if SERVER then runInits(tab, domain, TAB_DEINIT); end
    hook.Run("CTableNet_OnTableRemove", tab, domain);

    if SERVER then
        local removePck = vnet.CreatePacket("CTableNet_Net_ObjOutOfScope");
        removePck:String(id);
        removePck:String(domain);
        removePck:Broadcast();
        tab:ClearListeners(domain);
    end

    tab.TableNet[domain] = nil;
    if table.IsEmpty(tab.TableNet) then
        registry[id] = nil;
        tab.RegistryID = nil;
    end

    if singlesMade[domain] then
        singlesMade[domain] = nil;
    end
end

-- Get a netvar from a single table.
function PLUG:GetNetVars(domain, ids)
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

-- Set a netvar from a single table.
function PLUG:SetNetVars(domain, data)
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
