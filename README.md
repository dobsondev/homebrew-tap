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

All formulae in this tap share a single release tag (e.g. `v1.2.0`). When a tag matching `v*` is pushed, the `update-formula-sha.yml` workflow runs a matrix job — one job per formula — that:

1. Fetches the tarball for that tag from GitHub
2. Computes its SHA256
3. Updates the `url` and `sha256` fields in the formula file using `sed`
4. Commits and pushes the change back to `main`

This means you never need to manually update a formula after tagging a release.

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

### 3. Register the formula in the update workflow

Add the new formula path to the matrix in `.github/workflows/update-formula-sha.yml`:

```yaml
strategy:
  matrix:
    formula-file:
      - Formula/desktop-file-helper.rb
      - Formula/my-new-script.rb   # add this line
```

### 4. Commit, tag, and push

```bash
git add scripts/my-new-script.sh Formula/my-new-script.rb .github/workflows/update-formula-sha.yml
git commit -m "feat: add my-new-script formula"
git tag v1.x.0
git push origin main --tags
```

The workflow will trigger on the tag push and update the `url` and `sha256` in the formula automatically.

### 5. Install

```bash
brew update
brew install dobsondev/tap/my-new-script
```