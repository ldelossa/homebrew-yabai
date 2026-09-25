class Yabai < Formula
  desc "A tiling window manager for macOS based on binary space partitioning."
  homepage "https://github.com/ldelossa/yabai"
  url "https://github.com/ldelossa/yabai/releases/download/v7.1.25-ldelossa.6/yabai-v7.1.25.tar.gz"
  sha256 "11429c0ab3793820f1b759ba38a634aa06052ed5c44fe9a9173d9b453d84ed62"
  license "MIT"
  version "7.1.25"
  revision 5
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
