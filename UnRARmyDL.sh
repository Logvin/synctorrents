#!/bin/bash -x

#### Media file extraction script.
# This script processes files in a directory and extracts them and places them somewhere else for filebot.
#


command -v unrar >/dev/null 2>&1 || { echo >&2 "I require unrar but it's not installed or in my $PATH.  Aborting."; exit 1; }

# Set up some logging
SCRIPT_NAME="$(basename "$0")"
SCRIPT_PATH=$(pwd)
NOW=$(date +"%m%d%Y")
LOGDIR=""
LOGFILE="$SCRIPT_NAME-$NOW.log"

CHOWN="foo:bar"

# path to search for files to process
SEARCH_PATH="/cygdrive/X/Videos/temp"
# The base directory filebot watches for downloads
COMPLETED_PATH="/cygdrive/X/Videos/temp"
# Temporary location to extract to, such that files being written do not get processed
TEMP_EXTRACT_DIR="/cygdrive/X/Videos/extract"

# rar filter list, looks in same directory as script for a file called "unrar_files.lst", if not present defaults to *
UNRAR_MASK="@"
UNRAR_LIST="$SCRIPT_PATH/unrar_files.lst"
if [ ! -f $UNRAR_LIST ]; then
	UNRAR_MASK=""
	UNRAR_LIST="*"
fi

FILE_FILTER=$UNRAR_MASK$UNRAR_LIST

# Fix the IFS to deal with spaces in files
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

echo "Start Processing - $SCRIPT_NAME on $(date)"

# look for RAR archives
echo "Looking for archives (RAR) for extraction..."
for category in $( find $SEARCH_PATH -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort ); do
	cat_path="${SEARCH_PATH}/${category}"
	for archive in $( find $cat_path -maxdepth 2 -regextype egrep -type f -iregex '.*\.(rar)$' | sort ); do
		dest_path="${COMPLETED_PATH}/${category}"
		extr_path="${TEMP_EXTRACT_DIR}/${category}"
		echo "Extracting $archive TO $dest_path"
		unrar e -idq -y -o+ -p- "${archive}" "${FILE_FILTER}" "${extr_path}"
		if [ $? -eq 0 ]; then
        	echo "--> Successfully extracted."
        	echo "--> Move extracted file to destination where filebot can process it..."
        	mv ${extr_path}/* ${dest_dir}
    	else
        	echo "--> Error: Unable to extract."
        	exit 100
    	fi
	done
done

echo "Cleanup permissions..."
chown -R $CHOWN $COMPLETED_PATH

echo "Done processing!"

IFS=$SAVEIFS