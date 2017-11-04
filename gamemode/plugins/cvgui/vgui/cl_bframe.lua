--[[
    BFrame panel.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local surface = surface;

-- Panel object.
local PANEL = {};

--
-- DFrame functions.
--

function PANEL:Init()
    self:SetTitle("");
    self:ShowCloseButton(false);
    self:MakePopup();

    -- Sizes.
    self.TopBarHeight = 24;

    -- Colors.
    self.BackgroundCol = SCHEME_BASH["TopBar"];
    self.ButtonHover = SCHEME_BASH["ButtonHover"];
    self.ButtonTextPassive = SCHEME_BASH["ButtonTextPassive"];
    self.ButtonTextHover = SCHEME_BASH["ButtonTextHover"];

    -- Default size.
    self:SetSize(512, self.TopBarHeight);

    -- Topbar buttons.
    self.Title = "";
    self.CloseButton = vgui.Create("DButton", self);
    self.CloseButton:SetText("");
    self.CloseButton:SetSize(self.TopBarHeight, self.TopBarHeight);
    self.CloseButton.Paint = function(_self, w, h)
        local bgCol, textCol;
        local pad = 6;
        if _self:IsHovered() then
            bgCol = self.ButtonHover;
            textCol = self.ButtonTextHover;
        else
            bgCol = self.BackgroundCol;
            textCol = self.ButtonTextPassive;
        end

        surface.SetDrawColor(bgCol);
        surface.DrawRect(0, 0, w, h);

        draw.SimpleText("r", "marlett", w / 2, h / 2, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);

        --[[
        surface.SetDrawColor(textCol);
        surface.DrawLine(pad, pad, self.TopBarHeight - pad, self.TopBarHeight - pad);
        surface.DrawLine(pad, self.TopBarHeight - pad, self.TopBarHeight - pad, pad);
        ]]
    end
    self.CloseButton.DoClick = function(_self)
        self:Close();
    end

    self:InvalidateLayout();
end

function PANEL:Paint(w, h)
    -- Draw topbar.
    surface.SetDrawColor(self.BackgroundCol);
    surface.DrawRect(0, 0, w, self.TopBarHeight);

    -- Draw topbar title.
    if self.Title != "" then
        draw.SimpleText(
            self.Title, "cvgui-title",
            4, 4, self.ButtonTextPassive
        );
    end
end

function PANEL:PerformLayout(w, h)
    self.CloseButton:SetPos(w - self.TopBarHeight, 0);
end

function PANEL:Close()
    if self.Closing then return; end

    self.Closing = true;
    self:Remove();
    self = nil;
end

--
-- Panel functions.
--

function PANEL:SetTitleText(text)
    self.Title = text;
end

vgui.Register("BFrame", PANEL, "DFrame");
