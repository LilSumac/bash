--[[
    Player management functionality.
]]

--
-- Local storage.
--

local bash      = bash;
local pairs     = pairs;
local player    = player;

--
-- Global storage.
--

bash.Player = bash.Player or {};

--
-- Player functions.
--

-- Old player.GetAll function.
bash.Player.GetAll = player.GetAll;

-- Get a table of all players as keys.
function bash.Player.GetAllAsKeys()
    local plys = {};
    for _, ply in pairs(player.GetAll()) do
        plys[ply] = true;
    end
    return plys;
end

-- Get a table of all initialized players as values.
function bash.Player.GetInitialized()
    local plys = {};
    for _, ply in pairs(player.GetAll()) do
        if ply.Initialized then
            plys[#plys + 1] = ply;
        end
    end
    return plys;
end

-- Get a table of all initialized players as keys.
function bash.Player.GetInitializedAsKeys()
    local plys = {};
    for _, ply in pairs(player.GetAll()) do
        if ply.Initialized then
            plys[ply] = true;
        end
    end
    return plys;
end
