#! /bin/bash

# Do some prep work
command -v git >/dev/null 2>&1 || { echo >&2 "We require git for this script to run, but it's not installed.  Aborting."; exit 1; }

# make sure we have at least one argument
if [ $# -eq 0 ]
  then
    echo >&2 "Target folder must be supplied. Aborting."
    exit 1;
fi

# moving data to github
echo "[getBible.net] -- Move files in to github......"

# target folder
API_path="$1"

## declare an array variable
declare -a arr=("${API_path}_scripture" "${API_path}")
# now we loop over these folders
for path in "${arr[@]}"
do
	# got to path
	cd "${path}"
	# we first check if there are changes
	if [[ -z $(git status --porcelain) ]];
	then
		echo "Nothing to commit here"
	else
		# make sure all new files are added and others removed where needed
		git add .
		# now commit the bunch... this will take a while since its a very large repo
		git commit -am "Update"
		# now push changes up to github...
		git push
	fi
done

