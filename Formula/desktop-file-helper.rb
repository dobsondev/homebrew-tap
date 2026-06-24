# Formula/desktop-file-helper.rb
class DesktopFileHelper < Formula
  desc "A helper for working with desktop files on Bazzite"
  homepage "https://github.com/dobsondev/homebrew-tap"
  url "https://github.com/dobsondev/homebrew-tap/archive/refs/tags/v0.0.1.tar.gz"
  sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"

  def install
    bin.install "scripts/desktop-file-helper.sh" => "desktop-file-helper"
  end

  test do
    system "#{bin}/desktop-file-helper", "--help"
  end
end