"""Verify that every JSON file in a built getBible tree has a correct .sha sibling.

Runs once at the end of a build, after the hashing scripts, and walks the
whole tree: every .json file gets a .sha file beside it holding the SHA-1 of
its bytes (created when missing, rewritten when wrong), and a .sha file
without a .json sibling is removed as stale. The tree that leaves this step
has no JSON file without a checksum, whatever happened before it.
"""
import argparse
import hashlib
import os
import sys

# get arguments
parser = argparse.ArgumentParser()
parser.add_argument('--output_path', help='The root of the built API tree')
parser.add_argument('--plain', action='store_true', help='Print plain progress lines instead of whiptail gauge blocks')
# set to args
args = parser.parse_args()


# function to give notice in the format run.sh expects
def notice(percentage, message):
    if args.plain:
        print(message)
    else:
        print('XXX\n{}\n{}\nXXX'.format(percentage, message))


# function to get the SHA-1 checksum of a file (as sha1sum prints it)
def digest(path):
    hasher = hashlib.sha1()
    with open(path, 'rb') as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b''):
            hasher.update(block)
    return hasher.hexdigest()


# function to find every JSON and checksum file in the tree
def find_files(root):
    json_files = []
    sha_files = []
    for directory, dirnames, filenames in os.walk(root):
        # never look inside git (or any other hidden) folders
        dirnames[:] = sorted(name for name in dirnames if not name.startswith('.'))
        for name in sorted(filenames):
            if name.endswith('.json'):
                json_files.append(os.path.join(directory, name))
            elif name.endswith('.sha'):
                sha_files.append(os.path.join(directory, name))
    return json_files, sha_files


# customary main function
def main():
    if not args.output_path or not os.path.isdir(args.output_path):
        print('The output path ({}) is not a folder. Aborting.'.format(args.output_path), file=sys.stderr)
        return 1
    notice(0, 'Start verifying checksums')
    json_files, sha_files = find_files(args.output_path)
    total = len(json_files)
    step = max(1, total // 50)
    verified = created = repaired = 0
    for number, path in enumerate(json_files, 1):
        sibling = path[:-5] + '.sha'
        expected = digest(path)
        current = None
        if os.path.isfile(sibling):
            with open(sibling) as handle:
                current = handle.read().strip().lower()
        if current == expected:
            verified += 1
        else:
            with open(sibling, 'w') as handle:
                handle.write(expected + '\n')
            if current is None:
                created += 1
            else:
                repaired += 1
        if number % step == 0:
            notice(int(number * 100 / total), 'Verified {} of {} JSON files'.format(number, total))
    # a checksum without its JSON file is stale
    removed = 0
    for path in sha_files:
        if not os.path.isfile(path[:-4] + '.json'):
            os.remove(path)
            removed += 1
    notice(100, 'Done verifying checksums: {} JSON files, {} checksums verified, {} created, {} repaired, {} stale removed'
           .format(total, verified, created, repaired, removed))
    return 0


if __name__ == "__main__": sys.exit(main())
