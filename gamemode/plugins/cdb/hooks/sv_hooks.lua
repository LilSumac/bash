-- Hooks.
hook.Add("bash_InitService_Base", "CDatabase_OnInit", function()
    local db = getService("CDatabase");
    if db:IsConnected() then
        MsgLog(LOG_DB, "Database still connected, skipping.");
        return;
    end

    db:Connect();
end);
