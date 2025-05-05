@echo off

set INPUT=%1

ffmpeg-mod.exe -i "%INPUT%" -f avi -vcodec libx264 -vb 1500000 -r 14 -pix_fmt yuv420p -bufsize 25000k -maxrate 25000k -g 7 -refs 1 -qmin 18 -qmax 43 -profile:v baseline -x264-params imax=98304:pmax=65536:ipmax=163840 -vf "scale=-2:240, crop=320:240, transpose=2" -acodec pcm_s16le -ab 128k -ar 16000 -ac 1 "%~n1-p.avi"