#!/bin/bash

# Check if an SSH command was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 'ssh user@host -p port -i keyfile'"
    exit 1
fi

# Capture the input SSH command as a single string
SSH_CMD="$*"

# Extract user, host, port, and identity file using regex
USER_HOST=$(echo "$SSH_CMD" | grep -oP '(?<=ssh\s)[^ ]+')
PORT=$(echo "$SSH_CMD" | grep -oP '(?<=-p\s)\d+')
KEY=$(echo "$SSH_CMD" | grep -oP '(?<=-i\s)[^ ]+')

# Construct the SCP command
SCP_CMD="scp -P $PORT -i $KEY ~/Downloads/chapters/* $USER_HOST:/audiobook-creator/books/"

# Print the resulting SCP command
echo "$SCP_CMD"

