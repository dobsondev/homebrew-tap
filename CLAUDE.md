# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal [Homebrew](https://brew.sh) tap (`dobsondev/tap`). Users install it with `brew tap dobsondev/tap`, then install individual tools with `brew install dobsondev/tap/<formula-name>`.

## Structure

- `scripts/` — shell scripts that get installed into Homebrew's `bin/`
- `Formula/` — one `.rb` Homebrew formula per script
- `.github/workflows/update-formula-sha.yml` — CI that auto-updates `url` and `sha256` in each formula on release

## Release Workflow

Every formula references a versioned tarball of this repo. When a tag matching `v*` is pushed, the CI workflow runs a matrix job per formula that:

1. Fetches the tarball for that tag
2. Computes its SHA256
3. Updates the `url` and `sha256` fields in each formula via `sed`
4. Commits the change back to `main`

**You never manually update `url`/`sha256` in a formula** — push a tag and CI handles it.

## Adding a New Script and Formula

1. Place the script in `scripts/` and make it executable (`chmod +x`)
2. Create `Formula/my-script.rb` — use the existing formula as a template; set `url` and `sha256` to placeholders, they will be replaced on next tag push
3. Add the formula path to the `matrix.formula-file` list in `.github/workflows/update-formula-sha.yml`
4. Commit, tag (`git tag vX.Y.Z`), and push with tags (`git push origin main --tags`)

## Formula Template

```ruby
class MyScript < Formula
  desc "Short description"
  homepage "https://github.com/dobsondev/homebrew-tap"
  url "https://github.com/dobsondev/homebrew-tap/archive/refs/tags/v0.0.0.tar.gz"
  sha256 "placeholder"

  def install
    bin.install "scripts/my-script.sh" => "my-script"
  end

  test do
    system "#{bin}/my-script", "--help"
  end
end
```

The `bin.install` call strips the `.sh` extension so the command is available without it.

## Testing a Formula Locally

```bash
brew install --build-from-source Formula/desktop-file-helper.rb
brew test desktop-file-helper
brew audit --strict Formula/desktop-file-helper.rb
```
