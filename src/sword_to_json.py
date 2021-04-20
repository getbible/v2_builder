
import argparse
import json
import os
import requests
import sys

from pysword.modules import SwordModules

if sys.version_info > (3, 0):
    from past.builtins import xrange

# get arguments
parser = argparse.ArgumentParser()
# get the arguments
parser.add_argument('--source_file')
parser.add_argument('--output_path')
parser.add_argument('--counter')
parser.add_argument('--next')
parser.add_argument('--conf_dir')
parser.add_argument('--bible_conf')
# set to args
args = parser.parse_args()

# some helper dictionaries
v1_translation_names = json.loads(open(args.bible_conf).read())
v1_translations = json.loads(open(args.conf_dir + "/v1Translations.json").read())
book_numbers = json.loads(open(args.conf_dir + "/bookNumbers.json").read())
book_names = json.loads(open(args.conf_dir + "/bookNames.json").read())
lang_correction = json.loads(open(args.conf_dir + "/langCorrection.json").read())
language_names = json.loads(open(args.conf_dir + "/languageNames.json").read())
text_direction = json.loads(open(args.conf_dir + "/textDirection.json").read())

# function to build Bible dictionaries
def get_bible_dict(source_file, bible_version, output_path, current_counter, next_counter):
    # set some counter values
    counter = int(current_counter)
    current = int(current_counter)
    next = int(next_counter)
    # load the sword module
    module = SwordModules(source_file)
    # get the config
    module_config = module.parse_modules()[bible_version]
    # load the bible version
    bible_mod = module.get_bible_from_module(bible_version)
    # load the list of books per/testament
    testaments = bible_mod.get_structure()._books
    # merge the books
    books = []
    for testament in testaments:
        books += testaments[testament]
    # set the abbreviation
    abbreviation = v1_translation_names.get(bible_version, bible_version.lower())
    # get v1 Book Names (some are in the same language)
    v1_book_names = {}
    # check if this translations was in v1
    if bible_version in v1_translation_names:
        try:
            v1_book_names = requests.get('https://getbible.net/v1/' + abbreviation + '/books.json').json()
        except ValueError:
            # no json found
            v1_book_names = {}
    # start to build the complete scripture of the translation
    bible_ = {}
    bible_['translation'] = v1_translations.get(abbreviation, module_config.get('description', bible_version))
    bible_['abbreviation'] = abbreviation
    bible_['discription'] = module_config.get('description', '')
    # set language
    lang_ = module_config.get('lang', '')
    bible_['lang'] = lang_correction.get(lang_, lang_)
    bible_['language'] = language_names.get(lang_, '')
    bible_['direction'] = text_direction.get(lang_, 'LTR')
    # not sure if this is relevant seeing that json.dump ensure_ascii=True
    bible_['encoding'] = module_config.get('encoding', '')
    # set global book
    bible_book = {
        'translation': bible_.get('translation'),
        'abbreviation': abbreviation,
        'lang': bible_.get('lang'),
        'language': bible_.get('language'),
        'direction': bible_.get('direction', 'LTR'),
        'encoding': bible_.get('encoding')
    }
    # set global chapter
    bible_chapter = {
        'translation': bible_.get('translation'),
        'abbreviation': abbreviation,
        'lang': bible_.get('lang'),
        'language': bible_.get('language'),
        'direction': bible_.get('direction', 'LTR'),
        'encoding': bible_.get('encoding')
    }
    # start building the books
    bible_['books'] = []
    for book in books:
        # add the book only if it has verses
        book_has_verses = False;
        # reset chapter bucket
        chapters = []
        # set book number
        book_nr = book_numbers.get(book.name)
        # get book name as set in v1
        book_name = v1_book_names.get(str(book_nr), {}).get('name', book_names.get(book.name, book.name))
        # get book path
        book_path = os.path.join(output_path, bible_.get('abbreviation'), str(book_nr))
        # check if path is set
        check_path(book_path)
        # add the book only if it has verses
        chapter_has_verses = False;
        for chapter in xrange(1, book.num_chapters+1):
            # reset verse bucket
            verses = []
            for verse in xrange(1, len(book.get_indicies(chapter))+1 ):
                text = bible_mod.get(books=[book.name], chapters=[chapter], verses=[verse])
                _text = text.replace('[]', '')
                if len(text) > 0 and not _text.isspace():
                    book_has_verses = True;
                    chapter_has_verses = True;
                    verses.append({
                        'chapter': chapter,
                        'verse': verse,
                        'name': book_name + " " + str(chapter) + ":" + str(verse),
                        'text': text
                        })
            if chapter_has_verses:
                # load to complete Bible
                chapters.append({
                    'chapter': chapter,
                    'name': book_name + " " + str(chapter),
                    'verses': verses
                })
                # set chapter
                bible_chapter['book_nr'] = book_nr
                bible_chapter['book_name'] = book_name
                bible_chapter['chapter'] = chapter
                bible_chapter['name'] = book_name + " " + str(chapter)
                bible_chapter['verses'] = verses
                # store to chapter file
                write_json(bible_chapter, os.path.join(book_path, str(chapter) + '.json'))
                print('XXX\n{}\nChapter {} was added to {}-{}\nXXX'.format(counter, chapter, book_name, abbreviation))
                counter = increment_counter(counter, next, current)
        if book_has_verses:
            # load to complete Bible
            bible_['books'].append({
                'nr': book_nr,
                'name': book_name,
                'chapters': chapters
            })
            # set book
            bible_book['nr'] = book_nr
            bible_book['name'] = book_name
            bible_book['chapters'] = chapters
            # store to book file
            write_json(bible_book, book_path + '.json')
            print('XXX\n{}\nBook ({}) was added to {}\nXXX'.format(counter, book_name, abbreviation))
            counter = increment_counter(counter, next, current)
    # add distribution info
    bible_['distribution_lcsh'] = module_config.get('lcsh', '')
    bible_['distribution_version'] = module_config.get('version', '')
    bible_['distribution_version_date'] = module_config.get('SwordVersionDate', module_config.get('swordversiondate', ''))
    bible_['distribution_abbreviation'] = module_config.get('abbreviation', abbreviation)
    bible_['distribution_about'] = module_config.get('about', '')
    bible_['distribution_license'] = module_config.get('distributionlicense', '')
    bible_['distribution_sourcetype'] = module_config.get('sourcetype', '')
    bible_['distribution_source'] = module_config.get('textsource', '')
    bible_['distribution_versification'] = module_config.get('versification', '')

    # load the distribution history
    bible_['distribution_history'] = {}
    for k,v in module_config.items():
        if 'history' in k:
            bible_['distribution_history'][k] = v

    return bible_

# function to safe the json file output
def write_json(bible_dict, output_file):
    with open(output_file, 'w') as outfile:
        json.dump(bible_dict, outfile, indent=4)

# function to create path if not exist
def check_path(path):
    if not os.path.isdir(path):
        os.makedirs(path)

# function to manange increment of counter
def increment_counter(counter, next, current):
    if counter >= next:
        return int(current)
    return counter + 1

# customary main function
def main():
    # check if books directory exist
    check_path(args.output_path)
    # get version name from source file
    bible_version = args.source_file.replace(".zip", "").rsplit('/', 1)[-1]
    # get the all the scripture of this Bible
    bible_dict = get_bible_dict(args.source_file, bible_version, args.output_path, args.counter, args.next)
    # set the correct file name to match v1 if found
    version_file_name = v1_translation_names.get(bible_version, bible_version.lower()) + '.json'
    # save to json
    write_json(bible_dict, os.path.join(args.output_path, version_file_name))

if __name__ == "__main__": main()
