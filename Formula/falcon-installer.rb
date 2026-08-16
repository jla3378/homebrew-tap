class FalconInstaller < Formula
  desc "Install CrowdStrike Falcon sensors"
  homepage "https://github.com/CrowdStrike/falcon-installer"

  url "https://github.com/CrowdStrike/falcon-installer/releases/download/v0.27.0/falcon-installer-0.27.0-macos-arm64"
  sha256 "0dd1b1d3d8413012d4711b5236323400f491b4433735a4b90c6e6caf5c90c380"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on :macos

  def install
    bin.install "falcon-installer-#{version}-macos-arm64" => "falcon-installer"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/falcon-installer --version")
  end
end
