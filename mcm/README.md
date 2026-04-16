# MCM - Internal Documentation

This directory contains the MCM source code.

## Files

- `mcm.sh` - Main CLI tool
- `ccwrap.sh` - Shell wrapper for `cc` command
- `providers.json` - Provider registry (community-maintained)

## Testing

```bash
cd mcm
chmod +x tests/run_tests.sh
./tests/run_tests.sh
```

## Building Release

```bash
tar -czvf mcm-VERSION.tar.gz mcm/
```

## Provider Registry URL

The default registry URL is:
```
https://raw.githubusercontent.com/hadih/mcm/main/mcm/providers.json
```

This is configurable via `MCM_REGISTRY` environment variable.
