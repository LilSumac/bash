--[[
    iext2 character extensions.
]]

--
-- Local storage.
--

local bash = bash;

local LOG_CHAR = {pre = "[CHAR]", col = color_limegreen};

local Entity = FindMetaTable("Entity");
local Player = FindMetaTable("Player");

--
-- Plugin storage.
--

function