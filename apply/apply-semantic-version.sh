#!/usr/bin/env bash
# Exit immediately if any command including those in a piped sequence exits with a non-zero status
set -euo pipefail

# Provide a useful error message if tag already exists
if git tag -l "v${VERSION}" | grep -q .; then
    echo "Error: Tag v${VERSION} already exists" >&2
    exit 1
fi

git tag v${VERSION}
git push origin v${VERSION}

echo "Tagged branch with semantic version: ${VERSION}"
