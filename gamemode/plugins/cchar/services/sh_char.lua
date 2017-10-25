defineService_start("CChar");

-- Service info.
SVC.Name = "CChar";
SVC.Author = "LilSumac";
SVC.Desc = "A framework that provides a character system.";

-- Add scope-dependent files.
processFile("sv_char.lua");

defineService_end();
