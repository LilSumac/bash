--[[
    bash.TopBar element.
]]

--
-- Local storage.
--

-- Panel object.
local TOPBAR = {};

--
-- EditablePanel functions.
--

function TOPBAR:Init()
    -- Components.
    self.Title = "";
    self.Scheme = SCHEME_BASH;
    self.CloseButton = vgui.Create("bash.Close", self);

    self:InvalidateLayout();
end

function TOPBAR:Paint(w, h)
    -- Draw topbar.
    surface.SetDrawColor(self.Scheme["TopBar"]);
    surface.DrawRect(0, 0, w, h);

    -- Draw topbar title.
    if self.Title != "" then
        draw.SimpleText(
            self.Title, "cvgui-title",
            4, h / 2, self.Scheme["ButtonTextPassive"],
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
        );
    end

    -- Prevent the default background from being drawn.
    return true;
end

function TOPBAR:PerformLayout(w, h)
    if ispanel(self.CloseButton) then
        self.CloseButton:SetPos(w - h, 0);
        self.CloseButton:SetSize(h, h);
        self.CloseButton:SetTarget(self.Target or self:GetParent());
    end
end

--
-- bash.TopBar functions.
--

function TOPBAR:SetTitleText(text)
    self.Title = text;
end

vgui.Register("bash.TopBar", TOPBAR, "EditablePanel");
