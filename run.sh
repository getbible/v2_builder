#! /bin/bash

# Do some prep work
command -v jq >/dev/null 2>&1 || { echo >&2 "We require jq for this script to run, but it's not installed.  Aborting."; exit 1; }
command -v sha1sum >/dev/null 2>&1 || { echo >&2 "We require sha1sum for this script to run, but it's not installed.  Aborting."; exit 1; }
command -v git >/dev/null 2>&1 || { echo >&2 "We require git for this script to run, but it's not installed.  Aborting."; exit 1; }
command -v whiptail >/dev/null 2>&1 || { echo >&2 "We require whiptail for this script to run, but it's not installed.  Aborting."; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo >&2 "We require python3 for this script to run, but it's not installed.  Aborting."; exit 1; }

# main function
function main () {
	# main project Header
	header_string="getBible JSON API.v2"
	# remove and re-download Crosswire modules
	if (( "$DOWNLOAD" == 1 )); then
		getModules "${DIR_zip}"
	fi
	# prep the Scripture Main Git Folder
	prepScriptureMainGit "${DIR_api}_scripture"
	# numbers
	number=$(ls "${DIR_zip}" | wc -l)
	each_count=$((98 / $number))
	# Build Static JSON Files
	setStaticJsonFiles "${DIR_api}_scripture" "${DIR_zip}" "$number" "$each_count" "$header_string"
	# Remove Empty Folder & Static Files
	cleanSystem "${DIR_api}_scripture"
	# start hashing Translations
	hashingMethod "${DIR_api}_scripture" \
		"hash_versions" \
		"Hash Versions | ${header_string}" \
		"Start Versions Hashing" \
		"Done Hashing Versions" \
		"Please wait while we hash all versions"
	# start hashing Translations Books
	hashingMethod "${DIR_api}_scripture" \
		"hash_books" \
		"Hash Books | ${header_string}" \
		"Start Versions Books Hashing" \
		"Done Hashing All Versions Books" \
		"Please wait while we hash all versions books"
	# start hashing Translations Books Chapters
	hashingMethod "${DIR_api}_scripture" \
		"hash_chapters" \
		"Hash Chapters | ${header_string}" \
		"Start Versions Books Chapters Hashing" \
		"Done Hashing All Versions Books Chapters" \
		"Please wait while we hash all versions books chapters"
	# moving all public hash files into place
	hashingMethod "${DIR_api}" \
		"movePublicHashFiles" \
		"Moving Public Hash | ${header_string}" \
		"Start Moving Public Hashes" \
		"Done Moving All Public Hashes" \
		"Please wait while we move all the public hashes into place"
	# finally check if we must commit and push changes
	if (( "$PUSH" == 1 )); then
		"${DIR_src}/moveToGithub.sh" "${DIR_api}"
	fi
}

# remove and re-download Crosswire modules
function getModules () {
	# set local values
	local modules_path="$1"
	local header_string="$2"
	# we first delete the old models
	rm -fr $modules_path
	mkdir -p $modules_path
	# then we get the current modules
	{
		sleep 1
		echo -e "XXX\n0\nStart download of modules... \nXXX"
		sleep 1
		python3 -u "${DIR_src}/download.py" --output_path "${modules_path}" --conf_dir "${DIR_conf}"
		sleep 1
		echo -e "XXX\n100\nDone downloading modules... \nXXX"
		sleep 2
	} | whiptail --title "Get Crosswire Modules | ${header_string}" --gauge "Please wait while we download all modules" 7 77 0
}

# prep the Scripture Main Git Folder
function prepScriptureMainGit () {
	# set local values
	local scripture_path="$1"
	# if git folder does not exist clone it
	if [ ! -d "$scripture_path" ]; then
		# create the git folder (for scripture)
		mkdir -p "$scripture_path"
	fi
	# reset the git folder on each run
	if [ -d "$scripture_path/.git" ]; then
		mkdir -p "${scripture_path}Tmp"
		mv -f "${scripture_path}/.git" "${scripture_path}Tmp"
		mv -f "${scripture_path}/.gitignore" "${scripture_path}Tmp"

		# now we remove all the old git files (so we start clean each time in the build)
		rm -fr $scripture_path
		mv -f "${scripture_path}Tmp" "${scripture_path}"
	fi
}

# Build Static JSON Files
function setStaticJsonFiles () {
	# set local values
	local scripture_path="$1"
	local modules_path="$2"
	local counter="$3"
	local each_count="$4"
	local header_string="$5"
	# whiptail messaging
	{
		sleep 1
		echo -e "XXX\n0\nStart Building... \nXXX"
		sleep 1
		for filename in $modules_path/*.zip; do
			# give notice
			echo -e "XXX\n${counter}\nBuilding ${filename} static json files...\nXXX"
			# add more
			next=$(($each_count + $counter))
			# run script
			python3 -u "${DIR_src}/sword_to_json.py" --source_file "${filename}" --output_path "${scripture_path}" --counter "${counter}" --next "${next}" --conf_dir "${DIR_conf}"
			# add more
			counter=$(($each_count + $counter))
			# give notice
			echo -e "XXX\n${counter}\nDone building ${filename} static json files...\nXXX"
			sleep 1
		done
		echo -e "XXX\n100\nDone Building... \nXXX"
		sleep 1
	} | whiptail --title "Build Static JSON Files | ${header_string}" --gauge "Please wait while build the static json API" 7 77 0
}

# Remove Empty Folder & Static Files
function cleanSystem () {
	# set local values
	local scripture_path="$1"
	# remove all empty files
	find "${scripture_path}" -name "*.json" -type f -size -500c -delete
	# remove all empty folders
	find "${scripture_path}" -type d -empty -delete
}

# hashing all files in the project
function hashingMethod () {
	# set local values
	local scripture_path="$1"
	local script_name="$2"
	local w_title="$3"
	local w_start_ms="$4"
	local w_end_ms="$5"
	local w_initial_ms="$6"
	# now run the hashing
	{
		sleep 1
		echo -e "XXX\n0\n${w_start_ms}... \nXXX"
		sleep 1
		. "${DIR_src}/${script_name}.sh" "${scripture_path}"
		sleep 1
		echo -e "XXX\n100\n${w_end_ms}... \nXXX"
		sleep 1
	} | whiptail --title "$w_title" --gauge "$w_initial_ms" 7 77 0
}

# help message
function show_help () {
cat << EOF
Usage: ${0##*/:-} [OPTION...]

You are able to change a few default behaviours in the getBible API builder
  ------ Passing no command options will fallback on the defaults -------

	Options
	======================================================
   -a|--api
	set the API target folders full path
		- target folders will be created using this path

	example: ${0##*/:-} -a /home/username/v2
	example: ${0##*/:-} --api /home/username/v2

	two folders will be created:
		- /home/username/v2
		- /home/username/v2_scripture

	defaults:
		- repo/v2
		- repo/v2_scripture

	(these are the target folders)
	======================================================
   -p|--push
	push changes to github (only if there are changes)
		- setup the target folders (see target folders)
		- linked them to github (your own repos)
		- must be able to push (ssh authentication needed)
		
	REMEMBER THE AGREEMENT (README.md)

	example: ${0##*/:-} -p
	example: ${0##*/:-} --push
	======================================================
   -z|--zip
	set the ZIP target folder full path for the Crosswire Modules

	example: ${0##*/:-} -z /home/username/sword_zip 
	example: ${0##*/:-} --zip /home/username/sword_zip

	defaults:
		- repo/sword_zip
	======================================================
   -d
	Do not download all Crosswire Modules (helpful in testing)

	example: ${0##*/:-} -d
	======================================================
   -h|--help
	display this help menu

	example: ${0##*/:-} -h
	example: ${0##*/:-} --help
	======================================================
                            getBible.net
	======================================================
EOF
}

# get script path
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# set working paths
DIR_src="${DIR}/src"
DIR_conf="${DIR}/conf"
DIR_api="${DIR}/v2"
DIR_zip="${DIR}/sword_zip"
# download all modules
DOWNLOAD=1
# push changes to github (you need setup your own repos)
PUSH=0
# show values do not run
SHOWCONF=0

# check if we have options
while :; do
	case $1 in
		-h|--help)
			show_help # Display a usage synopsis.
			exit
			;;
		-d)
			DOWNLOAD=0
			;;
		--show)
			SHOWCONF=1
			;;
		-p|--push)
			PUSH=1
			;;
		-a|--api) # Takes an option argument; ensure it has been specified.
			if [ "$2" ]; then
				DIR_api=$2
				shift
			else
				echo 'ERROR: "--api" requires a non-empty option argument.'
				exit 1
			fi
			;;
		--api=?*)
			DIR_api=${1#*=} # Delete everything up to "=" and assign the remainder.
			;;
		--api=) # Handle the case of an empty --api=
			echo 'ERROR: "--api" requires a non-empty option argument.'
			exit 1
			;;
		-z|--zip) # Takes an option argument; ensure it has been specified.
			if [ "$2" ]; then
				DIR_zip=$2
				shift
			else
				echo 'ERROR: "--zip" requires a non-empty option argument.'
				exit 1
			fi
			;;
		--zip=?*)
			DIR_zip=${1#*=} # Delete everything up to "=" and assign the remainder.
			;;
		--zip=) # Handle the case of an empty --zip=
			echo 'ERROR: "--zip" requires a non-empty option argument.'
			exit 1
			;;
		*) # Default case: No more options, so break out of the loop.
			break
	esac
	shift
done

# show the config values
if (( "$SHOWCONF" == 1 )); then
	echo "DIR_api:   ${DIR_api}"
	echo "DIR_zip:   ${DIR_zip}"
	echo "DIR_src:   ${DIR_src}"
	echo "DIR_conf:  ${DIR_conf}"
	echo "DOWNLOAD:  ${DOWNLOAD}"
	echo "PUSH:      ${PUSH}"
	exit
fi

# run Main ;)
main

