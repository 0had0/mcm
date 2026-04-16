#!/usr/bin/env python3
import json
import sys
import os


def validate_providers():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    providers_file = os.path.join(script_dir, "..", "providers.json")

    with open(providers_file) as f:
        data = json.load(f)

    assert "providers" in data, "Missing providers key"
    assert isinstance(data["providers"], list), "Providers must be a list"
    assert len(data["providers"]) > 0, "Must have at least one provider"

    required_fields = ["id", "name", "base_url", "api_key_var", "api_link"]

    for i, p in enumerate(data["providers"]):
        for field in required_fields:
            assert field in p, f"Provider {i} missing required field: {field}"

        assert p["id"], f"Provider {i} has empty id"
        assert " " not in p["id"], f"Provider id cannot contain spaces: {p['id']}"

    ids = [p["id"] for p in data["providers"]]
    assert len(ids) == len(set(ids)), f"Duplicate provider IDs found: {ids}"

    print(f"Validated {len(data['providers'])} providers:")
    for p in data["providers"]:
        print(f"  - {p['id']}: {p['name']}")


if __name__ == "__main__":
    try:
        validate_providers()
        print("All validations passed!")
        sys.exit(0)
    except AssertionError as e:
        print(f"Validation failed: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
