defineService_start("CTableNet");

-- Service info.
SVC.Name = "Core TableNet";
SVC.Author = "LilSumac";
SVC.Desc = "A framework for creating, networking, and adding persistant variables to tables and objects.";
SVC.Depends = {"CDatabase"};

-- Service storage.
SVC.Domains = {};
SVC.Vars = {};
SVC.Registry = getNonVolatileEntry("CTableNet_Registry", EMPTY_TABLE);

function SVC:AddDomain(domain)
    if !domain then
        MsgErr("NilArgs", "domain");
        return;
    end
    if !domain.ID then
        MsgErr("NilField", "ID", "domain");
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
        MsgErr("NilField", "SQLTable", "domain");
        return;
    end

    domain.SingleTable = domain.SingleTable or false;

    local meta = domain.ParentMeta;
    if meta and !meta.GetNetVar then
        meta.GetNetVar = function(_self, domain, id)
            if !domain or !id then
                MsgErr("NilArgs", "domain/id");
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
            if !tablenet.Domains[domain] then
                MsgErr("NilEntry", domain);
                return;
            end

            local var = tablenet.Vars[domain][id];
            if !var then
                MsgErr("NilEntry", id);
                return;
            end

            -- add onGet?
            return _self.TableNet[domain][id];
        end
    end
    if SERVER and meta and !meta.SetNetVar then
        meta.SetNetVar = function(_self, domain, id, val)
            if !domain or !id or val == nil then
                MsgErr("NilArgs", "domain/id/val");
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
            if !tablenet.Domains[domain] then
                MsgErr("NilEntry", domain);
                return;
            end

            local var = tablenet.Vars[domain][id];
            if !var then
                MsgErr("NilEntry", id);
                return;
            end

            -- add onSet?
            _self.TableNet[domain][id] = val;
            tablenet:NetworkTable(_self.RegistryID, domain, id);
        end
    end

    domain.GetRecipients = domain.GetRecipients or function(_self, obj)
        return player.GetAll();
    end
    domain.GetPrivateRecipients = domain.GetPrivateRecipients or function(_self, obj)
        return;
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

    MsgCon(color_green, "Registering netvar %s in domain %s.", var.ID, var.Domain);
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

function SVC:NewTableNet(domain, data, obj)
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
    for id, var in pairs(self.Vars[domain]) do
        if data[id] != nil then
            _data[id] = data[id];
        else
            _data[id] = handleFunc(var.OnGenerate, var, tab);
        end
    end

    tab.TableNet = tab.TableNet or {};
    tab.TableNet[domain] = _data;

    if !tab.RegistryID then
        local id = randomString(8, CHAR_ALL);
        while self.Registry[id] do
            id = randomString(8, CHAR_ALL);
        end
        tab.RegistryID = id;
        self.Registry[id] = tab;
    end

    MsgCon(color_blue, "Registering table in TableNet with domain %s. (%s)", domain, tostring(tab));

    if SERVER then self:NetworkTable(tab, domain); end
    return tab;
end

-- Custom errors.
addErrType("TableNotRegistered", "This table has not been registered in TableNet! (%s)");
addErrType("NoDomainInTable", "No domain with that ID exists in that table! (%s -> %s)");

function SVC:GetNetVar(domain, )

if SERVER then

    -- Network pool.
    util.AddNetworkString("CTableNet_PreSendObjs");
    util.AddNetworkString("CTableNet_SendObjs");
    util.AddNetworkString("CTableNet_CreateObj");
    util.AddNetworkString("CTableNet_UpdateObj");

    util.AddNetworkString("CTableNet_ObjCount");
    util.AddNetworkString("CTableNet_ObjUpdate");
    util.AddNetworkString("CTableNet_ObjOutOfScope");

    -- Functions.
    function SVC:NetworkTable(id, domain, var)
        if !id or !domain then
            MsgErr("NilArgs", "id/domain");
            return;
        end
        if !self.Registry[id] then
            MsgErr("NilEntry", id);
            return;
        end
        if !self.Domains[domain] then
            MsgErr("NilEntry", "domain");
            return;
        end
        local domInfo = self.Domains[domain];

        local tab = self.Registry[id];
        if !tab.RegistryID or !tab.TableNet then
            MsgErr("TableNotRegistered", tostring(tab));
            return;
        end
        if !tab.TableNet[domain] then
            MsgErr("NoDomainInTable", domain, tostring(tab));
            return;
        end

        local pubPack = vnet.CreatePacket("CTableNet_ObjUpdate");
        local privPack = vnet.CreatePacket("CTableNet_ObjUpdate");
        pubPack:String(tab.RegistryID);
        pubPack:String(domain);
        privPack:String(tab.RegistryID);
        privPack:String(domain);

        local public = {};
        local private = {};
        local val;
        if var then
            local varData;
            if type(var) == "table" then
                for _, _var in pairs(var) do
                    varData = self.Vars[domain][_var];
                    if !varData then
                        MsgErr("NilEntry", "_var");
                        continue;
                    end

                    val = tab.TableNet[domain][_var];
                    private[_var] = val;
                    if var.Public then
                        public[_var] = val;
                    end
                end
            else
                varData = self.Vars[domain][var];
                if !varData then
                    MsgErr("NilEntry", "id");
                else
                    private[var] = tab.TableNet[domain][var];
                end
            end
        else
            for _id, _var in pairs(self.Vars[domain]) do
                val = tab.TableNet[domain][_var];
                if val != nil then
                    private[_var] = val;
                    if _var.Public then
                        public[_var] = val;
                    end
                end
            end
        end

        local recip;
        pubPack:Table(public);
        privPack:Table(private);
        if isentity(tab) or isplayer(tab) then
            pubPack:Bool(true);
            pubPack:Entity(tab);
            privPack:Bool(true);
            privPack:Entity(tab);
        else
            pubPack:Bool(false);
            privPack:Bool(false);
        end

        recip = domain:GetRecipients(tab);
        if #recip == 0 then
            pubPack:Discard();
        else
            pubPack:AddTargets(recip);
            pubPack:Send();
        end

        recip = domain:GetPrivateRecipients(tab);
        if #recip == 0 then
            privPack:Discard();
        else
            privPack:AddTargets(recip);
            privPack:Send();
        end
    end

    function SVC:SendTable(ply, id, domain)
        if !isplayer(ply) then
            MsgErr("InvalidPly");
            return;
        end
        if !id or !domain then
            MsgErr("NilArgs", "id/domain");
            return;
        end
    end

    -- Hooks.
    hook.Add("OnPlayerInit", "CTableNet_SendObjs", function(ply)
        local tablenet = getService("CTableNet");

        net.Start("CTableNet_ObjCount");
            net.WriteInt(table.Count(tablenet.Registry), 8);
        net.Send(ply);

        local delay = 0.1;
        for id, obj in pairs(tablenet.Registry) do
            for dom, vars in pairs(obj.TableNet) do
                timer.Simple(delay, function()
                    local metaPack = vnet.CreatePacket("CTableNet_CreateObj");
                    metaPack:String(id);
                    metaPack:String(dom);

                    local netData = {};
                    for _id, val in pairs(vars) do
                        if tablenet.Vars[dom][_id].Public then
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

    net.Receive("CTableNet_PreSendObjs", function(len)
        local tablenet = getService("CTableNet");
        local objs = net.ReadInt(8);
        tablenet.InitialSend = true;
        tablenet.WaitingOn = objs;
        tablenet.Received = 0;
        MsgCon(color_blue, "Waiting on %d networked objects...", objs);
    end);

    vnet.Watch("CTableNet_CreateObj", function(pck)
        local regID = pck:String();
        local domain = pck:String();
        local data = pck:Table();
        local obj;
        if pck:Bool() then
            obj = pck:Entity();
        end

        local tablenet = getService("CTableNet");
        local domInfo = tablenet.Domains[domain];
        local tab;
        if !obj then
            tab = setmetatable({}, domInfo.ParentMeta);
        else
            tab = obj;
        end

        tab.TableNet = tab.TableNet or {};
        tab.TableNet[domain] = data;

        tab.RegistryID = regID;
        tablenet.Registry[regID] = tab;

        if tablenet.InitialSend then
            tablenet.Received = tablenet.Received + 1;
            if tablenet.Received == tablenet.WaitingOn then
                MsgCon(color_blue, "Received all networked objects!");
                tablenet.InitialSend = false;
            end
        end
    end);

    vnet.Watch("CTableNet_UpdateObj", function(pck)
        local regID = pck:String();
        local domain = pck:String();
        local id = pck:String();
        local val = pck:Variable();

        local tablenet = getService("CTableNet");
        local obj = tablenet.Registry[regID];
        obj.TableNet[domain][id] = val;
    end);

end

defineService_end();
