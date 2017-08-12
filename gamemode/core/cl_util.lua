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
