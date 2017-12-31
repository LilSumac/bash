--[[
    Client utility functions.
]]

--
-- Local storage.
--

local bash          = bash;
local handleFunc    = handleFunc;
local Material      = Material;
local pairs         = pairs;

--
-- Global storage.
--

bash.Util = bash.Util or {};

--
-- Utility functions.
--

-- Check to see if a variable is a panel and a valid one.
function ispanel(panel)
    return panel and panel.IsValid and panel:IsValid();
end

-- Check to see if a variable is the base GMod panel.
function isbasepanel(panel)
    return ispanel(panel) and panel:GetName() == "GModBase";
end

-- Store all client data in a global table.
function bash.Util.AddClientData(id, generate)
    bash.ClientData = bash.ClientData or {};
    bash.ClientData[id] = generate;
end

-- Send stored client data to server.
function bash.Util.SendClientData(first, ids)
    local send = vnet.CreatePacket("bash_Net_SendClientData");
    local data = {};
    local tab = bash.ClientData or ids or {};
    for id, generate in pairs(bash.ClientData) do
        data[id] = handleFunc(generate);
    end

    send:Table(data);
    if first then
        send:Bool(true);
    else
        send:Bool(false);
    end

    send:AddServer();
    send:Send();
end

-- Store and cache used materials for optimization.
function bash.Util.GetMaterial(mat)
    bash.Materials = bash.Materials or {};
    bash.Materials[mat] = bash.Materials[mat] or Material(mat);
    return bash.Materials[mat];
end

-- Generate a table of points for a circle polygon.
function bash.Util.GenerateCircle(_x, _y, rad, qual)
    local points = {};
	local temp;
	for index = 1, qual do
		temp = math.rad(index * 360) / qual;

		points[index] = {
			x = _x + (math.cos(temp) * rad),
			y = _y + (math.sin(temp) * rad)
		};
	end
    return points;
end

-- Generate a table of points for a circle polygon.
function bash.Util.GenerateRadial(_x, _y, rad, ang, rot)
    rot = rot or -90;
    local seg = 360;
	local segToDraw = 360 * (ang / 360);
	rot = rot * (seg / 360);
    local segDiv = (360 / seg);
    local rads = (math.pi / 180);

	local points = {};
    points[1] = {
        x = _x,
        y = _y
    };

	for index = 1 + rot, segToDraw + rot do
        points[#points + 1] = {
            x = math.cos((index * segDiv) * rads) * rad + _x,
            y = math.sin((index * segDiv) * rads) * rad + _y;
        };
	end
    return points;
end
