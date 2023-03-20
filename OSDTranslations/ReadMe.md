# Background

There are a variety of OSD translations out there for the various models of the PSX.

It's been reported that some of these break things.  This makes sense - it looks like there's a lot of variations of the OSD `*.xml files which were used for localization.

These translations will be done on a one-by-one basis using a script which translates them via the Google Translate API.  This way - we can localize en masse all the different revisions.

# Folder Structure

This will be arranged first by model number, and second by firmware version, and lastly by language.  Because the translation script requires ISO 639 locale names, we'll be using that.

So: ja = Japanese, and these will be the original OSD files.  en = English, de = German, and so on

https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
