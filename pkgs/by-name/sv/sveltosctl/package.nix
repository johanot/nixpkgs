{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "sveltosctl";
  version = "0.42.0";

  src = fetchFromGitHub {
    owner = "projectsveltos";
    repo = "sveltosctl";
    rev = "v${version}";
    hash = "sha256-Gegkt7esb5QxilVLWnDaGgr4ZnaZwIW68x3bBuLOduo=";
  };

  vendorHash = "sha256-u7p/zdaXnasLrX2xrySrORNrSrBuf8AIBSZ1F1AyWpA=";

  meta = with lib; {
    homepage = "https://projectsveltos.github.io/sveltos";
    description = "CLI for managing Sveltos Kubernetes Add-on Controller";
    mainProgram = "sveltosctl";
    license = licenses.asl20;
    maintainers = with maintainers; [ johanot ];
    platforms = platforms.linux;
  };
}
