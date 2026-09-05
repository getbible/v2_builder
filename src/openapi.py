"""Write the OpenAPI document for a built getBible JSON API tree.

The builder produces a tree of static JSON files: one file per translation,
book and chapter, each with a SHA-1 checksum file beside it, and JSON indexes
at every level. This script runs once at the end of a build, reads the
finished tree, and writes openapi.json into its root: an OpenAPI 3.1
description of that tree as an HTTP API, for use when the tree is deployed
as an API endpoint downstream.

The tree itself is never changed and nothing here is used as input to the
build. The document is deterministic for a given tree, so rebuilding an
unchanged tree leaves it untouched.
"""
import argparse
import json
import os
import sys

# the file written into the root of the tree
OPENAPI_FILE = 'openapi.json'
# where the tree is served when the url fields of the indexes cannot tell us
DEFAULT_SERVER_URL = 'https://api.getbible.net/v2'
# the shape of a translation abbreviation (file and folder names)
ABBREVIATION_PATTERN = '^[a-z0-9]+$'
# the shape of a book or chapter number used as an index key
NUMBER_KEY_PATTERN = '^[0-9]+$'
# the shape of a SHA-1 checksum
SHA1_PATTERN = '^[0-9a-f]{40}$'
# the shape of a .sha file (the checksum followed by a newline)
SHA1_FILE_PATTERN = '^[0-9a-f]{40}\\s*$'

# get arguments
parser = argparse.ArgumentParser()
parser.add_argument('--output_path', help='The root of the built API tree (holds translations.json)')
parser.add_argument('--conf_dir', help='The builder conf folder (holds bookNumbers.json)')
parser.add_argument('--plain', action='store_true', help='Print plain progress lines instead of whiptail gauge blocks')
# set to args
args = parser.parse_args()


# function to give notice in the format run.sh expects
def notice(percentage, message):
    if args.plain:
        print(message)
    else:
        print('XXX\n{}\n{}\nXXX'.format(percentage, message))


# function to load a JSON file if it exists
def load_json(path):
    if not os.path.isfile(path):
        return None
    with open(path) as handle:
        return json.load(handle)


# function to read what the finished tree holds
def read_tree(output_path):
    translations = load_json(os.path.join(output_path, 'translations.json')) or {}
    abbreviations = sorted(key for key in translations if isinstance(translations.get(key), dict))
    server_url = DEFAULT_SERVER_URL
    # the hash scripts write the address of every file, so the tree knows where it is served
    for abbreviation in abbreviations:
        url = translations[abbreviation].get('url', '')
        suffix = '/' + abbreviation + '.json'
        if isinstance(url, str) and url.endswith(suffix) and len(url) > len(suffix):
            server_url = url[:-len(suffix)]
            break
    return abbreviations, server_url


# function to read the range of book numbers the builder uses
def book_number_range(conf_dir):
    numbers = load_json(os.path.join(conf_dir, 'bookNumbers.json')) if conf_dir else None
    values = [value for value in (numbers or {}).values() if isinstance(value, int)]
    if not values:
        return 1, None
    return min(values), max(values)


# some helpers to keep the schemas readable
def ref(name):
    return {'$ref': '#/components/schemas/' + name}


def string(description, **extra):
    schema = {'type': 'string', 'description': description}
    schema.update(extra)
    return schema


def integer(description, **extra):
    schema = {'type': 'integer', 'description': description}
    schema.update(extra)
    return schema


def array(description, item):
    return {'type': 'array', 'description': description, 'items': item}


def document(description, properties):
    return {
        'type': 'object',
        'description': description,
        'properties': properties,
        'required': list(properties.keys())
    }


def index(description, key_pattern, item):
    return {
        'type': 'object',
        'description': description,
        'propertyNames': {'pattern': key_pattern},
        'additionalProperties': item
    }


# the fields every translation, book and chapter file starts with
# (a translation file also carries its description, right after the abbreviation)
def meta_properties(with_description=False):
    properties = {
        'translation': string('Name of the translation'),
        'abbreviation': string('Abbreviation of the translation, used as its file and folder name',
                               pattern=ABBREVIATION_PATTERN)
    }
    if with_description:
        properties['description'] = string('Description of the translation from the source module')
    properties.update({
        'lang': string('Language code of the translation'),
        'language': string('Name of the language in English'),
        'direction': ref('Direction'),
        'encoding': string('Character encoding of the source module')
    })
    return properties


# the fields a translation file ends with
def distribution_properties():
    return {
        'distribution_lcsh': string('Library of Congress subject heading of the source module'),
        'distribution_version': string('Version of the source module'),
        'distribution_version_date': string('Date of the source module version'),
        'distribution_abbreviation': string('Abbreviation of the source module'),
        'distribution_about': string('About text of the source module'),
        'distribution_license': string('Distribution license of the source module text'),
        'distribution_sourcetype': string('Markup type of the source module text'),
        'distribution_source': string('Origin of the source module text'),
        'distribution_versification': string('Versification of the source module'),
        'distribution_history': {
            'type': 'object',
            'description': 'Change history of the source module, keyed by history entry',
            'additionalProperties': {'type': 'string'}
        }
    }


# the fields an index entry ends with
def reference_properties(subject):
    return {
        'url': string('Address of the ' + subject + ' file', format='uri'),
        'sha': {'$ref': '#/components/schemas/Sha1', 'description': 'SHA-1 checksum of the ' + subject + ' file'}
    }


# function to build all the schemas
def build_schemas():
    verse = document('One verse', {
        'chapter': integer('Chapter number', minimum=1),
        'verse': integer('Verse number', minimum=1),
        'name': string('Name of the verse, as book name, chapter and verse'),
        'text': string('Text of the verse')
    })
    book_chapter = document('One chapter with its verses', {
        'chapter': integer('Chapter number', minimum=1),
        'name': string('Name of the chapter, as book name and chapter'),
        'verses': array('Verses of the chapter', ref('Verse'))
    })
    translation_book = document('One book with its chapters', {
        'nr': integer('Book number', minimum=1),
        'name': string('Name of the book in the translation'),
        'chapters': array('Chapters of the book', ref('BookChapter'))
    })
    translation = document('A complete translation file', dict(
        list(meta_properties(with_description=True).items())
        + [('books', array('Books of the translation', ref('TranslationBook')))]
        + list(distribution_properties().items())
    ))
    translation_summary = document('A translation as listed in translations.json (the translation file without its books)', dict(
        list(meta_properties(with_description=True).items())
        + list(distribution_properties().items())
        + list(reference_properties('translation').items())
    ))
    book = document('A complete book file', dict(
        list(meta_properties().items())
        + [('nr', integer('Book number', minimum=1)),
           ('name', string('Name of the book in the translation')),
           ('chapters', array('Chapters of the book', ref('BookChapter')))]
    ))
    book_summary = document('A book as listed in books.json (the book file without its chapters)', dict(
        list(meta_properties().items())
        + [('nr', integer('Book number', minimum=1)),
           ('name', string('Name of the book in the translation'))]
        + list(reference_properties('book').items())
    ))
    chapter = document('A complete chapter file', dict(
        list(meta_properties().items())
        + [('book_nr', integer('Book number', minimum=1)),
           ('book_name', string('Name of the book in the translation')),
           ('chapter', integer('Chapter number', minimum=1)),
           ('name', string('Name of the chapter, as book name and chapter')),
           ('verses', array('Verses of the chapter', ref('Verse')))]
    ))
    chapter_summary = document('A chapter as listed in chapters.json (the chapter file without its verses)', dict(
        list(meta_properties().items())
        + [('book_nr', integer('Book number', minimum=1)),
           ('book_name', string('Name of the book in the translation')),
           ('chapter', integer('Chapter number', minimum=1)),
           ('name', string('Name of the chapter, as book name and chapter'))]
        + list(reference_properties('chapter').items())
    ))
    return {
        'Direction': {
            'type': 'string',
            'description': 'Writing direction of the text',
            'enum': ['LTR', 'RTL']
        },
        'Sha1': string('SHA-1 checksum of a JSON file, as 40 lowercase hexadecimal characters', pattern=SHA1_PATTERN),
        'Sha1File': string('The content of a .sha file: the SHA-1 checksum of the JSON file with the same name, '
                           'as 40 lowercase hexadecimal characters followed by a newline', pattern=SHA1_FILE_PATTERN),
        'Verse': verse,
        'BookChapter': book_chapter,
        'TranslationBook': translation_book,
        'Translation': translation,
        'TranslationSummary': translation_summary,
        'TranslationIndex': index('Every translation in the tree, keyed by abbreviation',
                                  ABBREVIATION_PATTERN, ref('TranslationSummary')),
        'Book': book,
        'BookSummary': book_summary,
        'BookIndex': index('Every book of a translation, keyed by book number', NUMBER_KEY_PATTERN, ref('BookSummary')),
        'Chapter': chapter,
        'ChapterSummary': chapter_summary,
        'ChapterIndex': index('Every chapter of a book, keyed by chapter number', NUMBER_KEY_PATTERN, ref('ChapterSummary')),
        'ChecksumIndex': index('The SHA-1 checksum of every JSON file at this level, keyed by file name without extension',
                               '^[a-z0-9]+$', ref('Sha1'))
    }


# function to build the path parameters
def build_parameters(abbreviations, book_range):
    abbreviation = {'type': 'string', 'pattern': ABBREVIATION_PATTERN}
    if abbreviations:
        abbreviation['enum'] = abbreviations
    book = {'type': 'integer', 'minimum': book_range[0]}
    if book_range[1] is not None:
        book['maximum'] = book_range[1]
    return {
        'abbreviation': {
            'name': 'abbreviation',
            'in': 'path',
            'required': True,
            'description': 'Abbreviation of the translation, as listed in translations.json',
            'schema': abbreviation,
            'example': 'kjv' if 'kjv' in abbreviations else (abbreviations[0] if abbreviations else 'kjv')
        },
        'book': {
            'name': 'book',
            'in': 'path',
            'required': True,
            'description': 'Book number, as listed in the books.json of the translation',
            'schema': book,
            'example': 1
        },
        'chapter': {
            'name': 'chapter',
            'in': 'path',
            'required': True,
            'description': 'Chapter number, as listed in the chapters.json of the book',
            'schema': {'type': 'integer', 'minimum': 1},
            'example': 1
        }
    }


# function to build one GET operation
def operation(operation_id, tag, summary, description, media_type, schema_name, parameters=(), not_found=True):
    get = {
        'tags': [tag],
        'summary': summary,
        'description': description,
        'operationId': operation_id
    }
    if parameters:
        get['parameters'] = [{'$ref': '#/components/parameters/' + name} for name in parameters]
    get['responses'] = {
        '200': {
            'description': summary,
            'content': {media_type: {'schema': ref(schema_name)}}
        }
    }
    if not_found:
        get['responses']['404'] = {'$ref': '#/components/responses/NotFound'}
    return {'get': get}


# function to build all the paths
def build_paths():
    return {
        '/translations.json': operation(
            'listTranslations', 'translations', 'Index of the translations',
            'Every translation in the tree with its details and checksum, keyed by abbreviation.',
            'application/json', 'TranslationIndex', not_found=False),
        '/checksum.json': operation(
            'listTranslationChecksums', 'checksums', 'Checksums of the translations',
            'The SHA-1 checksum of every translation file, keyed by abbreviation.',
            'application/json', 'ChecksumIndex', not_found=False),
        '/{abbreviation}.json': operation(
            'getTranslation', 'translations', 'A complete translation',
            'The whole translation: every book with every chapter and verse, and the details of the source module.',
            'application/json', 'Translation', ('abbreviation',)),
        '/{abbreviation}.sha': operation(
            'getTranslationChecksum', 'checksums', 'Checksum of a translation',
            'The SHA-1 checksum of the translation file.',
            'text/plain', 'Sha1File', ('abbreviation',)),
        '/{abbreviation}/books.json': operation(
            'listBooks', 'books', 'Index of the books of a translation',
            'Every book of the translation with its details and checksum, keyed by book number.',
            'application/json', 'BookIndex', ('abbreviation',)),
        '/{abbreviation}/checksum.json': operation(
            'listBookChecksums', 'checksums', 'Checksums of the books of a translation',
            'The SHA-1 checksum of every book file of the translation, keyed by book number.',
            'application/json', 'ChecksumIndex', ('abbreviation',)),
        '/{abbreviation}/{book}.json': operation(
            'getBook', 'books', 'A complete book',
            'One book of the translation with every chapter and verse.',
            'application/json', 'Book', ('abbreviation', 'book')),
        '/{abbreviation}/{book}.sha': operation(
            'getBookChecksum', 'checksums', 'Checksum of a book',
            'The SHA-1 checksum of the book file.',
            'text/plain', 'Sha1File', ('abbreviation', 'book')),
        '/{abbreviation}/{book}/chapters.json': operation(
            'listChapters', 'chapters', 'Index of the chapters of a book',
            'Every chapter of the book with its details and checksum, keyed by chapter number.',
            'application/json', 'ChapterIndex', ('abbreviation', 'book')),
        '/{abbreviation}/{book}/checksum.json': operation(
            'listChapterChecksums', 'checksums', 'Checksums of the chapters of a book',
            'The SHA-1 checksum of every chapter file of the book, keyed by chapter number.',
            'application/json', 'ChecksumIndex', ('abbreviation', 'book')),
        '/{abbreviation}/{book}/{chapter}.json': operation(
            'getChapter', 'chapters', 'A complete chapter',
            'One chapter of a book with every verse.',
            'application/json', 'Chapter', ('abbreviation', 'book', 'chapter')),
        '/{abbreviation}/{book}/{chapter}.sha': operation(
            'getChapterChecksum', 'checksums', 'Checksum of a chapter',
            'The SHA-1 checksum of the chapter file.',
            'text/plain', 'Sha1File', ('abbreviation', 'book', 'chapter')),
        '/openapi.json': {
            'get': {
                'summary': 'This document',
                'description': 'The OpenAPI description of this tree, written at the end of the build that produced it.',
                'operationId': 'getOpenApi',
                'responses': {
                    '200': {
                        'description': 'OpenAPI 3.1 document',
                        'content': {'application/json': {'schema': {'type': 'object'}}}
                    }
                }
            }
        }
    }


# function to build the whole document
def build_document(abbreviations, server_url, book_range):
    return {
        'openapi': '3.1.0',
        'info': {
            'title': 'getBible JSON API',
            'version': 'v2',
            'summary': 'Static JSON files of Bible translations built from the Crosswire modules',
            'description': (
                'Every resource is a static file in a fixed tree: a translation (`{abbreviation}.json`), '
                'one of its books (`{abbreviation}/{book}.json`) or one of its chapters '
                '(`{abbreviation}/{book}/{chapter}.json`), each with a `.sha` file beside it holding its SHA-1 '
                'checksum, and at every level a JSON index of what is available (`translations.json`, '
                '`books.json`, `chapters.json`) with a checksum index (`checksum.json`). '
                'The files take no parameters. The checksums identify a build: a changed checksum means '
                'the file was rebuilt from an updated module.'
            ),
            'contact': {'name': 'getBible', 'url': 'https://getbible.net'}
        },
        'servers': [{'url': server_url, 'description': 'Root of the tree'}],
        'tags': [
            {'name': 'translations', 'description': 'The translations in the tree and their complete text'},
            {'name': 'books', 'description': 'The books of a translation'},
            {'name': 'chapters', 'description': 'The chapters of a book'},
            {'name': 'checksums', 'description': 'SHA-1 checksums of the files, to detect changes between builds'}
        ],
        'paths': build_paths(),
        'components': {
            'schemas': build_schemas(),
            'parameters': build_parameters(abbreviations, book_range),
            'responses': {
                'NotFound': {
                    'description': 'No such file: the translation, book or chapter is not part of this tree'
                }
            }
        }
    }


# function to save the json file output
def write_json(document_dict, output_file):
    with open(output_file, 'w') as outfile:
        json.dump(document_dict, outfile, indent=2)
        outfile.write('\n')


# customary main function
def main():
    if not args.output_path or not os.path.isdir(args.output_path):
        print('The output path ({}) is not a folder. Aborting.'.format(args.output_path), file=sys.stderr)
        return 1
    notice(0, 'Building {}'.format(OPENAPI_FILE))
    abbreviations, server_url = read_tree(args.output_path)
    if not abbreviations:
        print('No translations.json found in {}; {} lists no translations.'.format(args.output_path, OPENAPI_FILE),
              file=sys.stderr)
    document_dict = build_document(abbreviations, server_url, book_number_range(args.conf_dir))
    write_json(document_dict, os.path.join(args.output_path, OPENAPI_FILE))
    notice(100, 'Done building {} ({} translations)'.format(OPENAPI_FILE, len(abbreviations)))
    return 0


if __name__ == "__main__": sys.exit(main())
