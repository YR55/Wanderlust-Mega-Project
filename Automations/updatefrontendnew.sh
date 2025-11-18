#!/bin/bash

ipv4_address=$(hostname -I | awk '{print $1}')

file_to_find="../frontend/.env.docker"

current_url=$(cat $file_to_find)

if [[ "$current_url" != "VITE_API_PATH=\"http://${ipv4_address}:31100\"" ]]; then
    if [ -f $file_to_find ]; then
        sed -i -e "s|VITE_API_PATH.*|VITE_API_PATH=\"http://${ipv4_address}:31100\"|g" $file_to_find
    else
        echo "ERROR: File not found."
    fi
fi
