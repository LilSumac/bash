--[[
    Base 'draw' library extentions.
]]

--
-- Constants.
--

-- Gradient directions.
GRADIENT_LEFT = 0;
GRADIENT_RIGHT = 1;
GRADIENT_TOP = 2;
GRADIENT_BOTTOM = 3;

--
-- Local storage.
--

-- Micro-optimizations.
local bash = bash;
local draw = draw;
local surface = surface;

-- Gradient materials.
local gradH = bash.Util.GetMaterial("gui/gradient");
local gradV = bash.Util.GetMaterial("gui/gradient_down");

--
-- Library functions.
--

-- Draw a box with a vertical or horizontal gradient.
function draw.GradientBox(x, y, w, h, color, dir)
    surface.SetMaterial(dir < 2 and gradH or gradV);
    surface.SetDrawColor(color);
    surface.DrawTexturedRectUV(
        x, y, w, h,
        ((dir == GRADIENT_RIGHT) and 1 or 0),
        ((dir == GRADIENT_BOTTOM) and 1 or 0),
        ((dir == GRADIENT_LEFT or dir == GRADIENT_TOP or dir == GRADIENT_BOTTOM) and 1 or 0),
        ((dir == GRADIENT_LEFT or dir == GRADIENT_TOP or dir == GRADIENT_RIGHT) and 1 or 0)
    );
end
