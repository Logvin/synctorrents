#!/bin/bash

#-----------------------------
# Import variables from synctorrents.conf file - Make sure you update it!
source ./synctorrents.conf

#-----------------------------
#This is the main function. Everything else should be a subset of this.
main() {
	myPrint "$appName Main" "Main Function started."
	#Make sure the script is not already running.
	if ! mkdir $lockFileLocation 2>/dev/null; then
		myPrint "File Lock Check" "ERROR: $appName is already running. Exiting now."
		exit 1
	fi
	#It is not running, and the lock file directory has been created.
	myPrint "File Lock Check" "$appName is not running, starting now."
	myPrint "File Lock Check" "Lock file created: $lockFileLocation"
	#The work happens here
	#Check that the flat files are created
	myPrint "$appName Main" "Checking for movedFileHistory.log file" "INFO"
	if test -f "$movedFileHistory"; then
		#It does exist
		myPrint "$appName Main" "movedFileHistory.log file exists!" "INFO"
	else
		#it does not exist, create it
		myPrint "$appName Main" "movedFileHistory.log file does not exist. Creating now!" "INFO"
		touch "$movedFileHistory"
		if test -f "$movedFileHistory"; then
			myPrint "$appName Main" "movedFileHistory.log file created succesfully."
		else
			myPrint "$appName Main" "movedFileHistory.log file creation failed. Exiting!"
			exit 1
		fi
		
	fi
	for (( w=0; w<"${#fileTypes[@]}"; w++ ))
	do
		moveFiles "${fileTypes[w]}"
	done
	#Transfer the files to the main server using Rsync for atomic transfers
	myPrint "File Transfer" "Checking $stagedForTransfer for files to transfer..." "INFO"
	local ftnumber=$(find $stagedForTransfer -type f | wc -l)
	if [ $ftnumber = "0" ] ; then
		myPrint "File Transfer" "No files to transfer found!"
	else
		myPrint "File Transfer" "Found $ftnumber files to transfer. Transferring now."
		#Make sure you have a text file titled "rsync_pass" located in the same directory as this script that contains the password of your remote rsync daemon
		if [ $dryRun = "FALSE" ] ; then
			rsync -rvh --progress -stats --password-file=$rsync_pass --remove-source-files --log-file=$rsyncLogFile  $stagedForTransfer  $remote_login@$remote_host::ReadyForImport
			myPrint "File Transfer" "File transfer complete."
		else
			rsync -rvh --dry-run --progress -stats --password-file=$rsync_pass --remove-source-files --log-file=$rsyncLogFile  $stagedForTransfer  $remote_login@$remote_host::ReadyForImport
			myPrint "File Transfer" "(Dry Run) File transfer complete."
		fi
		myPrint "File Transfer" "Truncating Rsync Log file to 20Mb." "INFO"
		#Trim the log files to 20Mb to ensure they does not grow too big.
		truncate -s 20m $rsyncLogFile
		truncate -s 20m $cronLog
		#Clear out the staging directory for next time
		find $stagedForTransfer -empty -type d -delete
        mkdir $stagedForTransfer
	fi
	
	
	
	
	#The work is over!
	myPrint "File Lock Check" "Main Function complete, removing lock file."
	rm -r $lockFileLocation
	myPrint "File Lock Check" "Lock file removed: $lockFileLocation"
	myPrint "$appName Main" "Main Function completed."
}

#Function that scans for a specific file type and moves to the staging directory
moveFiles() {
	for (( w=0; w<"${#fileTypes[@]}"; w++ ))
	do
		filetype="${fileTypes[w]}"
		myPrint "moveFiles" "Scanning for file type: $filetype"
		#Scans the source directory and documents the file paths in an array
		mapfile -t fileArrayTMP < <(find $finishedDownloadPath -type f -iname "*.$filetype" | grep -v "sample")
		myPrint "moveFiles" "${#yfileArrayTMP[@]} $filetype files found."
		if [ $filetype = "rar" ] ; then
			#RAR files are processed slightly differently than the rest.
			for (( i=0; i<${#fileArrayTMP[@]}; i++ ));
			do
				local tmpFile="${fileArrayTMP[i]}"
				local myBaseName=$(basename "$tmpFile")
				grep -q -F "$tmpFile" $movedFileHistory
				if [ $? = "0" ] ; then
					#Found it in the flat file. Skipping!
					myPrint "moveFiles" "Already Exists: $myBaseName" "INFO"
				else
					#Did not see this file name in the flat file. Time to process it.
					myPrint "moveFiles" "New Download: $myBaseName"
					#RAR files are always in a subfolder, so no need to verify it is in the completed download file.
					local DIR="$(basename "$(dirname "$tmpFile")")"
					myPrint "moveFiles" "Creating Directory: $stagedForTransfer/$DIR" "INFO"
					if [ $dryRun = "FALSE" ] ; then
						#OLD mkdir "$stagedForTransfer"/"$DIR"
						mkdir "$stagedForTransfer$myDIR"
					fi
					myPrint "moveFiles" "Extracting RAR Archive to destination directory: $tmpFile" "INFO"
					local extractedDIR="$(dirname "$tmpFile")"
                                        local myDIR="${extractedDIR:${#finishedDownloadPath}}"
					#The extraction command
					if [ $dryRun = "FALSE" ] ; then
						7z e -o"$extractedDIR" "$tmpFile" -y
					fi
					myPrint "moveFiles" "Extraction Complete. Getting extracted file name." "INFO"
					local fileName=$(7z l -slt "$tmpFile" | grep -e '^Path.*$' | grep -e '.*[^rar]$' | cut -c8-)
					myPrint "moveFiles" "Extracted file name: $fileName" "INFO"
					local fullExtractedPath="$extractedDIR/$fileName"
					myPrint "moveFiles" "Moving $extractedDIR/$fileName file to $stagedForTransfer$myDIR/$fileName" "INFO"
					if [ $dryRun = "FALSE" ] ; then
						#OLD cp --no-preserve=mode,ownership -f "$fullExtractedPath" "$stagedForTransfer"/"$DIR"/"$fileName" && rm "$fullExtractedPath"
						cp --no-preserve=mode,ownership -f "$fullExtractedPath" "$stagedForTransfer$myDIR"/"$fileName" && rm "$fullExtractedPath"
					fi
					myPrint "moveFiles" "Copy Complete. Adding $tmpFile to $movedFileHistory" "INFO"
					echo "$(date +%Y-%m-%d-%H:%M:%S) - $tmpFile" >> $movedFileHistory
				fi
			done
		else
			for (( i=0; i<"${#fileArrayTMP[@]}"; i++ ));
			do
				#Scan through the array of found files.
				tmpFile="${fileArrayTMP[i]}"
				local myBaseName=$(basename "$tmpFile")
				#Search the Moved File History flat file to ensure that the script has not previously moved the file.
				grep -q -F "$tmpFile" $movedFileHistory
				if [ $? = "0" ] ; then
					#Found it in the flat file. Skipping!
					myPrint "moveFiles" "Already Exists: $myBaseName" "INFO"
				else
					#Did not see this file name in the flat file. Time to process it.
					myPrint "moveFiles" "New Download: $myBaseName"
					#Sonarr/Radarr wants to see the file in the same directory it was originally downloaded to. Figuring out what that is here.
					local DIR="$(basename "$(dirname "$tmpFile")")"
					myPrint "moveFiles" "Directory Base Name: $DIR" "INFO"
					if [[ "$DIR" = "completed" ]] ; then
						#not in a subfolder, just copy it
						myPrint "moveFiles" "Not in a subfolder, making a copy to $stagedForTransfer/$myBaseName" "INFO"
						if [ $dryRun = "FALSE" ] ; then
							cp --no-preserve=mode,ownership "$tmpFile" "$stagedForTransfer"/"$myBaseName"
						fi
					else
						#ALEX Testing full path
						#myPrint "TESTING" "Testing full path creation"
						local myFullDir="$(dirname "$tmpFile")"
						local myDIR="${myFullDir:${#finishedDownloadPath}}"
						#myPrint "TESTING" "stagedForTransfer =  $stagedForTransfer"
						#myPrint "TESTING" "alexDIR = $alexDIR"
						#myPrint "TESTING" "Action: mkdir $stagedForTransfer$alexDIR"
						#END new Testing

						#its in a subfolder. mkdir and copy
						#OLD myPrint "moveFiles" "In a subfolder, making a copy to $stagedForTransfer/$DIR/$myBaseName"
						myPrint "moveFiles" "In a subfolder, making a copy to $stagedForTransfer$myDIR/$myBaseName"
						if [ $dryRun = "FALSE" ] ; then
							#OLD mkdir -p "$stagedForTransfer"/"$DIR"
							mkdir -p "$stagedForTransfer$myDIR"
							#OLD cp --no-preserve=mode,ownership "$tmpFile" "$stagedForTransfer"/"$DIR"/"$myBaseName"
							cp --no-preserve=mode,ownership "$tmpFile" "$stagedForTransfer$myDIR"/"$myBaseName"
						fi
					fi
					myPrint "moveFiles" "Copy Complete. Adding to $movedFileHistory" "INFO"
					echo "$(date +%Y-%m-%d-%H:%M:%S) - $tmpFile" >> $movedFileHistory
				fi
			done
		fi
	done
}

#This function will echo out with the current date/time, the function name and the message that is passed
myPrint() {
	if [ "$3" == "$logLevel" ] ; then
		echo "$(date +%Y-%m-%d-%H:%M:%S) - $1 - $2"
		echo "$(date +%Y-%m-%d-%H:%M:%S) - $1 - $2" >> $logFile
	elif [ "$3" == "" ]; then
		echo "$(date +%Y-%m-%d-%H:%M:%S) - $1 - $2"
		echo "$(date +%Y-%m-%d-%H:%M:%S) - $1 - $2" >> $logFile
	fi
}

enableLogging() {
	#This function will check if there is a log file, create if not, and trim entries older than X days. Set the X number of days in the variables at the begining of this script.
	if test -f "$logFile"; then
		#It does exist. Trim entries older than X days.
		#
		local oldestLogDate="$(date +%Y-%m-%d -d "$logDays days ago")" 
		sed -i "/^$oldestLogDate/ d" "$logFile" 
	else
		#it does not exist, create it
		echo "** touching $logFile now"
		touch "$logFile"
		echo "** touch done"
		if test -f "$logFile"; then
			echo "New log file created"
		else
			echo "Unable to create $logFile. Exiting app."
			exit 1
		fi
		
	fi

}
#This is the first thing the script will do. It will enable the log file and trim it.
enableLogging
#-----------------------------
#Set up the -v flag which outputs to terminal as well as log file. This will call the main function if the -v flag is set. If it is not set, the loop will end, and the main function will be called after.
myPrint "$appName Startup" "****************************************"
myPrint "$appName Startup" "$appName is starting up!"
while getopts ":v" opt; do
  case $opt in
    v)
	  myPrint "$appName Startup" "Verbose Mode = Enabled! All output will be mirrored to the terminal and INFO logs will be displayed."
	  logLevel="INFO"
      ;;
    \?)
      echo "Invalid option: -$OPTARG   Shutting down!"
	  myPrint "$appName Startup" "ERROR: Invalid option: -$OPTARG   Shutting down!"
	  exit 1
      ;;
  esac
done
if [ $logLevel = "ERROR" ] ; then
	myPrint "$appName Startup" "Verbose Mode = Disabled! There will be no additional terminal output and INFO logs will be hidden. Use the -v flag to mirror output to the terminal and enable INFO logs."
fi
#Call the main function
main
exit 1
#-----------------------------

