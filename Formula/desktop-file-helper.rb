# Formula/desktop-file-helper.rb
class DesktopFileHelper < Formula
  desc "A helper for working with desktop files on Bazzite"
  homepage "https://github.com/dobsondev/homebrew-tap"
  url "https://github.com/dobsondev/homebrew-tap/releases/download/v0.0.3/homebrew-tap-v0.0.3.tar.gz"
  sha256 "144329c405567bdf37a0a3e6ce6ff7a24298ef751cf9bfca7eed7a003df2b329"

  def install
    bin.install "scripts/desktop-file-helper.sh" => "desktop-file-helper"
  end

  test do
    system "#{bin}/desktop-file-helper", "--help"
  end
end