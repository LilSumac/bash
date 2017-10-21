GM.Name = BASE_NAME;
GM.Author = "LilSumac";

processDir("external");
processDir("libraries");
processDir("meta");
processDir("services");
processDir("hooks");

processModules();
