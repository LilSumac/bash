-- Server-side Gamemode Hooks

vnet.Watch("bash_clientInit", function(pck)
    local ply = pck.Source;

    hook.Call("PrePlayerInit", bash, ply);
    ply.InitReceived = true;
    hook.Call("OnPlayerInit", bash, ply);

    timer.Simple(5, function()
        bash.testing:SetNetVar("Char", "Name", "big nerd");
    end);
end);
