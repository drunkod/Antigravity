#!/usr/bin/env bash

echo "🧪 Testing Antigravity Bash"
echo "===================================="
echo ""

cd ~/antigravity
nix build . --impure 2>&1 | grep -v "warning:" || true

BASH_BIN="./result/bin/bash"

echo "1. Testing bash execution:"
$BASH_BIN -c 'echo "✅ Bash works"'
echo ""

echo "2. Checking binary type (should be ELF, not script):"
if file $BASH_BIN | grep -q "ELF"; then
    echo "✅ Bash is an ELF binary (symlink)"
else
    echo "❌ Bash is NOT an ELF binary (likely a wrapper script)"
fi
readlink -f $BASH_BIN
echo ""

echo "3. Checking Git symlink:"
if [ -L "./result/bin/git" ]; then
    echo "✅ Git symlink exists in bin/"
else
    echo "❌ Git symlink missing"
fi
echo ""

echo "4. Testing interactive mode (simulated):"
# This should no longer show __vsc_prompt_cmd_original errors
echo -e 'echo "Interactive test"\nexit' | $BASH_BIN -i
