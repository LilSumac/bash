defineMeta_start("Character");

function META:SetData(data)
    self.Data = {};
    for key, val in pairs(data) do
        self.Data[key] = val;
    end
end

function META:Get(vars)
    if !vars then
        MsgErr("NilArgs", "vars");
        return;
    end

    if type(vars) != "table" then
        vars = {vars};
    end

    self.Data = self.Data or {};
    local cchar = getService("CCharacter");
    local charvar;
    local vals = {};
    for index, var in ipairs(vars) do
        charvar = cchar.CharVars[var];
        if !charvar then
            MsgErr("NilEntry", var);
            continue;
        end

        if charvar.OnGet then
            vals[index] = charvar:OnGet(self);
        else
            vals[index] = self.Data[var];
        end

        if vals[index] == nil then
            if type(charvar.Default) == "function" then
                vals[index] = charvar:Default(self);
            else
                vals[index] = charvar.Default;
            end
        end
    end

    return unpack(vals);
end

function META:Set(data)
    if !data then
        MsgErr("NilArgs", "data");
        return;
    end

    self.Data = self.Data or {};
    local cchar = getService("CCharacter");
    local charvar;
    for var, val in pairs(data) do
        charvar = cchar.CharVars[var];
        if !charvar then
            MsgErr("NilEntry", var);
            continue;
        end

        if charvar.OnSet then
            self.Data[var] = charvar:OnSet(self, val);
        else
            self.Data[var] = val;
        end

        if self.Data[var] == nil then
            if type(charvar.Default) == "function" then
                self.Data[var] = charvar:Default(self);
            else
                self.Data[var] = charvar.Default;
            end
        end
    end
end

function META:AttachTo(ent)
    local old = (IsValid(self.Owner) and self.Owner) or nil;
    self.Owner = ent;
    self:OnDetach(old, self.Owner);
end

function META:Save()
    // take data and push to DB

    self:OnSave();
end

function META:OnDetach(old, new)
    // hook for when changing owners

    MsgCon(color_orange, "Switched character (%s) owner from '%s' to '%s'.", self.CharID, tostring(old), tostring(new));
end

function META:OnSave()
    // hook for saving
end

defineMeta_end();
