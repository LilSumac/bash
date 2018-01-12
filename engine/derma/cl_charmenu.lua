--[[
    Character menu element.
]]

local CHAR = {};

function CHAR:Init()
    self:SetSize(SCRH * 0.33, SCRH * 0.33);
    self:Center();
    self:MakePopup();
    self:ShowCloseButton(LocalPlayer():GetCharacter() != nil);
    self.WaitingOnChar = false;
    self.WaitingOnDigest = true;

    hook.Add("OnCharacterAttach", "bash_CharMenuWatchForLoad", function(char, ent)
        if ent != LocalPlayer() then return; end
        if !LocalPlayer().WaitingOn then return; end

        if LocalPlayer().WaitingOn == char:Get("CharID") or LocalPlayer().WaitingOn == char:Get("Name") then
            LocalPlayer().WaitingOn = false;
            self:Remove();
        end
    end);

    timer.Simple(5, function()
        bash.Character.RequestDigest();
    end);
end

function CHAR:RepopulateList()
    self:RemoveList();

    self.ListContainer = vgui.Create("DScrollPanel", self);
    self.ListContainer:Dock(FILL);

    for _, char in pairs(bash.Character.Digest) do
        local curChar = self.ListContainer:Add("DButton");
        curChar.CharData = char;
        curChar:SetText(char.Name);
        curChar:Dock(TOP);
        curChar:DockMargin(0, 0, 0, 5);
        curChar.DoClick = function(_self)
            local loadReq = vnet.CreatePacket("bash_Net_CharacterLoadRequest");
            loadReq:String(_self.CharData.CharID);
            loadReq:AddServer();
            loadReq:Send();

            LocalPlayer().WaitingOn = _self.CharData.CharID;
            self:RemoveList();
            self.WaitingOnChar = true;
        end

        if LocalPlayer():IsCharacter(char.CharID) then
            curChar:SetEnabled(false);
        end
    end

    local create = self.ListContainer:Add("DButton");
    create:SetText("Create Character");
    create:Dock(TOP);
    create:DockMargin(0, 0, 0, 5);
    create.DoClick = function(_self)
        Derma_StringRequest(
            "Create a Character",
            "Please give a valid name for your character.",
            "John Doe",
            function(text)
                local createReq = vnet.CreatePacket("bash_Net_CharacterCreateRequest");
                createReq:String(text);
                createReq:AddServer();
                createReq:Send();

                LocalPlayer().WaitingOn = text;
                self:RemoveList();
                self.WaitingOnChar = true;
            end,
            function() end,
            "Create"
        );
    end
end

function CHAR:RemoveList()
    if self.ListContainer then
        self.ListContainer:Remove();
        self.ListContainer = nil;
    end
end

function CHAR:PaintOver(w, h)
    if self.WaitingOnChar then
        draw.SimpleText("Waiting on char...", "ChatFont", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
    elseif self.WaitingOnDigest then
        draw.SimpleText("Waiting on digest...", "ChatFont", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
    end
end

function CHAR:OnRemove()
    hook.Remove("OnCharacterAttach", "bash_CharMenuWatchForLoad");
    bash.CharMenu = nil;
end

vgui.Register("bash_CharacterMenu", CHAR, "DFrame");
