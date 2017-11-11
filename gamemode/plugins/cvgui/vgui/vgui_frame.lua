--[[
    bash.Frame element.
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
    self.TopBar = nil;
    self.Navigation = nil;
    self.Content = nil;
    self.Scheme = SCHEME_BASH;
    self.TopBarHeight = 30;

    -- Default size.
    self:SetSize(200, self.TopBarHeight);

    gui.EnableScreenClicker(true);

    local parent = self:GetParent();

    -- Only independent panels should have a top bar.
    self.ShowTopBar = isbasepanel(parent);
    MsgN(self.ShowTopBar);
    if self.ShowTopBar then
        self.TopBar = vgui.Create("bash.TopBar", self);
        self.TopBar:SetPos(0, 0);
        self.TopBar:SetSize(200, self.TopBarHeight);
    end

    self.ShowingNavigation = false;
    self.NavigationType = nil;

    self:InvalidateLayout();
end

function PANEL:Paint(w, h)
    -- Prevent the default background from being drawn.
    return true;
end

function PANEL:PerformLayout(w, h)
    local parent = self:GetParent();
    local setW, setH = w, h;

    if self.ShowTopBar then
        if ispanel(self.TopBar) then
            self.TopBar:SetPos(0, 0);
            self.TopBar:SetSize(w, self.TopBarHeight);
        end
    else
        if ispanel(self.TopBar) then
            self.TopBar:Remove();
            self.TopBar = nil;
        end
    end

    if !isbasepanel(parent) and parent.GetMaxContentSize then
        local parX, parY = parent:GetMaxContentSize();
        self:SetSize(parX, parY);
        self.MaxContX = parX - (self.ShowNavigation and self.Navigation:GetWide() or 0);
        self.MaxContY = parY - (self.ShowTopBar and self.TopBarHeight or 0);
    else
        self.MaxContX, self.MaxContY = 200, 200;
    end
end

function PANEL:Close()
    if self.Closing then return; end

    self.Closing = true;
    self:Remove();
    self = nil;
end

--
-- bash.Frame functions.
--

function PANEL:ShowingTopBar()
    return self.ShowTopBar;
end

function PANEL:SetShowTopBar(show)
    self.ShowTopBar = show;
    self:InvalidateLayout();
end

function PANEL:SetTitleText(text)
    if ispanel(self.TopBar) then
        self.TopBar:SetTitleText(text);
    end
end

function PANEL:ShowingNavigation()
    return self.ShowNavigation, self.NavigationType;
end

function PANEL:SetShowNavigation(show)
    self.ShowNavigation = show;
    self:InvalidateLayout();
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

function PANEL:IsScreenLocked()
    return self.ScreenLocked;
end

function PANEL:SetScreenLock(lock)
    self.ScreenLocked = lock;
end

vgui.Register("bash.Frame", PANEL, "EditablePanel");
