--[[
    BFrame panel.
]]

--
-- Globals.
--

-- Navigation panel types.
NAV = {};
NAV.TOP = 1;
NAV.SIDE = 2;

--
-- Local storage.
--

-- Micro-optimizations.
local surface = surface;

-- Panel object.
local PANEL = {};

--
-- EditablePanel functions.
--

function PANEL:Init()
    -- Components.
    self.Title = "";
    self.TopBar = nil;
    self.Navigation = nil;
    self.Content = nil;

    -- Sizes.
    self.TopBarHeight = 24;

    local parent = self:GetParent();
    -- Only independent panels should have a top bar.
    self.ShowTopBar = !ispanel(parent);

    self.ShowingNavigation = false;
    self.NavigationType = nil;

    -- Colors.
    self.Scheme = SCHEME_BASH;
    --[[
    self.BackgroundCol = SCHEME_BASH["TopBar"];
    self.ButtonHover = SCHEME_BASH["ButtonHover"];
    self.ButtonTextPassive = SCHEME_BASH["ButtonTextPassive"];
    self.ButtonTextHover = SCHEME_BASH["ButtonTextHover"];
    ]]

    -- Default size.
    self:SetSize(300, 200);

    -- Topbar buttons.
    self.CloseButton = vgui.Create("DButton", self);
    self.CloseButton:SetText("");
    self.CloseButton:SetSize(self.TopBarHeight, self.TopBarHeight);
    self.CloseButton.Paint = function(_self, w, h)
        local bgCol, textCol;
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

    -- Prevent the default background from being drawn.
    return true;
end

function PANEL:PerformLayout(w, h)
    local parent = self:GetParent();
    local setW, setH = w, h;

    if self.ShowTopBar then
        if !ispanel(self.TopBar) then
            self.TopBar = vgui.Create("Panel", self);
        end
    else

    end

    if ispanel(parent) and parent.GetMaxContentSize then
        local parX, parY = parent:GetMaxContentSize();
        self:SetSize(parX, parY);
        self.MaxContX = parX - (self.ShowNavigation and self.Navigation:GetWide() or 0);
        self.MaxContY = parY - (self.ShowTopBar and self.TopBarHeight or 0);
    else
        self.MaxContX, self.MaxContY = 200, 200;
    end

    self.CloseButton:SetPos(w - self.TopBarHeight, 0);
end

function PANEL:Close()
    if self.Closing then return; end

    self.Closing = true;
    self:Remove();
    self = nil;
end

--
-- BFrame functions.
--

function PANEL:ShowingTopBar()
    return self.ShowTopBar;
end

function PANEL:SetShowTopBar(show)
    self.ShowTopBar = show;
    self:InvalidateLayout();
end

function PANEL:ShowingNavigation()
    return self.ShowNavigation, self.NavigationType;
end

function PANEL:SetShowNavigation(show)
    self.ShowNavigation = show;
    self:InvalidateLayout();
end

function PANEL:SetTitleText(text)
    self.Title = text;
end

function PANEL:SetContent(panel)
    self.Content = panel;
    self:InvalidateLayout();
end

function PANEL:GetMaxContentSize()
    return self.MaxContX, self.MaxContY;
end

function PANEL:SetMaxContentSize(x, y)
    self.MaxContX, self.MaxContY = x, y;
end

vgui.Register("bash.Frame", PANEL, "EditablePanel");
