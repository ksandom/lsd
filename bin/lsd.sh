#!/bin/bash
# An ls style util for listing out the first-line descriptions.

separator="	"
maxSymlinkDepth="20"

defaultColour="\\e[0m"

usefulColours[0]="$defaultColour"
colourCount=0

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
            result="$(file "$fileName" | sed 's/^.*symbolic link to //g')"
            if [ -h "$result" ]; then
                deepConvertSymlink "$result" "$maxSymlinkDepth"
            else
                echo "$result"
            fi
        else
            echo "$fileName"
        fi
    done
}

function deepConvertSymlink
{
    fileName="$1"
    depth="$2"
    
    result="$(file "$fileName" | sed 's/^.*symbolic link to //g')"
    
    if [ -h "$result" ]; then
        if [ "$depth" -lt "$maxSymlinkDepth" ]; then
            let nextDepth=$depth+1
            deepConvertSymlink "$result" "$nextDepth"
        else # We're out of our depth. Just return what we have.
            echo "$result"
        fi
    else # Success.
        echo "$result"
    fi
}

function getType
{
    fileName="$1"
    
    if [ ! -e "$fileName" ]; then
        echo "File not found - $fileName"
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

function getMethod
{
    fileName="$1"
    description="$2"
    
    line="$(grep -n "$description" "$fileName" | head -n1)"
    lineNumber="$(echo "$line" | cut -d: -f1)"
    lineRemainder="$(echo "$line" | cut -d: -f2-)"
    cleanedRemainder="$(echo "$lineRemainder" | sed 's/^ *//g')"
    
    if [ "${cleanedRemainder::1}" == '#' ]; then
        commentInitiator='#'
    elif [ "${cleanedRemainder::2}" == '//' ]; then
        commentInitiator='//'
    else
        commentInitiator="unknown (${cleanedRemainder::5})"
    fi
    
    echo "l=$lineNumber, c=$commentInitiator"
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
            method="--help"
        elif [ "${type::5}" == 'ASCII' ]; then
            description="$(head -n10 "$fileName" | exclude "$fileName" | grep '^#' | cut -b3- | head -n 1)"
            method="$(getMethod "$fileName" "$description")"
        fi
        
        echo -e "$type$separator$method$separator$description"
    else
        echo "$separator$separator$type."
    fi
}

function glue
{
    while read -r fileName; do
        echo -e "${fileName}$separator$(getDescriptionForFile "$fileName")" &
    done
    wait
}

function format
{
    #column -t -s"\0"
    IFS="${separator}"
    while read fileName type method description; do
        printf '%-30s' "$(truncateText "$fileName" 30)"
        printf '%-30s' "$(colouriseText "$type" 10)"
        printf '%-30s' "$(colouriseText "$method" 10)"
        printf '%-30s' "$(truncateText "$description" 50)"
        echo
    done
    
    # TODO This line is probably unnecessary.
    IFS=" "
}

function truncateText
{
    text="$1"
    limit="$2"
    
    echo "$text" | cut -b-$limit
}

function colouriseText
{
    text="$1"
    limit="$2"
    
    inputId="$(echo "$text" | md5sum | sed 's/\([a-z]\|-\| \)//g' | sed 's/^0*//g')"
    outputId=$(($inputId%$colourCount))
    
    colour="${usefulColours[$outputId]}"
    
    truncatedText="$(echo "$text" | cut -b-$limit)"
    
    echo -e "${colour}${truncatedText}${defaultColour}"
}

function generateColours
{
    for foreground in {39..37} {90..97}; do
        for background in {49..47} {100..107}; do
            let offsetBackground=$background-10
            
            # TODO Also remove light vs dark colour combinations.
            if [ "$offsetBackground" != "$background" ]; then
                usefulColours+=("\\e[${foreground}m\\e[${background}m")
            fi
        done
    done
    
    colourCount="$(echo "${usefulColours[@]}" | wc -w)"
}

function listColors
{
    for colour in ${usefulColours[@]}; do
        echo -e "${colour}thing${defaultColour}"
    done
}

generateColours
# listColors

if [ "$1" == '' ]; then
    getFileList | convertSymlinks | glue | format
else
    inputToList "$@" | convertSymlinks | glue | format
fi
