local player = player;

function player.GetInitialized()
    local plys = {};
    for _, ply in pairs(player.GetAll()) do
        if ply.Initialized then
            plys[#plys + 1] = ply;
        end
    end
    return plys;
end

function player.GetAllAsKeys()
    local plys = {};
    for _, ply in pairs(player.GetAll()) do
        plys[ply] = true;
    end
    return plys;
end

function player.GetInitializedAsKeys()
    local plys = {};
    for _, ply in pairs(player.GetAll()) do
        if ply.Initialized then
            plys[ply] = true;
        end
    end
    return plys;
end
