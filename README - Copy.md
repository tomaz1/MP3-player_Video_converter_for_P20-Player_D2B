# Portable music MP3 player - avi video converter tool (P20-Player)

## Background

I couldn't find "SetupPxConverter(2.0.10).exe", but I have found https://github.com/fdd4s/portable_music_player_avi_video_converter_tool_2025.

I didn't like mono sound and later I have found few limitations, main were: 
- missing stereo sound
- better audio sound (fdd4s has set it to 16k, but it works without problem at 22k)
- when splitting sometime first .avi file didn't work :(
- missing ratio aspect fix
- missing sound gain

This script convert videos for avi format of portable music player through ffmpeg. It creates a file with the same name than source but ended in "-p", or if splitting at the end of file add -00, -01, -02, ...

These scripts use a modified ffmpeg version with extra params for x264 codec, added to this project, called ffmeg-mod.exe. Normal ffmpeg can't take those parameters.

Personally I don't trust ffmpeg-mod and I call it from free [sandboxie](https://sandboxie-plus.com/) without access to internet.


## Dependencies

ffmpeg-mod.exe  

These scripts are designed to run in Windows.  

## Players supported

AVI Format H264 modified video codec - Portable Music Player 2.0 inch **288x240**
![alt text](players_pics/mp3-player-crn.png)
![alt text](players_pics/mp3-player-bel.png)

Feel free to search for 288 and 240 and change it to whatever you have, if you use similar player. TODO for myself: use variables. I don't know why I didn't use variables at the first place? :)

## How to know the player format
In folder test_video you can test a fragment of 30 seconds of the Creative Commons video Big Buck Bunny https://en.wikipedia.org/wiki/Big_Buck_Bunny  

## Usage

    C:\somewhere\> run-split.bat <video file>

For help:  

    C:\somewhere\> run-split.bat -?

Parameters:
- input_file    Path to the input video file (required)
- -cropadjust   0–100, how much to adjust the aspect ratio (default: 0)  
Adds or removes black borders to better match the device’s ideal 6:5 aspect ratio (288×240)  
- -splitmin     Segment length in minutes (0 = no splitting)  
Creates separate files: name-00.avi, name-01.avi, etc.
- -soundgain   Audio gain or reduction in x.x dB (default: 0.0, can also be negative)

## Example

    C:\somewhere\> run-split.bat C:\Cartoons\videofile.mp4 -cropadjust 50 -splitmin 30 -soundgain 5

## MP3 players - known limitations:

- Video can't be fast forwarded or bookmarked as mp3 can be.
- Sound of video doesn't go throuh bluetooth speakers
- Can't connect mp3 player with computer to transfer files, I have to use USB-C cable.

## Where to get those players?

I have bought my two MP3 player at AliExpress.

## Project name

 Why I have named project "P20 Player_D2B" ?
 When I tried to connect MP3 player to computer it is shown with this name :)

![P20 Player_D2B](<players_pics/P20 Player_D2B.png>)

## Credits

Originally created by [fdd4s](https://github.com/fdd4s/)  
Send feedback and questions to fc1471789@gmail.com  

---

This powershell script and new .bat file created by [tomaz1](https://github.com/tomaz1/)  
Send feedback to okay-aside-late@duck.com

---
All script files are public domain https://unlicense.org/