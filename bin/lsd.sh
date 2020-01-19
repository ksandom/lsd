#!/bin/bash
# An ls style util for listing out the first-line descriptions.

function getFileList
{
    ls -1
}

function inputToList
{
    for fileName in "$@"; do
        echo "$fileName"
    done
}

function getDescriptionForFile
{
    fileName="$1"
    
    head -n10 "$fileName" | grep -v '\(^#!\|^# *$\|Copyright\)' | grep '^#' | cut -b3- | head -n 1
}

function glue
{
    while read -r fileName; do
        echo "${fileName}\0$(getDescriptionForFile "$fileName")"- &
    done
    wait
}

function format
{
    column -t -s"\0"
}

if [ "$1" == '' ]; then
    getFileList | glue | format
else
    inputToList "$@" | glue | format
fi
