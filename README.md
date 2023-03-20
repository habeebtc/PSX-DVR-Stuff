# PSX-DVR-Stuff
A repo for files related to softmodding the Sony PSX DESR-#### Japanese DVR/Playstation combo unit


## Translate Script

Translate-PSXOSD.ps1 takes as a parameter a source path and a language identifier for what language to translate the OSD strings into.

The script works in a quick and dirty way - it iterates through the folder structure finding all XML files, and then iterates through every node in those files.  For each node with an attribute name of "str" - we feed that into a free (and undocumented) Google Translate API.

### Usage

Translate-PSXOSD.ps1 -path c:\projects\PSXBackup\xosd -TargetLanguage "ru"

The "TargetLanguage" parameter requires a 2 character ISO 932 locale identifier:

https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes

Regardless of what language the source string was in (and there's some English in there), it'll run it through the translation.  Non-Japanese languages will just stay the way they are (Sorry, not Sorry).  If you want to switch the API to auto-detect and localize *EVERYTHING* to the target language using language detection, you can modify the call to the REST API.  If this undocumented free API is like the cheap GCP API, then omitting the source language will switch to language detection.

The source files will be overwritten with the translated copies.  WORK ON A COPY OF YOUR BACKUP, NOT DIRECTLY ON THE BACKUP ITSELF.

### API Rate Limiting

This free, undocumented translation API will soon get killed off if too many people are hitting it too often.  Don't comment out the 1 second sleep in the translate function - just let the translation run overnight.  If this API disappears, you'll have to register for a GCP account and wire up a payment method, and then run the risk of getting charged for your usage if you don't select the right basic/free translation API tier/SKU.
