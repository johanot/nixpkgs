{ stdenv, fetchurl, buildPythonPackage, six, pytest, pyyaml }:

buildPythonPackage rec {
  pname = "ceph-common";
  version = "15.2.3";

  src = fetchurl {
    url = "https://github.com/ceph/ceph/archive/v${version}.tar.gz";
    sha256 = "0jipyp7xhfmq1dhv9lvbl4bvrqq2fw2sl5m76pv9lw1z19gkfy0k";
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
