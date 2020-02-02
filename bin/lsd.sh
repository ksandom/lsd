#!/bin/bash
# An ls style util for listing out the first-line descriptions.

separator="	"
maxSymlinkDepth="20"

defaultColour="\\e[0m"
extraColoursToBan=("97 103" "96 103" "96 102" "97 106" "97 107" "96 107" "96 106" "95 106" "64 100" "93 107" "93 107" "95 102" "95 101" "95 105" "94 100" "92 107" "93 103" "93 102" "92 106" "92 103" "92 102" "91 105" "93 106" "91 101" "90 105" "90 104" "90 100" "37 102" "37 103" "37 47" "39 47" "94 104" "37 105" "94 101" "94 105" "90 101" "95 100" "95 104" "97 102" "91 100" "91 104" "39 49" "38 49" "38 48" "38 47" "37 49" "37 48")

# Stuff you shouldn't mess with.
usefulColours[0]="$defaultColour"
colourCount=0
debug=0

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

function generateUnfilteredCodes
{
    for foreground in {39..37}; do
        for background in {49..47}; do
            echo "$foreground" "$background"
        done
    done
    for foreground in {90..97}; do
        for background in {100..107}; do
            echo "$foreground" "$background"
        done
    done
}

function filterSimilarColours
{
    while read -r foreground $background;do
            let offsetForeground1=$foreground+10
            let offsetForeground2=$foreground+60
            let offsetForeground3=$foreground+70
            
            if [ "$offsetForeground1" != "$foreground" ] && [ "$offsetForeground2" != "$foreground" ] && [ "$offsetForeground3" != "$foreground" ]; then
                echo "$foreground $background"
            fi
    done
}

function filterManualColours
{
    combinedFilter='\('
    
    for filter in "${extraColoursToBan[@]}"; do
        if [ "${#combinedFilter}" == '2' ]; then
            combinedFilter="$combinedFilter$filter"
        else
            combinedFilter="$combinedFilter\|$filter"
        fi
    done
    combinedFilter="$combinedFilter\)"
    
    grep -v "$combinedFilter"
}

function generateColours
{
    while read -r foreground background;do
        if [ "$debug" == '0' ]; then
            usefulColours+=("\\e[${foreground}m\\e[${background}m")
        else
            usefulColours+=("$foreground,$background \\e[${foreground}m\\e[${background}m")
        fi
    done < <(generateUnfilteredCodes | filterManualColours | filterSimilarColours )
    
    colourCount="$(echo "${usefulColours[@]}" | wc -w)"
}

function listColours
{
    for colour in ${usefulColours[@]}; do
        echo -e "${colour}thing${defaultColour}"
    done
}

generateColours

case $1 in
    '')
        getFileList | convertSymlinks | glue | format
    ;;
    '--listColours')
        debug="1"
        usefulColours[0]="$defaultColour"
        generateColours
        listColours
    ;;
    *)
        inputToList "$@" | convertSymlinks | glue | format
    ;;
esac
