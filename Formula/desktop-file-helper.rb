# Formula/desktop-file-helper.rb
class DesktopFileHelper < Formula
  desc "A helper for working with desktop files on Bazzite"
  homepage "https://github.com/dobsondev/homebrew-tap"
  url "https://github.com/dobsondev/homebrew-tap/releases/download/v0.1.2/homebrew-tap-v0.1.2.tar.gz"
  sha256 "26f6be54f6c49244eee1241603b6f08aedc195cf9c6cac948ef5c51351e5961a"

  def install
    bin.install "scripts/desktop-file-helper.sh" => "desktop-file-helper"
  end

  test do
    system "#{bin}/desktop-file-helper", "--help"
  end
end