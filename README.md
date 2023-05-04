# PSX-DVR-Stuff
A repo for files related to softmodding the Sony PSX DESR-#### Japanese DVR/Playstation combo unit


## Translate Module and components

`PSXOSD.psm1` is a powershell module which contains a series of tools for translating the OSD files.

`XX-replacements.csv` is the language-specific files which contain substitutions from common output texts to somewhat less awkward words.  Replacements take place for every translate operation.

`imagesourcestrings.csv` is the OSD specific list of images, the Japanese strings contained within, their coordinates, and as well the font they are to be printed in.

## Usage

```
import-module .\PSXOSD.psm1

$osdpath = "F:\bigprojects\PSX-DVR\translations\jp"
$destination = "F:\bigprojects\PSX-DVR\translations\en"

process-osd -osdpath $osdpath -outputpath $destination -TargetLanguage "en"
```

At its simplest, this will just require you to import the module, and then provide as command line parameters the source path, destination path and as well the target language.  

The "TargetLanguage" parameter requires a 2 character ISO 932 locale identifier:

https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes


Source should always be original Japanese OSD files + in the root of the folder a copy of `imagesourcestrings.csv`.



### Notes

Regardless of what language the source string was in (and there's some English in there), it'll run it through the translation.  Non-Japanese languages will just stay the way they are due to specifying Japanese as source instead of auto-detect.

The processing takes place in 4 phases:

1. File copy, which clones the source folder to the destination folder.
2. XML translation - every XML file in the folder will have their nodes matching certain criteria will have their attribute strings translated to the target language, and the XML files saved in place.
3. The  `imagesourcestrings.csv` copied to the destination OSD folder has all of its source strings translated, and saved back to the CSV file.
4. Each record in the CSV file is used as input to modify the images containing Japanese text.

Each of these phases is optional via parameters on `process-osd` (`-bCopyFolder`,`-bTranslateXML`,`-bWriteImages`,`-bProcessImageStrings`), in case you want to (for debug purposes) run them one by one.

### API Rate Limiting

This script uses a free, undocumented Google translation API that will soon get killed off if too many people are hitting it too often.  This script has a 100ms "sleep" after calling a translate operation, which greatly increases the runtime.  If you like the free translate API - leave the 100ms sleep in place and be patient.
