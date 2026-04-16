# Contributing to MCM

Thank you for your interest in contributing!

## Adding a New Provider

Providers are defined in `providers.json`. To add a new provider:

1. Fork the repository
2. Add your provider to `mcm/providers.json`:

```json
{
  "id": "yourprovider",
  "name": "Your Provider Name",
  "description": "Brief description of the provider",
  "models": "Model-1 / Model-2",
  "base_url": "https://api.yourprovider.com/v1",
  "api_key_var": "YOURPROV_API_KEY",
  "api_link": "https://yourprovider.com/docs",
  "env_vars": {
    "ANTHROPIC_MODEL": "model-name",
    "ANTHROPIC_SMALL_FAST_MODEL": "model-name"
  }
}
```

3. Ensure the JSON is valid
4. Submit a pull request

## Provider Schema

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique identifier (lowercase, no spaces) |
| `name` | Yes | Display name |
| `description` | No | Brief description |
| `models` | Yes | Available models |
| `base_url` | Yes | API base URL |
| `api_key_var` | Yes | Environment variable name for API key |
| `api_link` | Yes | Link to API documentation |
| `env_vars` | No | Additional environment variables |

## Running Tests

```bash
cd mcm
chmod +x tests/run_tests.sh
./tests/run_tests.sh
```

## Code Style

- Use `set -e` at the top of scripts
- Use `local` for function variables
- Use meaningful function names prefixed with `_mcm_` for internal functions
- Quote variables: `"$var"` not `$var`
