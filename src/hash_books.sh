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
	# setup: positional arguments to pass in literal variables, query with code
	jq_args=()
	jq_query='.'
	jq_t_args=()
	jq_t_query='.'
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
	# make sure the book directory is build
	if [ -d "${target_folder}/$abbreviation" ]; then
		# load the translation in
		bible=$(cat "${filename}" | jq '.' -a)
		# get book numbers
		readarray -t booknr < <(echo "${bible}" | jq -r '.books[].nr')
		# now remove all books
		bible=$(echo "${bible}" | jq '. | del(.books) | del(.discription)' -a)
		# set language
		language=$(echo "${bible}" | jq '.language' -r)
		# set translation
		translation=$(echo "${bible}" | jq '.translation' -r)
		# set direction
		direction=$(echo "${bible}" | jq '.direction' -r)
		# start bucket
		booksBucket="#	language	translation	abbreviation	direction	name	filename	sha\n"
		# checksum
		checksumBucket="#	filename	sha\n"
		# add more
		next=$((counter + 12))
		# make sure next is not above 99
		if (("$next" > 99)); then
			next=99
		fi
		counter_inner=$counter
		# read book names
		for nr in "${booknr[@]}"; do
			# check if file is set
			if [ -f "${target_folder}/${abbreviation}/${nr}.json" ]; then
				# load the book in
				book=$(cat "${target_folder}/${abbreviation}/${nr}.json" | jq '.' -a)
				# update the file formatting
				echo "${book}" >"${target_folder}/${abbreviation}/${nr}.json"
				# get the hash
				fileHash=$(sha1sum "${target_folder}/${abbreviation}/${nr}.json" | awk '{print $1}')
				# build the return values
				book=$(echo "${book}" | jq ". | del(.chapters) | .[\"url\"]=\"https://getbible.net/v2/${abbreviation}/${nr}.json\" | .[\"sha\"]=\"${fileHash}\"" -a)
				# load the values for json
				jq_t_args+=(--arg "key$nr" "$nr")
				jq_t_args+=(--argjson "value$nr" "$book")
				# build query for jq
				jq_t_query+=" | .[\$key${nr}]=\$value${nr}"
				# create/update the Bible file checksum
				echo "${fileHash}" >"${target_folder}/${abbreviation}/${nr}.sha"
				# load book name
				book_name=$(echo "${book}" | jq '.name' -r)
				# load the buckets
				checksumBucket+="${nr}	${nr}	${fileHash}\n"
				booksBucket+="${nr}	${language}	${translation}	${abbreviation}	${direction}	${book_name}	${nr}	${fileHash}\n"
				# load the values for json
				jq_args+=(--arg "key$nr" "${nr}")
				jq_args+=(--arg "value$nr" "$fileHash")
				# build query for jq
				jq_query+=" | .[\$key${nr}]=\$value${nr}"
				# check if we have counter upto next
				if (("$counter_inner" >= "$next")); then
					counter_inner=$counter
				fi
				# increment the counter
				counter_inner=$((counter_inner + 1))
				# give notice
				echo -e "XXX\n${counter_inner}\nHashing ${abbreviation}/${nr}.json\nXXX"
			fi
		done
		# set books checksum to text file
		echo -e "$checksumBucket" >"${target_folder}/${abbreviation}/checksum"
		# set books details to text file
		echo -e "$booksBucket" >"${target_folder}/${abbreviation}/books"
		# run the generated command with jq
		jq "${jq_args[@]}" "$jq_query" <<<'{}' >"${target_folder}/${abbreviation}/checksum.json"
		jq "${jq_t_args[@]}" "$jq_t_query" <<<'{}' >"${target_folder}/${abbreviation}/books.json"
		# check if we have counter upto 98
		if (("$counter" >= 98)); then
			counter=70
		fi
		# add more
		counter=$((counter + each))
		# give notice
		echo -e "XXX\n${counter}\nDone Hashing $abbreviation books\nXXX"
		sleep 1
	fi
done
