class Yabai < Formula
  desc "A tiling window manager for macOS based on binary space partitioning."
  homepage "https://github.com/ldelossa/yabai"
  url "https://github.com/ldelossa/yabai/releases/download/v7.1.25-ldelossa.7/yabai-v7.1.25.tar.gz"
  sha256 "772789fcc4f74fabd05b553a052e9d04f2476fe6ad898910357aa360b09964fb"
  license "MIT"
  version "7.1.25"
  revision 7
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

  def post_install
    # Install the daemon to a stable, non-versioned path so macOS keeps the
    # Accessibility (TCC) grant across upgrades. Homebrew's versioned Cellar
    # changes the resolved binary path on every upgrade, which forces a
    # re-grant. Replace atomically so a running daemon keeps its old inode.
    stable_dir = "#{HOMEBREW_PREFIX}/var/yabai"
    FileUtils.mkdir_p stable_dir
    tmp = "#{stable_dir}/.yabai.tmp"
    FileUtils.install "#{prefix}/bin/yabai", tmp, mode: 0555
    File.rename tmp, "#{stable_dir}/yabai"

    # Point the `yabai` command at the stable binary so the resolved path
    # (and therefore the TCC identity) never changes between upgrades.
    FileUtils.rm_f "#{HOMEBREW_PREFIX}/bin/yabai"
    FileUtils.ln_s "#{stable_dir}/yabai", "#{HOMEBREW_PREFIX}/bin/yabai"
  end

  def post_uninstall
    FileUtils.rm_f "#{HOMEBREW_PREFIX}/bin/yabai"
    FileUtils.rm_f "#{HOMEBREW_PREFIX}/var/yabai/yabai"
    begin
      Dir.rmdir "#{HOMEBREW_PREFIX}/var/yabai"
    rescue SystemCallError
      # Ignore if the directory is not empty.
    end
  end

  def caveats; <<~EOS
    This is the ldelossa fork of yabai, targeting macOS 27 (Golden Gate) and later.

    If you want yabai to be managed by launchd (start automatically upon login):
      yabai --start-service

    If you are using the scripting-addition, update your sudoers file and load it:
      sudo yabai --load-sa

    The binary is installed to a stable path so the Accessibility grant
    survives upgrades. Grant Accessibility once after your next upgrade;
    later upgrades will not re-prompt.

    README: https://github.com/ldelossa/yabai
    EOS
  end

  test do
    assert_match "yabai-v#{version}", shell_output("#{bin}/yabai --version")
  end
end
