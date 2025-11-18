#!/bin/bash

# VM ka current IP auto-detect:
ipv4_address=$(hostname -I | awk '{print $1}')

file_to_find="../backend/.env.docker"

current_url=$(sed -n "4p" $file_to_find)

if [[ "$current_url" != "FRONTEND_URL=\"http://${ipv4_address}:5173\"" ]]; then
    if [ -f $file_to_find ]; then
        sed -i -e "s|FRONTEND_URL.*|FRONTEND_URL=\"http://${ipv4_address}:5173\"|g" $file_to_find
    else
        echo "ERROR: File not found."
    fi
fi
