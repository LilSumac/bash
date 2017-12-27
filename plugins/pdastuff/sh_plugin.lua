MsgN("PDA SHIT ADDED");
PLUGIN.Name = "PDA";
PLUGIN.Depends = {"memers", "othershit", "bleep"};

function PLUGIN:PluginBullshit(msg)
    MsgN(msg .. " from PDA!");
end

hook.Add("TableUpdate", "PDA_TestingTableUpdate", function(regID, id, val)

end);
