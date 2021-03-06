import argparse
import json
import os
import os.path
import shutil
import urllib.request
import zipfile

parser = argparse.ArgumentParser()
# get the arguments
parser.add_argument('--output_path', help='The local path like "/home/username/sword_zip"', default="sword_zip")
parser.add_argument('--bible_conf')
parser.add_argument('--no_whiptail', action='store_false')
# set to args
args = parser.parse_args()
# this is a full path
MAIN_PATH = args.output_path

# some helper dictionaries
v1_translation_names = json.loads(open(args.bible_conf).read())
# scripts directory
CURRENT_DIR = os.path.dirname(os.path.realpath(__file__))


# function to create path if not exist
def check_path(path):
    if not os.path.isdir(path):
        os.makedirs(path)


def zipper(src, dest, filename):
    """Backup files from src to dest."""
    base = os.path.basename(src)
    new_file = filename + ".zip"

    # Set the current working directory.
    os.chdir(dest)

    if os.path.exists(new_file):
        os.unlink(new_file)

    # Write the zipfile and walk the source directory tree.
    with zipfile.ZipFile(new_file, 'w') as zip_file:
        for folder, _, files in os.walk(src):
            for file in files:
                zip_file.write(os.path.join(folder, file),
                               arcname=os.path.join(folder[len(src):], file),
                               compress_type=zipfile.ZIP_DEFLATED)

    # move back to working directory
    os.chdir(CURRENT_DIR)


# make sure the main folder exist
check_path(MAIN_PATH)
# number of items
number = len(v1_translation_names.keys())
each_count = int(98 / number)
counter = 0
# loop the names
for sword_name in v1_translation_names:
    # set local file name
    file_path = MAIN_PATH + "/" + sword_name + ".zip"
    # set remote URL
    file_url = "https://www.crosswire.org/ftpmirror/pub/sword/packages/rawzip/" + sword_name + ".zip"
    # notice name
    file_name = sword_name + ".zip"
    # check if file exist locally
    if os.path.isfile(file_path):
        print('XXX\n{}\n{} already exist\nXXX'.format(counter, file_name))
    else:
        try:
            if args.no_whiptail:
                print('Downloading the RAW format of {}'.format(file_name))
            else:
                print('XXX\n{}\nDownloading the RAW format of {}\nXXX'.format(counter, file_name))
            urllib.request.urlretrieve(file_url, file_path)
        except urllib.error.HTTPError as e:
            if args.no_whiptail:
                print('Download {} failed! {}'.format(sword_name, e))
            else:
                print('XXX\n{} Download {} failed! {}\nXXX'.format(counter, sword_name, e))
    # check if this is a legitimate zip file
    if not zipfile.is_zipfile(file_path):
        if os.path.exists(file_path):
            os.remove(file_path)
            if args.no_whiptail:
                print('{} was removed since it has errors...'.format(file_path))
            else:
                print('XXX\n{}\n{} was removed since it has errors...\nXXX'.format(counter, file_path))
        else:
            if args.no_whiptail:
                print('{} was not downloaded (check the link)...'.format(file_path))
            else:
                print('XXX\n{}\n{} was not downloaded (check the link)...\nXXX'.format(counter, file_path))
        # we try the win repository
        file_url = "https://www.crosswire.org/ftpmirror/pub/sword/packages/win/" + sword_name + ".zip"
        try:
            if args.no_whiptail:
                print('Downloading the WIN format of {}'.format(file_name))
            else:
                print('XXX\n{}\nDownloading the WIN format of {}\nXXX'.format(counter, file_name))
            urllib.request.urlretrieve(file_url, file_path)
        except urllib.error.HTTPError as e:
            if args.no_whiptail:
                print('Download {} failed! {}'.format(sword_name, e))
            else:
                print('XXX\n{}\nDownload {} failed! {}\nXXX'.format(counter, sword_name, e))
        # again check if this is a legitimate zip file
        if not zipfile.is_zipfile(file_path):
            if os.path.exists(file_path):
                os.remove(file_path)
                if args.no_whiptail:
                    print('{} was again removed since it has errors...'.format(file_name))
                else:
                    print('XXX\n{}\n{} was again removed since it has errors...\nXXX'.format(counter, file_name))
            else:
                if args.no_whiptail:
                    print('{} was not downloaded (check the link)...'.format(file_path))
                else:
                    print('XXX\n{}\n{} was not downloaded (check the link)...\nXXX'.format(counter, file_path))
        else:
            # set local file name
            folder_path = MAIN_PATH + "/" + sword_name
            folder_raw_path = MAIN_PATH + "/" + sword_name + "/RAW"
            data_raw_path = MAIN_PATH + "/" + sword_name + "/data.zip"
            if args.no_whiptail:
                print('{} is being converted to RAW format'.format(file_name))
            else:
                print('XXX\n{}\n{} is being converted to RAW format\nXXX'.format(counter, file_name))
            # first we extract the WIN format
            with zipfile.ZipFile(file_path, 'r') as zip_ref:
                zip_ref.extractall(folder_path)
            os.remove(file_path)
            # now we extract the RAW format
            with zipfile.ZipFile(data_raw_path, 'r') as zip_ref:
                zip_ref.extractall(folder_raw_path)
            os.remove(data_raw_path)
            # now rename the folder
            os.rename(folder_raw_path + "/newmods", folder_raw_path + "/mods.d")
            # now zip the RAW folder
            zipper(folder_raw_path, MAIN_PATH, sword_name)
            # now remove the tmp folder
            try:
                shutil.rmtree(folder_path)
            except OSError as e:
                if args.no_whiptail:
                    print("Error: %s - %s." % (e.filename, e.strerror))
                else:
                    print("XXX\nError: %s - %s.\nXXX" % (e.filename, e.strerror))
    # increase the counter
    counter = int(counter + each_count)
