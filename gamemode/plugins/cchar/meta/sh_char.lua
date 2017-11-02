--[[
    CChar main metatable.
]]

-- Start meta definition.
defineMeta_start("CChar");

--
-- Local storage.
--

-- Micro-optimizations.
local bash      = bash;
local MsgErr    = MsgErr;
local pairs     = pairs;
local tostring  = tostring;
local type      = type;

--
-- Meta functions.
--

-- Attach a character object to an entity.
function META:AttachTo(ent)
    local old = (IsValid(self.Owner) and self.Owner) or nil;
    self.Owner = ent;
    self:OnDetach(old, self.Owner);
end

-- Push character data to the database.
function META:Save()
    // take data and push to DB

    self:OnSave();
end

-- Called when a character is detached from an entity.
function META:OnDetach(old, new)
    // hook for when changing owners

    MsgLog(LOG_CHAR, "Switched character (%s) owner from '%s' to '%s'.", self.CharID, tostring(old), tostring(new));
end

-- Called when a character is saved.
function META:OnSave()
    // hook for saving
end

-- End meta definition.
defineMeta_end();
