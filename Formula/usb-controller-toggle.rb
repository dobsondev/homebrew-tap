# Formula/usb-controller-toggle.rb
class UsbControllerToggle < Formula
  desc "Toggle the wired-controller USB hub on Bazzite, with a tray indicator"
  homepage "https://github.com/dobsondev/homebrew-tap"
  url "https://github.com/dobsondev/homebrew-tap/releases/download/v0.1.0/homebrew-tap-v0.1.0.tar.gz"
  sha256 "0ce14462e64945e3dfdbc194f2250c7c252ad17563ed118040bae897b0e5da51"

  depends_on :linux

  def install
    bin.install "scripts/usb-controller-toggle.sh" => "usb-controller-toggle"
    bin.install "scripts/usb-controller-tray.sh" => "usb-controller-tray"
    pkgshare.install Dir["share/usb-controller-toggle/*"]
  end

  def caveats
    <<~EOS
      One-time setup on the Bazzite machine:

      1. Allow passwordless toggling of the hub's ports:
           echo "$(whoami) ALL=(root) NOPASSWD: /usr/bin/tee /sys/bus/usb/devices/*/*/*-port*/disable" \\
             | sudo tee /etc/sudoers.d/usb-controller-toggle
           sudo chmod 440 /etc/sudoers.d/usb-controller-toggle

      2. Enable the tray indicator (now, and on every login):
           usb-controller-tray install-autostart
           setsid usb-controller-tray >/dev/null 2>&1 &

      The tray needs `yad`, which ships with Bazzite. If it is ever missing:
           rpm-ostree install yad

      Note: passive adapters (e.g. the GameCube adapter) re-appear on their own
      after `enable`. Wireless pads that sleep on USB disconnect (e.g. the
      8BitDo 64) need a button press (Start) to wake back up.
    EOS
  end

  test do
    assert_match "Usage", shell_output("#{bin}/usb-controller-toggle --help")
    assert_match "Usage", shell_output("#{bin}/usb-controller-tray --help")
  end
end
