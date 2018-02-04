--[[
    Global constant variables.
    See documentation for more info.
]]

BASE_NAME = "/bash/";
BASE_FOLDER = "bash";

CHAR_ALPHA = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
CHAR_ALPHANUM = CHAR_ALPHA .. "0123456789";
CHAR_HEX = "abcdef0123456789";
CHAR_ALL = CHAR_ALPHANUM .. "!@#$%^&*()-_=+{}[]|;:<,>.?/";

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

DEFAULTS = {};
DEFAULTS["string"] = "";
DEFAULTS["number"] = 0;
DEFAULTS["boolean"] = false;

EMPTY_TABLE = function() return {}; end
DEFAULTS["table"] = EMPTY_TABLE;

ERR_TYPES = {};
ERR_TYPES["Generic"] = "An error has occured!";
ERR_TYPES["NilArgs"] = "Argument cannot be nil! (%s)";
ERR_TYPES["NilEntry"] = "A table entry with that identifier does not exist! (%s)";
ERR_TYPES["DupEntry"] = "A table entry with that identifier already exists! (%s)";
ERR_TYPES["NilField"] = "Field cannot be nil! (%s in table %s)";
ERR_TYPES["EmptyTable"] = "Table cannot be empty! (%s)";
ERR_TYPES["InvalidDataType"] = "This data type is not supported! (%s)";
ERR_TYPES["InvalidEnt"] = "Invalid entity argument!";
ERR_TYPES["InvalidPly"] = "Invalid player argument!";
ERR_TYPES["InvalidVarArgs"] = "Invalid number of varible arguments!";
ERR_TYPES["HookError"] = "The '%s' hook from '%s' has failed! Result: %s";
ERR_TYPES["SchemaOnBase"] = "Tried loading the engine as the schema! Call bash.StartSchema() in a separate gamemode.";
ERR_TYPES["NoDBModule"] = "No tmysql4 module found! This is required and must be resolved.";
ERR_TYPES["NoDBConnect"] = "Could not connect to database: %s";
ERR_TYPES["NoDBConnection"] = "Database is not connected!";
ERR_TYPES["QueryFailed"] = "The SQL query failed!\nQuery: %s\nError: %s";
ERR_TYPES["QueryNumFailed"] = "The #%d SQL query in the statement failed!\nQuery: %s\nError: %s";
ERR_TYPES["NoValidItem"] = "No item available with the Registry ID '%s'!";
ERR_TYPES["NoValidInv"] = "No inventory available with the Registry ID '%s'!";
ERR_TYPES["NoValidInv"] = "No inventory type available with the ID '%s' in networked table '%s'!";
ERR_TYPES["CharCreateFailed"] = "Failed to create character with ID '%s'.";
ERR_TYPES["InvCreateFailed"] = "Failed to create inventory with ID '%s'.";
ERR_TYPES["ItemCreateFailed"] = "Failed to create item with ID '%s'.";
ERR_TYPES["CharNotFound"] = "Failed to find an character with the ID '%s'.";
ERR_TYPES["ItemNotFound"] = "Failed to find an item with the ID '%s'.";
ERR_TYPES["InvNotFound"] = "Failed to find an inventory with the ID '%s'.";

ERR_TYPES["KeyExists"] = "A key already exists in this table! (Column %s in table %s)";
ERR_TYPES["DefStarted"] = "Tried to start a definition without ending the last one! (End %s before starting %s)";
ERR_TYPES["NoDefStarted"] = "Tried to end a definition without starting one!";
ERR_TYPES["NilNVEntry"] = "Non-volatile entry resolved to be nil! (%s)";
ERR_TYPES["UnsafeNVEntry"] = "Do not set NV entries to nil! Use 'removeNonVolatileEntry' instead. (%s)";
ERR_TYPES["NoPluginFile"] = "A sh_plugin.lua file does not exists in this plugin directory! (%s)";

F = Format;

LOG_DEF = {pre = "[LOG]", col = color_grey};
LOG_INIT = {pre = "[INIT]", col = color_green};
LOG_CONN = {pre = "[CONN]", col = color_darkgreen};
LOG_ERR = {pre = "[ERR]", col = color_red, log = true};
LOG_WARN = {pre = "[WARN]", col = color_orange, log = true};

OS_WIN = 1;
OS_OSX = 2;
OS_LIN = 3;
OS_UNK = 4;

PREFIXES_CLIENT = {["cl_"] = true, ["vgui_"] = true};
PREFIXES_SERVER = {["sv_"] = true};
PREFIXES_SHARED = {["sh_"] = true};

if SERVER then

    -- SQL constants were here. Now, they are defined inside the service.
    -- As they should be.

elseif CLIENT then

    CENTER_X = ScrW() / 2;
    CENTER_Y = ScrH() / 2;

    SCRW = ScrW();
    SCRH = ScrH();

end
