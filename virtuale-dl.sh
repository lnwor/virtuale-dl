#!/bin/sh

# You can get that part of the header by copying the request for curl from the
# browser and then getting the COOKIES part of the header to paste here

# example: "Cookie: ApplicationGatewayAffinity=02138802938409f092;
# MoodleSession=92837492834029384d;
# _shibsession_6465666019283019283019287019238=_029984029384026383039384"
COOKIES=""
# id of the courses
COURSE_IDS=""
# directory where the script should store files
DIR=""


show_help(){
    echo You can either pass COOKIES, COURSE_IDS and DIR as options or you can
    echo set them editing the script.
    echo
    echo "Usage: $0 [-c COOKIES] [-i COURSE_IDS] [-d DIR]"
}

urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

############### 
# ENTRY POINT #
###############

while getopts ":hc:i:d:" opt; do
	case $opt in
		"h") show_help; exit;;
        "c") COOKIES="$OPTARG";;
		"i") COURSE_IDS=$OPTARG;;
		"d") DIR="$OPTARG";;
	esac
done
shift $(($OPTIND - 1))

if test -z "$COOKIES" || test -z "$COURSE_IDS";then
    echo -e "\033[0;31mERR:\033[0m You have to set COOKIES and COURSE_IDS first"
    exit
fi

if test -z $DIR;then
    echo -e "\033[0;33mWARN:\033[0m DIR not set, the current directory will be used"
    DIR="./"
fi

for ID in $COURSE_IDS; do
    COURSE_URL='https://virtuale.unibo.it/course/view.php?id='$ID
    PAGE=`curl -sS -H "$COOKIES" "$COURSE_URL"`
    COURSE_NAME=$(echo "$PAGE" | grep -oP '(?<=<title>Corso: )(.*?)(?=<\/title>)')
    mkdir -p "$DIR/$COURSE_NAME"
    # get resources/unibores
    echo "$PAGE" | grep -oE 'https://virtuale.unibo.it/mod/(unibores|resource)[^"]+' | \
    while read link; do
        file_url="$(curl "$link" -sS -H "$COOKIES" | grep -oE 'https://virtuale.unibo.it/pluginfile.php/[0-9]{6,8}/mod_(unibores|resource)/[^\?"]+' | sed 's/http:/https:/g')"
        encoded="$(echo $file_url | rev | cut -d/ -f1 | rev )"
        filename=$(urldecode "$encoded")
        # with -nc wget doesn't download existing files, with -P specifies the download directory
        wget -nc --header="$COOKIES" -P "$DIR/$COURSE_NAME" "$file_url" 2>/dev/null && echo "Downloaded $filename" & 
        wait $!
    done
    # get folders
    echo "$PAGE" | grep -oE 'https://virtuale.unibo.it/mod/folder[^"]+' | \
        while read link; do
            encoded="$(curl -sS -H "$COOKIES" "$link" | grep -oP '(?<=<h2>)(.*?)(?=<\/h2>)' | cut -d'>' -f2)"
            fold_name=$(urldecode "$encoded")
            # create the folder
            mkdir -p "$DIR/$COURSE_NAME/${fold_name}"
            # get files inside the folder
            curl -sS -H "$COOKIES" "$link" | grep -oE 'https://virtuale.unibo.it/pluginfile.php/[0-9]{6,8}/mod_folder/[^"\?]+' |\
                while read file_url <&4; do
                    encoded="$(echo $file_url | rev | cut -d/ -f1 | rev )"
                    filename=$(urldecode "$encoded")
                    wget -nc --header="$COOKIES" -P "$DIR/$COURSE_NAME/${fold_name}" "$file_url" 2>/dev/null && echo "Downloaded $filename" &
                    wait $!
                done 4<&0
        done
done