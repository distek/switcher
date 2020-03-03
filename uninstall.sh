#!/bin/bash

if [[ $(id -u) != 0 ]]; then
    echo "Run as root"
    exit 2
fi

rm -r /root/.cache/switcher 2>/dev/null

if [ -f .name ]; then
    rm /usr/local/bin/$(cat .name)
else
    rm /usr/local/bin/$(grep 'scriptName=' install.sh | cut -d'"' -f2) 2>/dev/null
fi

rm .name
