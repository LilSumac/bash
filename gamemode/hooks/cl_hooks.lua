-- Client-side Gamemode Hooks

function GM:InitPostEntity()
    timer.Simple(5, function()
        local init = vnet.CreatePacket("bash_clientInit");
        init:AddServer();
        init:Send();
    end);
end
