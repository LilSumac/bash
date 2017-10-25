-- Network hooks.
vnet.Watch("CPlayer_Net_RespondClient", function(pck)
    bash.serverResponded = true;
    LocalPlayer().Initialized = true;
    MsgLog(LOG_INIT, "Received response from server! Successfully initialized.");
end);
