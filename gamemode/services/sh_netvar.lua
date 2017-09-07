defineService_start("CMetaNet");

-- Service info.
SVC.Name = "Core MetaNet";
SVC.Author = "LilSumac";
SVC.Desc = "The main functionality for networked variables attached to objects.";
SVC.Depends = {"CDatabase"};

-- Service storage.
SVC.Domains = {};
SVC.Vars = {};
SVC.Registry = {};
SVC.Entries = {};

function SVC:AddDomain(dom)
    if !dom then
        MsgErr("NilArgs", "dom");
        return;
    end
    if !dom.ID or !dom.ParentMeta then
        MsgErr("NilField", "ID/ParentMeta", "dom");
        return;
    end
    if self.Domains[dom.ID] then
        MsgErr("DupEntry", dom.ID);
        return;
    end

    -- Domain fields.
    -- dom.ID = dom.ID; (Redundant, no default)
    -- dom.ParentMeta = dom.ParentMeta; (Redundant, no default)

    dom.StoredInSQL = dom.StoredInSQL or false;
    if dom.StoredInSQL and !dom.SQLTable then
        MsgErr("NilField", "SQLTable");
        return;
    end

    local meta = dom.ParentMeta;
    if !meta.GetNetVar or !meta.SetNetVar then
        meta.GetNetVar = function(_self, dom, id)
            if !dom or !id then
                MsgErr("NilArgs", "dom/id");
                return;
            end

            if !_self.RegistryID or !_self.MetaNet then
                MsgErr("MetaNotRegistered", tostring(_self));
                return;
            end

            if !_self.MetaNet[dom] then
                MsgErr("NoDomainInMeta", dom);
                return;
            end

            local netvar = getService("CNetVar");
            if !netvar.Domains[dom] then
                MsgErr("NilEntry", dom);
                return;
            end

            local var = netvar.Vars[dom][id];
            if !var then
                MsgErr("NilEntry", varID);
                return;
            end

            local regID = _self.RegistryID;
            if !regID or !netvar.Entries[regID] then
                MsgErr("NilNetData", tostring(_self));
                return;
            end

            return var.Entries[regID][dom][id];
        end
        meta.SetNetVar = function(_self, dom, id, val)
            if !dom or !id or val == nil then
                MsgErr("NilArgs", "dom/id/val");
                return;
            end

            local netvar = getService("CNetVar");
            if !netvar.Domains[dom] then
                MsgErr("NilEntry", dom);
                return;
            end

            local var = netvar.Vars[dom][id];
            if !var then
                MsgErr("NilEntry", varID);
                return;
            end

            local regID = _self.RegistryID;
            if !regID or !netvar.Entries[regID] then
                MsgErr("NilNetData", tostring(_self));
                return;
            end

            var.Entries[regID][dom][id] = val;
        end
    end

    self.Vars[dom.ID] = self.Vars[dom.ID] or {};
    self.Domains[dom.ID] = dom;
    MsgCon(color_lightblue, "Adding metanet domain with the ID '%s'.", dom.ID);
end

function SVC:AddVar(var)
    if !var then
        MsgErr("NilArgs", "var");
        return;
    end
    if !var.ID then
        MsgErr("NilField", "ID", "var");
        return;
    end
    if !var.Domain then
        MsgErr("NilField", "Domain", "var");
        return;
    end
    if !self.Domains[var.Domain] then
        MsgErr("NilDomain", var.Domain);
        return;
    end
    if self.Vars[var.Domain][var.ID] then
        MsgErr("DupEntry", var.ID);
        return;
    end

    -- Netvar fields.
    -- var.ID = var.ID; (Redundant, no default)
    -- var.Domain = var.Domain; (Redundant, no default)
    var.Type = var.Type or "string";
    var.Public = var.Public or false;
    var.InSQL = var.InSQL or false;

    -- Netvar functions/hooks.
    var.OnGenerate = var.OnGenerate or DEFAULTS[var.Type];
end

function SVC:GetDomainVars(dom)
    if !dom then
        MsgErr("NilArgs", "dom");
        return;
    end
    if !self.Domains[dom] then
        MsgErr("NilDomain", dom);
        return;
    end

    return self.Vars[dom];
end

function SVC:RegisterMeta(meta)
    if !meta then
        MsgErr("NilArgs", "meta");
        return;
    end

    local newID = randomString(16, CHAR_HEX);
    while self.Registry[newID] do
        newID = randomString(16, CHAR_HEX);
    end

    meta.RegistryID = newID;
    self.Registry[newID] = meta;

    MsgCon(color_lightblue, "Metatable registered with ID '%s'. Distributing to clients...", type(meta), newID);


end

-- Custom errors.
addErrType("NilDomain", "No network domain exists with that name! (%s)");
addErrType("ObjNotRegistered", "This object is not registered! (%s)");

defineService_end();
