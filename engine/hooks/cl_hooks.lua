--[[
    Client engine hooks.
]]

--
-- Local storage.
--

local bash          = bash;
local LocalPlayer   = LocalPlayer;
local MsgDebug      = MsgDebug;
local ScrH          = ScrH;
local ScrW          = ScrW;

local resChanged = false;

--
-- Engine hooks.
--

-- Let the server know we're ready.
hook.Add("InitPostEntity", "bash_ClientInit", function()
    bash.Util.MsgLog(LOG_INIT, "Contacting server...");
    bash.Util.SendClientData(true);
    bash.ServerResponded = false;
end);

-- Detect if the resolution has been changed.
hook.Add("HUDPaint", "bash_ResChanged", function()
    if SCRW != ScrW() then
        SCRW = ScrW();
        resChanged = true;
    end
    if SCRH != ScrH() then
        SCRH = ScrH();
        resChanged = true;
    end
    if resChanged then
        local w, h = SCRW, SCRH;
        CENTER_X = w / 2;
        CENTER_Y = h / 2;
        resChanged = false;
        hook.Run("ResolutionChanged", w, h);
    end
end);

--
-- Network hooks.
--

-- Receive acknowledgement from the server.
-- This marks the end of the client-side initialization process.
vnet.Watch("bash_Net_RespondToClient", function(pck)
    bash.ServerResponded = true;
    hook.Run("ServerResponded");
end);
