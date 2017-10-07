-- Server-side Gamemode Hooks

vnet.Watch("bash_clientInit", function(pck)
    local ply = pck.Source;

    hook.Call("PrePlayerInit", bash, ply);
    ply.Initialized = true;
    hook.Call("OnPlayerInit", bash, ply);
    hook.Call("PostPlayerInit", bash, ply);
end);
