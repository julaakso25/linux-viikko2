#!/bin/bash
set -eu
for polku in "$@"; do
    printf '%s  |  ' "$polku"
    findmnt -n -o SOURCE,TARGET,FSTYPE -T "$polku" | tr -s ' ' | tr '\n' ' '
    df -h --output=size "$polku" | awk 'NR==2 {print "| koko " $1}'
done
