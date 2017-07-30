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

ERR_TYPES = {};
ERR_TYPES["NilErrType"] = "Error type cannot be nil!";
ERR_TYPES["UndefErrType"] = "Undefined error type! (%s)";
ERR_TYPES["NilArgs"] = "Cannot have nil arguments! (%s)";
ERR_TYPES["NilEntry"] = "An entry with that identifier doesn't exist! (%s)";
ERR_TYPES["DupEntry"] = "An entry with that identifier already exists! (%s)";
ERR_TYPES["DefStarted"] = "Tried to start a definition without ending the last one! (End %s before %s)";
ERR_TYPES["NoDefStarted"] = "Tried to end a definition without starting one!";
