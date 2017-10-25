defineService_start("CPlayer");

-- Service info.
SVC.Name = "Core Player";
SVC.Author = "LilSumac";
SVC.Desc = "The main player management functions.";

-- Process scope-dependent files.
processFile("sv_ply.lua");

defineService_end();
