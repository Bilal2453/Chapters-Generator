# Chapter-Genrator
Script that Generates video chapters.

## Supporting
For now, This Script only available as an Aegisub plugin.

## Supported Formats
For now, only OGG/OGM text format is supported, but in the future XML matroska chapters also will be supported.

## installition
1. Copy the [Script](https://github.com/Bilal2453/Chapter-Genrator/blob/master/ChapterMaker.lua) to program directoy `(your_aegisub_installition/automation/autoload/)`
2. Re-Open Aegisub, or reload your plugins.

## How to use
1. Create a new subtitle line.

2. Toggle line comment on.
![Step 2: Comment](https://i.imgur.com/PBGmVEE.png)

3. Type your chapter title/name.
![Step 3: Title](https://i.imgur.com/k6HZNcA.png)

4. Time your translation line, Chapter start and chapter end.
![Step 4: Time](https://i.imgur.com/WRI3A0w.png)

5. Change the effect field to "chapter"
![Step 5: Effect](https://i.imgur.com/xxDZ70e.png)

6. Use the plugin from the automatiom menu.
![Step 6: Use](https://i.imgur.com/WX41IEm.png)

Choose Data format (extenion)
![Format](https://i.imgur.com/HSdxRVm.png)

Click Save
![Save](https://i.imgur.com/6ogHlBK.png)


Choose file name and path

## Known Problems
- Weird Characters Appers when using MKV Toolnix (or other tools)
  If your Chapter files contains non-english character, Try changing your charset to UTF-8
  
  ![Problem](https://i.imgur.com/rQ3RfgZ.png)
  ![Solve](https://i.imgur.com/tqDTb9l.png)
  ![Solved](https://i.imgur.com/cTVmtw8.png)
