#!/bin/bash
# An ls style util for listing out the first-line descriptions.

separator="\0"

function getFileList
{
    ls -1
}

function inputToList
{
    for fileName in "$@"; do
        if [ -d "$fileName" ]; then
            ls -1 "$fileName" | sed "s#^#$fileName/#g"
        else
            echo "$fileName"
        fi
    done
}

function convertSymlinks
{
    while read -r fileName; do
        # TODO if [[ "$fileName" =~ ^.*:\ symbolic\ link.*$ ]]; then
        if echo "$(file "$fileName")" | grep -q "^.*: symbolic link.*$"; then
            echo "$(file "$fileName")" | sed 's/^.*symbolic link to //g'
        else
            echo "$fileName"
        fi
    done
}

function getType
{
    fileName="$1"
    
    if [ ! -e "$fileName" ]; then
        echo "File not found"
        return 1
    elif [ -d "$fileName" ]; then
        echo "Directory"
        return 1
    elif [ -h "$fileName" ]; then
        echo "Unresolved symlink"
        return 1
    else
        completeType="$(file "$fileName")"
        
        # TODO There are probably more types that should be supported here.
        if [[ "$completeType" =~ ^.*ASCII.*$ ]]; then
            firstLine="$(head -n1 "$fileName")"
            if [ "${firstLine::2}" == '#!' ]; then
                cleanedFirstLine="$(echo "$firstLine" | cut -d\# -f2 | sed 's/ //g;')"
                interpreter="$(basename "$cleanedFirstLine")"
                
                echo "ASCII/$interpreter"
                return 0
            else
                echo "ASCII"
                return 0
            fi
        else
            echo "Binary"
            return 0
        fi
    fi
}

function exclude
{
    fileName="$1"
    
    # TODO Should we exclude lines mentioning \|$fileName ?
    grep -iv "\(usage\| *or:\|^$\|^#!\|^ *$fileName\|^# *$\|Copyright\)"
}

function getDescriptionForFile
{
    fileName="$1"
    
    type="$(getType "$fileName")"
    if [ "$?" == 0 ] ; then
        if [ "$type" == 'Binary' ]; then
            # TODO Restrict to ELF?
            # TODO Fix path to the fileName. Eg ./filename vs an absolute path that is passed.
            description="$($fileName --help 2>/dev/null | head | exclude "$fileName" | head -n1)"
        elif [ "${type::5}" == 'ASCII' ]; then
            description="$(head -n10 "$fileName" | exclude "$fileName" | grep '^#' | cut -b3- | head -n 1)"
        fi
        
        echo "$type $separator$description"
    else
        echo "$type.$separator"
    fi
}

function glue
{
    while read -r fileName; do
        echo "${fileName}$separator$(getDescriptionForFile "$fileName")" &
    done
    wait
}

function format
{
    column -t -s"\0"
}

if [ "$1" == '' ]; then
    getFileList | convertSymlinks | glue | format
else
    inputToList "$@" | convertSymlinks | glue | format
fi
