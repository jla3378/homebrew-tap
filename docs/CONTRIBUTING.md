# Repository Guidelines

## Project Structure

This repository is a Homebrew tap for personal formulas and casks. Put casks
in `Casks/<token>.rb`. Put formulas in `Formula/<name>.rb`, and focused Ruby
tests in `test/`. Keep user documentation in `docs/`. Do not add downloaded
installers, generated archives, or Homebrew cache files.

## Build, Test, and Development Commands

Run these commands from the repository root.

```sh
/opt/homebrew/bin/brew style --cask adobe-acrobat-pro-sca
/opt/homebrew/bin/brew audit --cask --strict adobe-acrobat-pro-sca
/usr/bin/ruby -Itest test/adobe_acrobat_pro_sca_test.rb
/opt/homebrew/bin/brew install --cask jla3378/tap/adobe-acrobat-pro-sca
```

Use `style` to format and check Ruby style. Use `audit` to check Cask DSL and
tap policy. Run an install only when you intend to run a vendor installer.
It can request administrator authorization.

## Coding Style and Naming

Use Homebrew's Ruby style. Indent with two spaces. Use double quotes for
strings. Name files after their Homebrew tokens, such as
`Casks/adobe-acrobat-pro-sca.rb`. Keep cask definitions declarative. Place
vendor-specific behavior in a small `Utils` module only when the Cask DSL
cannot express it.

## Testing Guidelines

Use Minitest for cask logic. Name tests `<cask>_test.rb`. Run `brew style`,
`brew audit`, and the matching Ruby test for every cask change. For installer
changes, test the matching install or upgrade path on a disposable or
non-production machine. Do not modify signed app bundles after installation.

## Commits and Pull Requests

Use short imperative commit subjects, for example `Fix Acrobat update target`.
Create `feat/`, `fix/`, or `chore/` branches; never commit directly to `main`.
Open an issue for each feature or bug. Pull requests must explain the user
impact, link the issue, list the commands run, and include relevant installer
output.
