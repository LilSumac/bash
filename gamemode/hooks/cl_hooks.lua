--[[
    Client base gamemode hooks.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local bash          = bash;
local LocalPlayer   = LocalPlayer;
local MsgDebug      = MsgDebug;
local ScrH          = ScrH;
local ScrW          = ScrW;

-- Boolean for resolution-change hook.
local resChanged = false;

--
-- Gamemode hooks.
--

-- Send client data if client was too quick (unlikely).
hook.Add("InitPostEntity", "bash_DelayedClientInit", function()
    if bash.WaitForPostInit then
        MsgDebug(LOG_INIT, "Contacting server...");
        bash.Util.SendClientData();
        bash.WaitForPostInit = false;
        bash.ServerResponded = false;
    end
end);

-- Let the server know we're ready.
-- This marks the beginning of the client-side initialization process.
hook.Add("PostInit_Base", "bash_ClientInit", function()
    -- If InitPostEntity has not occured yet, postpone until then.
    if !isplayer(LocalPlayer()) then
        bash.WaitForPostInit = true;
        return;
    end

    -- Otherwise, contact the server.
    MsgDebug(LOG_INIT, "Contacting server...");
    bash.Util.SendClientData();
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
    hook.Run("ServerResponded");
end);
