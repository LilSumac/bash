defineService_start("CCharacter");

-- Service info.
SVC.Name = "Core Character";
SVC.Author = "LilSumac";
SVC.Desc = "The main character functions for /bash/.";

-- Service storage.
SVC.CharVars = {};
SVC.CachedData = getNonVolatileEntry("CCharacter_DataCache", EMPTY_TABLE);
SVC.CachedChars = getNonVolatileEntry("CCharacter_CharCache", EMPTY_TABLE);

function SVC:AddCharVar(var)
    if !var then
        MsgErr("NilArgs", "var");
        return;
    end
    if !var.ID then
        MsgErr("FieldReq", "ID", "var");
        return;
    end
    if self.CharVars[var.ID] then
        MsgErr("DupEntry", var.ID);
        return;
    end

    -- Charvar fields.
    var.Default = var.Default or "";
    var.Public = var.Public or false;
    var.BelongsInSQL = var.BelongsInSQL or false;

    -- Charvar functions/hooks.
    -- var.OnGet = var.OnGet;
    -- var.OnSet = var.OnSet;

    MsgCon(color_green, "Registering charvar: %s", var.ID);
    self.CharVars[var.ID] = var;
end

function SVC:FetchFromDB(id)
    -- query db and get char data
    -- store data in datacache
    -- call hook for instantiate

    self.CachedData[id] = {};
    local name = self.Name .. "_FetchDone_" .. id;
    hook.Call(name, self, id);
end

function SVC:Instantiate(id, refresh)
    -- look for data from id in cache
    -- if there, create new char obj and return
    -- else, fetch and hook to id
    -- call hook for finishing instantiate

    if !id then
        MsgErr("NilArgs", "id");
        return;
    end

    local data;
    if refresh or (!self.CachedChars[id] and !self.CachedData[id]) then
        -- data must be fetched

        local name = self.Name .. "_FetchDone_" .. id;
        hook.Add(name, self, self.Instantiate);
        self:FetchFromDB(id);
        return;
    elseif self.CachedChars[id] then
        -- a char instance already exists
    elseif self.CachedData[id] then
        -- data has already been fetched
        -- take data and push to new instance

        local char = {};
        local charMeta = getMeta("Character");
        setmetatable(char, charMeta);
        char.ID = id;
        char.Data = self.CachedData[id];
        return char;
    end

    local name = self.Name .. "_FetchDone_" .. id;
    hook.Remove(name, self);
end

-- Add default charvars.
SVC:AddCharVar{
    ID = "CharID"
};

SVC:AddCharVar{
    ID = "Name"
};

SVC:AddCharVar{
    ID = "Desc"
};

SVC:AddCharVar{
    ID = "Bing",
    OnGet = function(_self, char)
        MsgN("BING GET: " .. tostring(char));
        PrintTable(_self);
        return "nice try small fry";
    end
};

SVC:AddCharVar{
    ID = "Bong",
    OnSet = function(_self, char, val)
        if val != "blap" then
            return "nope";
        end
        return val;
    end
};

defineService_end();
