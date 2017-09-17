-- Client-side Gamemode Hooks

-- Handle sending initial client data.
hook.Add("InitPostEntity", "bash_sendClientData", function()
    sendClientData();
end);

-- Let the server know we're ready.
hook.Add("PostInit_Base", "bash_ClientInit", function()
    timer.Simple(2, function()
        MsgCon(color_green, "Contacting server...");
        local init = vnet.CreatePacket("bash_clientInit");
        init:AddServer();
        init:Send();
    end);
end);
