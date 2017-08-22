-- Server-side Gamemode Hooks

vnet.Watch("bash_clientInit", function(pck)
    local ply = pck.Source;
    hook.Call("OnPlayerInit", bash, ply);
end);
