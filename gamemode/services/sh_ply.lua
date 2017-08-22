defineService_start("CPlayer");

-- Service info.
SVC.Name = "Core Player";
SVC.Author = "LilSumac";
SVC.Desc = "The main player functions for /bash/.";
SVC.Depends = {"CDatabase"};

-- Service storage.
SVC.PlyVars = {};

function SVC:AddPlyVar(var)

end

-- Hooks.
hook.Add("EditDatabase", "CPlayer_AddTables", function()
    local db = getService("CDatabase");
    db:AddTable("bash_plys", REF_PLY);
    db:AddColumn("bash_plys", {
        ["Name"] = "Name",
        ["Type"] = "string",
        ["Default"] = "Steam Name"
    });
    db:AddColumn("bash_plys", {
        ["Name"] = "NewPlayer",
        ["Type"] = "boolean",
        ["Default"] = true
    });
    db:AddColumn("bash_plys", {
        ["Name"] = "FirstLogin",
        ["Type"] = "number"
    });
    db:AddColumn("bash_plys", {
        ["Name"] = "Addresses",
        ["Type"] = "table"
    });
end);

hook.Add("OnPlayerInit", "CPlayer_OnPlayerInit", function(ply)
    local db = getService("CDatabase");
    db:InsertRow("bash_plys", {
        ["SteamID"] = ply:SteamID(),
        ["Name"] = ply:Name(),
        ["NewPlayer"] = 0,
        ["FirstLogin"] = os.time(),
        ["Addresses"] = {[ply:IPAddress()] = true}
    });
    db:GetRow(
        "bash_plys", "SteamID, Name",
        Format("SteamID = \'%s\'", ply:SteamID())
    );
    db:UpdateRow("bash_plys", {
        ["SteamID"] = "poop",
        ["Name"] = "bap"
    }, "EntryNum = 6");
end);

defineService_end();
