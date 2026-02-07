#!/bin/bash
if command -v nuon &> /dev/null; then
    echo "nuon CLI found: $(nuon version 2>/dev/null || echo 'installed')"
    exit 0
else
    echo "Nuon CLI is not installed."
    echo ""
    echo "Install via Homebrew:"
    echo "  brew install nuonco/tap/nuon"
    echo ""
    echo "Or via install script:"
    echo "  curl -sSL install.nuon.co | bash"
    echo ""
    echo "The plugin works without the CLI, but sync and validation require it."
    exit 1
fi
