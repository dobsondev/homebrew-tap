# Formula/desktop-file-helper.rb
class DesktopFileHelper < Formula
  desc "A helper for working with desktop files on Bazzite"
  homepage "https://github.com/dobsondev/homebrew-tap"
  url "https://github.com/dobsondev/homebrew-tap/releases/download/v0.1.1/homebrew-tap-v0.1.1.tar.gz"
  sha256 "0ea60e4f722fef464d493aa121804329729e1709d8b58cf6b38fac5977ba9cc2"

  def install
    bin.install "scripts/desktop-file-helper.sh" => "desktop-file-helper"
  end

  test do
    system "#{bin}/desktop-file-helper", "--help"
  end
end