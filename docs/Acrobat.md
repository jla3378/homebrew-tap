# Adobe Acrobat Pro SCA

## Install

```sh
brew tap jla3378/tap
brew install --cask adobe-acrobat-pro-sca
```

## Upgrade

```sh
brew update
brew upgrade --cask adobe-acrobat-pro-sca
```

The cask uses Adobe's static SCA installer when Acrobat is absent. It uses
Adobe's current update package when an older Acrobat app is present. If the
installed app already matches Adobe's manifest, the cask records its receipt
without running an installer.

Before installation, the cask expands the full installer and checks its Acrobat
package version against Adobe's manifest. If Adobe's full installer lags, the
cask stages the manifest update, installs the full package, and then installs
the staged update. This keeps the Cask receipt and installed Acrobat version
aligned with the manifest.

## Repair an altered Acrobat installation

The cask does not modify files inside the signed Acrobat app bundle. If an
existing app is already at the manifest version, install the cask again to
record its Homebrew receipt without changing the app.

## Uninstall

A normal uninstall preserves Acrobat so a later incremental update can use the
base installation:

```sh
brew uninstall --cask adobe-acrobat-pro-sca
```

To remove Acrobat and related support files:

```sh
brew uninstall --cask --zap adobe-acrobat-pro-sca
```
