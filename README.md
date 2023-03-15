# Abydos Tutorial

## Dependencies
- [wait-for](https://github.com/eficode/wait-for)

# Steps

## Schema Generation

Use kaslcred for generation of schemas

## Troubleshooting
### Seeing the keri/cf/main directory created
This means you don't have the configuration directory properly set, or you may not be running the script from the root of this repository.

Make sure you are running the script from the root of the repository.


## Code Style
### Double quoting to prevent word splitting
Use `"${VARNAME}"` instead of `${VARNAME}`. See [SC2086](https://github.com/koalaman/shellcheck/wiki/SC2086)