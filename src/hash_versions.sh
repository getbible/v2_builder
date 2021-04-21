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

# make sure we have at least one argument
if [ $# -eq 0 ]; then
	echo >&2 "Target folder must be supplied. Aborting."
	exit 1
fi

# setup: positional arguments to pass in literal variables, query with code
jq_args=()
jq_query='.'
jq_t_args=()
jq_t_query='.'

# counter
nr=1

# target folder
target_folder="$1"
# tracker counter
counter=0
each="${2:-1}"

# check if the folder exist
if [ ! -d $target_folder ]; then
	echo >&2 "Folder $target_folder not found.  Aborting."
	exit 1
fi

# book names
echo "#	language	translation	abbreviation	direction	filename	sha" >"${target_folder}/translations"
# checksum
echo "#	filename	sha" >"${target_folder}/checksum"

for filename in $target_folder/*.json; do
	# get the abbreviation
	abbreviation="${filename/.json/}"
	abbreviation="${abbreviation/${target_folder}\//}"
	# do not work with the translations or checksum file
	if [[ "$abbreviation" == 'translations' || "$abbreviation" == 'checksum' ]]; then
		continue
	fi
	# do not work with the books or chapters file
	if [[ "$abbreviation" == 'books' || "$abbreviation" == 'chapters' ]]; then
		continue
	fi
	# load the translation in
	bible=$(cat "${filename}" | jq '.' -a)
	# update the file formating
	echo "${bible}" >"${filename}"
	# build the hash file name
	hashFileName="${target_folder}/${abbreviation}.sha"
	# get the hash
	fileHash=$(sha1sum "${filename}" | awk '{print $1}')
	# build the return values
	bible=$(echo "${bible}" | jq ". | del(.books) | del(.discription) | .[\"url\"]=\"https://getbible.net/v2/${abbreviation}.json\" | .[\"sha\"]=\"${fileHash}\"" -a)
	# get the details
	language=$(echo "${bible}" | jq '.language' -r)
	translation=$(echo "${bible}" | jq '.translation' -r)
	direction=$(echo "${bible}" | jq '.direction' -r)
	# set file details to text file
	echo "${nr}	${language}	${translation}	${abbreviation}	${direction}	${abbreviation}	${fileHash}" >>"${target_folder}/translations"
	# load the values for json
	jq_t_args+=(--arg "key$nr" "$abbreviation")
	jq_t_args+=(--argjson "value$nr" "$bible")
	# build query for jq
	jq_t_query+=" | .[\$key${nr}]=\$value${nr}"
	# create/update the Bible file checksum
	echo "${fileHash}" >"$hashFileName"
	# echo "${fileHash}" > "$_hashFileName"
	echo "${nr}	${abbreviation}	${fileHash}" >>"${target_folder}/checksum"
	# load the values for json
	jq_args+=(--arg "key$nr" "$abbreviation")
	jq_args+=(--arg "value$nr" "$fileHash")
	# build query for jq
	jq_query+=" | .[\$key${nr}]=\$value${nr}"
	#next
	nr=$((nr + 1))
	# check if we have counter upto 98
	if (("$counter" >= 98)); then
		counter=70
	fi
	# add more
	counter=$((counter + each))
	# give notice
	echo -e "XXX\n${counter}\nDone Hashing $abbreviation\nXXX"
done

# run the generated command with jq
jq "${jq_args[@]}" "$jq_query" <<<'{}' >"${target_folder}/checksum.json"
jq "${jq_t_args[@]}" "$jq_t_query" <<<'{}' >"${target_folder}/translations.json"
