# [Abydos](https://en.wikipedia.org/wiki/Abydos,_Egypt) Tutorial

## Dependencies
- [wait-for](https://github.com/eficode/wait-for)
- [kaslcred](https://pypi.org/project/kaslcred/) for generation of schemas

## Modes
1. KLI: Use the KERI Command Line to create witnesses, controllers, and issue credentials
```bash
./workflow.sh
```
2. Agents: Use KERI Agents to create controllers and issue credentials. Uses the KLI for witness creation.
```bash
./workflow.sh -a
```

## Troubleshooting
### Seeing the keri/cf/main directory created
This means you don't have the configuration directory properly set, or you may not be running the script from the root of this repository.

Make sure you are running the script from the root of the repository.


## Code Style
### Double quoting to prevent word splitting
Use `"${VARNAME}"` instead of `${VARNAME}`. See [SC2086](https://github.com/koalaman/shellcheck/wiki/SC2086)