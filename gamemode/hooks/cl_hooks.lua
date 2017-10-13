-- Client-side Gamemode Hooks

-- Handle sending initial client data.
hook.Add("InitPostEntity", "bash_Hook_DelayedClientInit", function()
    if bash.waitForPostInit then
        MsgCon(color_green, "Contacting server...");
        sendClientData();
        bash.waitForPostInit = false;
    end
end);

-- Let the server know we're ready.
hook.Add("PostInit_Base", "bash_Hook_ClientInit", function()
    -- If InitPostEntity has not occured yet, postpone until then.
    if LocalPlayer() == NULL then
        bash.waitForPostInit = true;
        return;
    end

    MsgCon(color_green, "Contacting server...");
    sendClientData();
end);
