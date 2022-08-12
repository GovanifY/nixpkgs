{ stdenv, fetchurl, lib, makeWrapper, autoPatchelfHook
, openjdk11, pam, makeDesktopItem, icoutils
}: let

  pname = "komga";
  version = "0.157.0";
  jar = fetchurl {
    url = "https://github.com/gotson/${pname}/releases/download/v${version}/${pname}-${version}.jar";
    sha256 = "sha256-PkQL61fKplt6h1jcFCIMER+ZfzowDP466dR1AaDHw5Q=";
  };

in stdenv.mkDerivation rec {
  inherit pname version;

  nativeBuildInputs = [
   # makeWrapper
    #autoPatchelfHook
  ];

  #buildInputs = [
  #  stdenv.cc.cc.lib
  #  pam
  #];

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p "$out/bin"
    mkdir -p "$out/share/lib/komga/"
    cp -a ${jar} "$out/share/lib/komga/komga.jar"

    cat <<EOF > "$out/bin/komga"
    #!/bin/sh
    ${openjdk11}/bin/java -jar "$out/share/lib/komga/komga.jar"
    EOF
    chmod +x "$out/bin/komga"
  '';

  meta = with lib; {
    description = "Free and open source comics/mangas server.";
    homepage = "https://komga.org/";
    license = licenses.mit;
    maintainers = with maintainers; [ govanify ];
  };

}
