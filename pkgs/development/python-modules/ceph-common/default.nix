{ stdenv, fetchurl, buildPythonPackage, six, pytest, pyyaml }:

buildPythonPackage rec {
  pname = "ceph-common";
  version = "15.2.4";

  src = fetchurl {
    url = "http://download.ceph.com/tarballs/ceph-${version}.tar.gz";
    sha256 = "0jy5dp4r1bqk1l7nrv8l8zpl984k61p3vkvf73ygcn03bxyjjlax";
  };

  SOURCE_DATE_EPOCH=315532800;

  unpackPhase = ''
    tar -xf $src ceph-${version}/src/python-common
    cd ceph-${version}/src/python-common
  '';

  nativeBuildInputs = [ pytest pyyaml ];
  buildInputs = [ six ];

  meta = with stdenv.lib; {
    description = "Ceph common module for code shared by manager modules";
    homepage    = "https://ceph.io";
    license     = with licenses; [ lgpl21 gpl2 bsd3 mit publicDomain ];
    maintainers = [ maintainers.johanot ];
  };
}
