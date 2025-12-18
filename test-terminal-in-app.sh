#!/usr/bin/env bash

# This creates a test file to run inside Antigravity terminal

cat > ~/test-terminal.sh <<'EOF'
#!/usr/bin/env bash

echo "=================================="
echo "Antigravity Terminal Test"
echo "=================================="
echo ""
echo "SHELL: $SHELL"
echo "PATH entries: $(echo $PATH | tr ':' '\n' | wc -l)"
echo "Bash version: $(bash --version | head -1)"
echo "PWD: $PWD"
echo "USER: $USER"
echo "HOME: $HOME"
echo ""
echo "Available commands:"
for cmd in ls cat grep git which pwd cd; do
    if command -v $cmd >/dev/null 2>&1; then
        echo "  ✅ $cmd: $(which $cmd)"
    else
        echo "  ❌ $cmd: NOT FOUND"
    fi
done
echo ""
echo "Test basic command:"
ls -la ~ | head -5
echo ""
echo "Git test:"
git --version
echo ""
echo "✅ Terminal is working!"
EOF

chmod +x ~/test-terminal.sh

echo "✅ Created ~/test-terminal.sh"
echo ""
echo "Now:"
echo "1. Restart Antigravity: ./stop-vnc.sh && ./start-with-vnc.sh"
echo "2. Open terminal in Antigravity"
echo "3. Run: ~/test-terminal.sh"
