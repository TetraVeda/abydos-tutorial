# [Abydos](https://en.wikipedia.org/wiki/Abydos,_Egypt) Tutorial

## Dependencies
- [wait-for](https://github.com/eficode/wait-for)
- [kaslcred](https://pypi.org/project/kaslcred/) for generation of schemas
- [vLEI server (vLEI-server)](https://github.com/WebOfTrust/vLEI)

See the [installation](#installation) section for a dependency set up walkthrough.

## Modes
1. KLI: Use the KERI Command Line to create witnesses, controllers, and issue credentials
```bash
./workflow.sh
```
2. Agents: Use KERI Agents to create controllers and issue credentials. Uses the KLI for witness creation.
```bash
./workflow.sh -a
```

## Installation

### KASLCred

KASLCred depends on the following libraries being installed:
- [KERIpy](https://github.com/WebOfTrust/keripy) version 1.0.0 \
  Install with PIP
  ```bash
  python -m pip install keri=1.0.0
  ``` 

KERIpy further depends on the following set of dependencies being installed:
- [Rust](https://www.rust-lang.org/tools/install) \
  Install with the typical script. 
  ```bash
  # the "-s -- -y" options are for a silent, unattended install. Omit them if you want to configure the install.
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # Remember to set the PATH variable to include the Cargo binary directory like so:  PATH="$HOME/.cargo/bin:$PATH
  ```
- [Libsodium](https://libsodium.gitbook.io/doc/installation) \
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

## Troubleshooting
### Seeing the keri/cf/main directory created
This means you don't have the configuration directory properly set, or you may not be running the script from the root of this repository.

Make sure you are running the script from the root of the repository.


## Code Style
### Double quoting to prevent word splitting
Use `"${VARNAME}"` instead of `${VARNAME}`. See [SC2086](https://github.com/koalaman/shellcheck/wiki/SC2086)