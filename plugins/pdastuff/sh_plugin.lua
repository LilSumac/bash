MsgN("PDA SHIT ADDED");
PLUGIN.Name = "PDA";
PLUGIN.Depends = {"memers", "othershit", "bleep"};

function PLUGIN:PluginBullshit(msg)
    MsgN(msg .. " from PDA!");
end
