defineService_start("CCharacter");

-- Service info.
SVC.Name = "Core Character";
SVC.Author = "LilSumac";
SVC.Desc = "The main character functions for /bash/.";
SVC.Depends = {"CDatabase"};

-- Service storage.
SVC.CharVars = {};
SVC.CachedData = getNonVolatileEntry("CCharacter_DataCache", EMPTY_TABLE);
SVC.CachedChars = getNonVolatileEntry("CCharacter_CharCache", EMPTY_TABLE);
SVC.CachedIDs = {};

function SVC:AddCharVar(var)
    if !var then
        MsgErr("NilArgs", "var");
        return;
    end
    if !var.ID then
        MsgErr("NilField", "ID", "var");
        return;
    end
    if self.CharVars[var.ID] then
        MsgErr("DupEntry", var.ID);
        return;
    end

    -- Charvar fields.
    -- var.ID = var.ID; (Redundant, no default)
    var.Type = var.Type or "string";
    var.Public = var.Public or false;
    var.BelongsInSQL = var.BelongsInSQL or false;

    -- Charvar functions/hooks.
    var.OnGenerate = var.OnGenerate or DEFAULTS[var.Type];
    -- var.OnGet = var.OnGet; (Redundant, no default)
    -- var.OnSet = var.OnSet; (Redundant, no default)

    MsgCon(color_green, "Registering charvar: %s", var.ID);
    self.CharVars[var.ID] = var;
end

function SVC:PostDBFetch(data)
    MsgCon(color_green, "Completed character fetch: %s", data.CharID);

    self.CachedData[data.CharID] = data;
    local name = "CharFetch_" .. data.CharID;
    hook.Call(name, self, data.CharID);
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
        MsgCon(color_orange, "Hooking character fetch: %s", id);

        local name = "CharFetch_" .. id;
        hook.Add(name, self, self.Instantiate);

        local db = getService("CDatabase");
        db:FetchCharacter(id);
        return;
    elseif self.CachedChars[id] then
        -- a char instance already exists
    elseif self.CachedData[id] then
        -- data has already been fetched
        -- take data and push to new instance

        MsgCon(color_green, "Instantiating character: %s", id);

        local charMeta = getMeta("Character");
        local char = setmetatable({}, charMeta);
        char.CharID = id;
        char.Data = self.CachedData[id];
        return char;
    end

    MsgCon(color_orange, "Removing character fetch hook: %s", id);
    local name = "CharFetch_" .. id;
    hook.Remove(name, self);
end

-- Add default charvars.
SVC:AddCharVar{
    ID = "CharID",
    Type = "string",
    OnGenerate = function() end,
    OnSet = function(_self, char, val)
        char.CharID = val;
        return val;
    end
};

SVC:AddCharVar{
    ID = "Name"
};

SVC:AddCharVar{
    ID = "Desc"
};

-- Hooks.
hook.Add("EditDatabase", "CCharacter_AddTables", function()
    local db = getService("CDatabase");
    db:AddTable("bash_chars", REF_CHAR);
end);

hook.Add("OnDBConnected", "CCharacter_OnDBConnected", function()
    local db = getService("CDatabase");
    db:Query("SELECT CharID FROM bash_chars;", function(results)
        local ids = {};
        local cchar = getService("CCharacter");

        results = results[1];
        for index, data in pairs(results.data) do
            ids[data.CharID] = true;
        end
        cchar.CachedIDs = ids;
    end);
end);

defineService_end();
