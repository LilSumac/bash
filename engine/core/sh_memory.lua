--[[
    Persistant memory functions.
]]

--
-- Local storage.
--

local bash          = bash;
local handleFunc    = handleFunc;

--
-- Global storage.
--

bash.Memory             = bash.Memory or {};
bash.Memory.NonVolatile = bash.Memory.NonVolatile or {};

--
-- Memory functions.
--

-- Fetch a non-volatile memory entry, or a default value.
function bash.Memory.GetNonVolatile(id, def)
    local val = bash.Memory.NonVolatile[id];
    if val == nil then
        bash.Memory.NonVolatile[id] = def;
        return handleFunc(def);
    else
        return handleFunc(val);
    end
end

-- Sets the value of a non-volatile memory entry.
function bash.Memory.SetNonVolatile(id, val)
    bash.Memory.NonVolatile[id] = val;
end
