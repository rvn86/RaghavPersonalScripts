if [[ "$1" == "" ]];then
    FILE_PATH="/audiobook-creator/generated_audiobooks/audiobook.m4a"
else
    FILE_PATH="$1"
fi

ffprobe -v quiet -show_entries format_tags=comment -of default=noprint_wrappers=1 $FILE_PATH | cut -f2 -d '=' | jq
