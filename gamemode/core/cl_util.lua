local bash = bash;

function addClientData(id, generate)
    if !id or !generate then
        MsgErr("NilArgs", "id/generate");
        return;
    end

    bash.clientData = bash.clientData or {};
    if bash.clientData[id] then
        MsgErr("DupEntry", id);
        return;
    end

    bash.clientData[id] = generate;
end

function sendClientData()
    local send = vnet.CreatePacket("bash_sendClientData");
    local data = {};
    for id, generate in pairs(bash.clientData) do
        data[id] = handleFunc(generate);
    end

    send:Table(data);
    send:AddServer();
    send:Send();
end
