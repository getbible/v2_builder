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

for filename in $target_folder/*.json; do
	# get the abbreviation
	abbreviation="${filename/.json/}"
	abbreviation="${abbreviation/${target_folder}\//}"
	echo "$abbreviation"
	# do not work with the translations or checksum file
	if [[ "$abbreviation" == 'translations' || "$abbreviation" == 'checksum' ]]; then
		continue
	fi
	# do not work with the books or chapters file
	if [[ "$abbreviation" == 'books' || "$abbreviation" == 'chapters' ]]; then
		continue
	fi
	# make sure the book directory is build
	if [ -d "${target_folder}/$abbreviation" ]; then
		# set language
		language=$(cat "${filename}" | jq '.language' -r)
		# set translation
		translation=$(cat "${filename}" | jq '.translation' -r)
		# set language
		direction=$(cat "${filename}" | jq '.direction' -r)
		# get booknumbers
		readarray -t booknr < <(cat "${filename}" | jq -r '.books[].nr')
		# add more
		next=$((counter + 12))
		# make sure next is not above 99
		if (("$next" > 99)); then
			next=99
		fi
		counter_inner=$counter
		# read book names
		for nr in "${booknr[@]}"; do
			# setup: positional arguments to pass in literal variables, query with code
			jq_args=()
			jq_query='.'
			jq_t_args=()
			jq_t_query='.'
			# check if file is set
			if [ -f "${target_folder}/${abbreviation}/${nr}.json" ]; then
				# chapters details
				chaptersBucket="#	language	translation	abbreviation	textdirection	book_nr	book_name	filename	sha\n"
				# checksum
				checksumBucket="#	filename	sha\n"
				# get book name
				book_name=$(cat "${target_folder}/${abbreviation}/${nr}.json" | jq '.name' -r)
				# get all chapters
				readarray -t chapters < <(cat "${target_folder}/${abbreviation}/${nr}.json" | jq -r '.chapters[].chapter' | sort -g)
				# get chapters
				for chapter in "${chapters[@]}"; do
					# only build hash chapter for existing files
					if [ -f "${target_folder}/${abbreviation}/${nr}/${chapter}.json" ]; then
						# get the hash
						fileHash=$(sha1sum "${target_folder}/${abbreviation}/${nr}/${chapter}.json" | awk '{print $1}')
						# load the book in
						chapter_info=$(cat "${target_folder}/${abbreviation}/${nr}/${chapter}.json" | jq ". | del(.verses) | .[\"url\"]=\"https://getbible.net/v2/${abbreviation}/${nr}/${chapter}.json\" | .[\"sha\"]=\"${fileHash}\"" -a)
						# load the values for json
						jq_t_args+=(--arg "key$chapter" "${chapter}")
						jq_t_args+=(--argjson "value$chapter" "${chapter_info}")
						# build query for jq
						jq_t_query+=" | .[\$key${chapter}]=\$value${chapter}"
						# create/update the Bible file checksum
						echo "${fileHash}" >"${target_folder}/${abbreviation}/${nr}/${chapter}.sha"
						# load the buckets
						checksumBucket+="${chapter}	${chapter}	${fileHash}\n"
						chaptersBucket+="${chapter}	${language}	${translation}	${abbreviation}	${direction}	${nr}	${book_name}	${chapter}	${fileHash}\n"
						# load the values for json
						jq_args+=(--arg "key$chapter" "${chapter}")
						jq_args+=(--arg "value$chapter" "$fileHash")
						# build query for jq
						jq_query+=" | .[\$key${chapter}]=\$value${chapter}"
						# check if we have counter upto next
						if (("$counter_inner" >= "$next")); then
							counter_inner=$counter
						fi
						# increment the counter
						counter_inner=$((counter_inner + 1))
						# give notice
						echo -e "XXX\n${counter_inner}\nHashing ${abbreviation}/${nr}/${chapter}.json\nXXX"
					fi
				done
				# set books checksum to text file
				echo -e "$checksumBucket" >"${target_folder}/${abbreviation}/${nr}/checksum"
				# set books details to text file
				echo -e "$chaptersBucket" >"${target_folder}/${abbreviation}/${nr}/chapters"
				# run the generated command with jq
				jq "${jq_args[@]}" "$jq_query" <<<'{}' >"${target_folder}/${abbreviation}/${nr}/checksum.json"
				jq "${jq_t_args[@]}" "$jq_t_query" <<<'{}' >"${target_folder}/${abbreviation}/${nr}/chapters.json"
			fi
		done
		# check if we have counter upto 98
		if (("$counter" >= 98)); then
			counter=70
		fi
		# add more
		counter=$((counter + each))
		# give notice
		echo -e "XXX\n${counter}\nDone Hashing $abbreviation chapters\nXXX"
	fi
done
