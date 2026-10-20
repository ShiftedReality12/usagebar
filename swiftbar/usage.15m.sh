#!/bin/bash
# SwiftBar plugin: refreshes every 15 minutes (the "15m" in the file name).
# Set USAGEBAR_BIN if you installed the script somewhere other than ~/bin/usage.
exec "${USAGEBAR_BIN:-$HOME/bin/usage}" --swiftbar
