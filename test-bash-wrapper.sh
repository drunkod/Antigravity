#!/usr/bin/env bash

echo "🧪 Testing Antigravity Bash Wrapper"
echo "===================================="
echo ""

cd ~/antigravity
nix build . --impure 2>&1 | grep -v "warning:" || true

echo "1. Testing bash wrapper directly:"
./result/bin/bash -c 'echo "✅ Bash works"; echo "PATH has $(echo $PATH | tr ":" "\n" | wc -l) entries"'
echo ""

echo "2. Testing with --init-file (like Antigravity uses):"
echo 'echo "✅ Init file executed"' > /tmp/test-init.sh
./result/bin/bash --init-file /tmp/test-init.sh -c 'echo "✅ Bash with init-file works"'
rm /tmp/test-init.sh
echo ""

echo "3. Testing git availability:"
./result/bin/bash -c 'which git && git --version'
echo ""

echo "4. Testing PATH contents:"
./result/bin/bash -c 'echo $PATH | tr ":" "\n" | head -10'
echo ""

echo "5. Checking what bash actually is:"
readlink -f ./result/bin/bash
cat ./result/bin/bash | head -20
echo ""

echo "6. Testing interactive mode:"
echo -e 'echo "Interactive test"\nls /\nexit' | ./result/bin/bash -i
