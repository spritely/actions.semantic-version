#!/usr/bin/env bash
# Exit immediately if any command including those in a piped sequence exits with a non-zero status
set -euo pipefail

# Provide a useful error message if tag already exists
if git tag -l "v${VERSION}" | grep -q .; then
    echo "Error: Tag v${VERSION} already exists" >&2
    exit 1
fi

# Catch the rare case where it was pushed by another job in the meantime
if git ls-remote --tags origin "refs/tags/v${VERSION}" | grep -q .; then
    echo "Error: Tag v${VERSION} already exists on remote" >&2
    exit 1
fi

git tag "v${VERSION}"

max_attempts=5
delay=5
for attempt in $(seq 1 $max_attempts); do
    if git push origin "v${VERSION}"; then
        echo "Tagged branch with semantic version: ${VERSION}"
        exit 0
    fi

    # Partial-success guard: did it actually land despite the error?
    if git ls-remote --tags origin "refs/tags/v${VERSION}" | grep -q .; then
        echo "Tag v${VERSION} confirmed on remote after error; treating as success"
        exit 0
    fi

    if [ "$attempt" -lt "$max_attempts" ]; then
        echo "Push attempt $attempt failed; retrying in ${delay}s..." >&2
        sleep $delay
        delay=$((delay * 2))
    fi
done

echo "Error: Push failed after ${max_attempts} attempts" >&2
exit 1