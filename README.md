# V2 API Builder

These scripts are used to build the version 2 of the getBible API based on the Crosswire modules.

## Before you continue reading the instructions...
### You must please agree to the following few conventions:

- Please run the script (as explained below) once a week to keep your repositories in sync with the Crosswire Modules.
- Please do not remove the hash methods from the project as they are used to identify change for those using your **scripture JSON API** and **HASH** repositories.
- Please do not host the repository that contains all the **scripture JSON** on a public repository like github (unless private), since if it gets forked those downstream repositories may go out of sync with any changes/fixes from the Crosswire Modules.
- Should you expose the **scripture JSON API** to the public (like [getBible.net](https://getbible.net/v2/translations.json) has done), please let us know by posting the details in an Issue on this repository.
- Should you not be able to do (or continue doing) any of the above requests then please do not place any of the project produced JSON or HASH files in the public space or in any project.

> You can still just use https://github.com/getbible/v2 directly and do not need to run your own API.

### You may ask Why?

Well, because we at getBible would like to comply with the Crosswire conventions to remain in sync with their modules all the way downstream from our project. Those who do not honor these agreements are responsible for Scripture Text (Digital) being incorrectly distributed with errors, as the digital versions of these Bibles may contain spelling mistakes, typos, or other errors like missing verses or chapters. So as they are discovered and fixed, Crosswire releases updates to their modules, and our commitment to the above agreed conventions ensure that these updates flow downstream. Should you have any further questions please do not hesitate to open an issue on this repository. Honestly, without these measures there is no getBible project... it is that serious.

**We made this code public so those who use our [API](https://github.com/getbible/v2) can see how it is build, and help improve and guide the project's code and future.**

# Okay, Lets get started... ˘Ô≈ôﺣ

Should you like to contribute any improvements either in code or conduct, just open an issue as the first step, and beginning of the conversation. ツ

## Install Dependencies (only Ubuntu 20 *tested)

Install Python3.8+
```bash 
$ sudo apt update
$ sudo apt install python3.8 python3-pip python3-requests
```
> make sure the [python3 version is 3.8](https://askubuntu.com/a/892322/379265) or higher so that the JSON order remains the same as found on [our API](https://github.com/getbible/v2), else your hash values will not be the same.

Install [pysword](https://gitlab.com/tgc-dk/pysword) (A native Python reader of the SWORD Project Bible Modules)
```bash
$ sudo pip3 install future
$ sudo pip3 install pysword
```

## Setup the Builder

Clone this repository
```bash
$ git clone https://github.com/getbible/v2_builder.git
$ cd v2_builder/
```

## Run the Builder

Make sure that the following files are executable.
```bash
$ sudo chmod +x run.sh
$ sudo chmod +x src/hash_books.sh
$ sudo chmod +x src/hash_chapters.sh
$ sudo chmod +x src/hash_versions.sh
$ sudo chmod +x src/movePublicFiles.sh
$ sudo chmod +x src/moveToGithub.sh
```

Start the Building process (this will take long)
```bash
$ ./run.sh
```

### Help Menu
```txt
Usage: ./run.sh [OPTION...]

You are able to change a few default behaviours in the getBible API builder
  ------ Passing no command options will fallback on the defaults -------

	Options ᒡ◯ᵔ◯ᒢ
	======================================================
   --api=<path>
	set the API target folders full path
		- target folders will be created using this path

	example: ./run.sh --api=/home/bible/v2

	two folders will be created:
		- /home/bible/v2
		- /home/bible/v2_scripture

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

	example: ./run.sh --bconf=/home/bible/getbible.json

	defaults:
		- repo/conf/CrosswireModulesMap.json
	======================================================
   --conf=<path>
	set all the config properties with a file

	example: ./run.sh --conf=/home/bible/.config/getbible.conf

	defaults:
		- repo/conf/.config
	======================================================
   --push
	push changes to github (only if there are changes)
		- setup the target folders (see target folders)
		- linked them to github (your own repos)
		- must be able to push (ssh authentication needed)

	REMEMBER THE AGREEMENT (README.md)

	example: ./run.sh --push
	======================================================
   --zip=<path>
	set the ZIP target folder full path for the Crosswire Modules

	example: ./run.sh --zip=/home/bible/sword_zip

	defaults:
		- repo/sword_zip
	======================================================
   -d
	Do not download all Crosswire Modules (helpful in testing)
	Only use this if you already have modules.

	example: ./run.sh -d
	======================================================
   --hashonly
	To only hash the existing JSON scripture files

	example: ./run.sh --hashonly
	======================================================
   --github
	Trigger github workflow behaviour

	example: ./run.sh --github
	======================================================
   --test
	Run a test with only three Bibles

	example: ./run.sh --test
	======================================================
   --dry
	To show all defaults, and not run the build

	example: ./run.sh --dry
	======================================================
   -q|--quiet
	Quiet mode that prevent whiptail from showing progress

	example: ./run.sh -q
	example: ./run.sh --quiet
	======================================================
   -h|--help
	display this help menu

	example: ./run.sh -h
	example: ./run.sh --help
	======================================================
			getBible JSON API.v2
	======================================================
```

### Setup Cron Job

To run this in a crontab
```bash
$ crontab -e
```
Then add the following line, update the time as needed
```bash
10 5 * * MON /home/username/v2_builder/run.sh >> /home/username/v2_builder/builder.log 2>&1
```

# Don't Forget Our Agreement!

### Free Software (with responsibility)
```txt
Llewellyn van der Merwe <github@vdm.io>
Copyright (C) 2019. All Rights Reserved
GNU/GPL Version 2 or later - http://www.gnu.org/licenses/gpl-2.0.html
```

