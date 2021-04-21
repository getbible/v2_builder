#! /bin/bash

# Do some prep work
command -v jq >/dev/null 2>&1 || {
	echo >&2 "We require jq for this script to run, but it's not installed.  Aborting."
	exit 1
}
command -v sha1sum >/dev/null 2>&1 || {
	echo >&2 "We require sha1sum for this script to run, but it's not installed.  Aborting."
	exit 1
}
command -v git >/dev/null 2>&1 || {
	echo >&2 "We require git for this script to run, but it's not installed.  Aborting."
	exit 1
}
command -v whiptail >/dev/null 2>&1 || {
	echo >&2 "We require whiptail for this script to run, but it's not installed.  Aborting."
	exit 1
}
command -v python3 >/dev/null 2>&1 || {
	echo >&2 "We require python3 for this script to run, but it's not installed.  Aborting."
	exit 1
}

# get start time
STARTBUILD=$(date +"%s")
# use UTC+00:00 time also called zulu
STARTDATE=$(TZ=":ZULU" date +"%m/%d/%Y @ %R (UTC)")
# main project Header
HEADERTITLE="getBible JSON API.v2"

# main function ˘Ô≈ôﺣ
function main() {
	# Only Hash existing scripture JSON files
	if (("$HASHONLY" == 1)); then
		# the hashing of all files
		hashingAll
		# show completion message
		completedBuildMessage
		exit
	fi
	# download Crosswire modules
	if (("$DOWNLOAD" == 1)); then
		getModules "${DIR_zip}"
	fi
	# prep the Scripture Main Git Folder
	prepScriptureMainGit "${DIR_api}_scripture"
	# numbers
	number=$(ls "${DIR_zip}" | wc -l)
	each_count=$((98 / $number))
	# Build Static JSON Files
	setStaticJsonFiles "${DIR_api}_scripture" "${DIR_zip}" "$number" "$each_count"
	# Remove Empty Folder & Static Files
	cleanSystem "${DIR_api}_scripture"
	# the hashing of all files
	hashingAll
	# finally check if we must commit and push changes
	if (("$PUSH" == 1)); then
		"${DIR_src}/moveToGithub.sh" "${DIR_api}"
	fi
	# show completion message
	completedBuildMessage

	exit 0
}

# completion message
function completedBuildMessage() {
	# set the build time
	ENDBUILD=$(date +"%s")
	SECONDSBUILD=$((ENDBUILD - STARTBUILD))
	# use UTC+00:00 time also called zulu
	ENDDATE=$(TZ=":ZULU" date +"%m/%d/%Y @ %R (UTC)")
	# give completion message
	if (("$QUIET" == 0)); then
		whiptail --title "${HEADERTITLE}" --separate-output --infobox "${USER^}, the ${HEADERTITLE} build is complete!\n\n   Started: ${STARTDATE}\n     Ended: ${ENDDATE}\nBuild Time: ${SECONDSBUILD} seconds" 12 77
	else
		echo "${HEADERTITLE} build on ${STARTDATE} is completed in ${SECONDSBUILD} seconds!"
	fi
}

# show the progress of all tasks
function showProgress() {
	if (("$QUIET" == 0)); then
		# little neardy  ᒡ◯ᵔ◯ᒢ
		whiptail --title "$1" --gauge "$2" 7 77 0
	else
		# looking for a better solution... ¯\_(ツ)_/¯
		whiptail --title "$1" --gauge "$2" 7 77 0 >>/dev/null
	fi
}

# download Crosswire modules
function getModules() {
	# set local values
	local modules_path="$1"
	# we first delete the old modules
	rm -fr $modules_path
	mkdir -p $modules_path
	# then we get the current modules
	{
		sleep 1
		echo -e "XXX\n0\nStart download of modules... \nXXX"
		sleep 1
		python3 -u "${DIR_src}/download.py" \
			--output_path "${modules_path}" \
			--bible_conf "${DIR_bible}"
		sleep 1
		echo -e "XXX\n100\nDone downloading modules... \nXXX"
		sleep 2
	} | showProgress "Get Crosswire Modules | ${HEADERTITLE}" "Please wait while we download all modules"
}

# prep the Scripture Main Git Folder
function prepScriptureMainGit() {
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
function setStaticJsonFiles() {
	# set local values
	local scripture_path="$1"
	local modules_path="$2"
	local counter="$3"
	local each_count="$4"
	# build the files
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
			python3 -u "${DIR_src}/sword_to_json.py" \
				--source_file "${filename}" \
				--output_path "${scripture_path}" \
				--counter "${counter}" --next "${next}" \
				--conf_dir "${DIR_conf}" \
				--bible_conf "${DIR_bible}"
			# add more
			counter=$(($each_count + $counter))
			# give notice
			echo -e "XXX\n${counter}\nDone building ${filename} static json files...\nXXX"
			sleep 1
		done
		echo -e "XXX\n100\nDone Building... \nXXX"
		sleep 1
	} | showProgress "Build Static JSON Files | ${HEADERTITLE}" "Please wait while build the static json API"
}

# Remove Empty Folder & Static Files
function cleanSystem() {
	# set local values
	local scripture_path="$1"
	# remove all empty files
	find "${scripture_path}" -name "*.json" -type f -size -500c -delete
	# remove all empty folders
	find "${scripture_path}" -type d -empty -delete
}

# the hashing of all files
function hashingAll() {
	# start hashing Translations
	hashingMethod "${DIR_api}_scripture" \
		"hash_versions" \
		"Hash Versions" \
		"Start Versions Hashing" \
		"Done Hashing Versions" \
		"Please wait while we hash all versions"
	# start hashing Translations Books
	hashingMethod "${DIR_api}_scripture" \
		"hash_books" \
		"Hash Books" \
		"Start Versions Books Hashing" \
		"Done Hashing All Versions Books" \
		"Please wait while we hash all versions books"
	# start hashing Translations Books Chapters
	hashingMethod "${DIR_api}_scripture" \
		"hash_chapters" \
		"Hash Chapters" \
		"Start Versions Books Chapters Hashing" \
		"Done Hashing All Versions Books Chapters" \
		"Please wait while we hash all versions books chapters"
	# moving all public hash files into place
	hashingMethod "${DIR_api}" \
		"movePublicHashFiles" \
		"Moving Public Hash" \
		"Start Moving Public Hashes" \
		"Done Moving All Public Hashes" \
		"Please wait while we move all the public hashes into place"
}

# hashing all files in the project
function hashingMethod() {
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
	} | showProgress "$w_title | ${HEADERTITLE}" "$w_initial_ms"
}

# set any/all default config property
function setDefaults() {
	if [ -f $CONFIGFILE ]; then
		# set all defaults
		DIR_api=$(getDefault "getbible.api" "${DIR_api}")
		DIR_zip=$(getDefault "getbible.zip" "${DIR_zip}")
		DIR_bible=$(getDefault "getbible.bconf" "${DIR_bible}")
		DOWNLOAD=$(getDefault "getbible.download" "$DOWNLOAD")
		PUSH=$(getDefault "getbible.push" "$PUSH")
		HASHONLY=$(getDefault "getbible.hashonly" "$HASHONLY")
		QUIET=$(getDefault "getbible.quiet" "$QUIET")
	fi
}

# get default properties from config file
function getDefault() {
	PROP_KEY="$1"
	PROP_VALUE=$(cat $CONFIGFILE | grep "$PROP_KEY" | cut -d'=' -f2)
	echo "${PROP_VALUE:-$2}"
}

# help message ʕ•ᴥ•ʔ
function show_help() {
	cat <<EOF
Usage: ${0##*/:-} [OPTION...]

You are able to change a few default behaviours in the getBible API builder
  ------ Passing no command options will fallback on the defaults -------

	Options
	======================================================
   --api=<path>
	set the API target folders full path
		- target folders will be created using this path

	example: ${0##*/:-} --api=/home/$USER/v2

	two folders will be created:
		- /home/$USER/v2
		- /home/$USER/v2_scripture

	defaults:
		- repo/v2
		- repo/v2_scripture

	(these are the target folders)
	======================================================
   --bconf=<path>
	set the path to the Bible config file
		- This file contains the list of Crosswire
		  Bible Modules that will be used to build
		  the JSON API files

	example: ${0##*/:-} --bconf=/home/$USER/getbible.json

	defaults:
		- repo/conf/CrosswireModulesMap.json
	======================================================
   --conf=<path>
	set all the config properties with a file

	example: ${0##*/:-} --conf=/home/$USER/.config/getbible.conf

	defaults:
		- repo/conf/.config
	======================================================
   --push
	push changes to github (only if there are changes)
		- setup the target folders (see target folders)
		- linked them to github (your own repos)
		- must be able to push (ssh authentication needed)

	REMEMBER THE AGREEMENT (README.md)

	example: ${0##*/:-} --push
	======================================================
   --zip=<path>
	set the ZIP target folder full path for the Crosswire Modules

	example: ${0##*/:-} --zip=/home/$USER/sword_zip

	defaults:
		- repo/sword_zip
	======================================================
   -d
	Do not download all Crosswire Modules (helpful in testing)
	Only use this if you already have modules.

	example: ${0##*/:-} -d
	======================================================
   --hashonly
	To only hash the existing JSON scripture files

	example: ${0##*/:-} --hashonly
	======================================================
   --test
	Run a test with only three Bibles

	example: ${0##*/:-} --test
	======================================================
   --dry
	To show all defaults, and not run the build

	example: ${0##*/:-} --dry
	======================================================
   -q|--quiet
	Quiet mode that prevent whiptail from showing progress

	example: ${0##*/:-} -q
	example: ${0##*/:-} --quiet
	======================================================
   -h|--help
	display this help menu

	example: ${0##*/:-} -h
	example: ${0##*/:-} --help
	======================================================
			${HEADERTITLE}
	======================================================
EOF
}

# get script path
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# set working paths
DIR_src="${DIR}/src"
DIR_conf="${DIR}/conf"
DIR_api="${DIR}/v2"
DIR_zip="${DIR}/sword_zip"
# set Bible config file path
DIR_bible="${DIR_conf}/CrosswireModulesMap.json"
# set default config path
CONFIGFILE="${DIR}/conf/.config"
# download all modules
DOWNLOAD=1
# push changes to github (you need setup your own repos)
PUSH=0
# show values do not run
DRYRUN=0
# only hash the scriptures
HASHONLY=0
# kill all messages
QUIET=0

# check if we have options
while :; do
	case $1 in
	-h | --help)
		show_help # Display a usage synopsis.
		exit
		;;
	-q | --quiet)
		QUIET=1
		;;
	-d)
		DOWNLOAD=0
		;;
	--hashonly)
		HASHONLY=1
		;;
	--test)
		# setup the test environment
		DIR_bible="${DIR_conf}/CrosswireModulesMapTest.json"
		DIR_api="${DIR}/v2t"
		DIR_zip="${DIR}/sword_zipt"
		;;
	--dry)
		DRYRUN=1
		;;
	--push)
		PUSH=1
		;;
	--bconf) # Takes an option argument; ensure it has been specified.
		if [ "$2" ]; then
			DIR_bible=$2
			shift
		else
			echo 'ERROR: "--bconf" requires a non-empty option argument.'
			exit 1
		fi
		;;
	--bconf=?*)
		DIR_bible=${1#*=} # Delete everything up to "=" and assign the remainder.
		;;
	--bconf=) # Handle the case of an empty --bconf=
		echo 'ERROR: "--bconf" requires a non-empty option argument.'
		exit 1
		;;
	--conf) # Takes an option argument; ensure it has been specified.
		if [ "$2" ]; then
			CONFIGFILE=$2
			shift
		else
			echo 'ERROR: "--conf" requires a non-empty option argument.'
			exit 1
		fi
		;;
	--conf=?*)
		CONFIGFILE=${1#*=} # Delete everything up to "=" and assign the remainder.
		;;
	--conf=) # Handle the case of an empty --conf=
		echo 'ERROR: "--conf" requires a non-empty option argument.'
		exit 1
		;;
	--api) # Takes an option argument; ensure it has been specified.
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
	--zip) # Takes an option argument; ensure it has been specified.
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
		break ;;
	esac
	shift
done

# check if config file is set
setDefaults

# show the config values ¯\_(ツ)_/¯
if (("$DRYRUN" == 1)); then
	echo "		${HEADERTITLE}"
	echo "======================================================"
	echo "DIR_api:    ${DIR_api}"
	echo "DIR_zip:    ${DIR_zip}"
	echo "DIR_src:    ${DIR_src}"
	echo "DIR_conf:   ${DIR_conf}"
	echo "DIR_bible:  ${DIR_bible}"
	echo "QUIET:      ${QUIET}"
	echo "HASHONLY:   ${HASHONLY}"
	echo "DOWNLOAD:   ${DOWNLOAD}"
	echo "PUSH:       ${PUSH}"
	echo "CONFIGFILE: ${CONFIGFILE}"
	echo "======================================================"
	exit
fi

# run Main ┬┴┬┴┤(･_├┬┴┬┴
main
