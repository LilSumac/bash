-- Server-side Gamemode Hooks

vnet.Watch("bash_clientInit", function(pck)
    local ply = pck.Source;

    hook.Call("PrePlayerInit", bash, ply);
    hook.Call("OnPlayerInit", bash, ply);
    ply.Initialized = true;
    hook.Call("PostPlayerInit", bash, ply);

    timer.Simple(5, function()
        bash.testing:SetNetVar("Char", "Name", "big nerd");
    end);
end);
