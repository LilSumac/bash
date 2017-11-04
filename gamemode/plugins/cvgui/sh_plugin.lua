--[[
    CTask plugin file.
]]

-- Start plugin definition.
definePlugin_start("CVGUI");

-- Plugin info.
PLUG.Name = "Core VGUI";
PLUG.Author = "LilSumac";
PLUG.Desc = "Simple framework for implementing code-based tasks with progress, feedback, and callbacks.";

if CLIENT then

    --
    -- Constants.
    --

    -- Color scheme.
    SCHEME_BASH = {};
    SCHEME_BASH["TopBar"] = Color(32, 34, 37);
    SCHEME_BASH["ButtonPassive"] = Color(32, 34, 37);
    SCHEME_BASH["ButtonHover"] = Color(42, 44, 47);
    SCHEME_BASH["ButtonTextPassive"] = Color(165, 166, 167);
    SCHEME_BASH["ButtonTextHover"] = Color(255, 255, 255);
    SCHEME_BASH["ButtonClose"] = Color(240, 71, 71);

    --
    -- Misc. operations.
    --

    surface.CreateFont("cvgui-title", {
        font = "Courier New",
        size = 18,
        weight = 400
    });

end

-- Process plugin contents.
bash.Util.ProcessDir("vgui");

-- End plugin definition.
definePlugin_end();
