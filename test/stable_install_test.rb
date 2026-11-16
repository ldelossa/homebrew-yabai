# Run with: brew ruby test/stable_install_test.rb SIGNED_CANDIDATE
# Executes the formula's exact helper only against a temporary prefix.
require "digest"
require "fileutils"
require "formulary"
require "open3"
require "tmpdir"

formula = Formulary.factory("ldelossa/yabai/yabai")
steps = formula.post_install_steps
raise "legacy hook remains" if formula.post_install_defined?
raise "unexpected hook" unless steps.length == 1 && steps.first["type"] == "run"
raise "wrong executable" unless steps.first["command"] == { "path" => "libexec/yabai-stable-install", "base" => "prefix" }
raise "wrong runtime bindings" unless steps.first["args"] == ["{{HOMEBREW_PREFIX}}", "{{prefix}}"]
source = Pathname.new(ARGV.fetch(0)).realpath
raise "candidate missing" unless source.file?
expected = Digest::SHA256.file(source).hexdigest
checks = 0
Dir.mktmpdir("yabai-stable-test-") do |dir|
  prefix = Pathname.new(dir)/"prefix with spaces"
  keg = prefix/"Cellar/yabai/7.1.25_15"
  (keg/"libexec").mkpath
  payload = keg/"libexec/yabai"
  FileUtils.cp source, payload
  script = keg/"libexec/yabai-stable-install"
  script.write formula.stable_install_script
  script.chmod 0755
  stable = prefix/"var/yabai/yabai"
  cli = prefix/"bin/yabai"
  install = lambda do |success|
    output, status = Open3.capture2e(script.to_s, prefix.to_s, keg.to_s)
    raise "unexpected helper result: #{output}" unless status.success? == success
    checks += 1
  end
  validate = lambda do
    raise "CLI not stable" unless cli.symlink? && cli.readlink.to_s == stable.to_s
    raise "bad installed bytes" unless Digest::SHA256.file(stable).hexdigest == expected
    raise "wrong permissions" unless (stable.stat.mode & 0777) == 0555
    raise "temporary files leaked" unless Dir.glob((prefix/"{var/yabai/.yabai.install.*,bin/.yabai.link.*}").to_s).empty?
    checks += 1
  end
  install.call(true)
  validate.call
  # An open old executable must retain its inode and contents after replacement.
  old = File.open(stable, "rb")
  old_inode = old.stat.ino
  errors = Queue.new
  stop = false
  samples = 0
  reader = Thread.new do
    until stop
      begin
        raise "partial binary or CLI gap" unless Digest::SHA256.file(cli).hexdigest == expected
        samples += 1
      rescue StandardError => e
        errors << e
        break
      end
    end
  end
  begin
    8.times { install.call(true); validate.call }
  ensure
    stop = true
    reader.join
  end
  raise errors.pop unless errors.empty?
  raise "reader never sampled" if samples.zero?
  raise "binary replaced in-place" if stable.stat.ino == old_inode
  raise "old inode corrupted" unless Digest::SHA256.hexdigest(old.read) == expected
  old.close
  checks += 1
  # Migration from Homebrew's old versioned bin link.
  old_bin = prefix/"Cellar/yabai/7.1.25_14/bin/yabai"
  old_bin.dirname.mkpath
  FileUtils.cp source, old_bin
  cli.unlink
  File.symlink "../Cellar/yabai/7.1.25_14/bin/yabai", cli
  install.call(true)
  validate.call
  # Unknown CLI targets must be rejected before replacing the stable binary.
  cli.unlink
  File.symlink "/does/not/belong/to/yabai", cli
  before = stable.stat.ino
  install.call(false)
  raise "stable changed on rejected CLI" unless stable.stat.ino == before
  raise "unknown CLI overwritten" unless cli.readlink.to_s == "/does/not/belong/to/yabai"
  cli.unlink
  File.symlink stable, cli
  # Invalid input/signature must leave the live copy untouched.
  payload.chmod 0644
  payload.write "not a signed executable\n"
  install.call(false)
  validate.call
  # Do not follow an unexpected symlink at the stable executable path.
  FileUtils.cp source, payload
  victim = prefix/"must-not-change"
  victim.write "untouched"
  stable.unlink
  File.symlink victim, stable
  install.call(false)
  raise "symlink victim changed" unless victim.read == "untouched"
  raise "stable symlink replaced" unless stable.symlink?
  checks += 1
  puts "PASS: #{checks} stable-install assertions; #{samples} concurrent reads; temporary prefix only"
end
