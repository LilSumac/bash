-- Global constants. See Documentation for more info.
BASE_NAME = "/bash/";

color_trans =       Color(0, 0, 0, 0);
color_black =       Color(0, 0, 0, 255);
color_white =       Color(255, 255, 255, 255);
color_grey =        Color(151, 151, 151, 255);
color_con =         Color(200, 200, 200, 255);
color_darkred =     Color(151, 0, 0, 255);
color_red =         Color(255, 0, 0, 255);
color_darkgreen =   Color(0, 151, 0, 255);
color_green =       Color(0, 255, 0, 255);
color_darkblue =    Color(0, 0, 151, 255);
color_blue =        Color(0, 0, 255, 255);
color_beige =       Color(151, 151, 0, 255);
color_yellow =      Color(255, 255, 0, 255);
color_turquoise =   Color(0, 151, 151, 255);
color_cyan =        Color(0, 255, 255, 255);
color_purple =      Color(151, 0, 151, 255);
color_pink =        Color(255, 0, 255, 255);
color_orange =      Color(255, 151, 0, 255);
color_neonpink =    Color(255, 0, 151, 255);
color_limegreen =   Color(151, 255, 0, 255);
color_mint =        Color(0, 255, 151, 255);
color_violet =      Color(151, 0, 255, 255);
color_lightblue =   Color(0, 151, 255, 255);

EMPTY_TABLE = function() return {}; end

ERR_TYPES = {};
ERR_TYPES["NilArgs"] = "Argument cannot be nil! (%s)";
ERR_TYPES["NilEntry"] = "An entry with that identifier does not exist! (%s)";
ERR_TYPES["DupEntry"] = "An entry with that identifier already exists! (%s)";
ERR_TYPES["NilField"] = "Field cannot be nil! (%s in table %s)"
ERR_TYPES["InsufVarArgs"] = "Insufficient varible arguments!";
ERR_TYPES["DefStarted"] = "Tried to start a definition without ending the last one! (End %s before starting %s)";
ERR_TYPES["NoDefStarted"] = "Tried to end a definition without starting one!";
ERR_TYPES["NilNVEntry"] = "Non-volatile entry resolved to be nil! (%s)";
ERR_TYPES["UnsafeNVEntry"] = "Do not set NV entries to nil! Use 'removeNonVolatileEntry' instead. (%s)";

PREFIXES_CLIENT = {["cl_"] = true};
PREFIXES_SERVER = {["sv_"] = true};
PREFIXES_SHARED = {["sh_"] = true};

PROCESS_DIRS = {["core"] = true, ["services"] = true};
PROCESS_IGNORE = {["sh_const.lua"] = true, ["sh_util.lua"] = true};
