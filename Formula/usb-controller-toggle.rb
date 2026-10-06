# Formula/usb-controller-toggle.rb
class UsbControllerToggle < Formula
  desc "Toggle the wired-controller USB hub on Bazzite, with a tray indicator"
  homepage "https://github.com/dobsondev/homebrew-tap"
  url "https://github.com/dobsondev/homebrew-tap/releases/download/v0.1.2/homebrew-tap-v0.1.2.tar.gz"
  sha256 "26f6be54f6c49244eee1241603b6f08aedc195cf9c6cac948ef5c51351e5961a"

  depends_on :linux

  def install
    bin.install "scripts/usb-controller-toggle.sh" => "usb-controller-toggle"
    bin.install "scripts/usb-controller-tray.py" => "usb-controller-tray"
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

      The tray uses the system python's PySide6 (python3-pyside6), which ships
      with Bazzite. If it is ever missing:
           rpm-ostree install python3-pyside6

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
