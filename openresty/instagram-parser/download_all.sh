#!/bin/bash
# Download Instagram HTML files with random delays
# Run from the instagram-parser directory

cd "$(dirname "$0")"
mkdir -p test_data

# Function to convert name to safe filename
to_filename() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | \
        LC_ALL=C sed 's/[^a-z0-9]/_/g' | \
        sed 's/__*/_/g; s/^_//; s/_$//'
}

# Function for random delay (2-5 seconds)
random_delay() {
    sleep $((RANDOM % 4 + 2))
}

# Parse urls_for_test.md and download each URL
tail -n +3 urls_for_test.md | while IFS='|' read -r _ name url _; do
    # Clean up name and url
    name=$(echo "$name" | xargs)
    url=$(echo "$url" | xargs | tr -d ' ')

    # Skip empty lines
    [ -z "$url" ] && continue
    [ -z "$name" ] && continue

    # Generate filename
    filename="test_data/$(to_filename "$name").html"

    # Skip if already exists and has og:description
    if [ -f "$filename" ] && grep -q 'og:description' "$filename" 2>/dev/null; then
        echo "✓ Skipping $filename (already exists with content)"
        continue
    fi

    echo "→ Downloading: $name"
    echo "  URL: $url"
    echo "  File: $filename"

    curl -s "$url" > "$filename"

    # Verify download
    if grep -q 'og:description' "$filename" 2>/dev/null; then
        echo "  ✓ Success"
    else
        echo "  ✗ Warning: No og:description found"
    fi

    echo ""
    random_delay
done

echo "Done! Run the parser on all files:"
echo "  nix-shell --run 'for f in test_data/*.html; do echo \"=== \$f ===\"; luajit cli.lua \"\$f\" | python3 -m json.tool; done'"
