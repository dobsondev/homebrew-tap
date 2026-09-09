# dobsondev/homebrew-tap

A personal [Homebrew](https://brew.sh) tap containing helper scripts and tools for my machines.

## Installation

```bash
brew tap dobsondev/tap
```

Once tapped, you can install any formula from this repo:

```bash
brew install dobsondev/tap/<formula-name>
```

---

## Available Formulae

| Formula | Description |
|---|---|
| `desktop-file-helper` | Manage custom `.desktop` files on Bazzite — create new entries or update existing ones to point at a new AppImage version |
| `usb-controller-toggle` | Disable/enable the USB hub feeding wired controllers on the Bazzite HTPC, with a green/red Plasma tray indicator |

---

## How This Repo Works

### Structure

```
homebrew-tap/
├── Formula/
│   └── desktop-file-helper.rb   # Homebrew formula
├── scripts/
│   └── desktop-file-helper.sh   # The shell script installed by the formula
└── .github/
    └── workflows/
        └── update-formula-sha.yml   # Automatically updates url= and sha256= on release
```

Scripts live in `scripts/` and are installed by their corresponding formula in `Formula/`. The formula references a versioned tarball of this repo, so every release must be tagged in order for Homebrew to resolve and verify the download.

### Releases and the Update Workflow

All formulae in this tap share a single release tag (e.g. `v1.2.0`). When a tag matching `v*` is pushed, the `update-formula-sha.yml` workflow:

1. Builds a deterministic tarball for that tag and computes its SHA256
2. Creates the GitHub Release and uploads the tarball as a release asset
3. Rewrites the `url` and `sha256` fields in **every** `Formula/*.rb` to point at that asset
4. Commits and pushes the change back to `main` in a single commit

This means you never need to manually update a formula after tagging a release, and adding a new formula requires no workflow change.

> **Note:** If `main` is branch-protected, `GITHUB_TOKEN` will not have permission to push directly. In that case, replace the token in the `actions/checkout` step with a GitHub App token or a Personal Access Token that has write access.

---

## Adding a New Script and Formula

### 1. Add the script

Place your shell script in the `scripts/` directory and make sure it is executable:

```bash
chmod +x scripts/my-new-script.sh
```

The script can be written for any shell. The formula will install it into the Homebrew `bin` directory so it is available on `$PATH`.

### 2. Create the formula

Create a new file at `Formula/my-new-script.rb`:

```ruby
class MyNewScript < Formula
  desc "A short description of what the script does"
  homepage "https://github.com/dobsondev/homebrew-tap"
  url "https://github.com/dobsondev/homebrew-tap/archive/refs/tags/v0.0.0.tar.gz"
  sha256 "placeholder"

  def install
    bin.install "scripts/my-new-script.sh" => "my-new-script"
  end

  test do
    system "#{bin}/my-new-script", "--help"
  end
end
```

The `url` and `sha256` values are placeholders — they will be replaced automatically the next time you push a release tag.

The `bin.install` line copies the script from `scripts/` into the Homebrew `bin` directory and renames it (stripping the `.sh` extension), so users run it as `my-new-script`.

### 3. Commit, tag, and push

```bash
git add scripts/my-new-script.sh Formula/my-new-script.rb
git commit -m "feat: add my-new-script formula"
git tag v1.x.0
git push origin main --tags
```

The workflow triggers on the tag push, creates the release, and rewrites `url`/`sha256` in every formula automatically — no workflow edit needed for a new formula.

### 4. Install

```bash
brew update
brew install dobsondev/tap/my-new-script
```