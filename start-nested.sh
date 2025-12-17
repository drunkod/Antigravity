#!/usr/bin/env bash
# start-nested.sh
export DISPLAY_NUM=100  # Different display for nested instance
exec ./start-with-vnc.sh
