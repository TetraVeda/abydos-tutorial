# [Abydos](https://en.wikipedia.org/wiki/Abydos,_Egypt) Tutorial

This is the companion repository for the *KERI Tutorial Series: Treasure Hunting in Abydos! Issuing and Verifying a Credential (ACDC)* blog article.

## Modes

1. KLI: Use the KERI Command Line to create witnesses, controllers, and issue credentials
```bash
./workflow.sh
```
2. Agents: Use KERI Agents to create controllers and issue credentials. Uses the KLI for witness creation.
```bash
./workflow.sh -a
```

## Dependencies

| Project       | Version  |
|---------------|----------|
| libsodium.org | ^1.0.18  |
| python.org    | ^3.11.2  |
| rust-lang.org | ^1.65.0  |

One approach is to run the following command in this directory,
which will start a temporary shell with those basic tools
but will not make permanent changes to your machine: `sh <(curl tea.xyz) -E sh`
(We recommend installing [tea](tea.xyz) but it is not necessary.)

- [kaslcred](https://pypi.org/project/kaslcred/) for generation of schemas
- [vLEI server (vLEI-server)](https://github.com/WebOfTrust/vLEI)
- [sally](https://github.com/kentbull/sally)

See the [installation](#installation) section for a detailed dependency set up walkthrough.

## Installation

### KASLCred

KASLCred depends on the following libraries being installed:
- KERIpy
  - Rust
  - Libsodium
- vLEI-server
- sally (my fork)

#### [KERIpy](https://github.com/WebOfTrust/keripy)

Install version 1.0.0 of KERIpy. Since 1.0.0 has not yet been pushed to PyPi, the Python package manager,
you have to install from source like so:
```bash
git clone https://github.com/WebOfTrust/keripy.git
cd keripy
# You will use python3 or python depending on your environment configuration.
# Beware using a python virtual environment may interfere with your installation and prevent it from being seen from the abydos-tutorial directory.
python3 -m pip install -e ./
``` 

KERIpy further depends on the following set of dependencies being installed:
- [Rust](#rust)
- [Libsodium](#libsodium)

#### [Rust](https://www.rust-lang.org/tools/install)

Install with the typical script. 
```bash
# the "-s -- -y" options are for a silent, unattended install. Omit them if you want to configure the install.
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
# Remember to set the PATH variable to include the Cargo binary directory like so:  PATH="$HOME/.cargo/bin:$PATH
```

#### [Libsodium](https://libsodium.gitbook.io/doc/installation)

The Homebrew installation of Libsodium is not sufficient, or did not work for me. I had to do the following instructions like stated in Libsodium's Gitbook [Installation documentation](https://libsodium.gitbook.io/doc/installation) \
You need Libsodium on your PATH.\
Download a tarball of libsodium, preferably the latest stable version, then follow the ritual:
```bash
./configure
make && make check
sudo make install
```

### vLEI-server

The vLEI-server binary is created from the [WebOfTrust/vLEI](https://github.com/WebOfTrust/vLEI) repository.\
Install it like so:
```bash 
git clone https://github.com/WebOfTrust/vLEI.git
cd vLEI
python -m pip install -e ./
# installs the vLEI-server binary to your Python bin directory.
```

### My fork of Sally

The [sally](https://github.com/kentbull/sally) component is a small credential handler wrapper on top of KERIpy.\
You could think of it as a custom controller.\
Make sure to download my fork at https://github.com/kentbull/sally.

Sally depends on [KERIpy](#keripy) so all of KERIpy's dependencies must be installed including Rust and Libsodium.

Do not use the [GLEIF-IT/sally](https://github.com/GLEIF-IT/sally) upstream repository unless you want to write your own customizations.

If you end up writing a lot of customizations you may as well write your own custom controller from scratch using my fork and the GLEIF-IT sally as inspiration.

## References
- [wait-for](https://github.com/eficode/wait-for)

## Troubleshooting

### Seeing the keri/cf/main directory created

This means you don't have the configuration directory properly set, or you may not be running the script from the root of this repository.

Make sure you are running the script from the root of the repository.


## Code Style

### Double quoting to prevent word splitting

Use `"${VARNAME}"` instead of `${VARNAME}`. See [SC2086](https://github.com/koalaman/shellcheck/wiki/SC2086)
