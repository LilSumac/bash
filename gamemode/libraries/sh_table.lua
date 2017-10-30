--[[
    Base 'table' library extentions.
]]

local next = next;
local table = table;
local type = type;

function table.IsEmpty(tab)
    if !tab or type(tab) != "table" then return false; end
    return next(tab) == nil;
end
