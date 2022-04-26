{ lib
, fetchFromGitHub
, buildPythonPackage
, pykickstart
, pyudev
, dbus-python
, pyparted
, libselinux
, lsof
, util-linux
, multipath-tools
, libblockdev
, libbytesize
, pygobject3
}:

buildPythonPackage rec {
  pname = "blivet";
  version = "3.4.3";

  src = fetchFromGitHub {
    owner = "storaged-project";
    repo = "blivet";
    rev = "${pname}-${version}";
    sha256 = "sha256-O5obVsR8erZheLvwWoSyqz/IHu+FStuNdG1nzrF7H58=";
  };

  propagatedBuildInputs = [
    pykickstart pyudev dbus-python pyparted libselinux libblockdev
    libbytesize pygobject3
  ];

  # tests are heavily broken
  doCheck = false;

  meta = with lib; {
    homepage = "https://github.com/storaged-project/blivet";
    description = "Module for management of a system's storage configuration";
    license = with licenses; [ gpl2Plus lgpl21Plus ];
    platforms = platforms.linux;
    maintainers = [ maintainers.govanify ];
  };
}
