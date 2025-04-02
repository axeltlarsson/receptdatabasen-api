{
  lib,
  buildLuarocksPackage,
  fetchFromGitHub,
}:

buildLuarocksPackage {
  pname = "lua-resty-template";
  version = "2.0-1";

  src = fetchFromGitHub {
    owner = "bungle";
    repo = "lua-resty-template";
    rev = "v2.0";
    sha256 = "sha256-YW3h9exkAC0WKnlK38L9qbso2Uk/TfNjRysWXQeW/r4=";
  };

  rockspecFilename = "lua-resty-template-dev-1.rockspec";

  meta = with lib; {
    description = "Templating Engine for OpenResty and Lua";
    homepage = "https://github.com/bungle/lua-resty-template";
    license = licenses.bsd2;
    maintainers = [ ];
  };
}
