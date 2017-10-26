--[[
    Base 'draw' library extentions.
]]

local draw = draw;

-- Constants.
GRADIENT_LEFT = 0;
GRADIENT_RIGHT = 1;
GRADIENT_TOP = 2;
GRADIENT_BOTTOM = 3;

-- Materials.
local gradH = getMaterial("gui/gradient");
local gradV = getMaterial("gui/gradient_down");
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
