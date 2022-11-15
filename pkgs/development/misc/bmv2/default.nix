{ lib
, stdenv
, fetchFromGitHub
, gmp
, boost
, autoreconfHook
, pkg-config
, thrift
, nanomsg
, libpcap
, python3Packages
}:

stdenv.mkDerivation rec {
  pname = "bmv2";
  version = "1.15.0";

  src = fetchFromGitHub {
    owner = "p4lang";
    repo = "behavioral-model";
    rev = "${version}";
    sha256 = "sha256-XXOqRYMQjbfyDJWRg1fKf+Q7n7S8OZX2m/JpuwBi+LI=";
    fetchSubmodules = true;
  };

  checkTarget = "check";

  pythondir = python3Packages.python.sitePackages;

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
  ];

  buildInputs = [
    thrift
    nanomsg
    libpcap
    boost
    gmp
  ];

  meta = with lib; {
    homepage = "https://github.com/p4lang/behavioral-model";
    description = "The reference P4 software switch";
    platforms = platforms.linux;
    maintainers = with maintainers; [ govanify ];
    license = licenses.asl20;
  };
}
