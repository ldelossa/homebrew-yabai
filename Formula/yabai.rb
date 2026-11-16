class Yabai < Formula
  desc "Tiling window manager for macOS based on binary space partitioning"
  homepage "https://github.com/ldelossa/yabai"
  url "https://github.com/ldelossa/yabai/releases/download/v7.1.25-ldelossa.15/yabai-v7.1.25.tar.gz"
  sha256 "32daa6434cba6a5e9e4c69c724a6f5d147d2280cb451abba9d4ef74befec8f1c"
  license "MIT"
  revision 15
  head "https://github.com/ldelossa/yabai.git"

  depends_on macos: :golden_gate

  # Preserve the released Developer ID signature byte-for-byte.
  skip_clean "libexec/yabai"

  def install
    man.mkpath

    if build.head?
      system "make", "-j1", "install"
      system "codesign", "-fs", "-", "#{buildpath}/bin/yabai"
    end

    # Keep Homebrew's normal bin linking away from the stable CLI symlink.
    libexec.install "#{buildpath}/bin/yabai"
    (libexec/"yabai-stable-install").write stable_install_script
    (libexec/"yabai-stable-install").chmod 0755
    (pkgshare/"examples").install "#{buildpath}/examples/yabairc"
    (pkgshare/"examples").install "#{buildpath}/examples/skhdrc"
    man1.install "#{buildpath}/doc/yabai.1"
  end

  post_install_steps do
    run "libexec/yabai-stable-install", base: :prefix,
        args: ["{{HOMEBREW_PREFIX}}", "{{prefix}}"],
        writable_paths: ["bin", "var/yabai"], writable_base: :homebrew_prefix
  end

  def stable_install_script
    <<~SH
      #!/bin/sh
      set -eu
      [ "$#" -eq 2 ] || exit 64
      prefix=${1%/}
      keg=${2%/}
      case "$prefix" in /*) ;; *) exit 64 ;; esac
      case "$keg" in /*) ;; *) exit 64 ;; esac
      source="$keg/libexec/yabai"
      stable="$prefix/var/yabai"
      cli="$prefix/bin/yabai"
      [ -f "$source" ] || exit 1
      # Never follow an unexpected stable-path symlink or replace another CLI.
      [ ! -L "$stable" ] && [ ! -L "$stable/yabai" ] || exit 1
      if [ -e "$cli" ] || [ -L "$cli" ]; then
        [ -L "$cli" ] || exit 1
        target=$(/usr/bin/readlink "$cli")
        case "$target" in
          "$stable/yabai"|../var/yabai/yabai|"$prefix"/Cellar/yabai/*/bin/yabai|../Cellar/yabai/*/bin/yabai) ;;
          *) exit 1 ;;
        esac
      fi
      /usr/bin/codesign --verify --strict "$source"
      /bin/mkdir -p "$stable" "$prefix/bin"
      tmp="$stable/.yabai.install.$$"
      link="$prefix/bin/.yabai.link.$$"
      cleanup() { /bin/rm -f "$tmp" "$link"; }
      trap cleanup EXIT
      trap 'exit 1' HUP INT TERM
      /usr/bin/install -m 0555 "$source" "$tmp"
      /usr/bin/codesign --verify --strict "$tmp"
      /bin/ln -s "$stable/yabai" "$link"
      # Both temporary files share their destination directory/filesystem.
      # Unlike the declarative move step, mv renames over the old inode.
      /bin/mv -f "$tmp" "$stable/yabai"
      /bin/mv -f "$link" "$cli"
    SH
  end

  def caveats
    <<~EOS
      This is the ldelossa fork of yabai, targeting macOS 27 (Golden Gate) and later.

      If you want yabai to be managed by launchd (start automatically upon login):
        yabai --start-service

      The binary uses a stable, non-versioned path to preserve Accessibility
      permissions across signed release upgrades. If macOS requests access,
      grant it to the stable binary at var/yabai/yabai under your Homebrew prefix.

      Scripting-addition setup and compatibility details:
        https://github.com/ldelossa/yabai#scripting-addition
    EOS
  end

  test do
    assert_match "yabai-v#{version}", shell_output("#{libexec}/yabai --version")
    stable = HOMEBREW_PREFIX/"var/yabai/yabai"
    assert_predicate stable, :executable?
    assert_equal stable, (HOMEBREW_PREFIX/"bin/yabai").realpath
    assert_equal Digest::SHA256.file(libexec/"yabai").hexdigest, Digest::SHA256.file(stable).hexdigest
  end
end
