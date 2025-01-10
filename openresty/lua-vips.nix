{
  buildLuarocksPackage,
  fetchgit,
  fetchurl,
  vips,
  lib,
  lua,
  stdenv,
}:
buildLuarocksPackage {
  pname = "lua-vips";
  version = "1.1-11";

  inherit lua;

  knownRockspec = fetchurl {
    url = "mirror://luarocks/lua-vips-1.1-11.rockspec";
    sha256 = "sha256-iKSx+Mt4RicfGVe+y1CN5/OhxLnCNVgiyuvGI/8mOIE=";
  };

  src = fetchgit {
    url = "https://github.com/libvips/lua-vips.git";
    sha256 = "sha256-qqNsJfWPzLT0Mm+3mfUNk4NbTS/OBRho/keDfGB6vcU=";
  };

  externalDeps = [ vips ];

  # Configure LuaRocks to recognize LuaJIT as providing luaffi-tkl - so we don't have to pass dependency in
  extraConfig = ''
    rocks_provided = {
      ["luaffi-tkl"] = "2.1-1"
    }
  '';

  # one way of trying to fix the ffi.load call

  # Patch `ffi.load` to use the absolute path to libvips
  # alternatively one can set LD_LIBRARY_PATH on Linux or DYLD_LIBRARY_PATH on macOS to point to the libvips library
  # at ${lib.getLib vips}/lib
  # or even wrap the lua interpreter (luaajit-openresty) with the LD_LIBRARY_PATH/DYLD_LIBRARY_PATH set
  # but this approach seems to be the most reliable and portable
  postPatch = ''
    # lua-vips uses ffi.load differently in different files, first set of files like so:
    substituteInPlace src/vips.lua src/vips/voperation.lua src/vips/version.lua src/vips/verror.lua src/vips/Interpolate.lua \
      --replace-fail 'ffi.load(ffi.os == "Windows" and "libvips-42.dll" or "vips")' 'ffi.load("${lib.getLib vips}/lib/libvips${stdenv.hostPlatform.extensions.sharedLibrary}")'

    # second set of files like so:
    substituteInPlace src/vips/vobject.lua src/vips/Image_methods.lua src/vips/gvalue.lua \
      --replace-fail 'ffi.load("vips")' 'ffi.load("${lib.getLib vips}/lib/libvips${stdenv.hostPlatform.extensions.sharedLibrary}")'
  '';

  meta = {
    homepage = "github.com/libvips/lua-vips";
    description = "A fast image processing library with low memory needs.";
    license.fullName = lib.licenses.mit;
  };
}
