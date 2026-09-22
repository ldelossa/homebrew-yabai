class Yabai < Formula
  desc "A tiling window manager for macOS based on binary space partitioning."
  homepage "https://github.com/ldelossa/yabai"
  url "https://github.com/ldelossa/yabai/releases/download/v7.1.25-ldelossa.2/yabai-v7.1.25.tar.gz"
  sha256 "3741bbfe2cc75780f7494c7c70a53ed9ff9f035b912d16be8dd778710c8c1f2f"
  license "MIT"
  version "7.1.25"
  revision 1
  head "https://github.com/ldelossa/yabai.git"

  depends_on :macos => :golden_gate

  def install
    man.mkpath

    if build.head?
      system "make", "-j1", "install"
      system "codesign", "-fs", "-", "#{buildpath}/bin/yabai"
    end

    bin.install "#{buildpath}/bin/yabai"
    (pkgshare/"examples").install "#{buildpath}/examples/yabairc"
    (pkgshare/"examples").install "#{buildpath}/examples/skhdrc"
    man1.install "#{buildpath}/doc/yabai.1"
  end

  def caveats; <<~EOS
    This is the ldelossa fork of yabai, targeting macOS 27 (Golden Gate) and later.

    If you want yabai to be managed by launchd (start automatically upon login):
      yabai --start-service

    If you are using the scripting-addition, update your sudoers file and load it:
      sudo yabai --load-sa

    README: https://github.com/ldelossa/yabai
    EOS
  end

  test do
    assert_match "yabai-v#{version}", shell_output("#{bin}/yabai --version")
  end
end
