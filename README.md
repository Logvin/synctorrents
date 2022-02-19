# synctorrents
This is a bash script written to assist in moving content from one linux based machine to another. This solution utilizes the “Atomic Transfers” needed to ensure that destination utilities (Sonarr, Radarr, etc) do not move partially transferred files too early.

## Prerequisites
1. Install Rsync Daemon on the destination server.
	- Rsync Man Page: https://linux.die.net/man/1/rsync
	- Terrific Resource on how to set up the Daemon: https://www.atlantic.net/vps-hosting/how-to-setup-rsync-daemon-linux-server/
	- Ensure you follow the steps to create a username and password file on the destination server
2.	Create the ExtractAndTransfer file on the originating server, typically as ExtractAndTransfer.sh, and ensure that it is executable with `chmod +x ExtractAndTransfer.sh`
3.	Create a file for your Rsync Password on the originating server, typically named rsync_pass and located with the ExtrctAndTransfer.sh file. This file should contain only the password, nothing else. Ensure you `chmod 600 rsync_pass` if this is a shared server.
4.	Go through the ExtractAndTransfer.sh variables to ensure that your path names and variable names match your environment (IE: `rsync_pass="/your/location/rsync_pass"` should be updated to the correct path)

### If you have run into any issues, please file an issue in Github. 
