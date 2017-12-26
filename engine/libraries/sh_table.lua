--[[
    Base 'table' library extentions.
]]

--
-- Local storage.
--

local next = next;
local table = table;
local type = type;

--
-- Table functions.
--

-- Check to see if a table is empty.
function table.IsEmpty(tab)
    if !tab or type(tab) != "table" then return false; end
    return next(tab) == nil;
end
