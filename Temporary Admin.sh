#!/bin/zsh

:<<HEADER
██████╗  ██████╗  ██████╗██╗  ██╗███████╗████████╗███╗   ███╗ █████╗ ███╗   ██╗
██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝╚══██╔══╝████╗ ████║██╔══██╗████╗  ██║
██████╔╝██║   ██║██║     █████╔╝ █████╗     ██║   ██╔████╔██║███████║██╔██╗ ██║
██╔══██╗██║   ██║██║     ██╔═██╗ ██╔══╝     ██║   ██║╚██╔╝██║██╔══██║██║╚██╗██║
██║  ██║╚██████╔╝╚██████╗██║  ██╗███████╗   ██║   ██║ ╚═╝ ██║██║  ██║██║ ╚████║
╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝

           Name: Temporary Admin
    Description: Grants the active user temporary admin rights
     Created By: Chad Lawson
        License: Copyright (c) 2023, Rocketman Management LLC. All rights reserved. Distributed under MIT License.
      More Info: For Documentation, Instructions and Latest Version, visit https://www.rocketman.tech/jamf-toolkit

      Parameter Options
        A number of options can be set with policy parameters.
        The order does not matter, but they must be written in this format:
           --options=value
           --trueoption
        See the section immediately below starting with CONFIG for the list.
HEADER

## Configuration Options and Defaults
## An empty value indicates false or no default.
declare -A CONFIG
CONFIG=(
	[timemin]=5                         # Time (in min) for admin rights
	[askreason]=''                      # Ask user for reason - uses Applescript
	[uploadlog]=''                      # Upload logs to Jamf (y/n)
	[removegroup]=''                    # Name of static group from which to
	[basicauth]=''                      # Base 64 encoded "user:pass" for an api
	[action]="promote"                  # Alternative is "demote"
	[demotetrigger]="demote"            # Custom trigger for demotion policy
	[domain]="tech.rocketman.tempadmin" # plist(s) to read or store data and options
)

function loadPlist() {
	local hashName=$1
	local configFile=$2

	if [[ -f "${configFile}" ]]; then
		echo "Updating $hashName with $configFile"
		for key in ${(Pk)hashName}; do
			val=$(defaults read "${configFile}" "${key}" 2>/dev/null)
			if [[ $? -eq 0 ]]; then
				echo "UPDATE: Setting ${key} to ${val}"
				eval "${hashName}[$key]=$val"
			fi
		done
	fi
}

function loadArgs() {
	hashName=$1
	shift ## Now the rest of the arguments start at 1

	## Parsing command line arguments
	if [[ $1 == "/" ]]; then ## We are in a Jamf environment
		eval "${hashName}[currentuser]=$3"
		shift 3
	fi
	while [[ $1 ]] ; do
		case $1 in
			--*=* ) # Key/Value pairs
				key=$(echo "$1" | sed -re 's|^\-\-([^=]+)\=.*$|\1|g')
				val=$(echo "$1" | sed -re 's|^\-\-[^=]+\=(.*)$|\1|g')
			;;
	
			--* ) # Simple flags
				key=$(echo "$1" | sed -re 's|\-+(.*)|\1|g')
				val="True"
			;;
		esac
		keys=${(Pk)hashName}
		if (($keys[(Ie)$key])); then
			echo "${key} is valid. Setting to ${val}"
			eval "${hashName}[${key}]=${val}"
		else
			echo "Ignoring unknown key: ${key}"
		fi
	shift
	done
}

function getAPIToken() {
	jamfURL=$1
	basicAuth=$2

	authToken=$(curl -s \
		--request POST \
		--url "${jamfURL}/api/v1/auth/token" \
		--header "Accept: application/json" \
		--header "Authorization: Basic ${basicAuth}" \
		2>/dev/null \
	)
	
	## Courtesy of Der Flounder
	## Source: https://derflounder.wordpress.com/2021/12/10/obtaining-checking-and-renewing-bearer-tokens-for-the-jamf-pro-api/
	if [[ $(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}') -lt 12 ]]; then
		api_token=$(/usr/bin/awk -F \" 'NR==2{print $4}' <<< "$authToken" | /usr/bin/xargs)
	else
		api_token=$(/usr/bin/plutil -extract token raw -o - - <<< "$authToken")
	fi
	
	echo ${api_token}
}

###
### Parsing plists and argv
###

LOCALPLIST="/Library/Preferences/${CONFIG[domain]}.plist"
PROFILE="/Library/Managed Preferences/${CONFIG[domain]}.plist"

loadArgs  "CONFIG" ${argv} ## Start here to get changes in $CONFIG[domain] for plists
loadPlist "CONFIG" "${LOCALPLIST}"
loadPlist "CONFIG" "${PROFILE}"
loadArgs  "CONFIG" ${argv} ## Now take these as written in stone

## Convert CONFIG key/value pair into a global (ALL CAPS)
## Example: ${CONFIG[timemin]} becomes ${TIMEMIN}
for key in ${(k)CONFIG}; do
	GLOBAL=$(echo $key | tr '[:lower:]' '[:upper:]')
	: ${(P)GLOBAL::=${CONFIG[$key]}}
done

###
### MAIN
###

if [[ ${ACTION} == "promote" ]]; then	

	## Make sure they aren't already an admin first.
	isAdmin=$(dseditgroup -o checkmember -m ${CURRENTUSER} admin | awk '{print $1}')
	if [[ $isAdmin == "no" ]]; then
		
		## Okay. Do we need to ask them why they need this?
		if [[ ${ASKREASON} ]]; then
			while [[ ! ${REASON} ]]; do
				## TODO: In the next version, all display text will exist within its own associative array
				REASON=$(osascript -e 'return the text returned  of (display dialog "Please state briefly why you need admin rights." default answer "")')
			done
		fi
		
		## Prep the demote system
		
		## Store the name of the promoted user for the demote policy
		defaults write "${LOCALPLIST}" userToRemove -string "${CURRENTUSER}"
		defaults write "${LOCALPLIST}" promotedOn -string "$(date "+%Y-%m-%d %H:%M:%S")"
		
		## Create the LaunchDaemon to demote
		launchDaemon="/Library/LaunchDaemons/${DOMAIN}.plist"
		## Write it
		defaults write "${launchDaemon}" Label -string "${DOMAIN}"
		defaults write "${launchDaemon}" StartInterval -integer $((TIMEMIN*60))
		defaults write "${launchDaemon}" UserName -string "root"
		defaults write "${launchDaemon}" ProgramArguments -array
		defaults write "${launchDaemon}" ProgramArguments -array-add "/usr/local/jamf/bin/jamf"
		defaults write "${launchDaemon}" ProgramArguments -array-add "policy"
		defaults write "${launchDaemon}" ProgramArguments -array-add "-event"
		defaults write "${launchDaemon}" ProgramArguments -array-add "${DEMOTETRIGGER}"
		defaults write "${launchDaemon}" StandardErrorPath -string "/tmp/stderr.log"
		defaults write "${launchDaemon}" StandardOutPath -string "/tmp/stdout.log"
		## Set it
		chown root:wheel "${launchDaemon}"
		chmod 644 "${launchDaemon}"
		## Load it
		launchctl load "${launchDaemon}"
		
		## Promote the user
		echo "Granting ${CURRENTUSER} admin rights for ${TIMEMIN} minutes."
		if [[ ${ASKREASON} == "y" ]]; then
			echo "The reason they gave was: ${REASON}"
		fi
		dseditgroup -o edit -a ${CURRENTUSER} -t user admin
		STATUS=$?
		
		## Let's double check our work and report error if not
		verify=$(dseditgroup -o checkmember -m ${CURRENTUSER} admin)
		if [[ ${verify} =~ "yes" ]]; then
			echo "VERIFIED: ${verify}"
			## TODO: In the next version, all display text will exist within its own associative array
				endTime=$(date -v +${TIMEMIN}M +"%H:%M")
				osascript -e "display dialog \"You will have administrative rights until ${endTime}. DO NOT ABUSE THIS PRIVILEGE!\" buttons {\"I agree\"} default button 1" &
		else
			echo "ERROR: ${verify}"
			STATUS=1
		fi
		
		## Remove from scoped static group if requested
		if [[ ${REMOVEGROUP} ]]; then
			if [[ ${BASICAUTH} ]]; then
				## Get the Jamf Pro URL
				jamfURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)
				
				## Token time
				authToken=$(getAPIToken "${jamfURL}" "${BASICAUTH}")
				
				## Let's remove the computer from the requested group
				serialNumber=$(system_profiler SPHardwareDataType | awk '/Serial Number/ {print $NF}')

				## We need to url encode the group name for the XML
				sanitiezedGroup=$(curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "${REMOVEGROUP}" "" | cut -c3-) ## URL Encoded
				dataXML="<?xml version=\"1.0\" encoding=\"UTF-8\" ?><computer_group><computer_deletions><computer><serial_number>${serialNumber}</serial_number></computer></computer_deletions></computer_group>"
				## Send the API command
				curl -s -X PUT \
					-H "Content-type: text/xml" \
					-H "Authorization: Bearer ${authToken}" \
					"${jamfURL}/JSSResource/computergroups/name/${sanitiezedGroup}" \
					-d "${dataXML}"

				
			else
				echo "ERROR: API access requested but no auth provided"
			fi
		fi

	else ## Nothing to do here
		osascript -e 'display dialog "You are already an admin."'
		echo "${CURRENTUSER} is already an admin. Exiting."
		exit 0
	fi
	
else ## We are demoting the previously promoted user
	
	CURRENTUSER=$(defaults read "${LOCALPLIST}" userToRemove 2>/dev/null)
	echo "Demoting ${CURRENTUSER}"
	
	## Demote the user
	dseditgroup -o edit -d ${CURRENTUSER} -t user admin

	## Verify demotion
	verify=$(dseditgroup -o checkmember -m ${CURRENTUSER} admin)
	if [[ ${verify} =~ "no" ]]; then
		## No means they are NOT an admin. It worked.
		echo "${CURRENTUSER} has been demoted."

		## Log it
		defaults write "${LOCALPLIST}" demotedOn -string "$(date '+%Y-%m-%d %H:%M:%S')"

		## Upload Logs as Needed
		if [[ ${UPLOADLOG} ]]; then
			if [[ ${BASICAUTH} ]]; then
				jamfURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)
						
				## Token time
				authToken=$(getAPIToken "${jamfURL}" "${BASICAUTH}")
		
				## We need the computer's ID
				serialNumber=$(system_profiler SPHardwareDataType | awk '/Serial Number/ {print $NF}')
				compRecord=$(curl -s \
					-H "Authorization: Bearer ${authToken}" \
					-H "Accept: text/xml" \
					"${jamfURL}/JSSResource/computers/serialnumber/${serialNumber}")
				compID=$(echo "${compRecord}" | xmllint --xpath '/computer/general/id/text()' -)
				
				## Gather the logs
				startTime=$(defaults read "${LOCALPLIST}" promotedOn 2>/dev/null)
				if [[ $? -gt 0 ]]; then
					startTime=$(date '+%Y-%m-%d %H:%M:%S')
				fi
				startString=$(echo ${startTime} | tr ' ' '-')
				logArchive="/tmp/${CURRENTUSER}.logarchive"
				logZip="/tmp/${CURRENTUSER}-${startTime}.logarchive.zip"

				## Note: have to use the full path here because 'log' is 
				## also a built-in shell command.
				echo "Getting the logs"
				/usr/bin/log collect --output "${logArchive}" --last "${TIMEMIN}m" >/dev/null
				echo "Compressing logs"
				zip -rm "${logZip}" "${logArchive}" >/dev/null
	
				## Upload the Logs
				echo "Uploading logs"
				curl -s -X POST \
					-H "Authorization: Bearer ${authToken}" \
					"${jamfURL}/JSSResource/fileuploads/computers/id/${compID}" \
					-F name=@"${logZip}"
	
			else
				echo "ERROR: Log upload was requested by API credentials are missing."
			fi
		fi
		
	fi
	##
	## Remove LaunchDaemon
	##
	launchDaemon="/Library/LaunchDaemons/${DOMAIN}.plist"
	cleanUpScript="/tmp/cleanup.sh"
	cat << EOF > ${cleanUpScript}
		#!/bin/zsh
		TRAPEXIT() {
			rm -rf "${launchDaemon}"
			rm "${cleanUpScript}"
		}
	
		TRAPTERM() {
			waiting='False'
		}
	
		waiting='True'
		while [[ \${waiting} == 'True' ]]; do
			sleep 1
		done
		launchctl unload "${launchDaemon}"
		exit
EOF

	## Now we put the cleanup script in the background
	## This allows the Jamf Policy log to continue and send results to Jamf.
	## After that happens, the Jamf Policy calls sends the TERM signal to 
	## the cleanup script which finishes.
	## And when the cleanup script unloads the LaunchDaemon process, it gets 
	## sent the EXIT signal which causes the LaunchDaemon plist and cleanup
	## script to get removed.
	/bin/zsh ${cleanUpScript} &
fi

