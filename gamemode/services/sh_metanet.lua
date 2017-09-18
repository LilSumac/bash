defineService_start("CMetaNet");

-- Service info.
SVC.Name = "Core MetaNet";
SVC.Author = "LilSumac";
SVC.Desc = "A framework for creating, networking, and adding persistant variables to instance objects.";
SVC.Depends = {"CDatabase"};

-- Service storage.
SVC.Domains = {};
SVC.Vars = {};
SVC.Registry = getNonVolatileEntry("CMetaNet_Registry", EMPTY_TABLE);

function SVC:AddDomain(domain)
    if !domain then
        MsgErr("NilArgs", "domain");
        return;
    end
    if !domain.ID or !domain.ParentMeta then
        MsgErr("NilField", "ID/ParentMeta", "domain");
        return;
    end
    if self.Domains[domain.ID] then
        MsgErr("DupEntry", domain.ID);
        return;
    end

    -- Domain fields.
    -- domain.ID = domain.ID; (Redundant, no default)
    -- domain.ParentMeta = domain.ParentMeta; (Redundant, no default);
    domain.StoredInSQL = domain.StoredInSQL or false;
    if domain.StoredInSQL and !domain.SQLTable then
        MsgErr("NilField", "SQLTable");
        return;
    end

    local meta = domain.ParentMeta;
    if !meta.GetNetVar then
        meta.GetNetVar = function(_self, domain, id)
            if !domain or !id then
                MsgErr("NilArgs", "domain/id");
                return;
            end

            if !_self.RegistryID or !_self.MetaNet then
                MsgErr("MetaNotRegistered", tostring(_self));
                return;
            end

            if !_self.MetaNet[domain] then
                MsgErr("NoDomainInMeta", domain);
                return;
            end

            local netvar = getService("CMetaNet");
            if !netvar.Domains[domain] then
                MsgErr("NilEntry", domain);
                return;
            end

            local var = netvar.Vars[domain][id];
            if !var then
                MsgErr("NilEntry", id);
                return;
            end

            -- add onGet?
            return _self.MetaNet[domain][id];
        end
    end
    if SERVER and !meta.SetNetVar then
        meta.SetNetVar = function(_self, domain, id, val)
            if !domain or !id or val == nil then
                MsgErr("NilArgs", "domain/id/val");
                return;
            end

            if !_self.RegistryID or !_self.MetaNet then
                MsgErr("MetaNotRegistered", tostring(_self));
                return;
            end

            if !_self.MetaNet[domain] then
                MsgErr("NoDomainInMeta", domain);
                return;
            end

            local netvar = getService("CMetaNet");
            if !netvar.Domains[domain] then
                MsgErr("NilEntry", domain);
                return;
            end

            local var = netvar.Vars[domain][id];
            if !var then
                MsgErr("NilEntry", id);
                return;
            end

            -- add onSet?
            _self.MetaNet[domain][id] = val;

            if var.Public then
                local metaPack = vnet.CreatePacket("CMetaNet_UpdateObj");
                metaPack:String(_self.RegistryID);
                metaPack:String(domain);
                metaPack:String(id);
                metaPack:Variable(val);
                metaPack:Broadcast();
            end
        end
    end

    MsgCon("Registering domain: %s", domain.ID);
    self.Domains[domain.ID] = domain;
    self.Vars[domain.ID] = {};
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
    if !self.Vars[var.Domain] then
        MsgErr("NilEntry", var.Domain);
        return;
    end
    if self.Vars[var.Domain][var.ID] then
        MsgErr("DupEntry", var.ID);
        return;
    end

    -- Variable fields.
    -- var.ID = var.ID; (Redundant, no default)
    -- var.Domain = var.Domain; (Redundant, no default)
    var.Type = var.Type or "string";
    var.Public = var.Public or false;
    if CLIENT and !var.Public then return; end
    var.InSQL = var.InSQL or false;

    -- Charvar functions/hooks.
    var.OnGenerate = var.OnGenerate or DEFAULTS[var.Type];
    -- var.OnGet = var.OnGet; (Redundant, no default)
    -- var.OnSet = var.OnSet; (Redundant, no default)

    MsgCon(color_green, "Registering metavar: %s", var.ID);
    self.Vars[var.Domain][var.ID] = var;
end

function SVC:GetDomainVars(domain)
    if !domain then
        MsgErr("NilArgs", "domain");
        return;
    end

    if !self.Vars[domain] then
        MsgErr("NilEntry", domain);
        return;
    end

    return self.Vars[domain];
end

function SVC:NewMetaNet(domain, data, obj, recip)
    if !domain then
        MsgErr("NilArgs", "domain");
        return;
    end

    local domInfo = self.Domains[domain];
    if !domInfo then
        MsgErr("NilEntry", domain);
        return;
    end

    local tab;
    if !obj then
        tab = setmetatable({}, domInfo.ParentMeta);
    else
        tab = obj;
    end

    data = data or {};
    local _data = {};
    for id, var in pairs(self.Vars[domain]) do
        if data[id] != nil then
            _data[id] = data[id];
        else
            _data[id] = handleFunc(var.OnGenerate, var, tab);
        end
    end

    tab.MetaNet = tab.MetaNet or {};
    tab.MetaNet[domain] = _data;

    if !tab.RegistryID then
        local id = randomString(8, CHAR_ALL);
        while self.Registry[id] do
            id = randomString(8, CHAR_ALL);
        end
        tab.RegistryID = id;
        self.Registry[id] = tab;
    end

    MsgCon(color_blue, "Registering meta in MetaNeta with domain %s. (%s)", domain, tostring(tab));

    if CLIENT then return tab; end

    local metaPack = vnet.CreatePacket("CMetaNet_CreateObj");
    metaPack:String(tab.RegistryID);
    metaPack:String(domain);

    local netData = {};
    for id, var in pairs(self.Vars[domain]) do
        if var.Public then
            netData[id] = _data[id];
        end
    end
    metaPack:Table(netData);

    if obj and (isentity(obj) or isplayer(obj)) then
        metaPack:Bool(true);
        metaPack:Entity(obj);
    else
        metaPack:Bool(false);
    end

    if recip then
        metaPack:AddTargets(recip);
        metaPack:Send();
    else
        recip = {};
        for _, ply in pairs(player.GetAll()) do
            if ply.Initialized then
                recip[#recip + 1] = ply;
            end
        end
        if #recip == 0 then
            metaPack:Discard();
        else
            metaPack:AddTargets(recip);
            metaPack:Send();
        end
    end

    return tab;
end

if SERVER then

    -- Network pool.
    util.AddNetworkString("CMetaNet_PreSendObjs");
    util.AddNetworkString("CMetaNet_SendObjs");
    util.AddNetworkString("CMetaNet_CreateObj");
    util.AddNetworkString("CMetaNet_UpdateObj");

    -- Hooks.
    hook.Add("OnPlayerInit", "CMetaNet_SendObjs", function(ply)
        local metanet = getService("CMetaNet");

        net.Start("CMetaNet_PreSendObjs");
            net.WriteInt(table.Count(metanet.Registry), 8);
        net.Send(ply);

        local delay = 0.1;
        for id, obj in pairs(metanet.Registry) do
            for dom, vars in pairs(obj.MetaNet) do
                timer.Simple(delay, function()
                    local metaPack = vnet.CreatePacket("CMetaNet_CreateObj");
                    metaPack:String(id);
                    metaPack:String(dom);

                    local netData = {};
                    for _id, val in pairs(vars) do
                        if metanet.Vars[dom][_id].Public then
                            netData[_id] = val;
                        end
                    end
                    metaPack:Table(netData);

                    if obj and (isentity(obj) or isplayer(obj)) then
                        metaPack:Bool(true);
                        metaPack:Entity(obj);
                    else
                        metaPack:Bool(false);
                    end

                    metaPack:AddTargets(ply);
                    metaPack:Send();
                end);
                delay = delay + 0.1;
            end
        end
    end);

elseif CLIENT then

    net.Receive("CMetaNet_PreSendObjs", function(len)
        local metanet = getService("CMetaNet");
        local objs = net.ReadInt(8);
        metanet.InitialSend = true;
        metanet.WaitingOn = objs;
        metanet.Received = 0;
        MsgCon(color_blue, "Waiting on %d networked objects...", objs);
    end);

    vnet.Watch("CMetaNet_CreateObj", function(pck)
        local regID = pck:String();
        local domain = pck:String();
        local data = pck:Table();
        local obj;
        if pck:Bool() then
            obj = pck:Entity();
        end

        local metanet = getService("CMetaNet");
        local domInfo = metanet.Domains[domain];
        local tab;
        if !obj then
            tab = setmetatable({}, domInfo.ParentMeta);
        else
            tab = obj;
        end

        tab.MetaNet = tab.MetaNet or {};
        tab.MetaNet[domain] = data;

        tab.RegistryID = regID;
        metanet.Registry[regID] = tab;

        if metanet.InitialSend then
            metanet.Received = metanet.Received + 1;
            if metanet.Received == metanet.WaitingOn then
                MsgCon(color_blue, "Received all networked objects!");
                metanet.InitialSend = false;
            end
        end
    end);

    vnet.Watch("CMetaNet_UpdateObj", function(pck)
        local regID = pck:String();
        local domain = pck:String();
        local id = pck:String();
        local val = pck:Variable();

        local metanet = getService("CMetaNet");
        local obj = metanet.Registry[regID];
        obj.MetaNet[domain][id] = val;
    end);

end

defineService_end();
