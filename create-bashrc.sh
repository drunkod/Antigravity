#!/usr/bin/env bash

# Create a .bashrc that works with VS Code shell integration

cat > ~/.bashrc <<'EOF'
# Antigravity-compatible .bashrc

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Basic history settings
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend

# Check window size after each command
shopt -s checkwinsize

# Make less more friendly for non-text files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Set a simple prompt (will be overridden by VS Code if integration works)
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Enable color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

# Useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Source VS Code shell integration if it exists
# This variable is set by VS Code when launching the terminal
if [ -n "$VSCODE_SHELL_INTEGRATION" ]; then
    # Prevent the __vsc_prompt_cmd_original error
    if [ -z "$__vsc_prompt_cmd_original" ]; then
        __vsc_prompt_cmd_original=""
    fi
fi

echo "✅ .bashrc loaded for Antigravity terminal"
EOF

echo "✅ Created ~/.bashrc for Antigravity"
echo ""
echo "Now restart Antigravity:"
echo "  ./stop-vnc.sh && ./start-with-vnc.sh"
