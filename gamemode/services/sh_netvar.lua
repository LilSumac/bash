defineService_start("CNetVar");

-- Service info.
SVC.Name = "Core NetVar";
SVC.Author = "LilSumac";
SVC.Desc = "The main functionality for networked variables.";
SVC.Depends = {"CDatabase"};

-- Service storage.
SVC.Domains = {};
SVC.Vars = {};

function SVC:AddDomain(dom)
    if !dom then
        MsgErr("NilArgs", "dom");
        return;
    end
    if !dom.ID then
        MsgErr("NilField", "ID", "dom");
        return;
    end
    if self.Domains[dom] then
        MsgErr("DupEntry", dom);
        return;
    end

    -- Domain fields.
    --
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

    if self.Vars[var.ID] then
        MsgErr("DupEntry", var.ID);
        return;
    end

    -- Charvar fields.
    -- var.ID = var.ID; (Redundant, no default)
end

defineService_end();
