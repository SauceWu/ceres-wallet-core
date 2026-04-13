#!/usr/bin/env python3
"""Trims wallet-core registry.json to keep only needed chains."""

import json
import shutil
import sys
from pathlib import Path

DEFAULT_CHAINS = {
    'ethereum', 'solana', 'sui', 'tron',
    'smartchain', 'polygon', 'optimism', 'arbitrum',
    'avalanchec', 'base', 'fantom', 'cronos',
    'zksync', 'linea', 'scroll', 'mantle', 'blast',
    'ronin', 'moonbeam', 'boba', 'kaia', 'opbnb',
    'arbitrumnova', 'polygonzkevm', 'manta',
    'metis', 'aurora', 'celo', 'xdai', 'kavaevm', 'sonic',
}

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <wallet-core-dir> [chains...]")
        sys.exit(1)

    wc_dir = sys.argv[1]
    chains = set(sys.argv[2:]) if len(sys.argv) > 2 else None
    if chains is None:
        chains = DEFAULT_CHAINS

    registry_path = Path(wc_dir) / 'registry.json'
    if not registry_path.exists():
        print(f"Error: {registry_path} not found")
        sys.exit(1)

    shutil.copy2(registry_path, registry_path.with_suffix('.json.bak'))

    with open(registry_path) as f:
        registry = json.load(f)

    original = len(registry)
    keep = {c.lower() for c in chains}
    filtered = [
        e for e in registry
        if e.get('id', '').lower() in keep
        or e.get('name', '').lower() in keep
    ]

    with open(registry_path, 'w') as f:
        json.dump(filtered, f, indent=2)

    print(f"Trimmed registry: {original} -> {len(filtered)} chains")

if __name__ == '__main__':
    main()
