#! /bin/bash

# make sure we have at least one argument
if [ $# -eq 0 ]
  then
    echo >&2 "Target folder must be supplied. Aborting."
    exit 1;
fi

# target folder
API_path="$1"

scripture_path="${API_path}_scripture"
hash_path="${API_path}"

# check if the target to folder exist
if [ -d "$hash_path" ]; then
	# reset the git folder on each run
	if [ -d "${hash_path}/.git" ]; then
		mkdir -p "${hash_path}Tmp"
		mv -f "${hash_path}/.git" "${hash_path}Tmp"
		mv -f "${hash_path}/LICENSE" "${hash_path}Tmp"
		mv -f "${hash_path}/README.md" "${hash_path}Tmp"

		# now we remove all the old git files (so we start clean each time in the build)
		rm -fr $hash_path
		mv -f "${hash_path}Tmp" "${hash_path}"
	fi
else
	# make sure it is created
	mkdir -p "$hash_path"
fi

## declare an array variable
declare -a arr=('*.sha' 'checksum' 'checksum.json' 'translations' 'translations.json' 'books' 'books.json' 'chapters' 'chapters.json')

## now loop through the above array
for key in "${arr[@]}"
do
	# give notice
	counter=0
	echo -e "XXX\n$counter\nMoving all these type ($key) of files\nXXX"
	sleep 1
	find "$scripture_path" -type f -name "$key" -print0 | while IFS= read -r -d '' file; do
		newFile=${file/$scripture_path/$hash_path}
		newPath=$(dirname "${newFile}")
		if [ ! -d "$newPath" ]; then
			mkdir -p "$newPath"
		fi
		# copy the files there
		cp --remove-destination "$file" "$newFile"
		# check if we have counter up-to total
		if (("$counter" >= 98))
		then
			counter=3
		fi
		# increment the counter
		counter=$((counter+1))
		# give notice
		echo -e "XXX\n${counter}\nMoving $file\nXXX"
	done
done

