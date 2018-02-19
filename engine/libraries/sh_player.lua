--[[
    Base 'player' library extentions.
]]

--
-- Local storage.
--

local next = next;
local table = table;
local type = type;

--
-- Player functions.
--

-- Get a table of all players as keys.
function player.GetAllAsKeys()
    local plys = {};
    for _, ply in pairs(player.GetAll()) do
        plys[ply] = true;
    end
    return plys;
end

-- Get a table of all initialized players as values.
function player.GetInitialized()
    local plys = {};
    for _, ply in pairs(player.GetAll()) do
        if ply.Initialized then
            plys[#plys + 1] = ply;
        end
    end
    return plys;
end

-- Get a table of all initialized players as keys.
function player.GetInitializedAsKeys()
    local plys = {};
    for _, ply in pairs(player.GetAll()) do
        if ply.Initialized then
            plys[ply] = true;
        end
    end
    return plys;
end