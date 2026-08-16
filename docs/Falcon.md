# Falcon Installer

`jla3378/tap/falcon-installer` installs CrowdStrike's Falcon Installer command
line tool. It does not install a sensor during `brew install`.

The formula uses CrowdStrike's published ARM64 macOS release. The release
checksum is in the formula. It does not contain tenant credentials, a CID, or
a Falcon sensor package.

Use the installed command with tenant-provided credentials or a secure local
configuration file to download and install the sensor. This action needs
administrator privileges and is separate from Homebrew:

```sh
sudo falcon-installer --config /path/to/falcon-installer.yaml
```

For atlas, `modules/mdm-profiles.nix` still installs the system-extension
approval profile. It is independent of this formula.

## Maintenance

Update the formula after a new upstream release. Verify the ARM64 macOS asset
checksum from the CrowdStrike release, then run:

```sh
/opt/homebrew/bin/brew style --formula falcon-installer
/opt/homebrew/bin/brew audit --formula --strict falcon-installer
/opt/homebrew/bin/brew test falcon-installer
```
