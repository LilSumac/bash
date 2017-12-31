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

-- Swap a table's keys and values.
function table.SwapKeyValue(tab)
    if !tab or type(tab) != "table" then return; end
    local _tab = {};
    for key, val in pairs(tab) do
        _tab[val] = key;
    end
    return _tab;
end
