{ stdenv
, buildPythonPackage
, fetchPypi
, fetchpatch
, flask
, flask-limiter
, markupsafe
, decorator
, itsdangerous
, raven
, six
, brotlipy
}:

buildPythonPackage rec {
  pname = "httpbin";
  version = "0.7.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "1yldvf3585zcwj4vxvfm4yr9wwlz3pa2mx2pazqz8x8mr687gcyb";
  };

  propagatedBuildInputs = [ brotlipy flask flask-limiter markupsafe decorator itsdangerous raven six ];

  # No tests
  doCheck = false;

  meta = with stdenv.lib; {
    homepage = "https://github.com/kennethreitz/httpbin";
    description = "HTTP Request & Response Service";
    license = licenses.mit;
  };
}
