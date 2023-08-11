# V2 API Builder

[![Badge indicating the build status of getBible static JSON API files](https://github.com/getbible/v2_builder/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/getbible/v2_builder/actions/workflows/build.yml)

This guide will assist you in building the V2 of the getBible API using the Crosswire modules. But before we start, there are a few guidelines we need you to follow.

## Guidelines:
1. Run the script once a week to sync your repositories with the Crosswire Modules.
2. Do not remove the hash methods from the project. They're important for identifying changes.
3. Do not host the scripture JSON repository on a public platform (like GitHub) unless it's private to prevent any discrepancies with the Crosswire Modules.
4. If you make the scripture JSON API public, please let us know by [posting the details in an Issue in Support](https://git.vdm.dev/getBible/support).
5. If you can't follow the above requests, please do not distribute any of the JSON or HASH files produced by the project.

Please adhere to these guidelines to ensure consistency and prevent errors. If you have any questions, feel free to open an issue on this repository. If you don't wish to run your own API, you can use https://api.getbible.net/v2/translations.json directly.

Here is the documentation to the Official getBible API: https://getbible.net/docs

## Getting Started:

Interested in contributing? Great! Just open an issue to start the conversation. Now let's proceed with the setup.

## Installation:
(These steps have been tested on Ubuntu 20)

1. Install Python 3.8 or higher
```bash 
$ sudo apt update
$ sudo apt install python3.8 python3-pip python3-requests
```
Ensure the Python 3 version is 3.8 or higher for the JSON order to be the same as [our API](https://git.vdm.dev/getBible/v2).

2. Install [pysword](https://gitlab.com/tgc-dk/pysword), a Python reader of the SWORD Project Bible Modules.
```bash
$ sudo pip3 install future
$ sudo pip3 install pysword
```

## Setup:

1. Clone this repository and navigate into it.
```bash
$ git clone https://git.vdm.dev/getBible/v2_builder.git
$ cd v2_builder/
```

2. Make sure the following files are executable.
```bash
$ sudo chmod +x run.sh
$ sudo chmod +x src/hash_books.sh
$ sudo chmod +x src/hash_chapters.sh
$ sudo chmod +x src/hash_versions.sh
$ sudo chmod +x src/movePublicFiles.sh
$ sudo chmod +x src/moveToGithub.sh
```

3. Start the building process. Note that this may take some time (3 hours+).
```bash
$ ./run.sh
```

The `run.sh` script has several options that you can utilize to modify the default behaviors. You can view these options in the help menu by using `./run.sh -h` or `./run.sh --help`.

### Automation:

To run this script automatically every week, you can set up a Cron job as follows:

1. Open crontab.
```bash
$ crontab -e
```
2. Add the following line. Make sure to update the time and paths as needed.
```bash
10 5 * * MON /home/username/v2_builder/run.sh >> /home/username/v2_builder/builder.log 2>&1
```

## Let's be responsible!

While this software is free, it comes with a responsibility to maintain the integrity of the scripture text. Let's work together to ensure that the digital versions of these Bibles are accurate and error-free.

## Help Menu
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
   --pull
	clone and/or pull target folders/repositories

	example: ./run.sh --pull
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

## Use GitHub Actions

If you wish to use GitHub Actions for automation, you'll need to set up several secrets in your fork of `v2_builder`. The details are listed below.

> The github user email being used to build
- GETBIBLE_GIT_EMAIL
> The github username being used to build
- GETBIBLE_GIT_USER
> `gpg -a --export-secret-keys >myprivatekeys.asc`
> The whole key file text from the above myprivatekeys.asc
> This key must be linked to the github user being used
- GETBIBLE_GPG_KEY
> The name of the myprivatekeys.asc user
- GETBIBLE_GPG_USER
> A **OFFICIAL** repository of the hash files
> like: `git@github.com:getbible/v2.git`
> the github user must have push/pull access to this repo
- GETBIBLE_HASH_REPO
> A **TEST** repository of the hash files
> like: `git@github.com:Llewellyn/v2.git`
> the github user must have push/pull access to this repo
- GETBIBLE_HASH_REPO_T
> A **OFFICIAL** repository of the scripture files
> like: `git@github.com:getbible/v2_scripture.git`
> the github user must have push/pull access to this repo
- GETBIBLE_SCRIPTURE_REPO
> A **TEST** repository of the scripture files
> like: `git@github.com:Llewellyn/v2_scripture.git`
> the github user must have push/pull access to this repo
- GETBIBLE_SCRIPTURE_REPO_T
> A id_ed25519 ssh private key liked to the github user account
- GETBIBLE_SSH_KEY
> A id_ed25519.pub ssh public key liked to the github user account
- GETBIBLE_SSH_PUB

All these secret values are needed to fully automate the build. Then you need to go to the actions are in your fork of v2_builder and activate the actions.

### Free Software (with responsibility)
```txt
Llewellyn van der Merwe <github@vdm.io>
Copyright (C) 2019. All Rights Reserved
GNU/GPL Version 2 or later - http://www.gnu.org/licenses/gpl-2.0.html
```
