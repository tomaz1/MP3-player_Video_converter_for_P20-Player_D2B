param (
    [string]$InputFile = "",
    [int]$CropAdjustPercent = 0,
    [int]$SplitMinutes = 0,
    [double]$SoundGain = 0.0,
    [switch]$ShowHelp
)

# Add and use variables for resolution 240x288 instead of hardcoded values !!!
$targetWidth = 288
$targetHeight = 240


if ($ShowHelp) {
    Write-Host ""
    Write-Host "Tomaz, 17.5.25, v1.3"
    Write-Host ""
    Write-Host "Usage: run-split.bat input_file [-cropadjust X] [-splitmin Y] [-soundgain Z.Z]"
    write-host "         (X = number in % from 0 to 100, Y = split video every Y minutes,"
    write-host "          Z.Z = dB gain is a number where . is the decimal separator)"
    Write-Host "Example:  run-split.bat video.avi -cropadjust 80 -splitmin 30"
    write-host "         #will do 80% adjustment to 6/5 aspect ratio and video will be split into pieces every 30 minutes)"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  input_file      Path to video file (required)"
    Write-Host "  cropadjust      0–100, how much to adjust aspect ratio (default 0) -"
    write-host "                  adding or removing black borders, to ideal device aspect ratio 6/5 (288x240)"
    Write-Host "  splitmin        Length of segments in minutes (default 0 = no splitting) - creates files: name-01.avi, name-02.avi, etc."
    write-host "  soundgain       Sound will be boosted/reduced by x.x dB (default 0.0) - Can also be a negative value, e.g. -2"
    exit 0
}

# Preverjanje, če je ffmpeg-mod.exe na voljo v trenutni mapi
if (-not (Test-Path -Path ".\ffmpeg-mod.exe")) {
    Write-Error "ffmpeg-mod.exe not found in the current directory. Please ensure it is present."
    exit 1
}


# Preverjanje InputFile
if (-not $InputFile -or -not (Test-Path -LiteralPath $InputFile)) {
    Write-Error "Input file is not specified or does not exist."
    exit 1
}

$baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$ext = "avi"

# Preverjanje CropAdjustPercent: mora biti integer med 0 in 100
#if ($CropAdjustPercent -notmatch '^\d+$' -or $CropAdjustPercent -lt 0 -or $CropAdjustPercent -gt 100) {
#    Write-Error "CropAdjustPercent mora biti celo število med 0 in 100, brez decimalnih vejic/pik ali črk."
#    exit 1
#}
Write-Host "CropAdjustPercent=$($CropAdjustPercent)"
Write-Host "SplitMinutes=$($SplitMinutes)"
Write-Host "SoundGain=$($SoundGain)"

# Preverjanje SplitMinutes: mora biti integer med 0 in 300
if ($SplitMinutes -notmatch '^\d+$' -or $SplitMinutes -lt 0 -or $SplitMinutes -gt 300) {
    Write-Error "SplitMinutes must be an integer between 0 and 300, without decimal points or letters."
    exit 1
}

# Izračunaj trajanje (v sekundah)
$durationInfo = & .\ffmpeg-mod.exe -i "$InputFile" 2>&1 | Select-String "Duration"
if ($durationInfo -match "Duration: (\d+):(\d+):(\d+)") {
    $hh = [int]$matches[1]
    $mm = [int]$matches[2]
    $ss = [int]$matches[3]
    $totalSeconds = $hh * 3600 + $mm * 60 + $ss
} else {
    Write-Error "Cannot read video duration."
    exit 1
}
#pridobimo video ločljivost original datoteke
$videoInfo = & .\ffmpeg-mod.exe -i "$InputFile" 2>&1 | Select-String "Stream.*Video"
if ($videoInfo -match "(\d{3,5})x(\d{3,5})") {
    $origW = [int]$matches[1]
    $origH = [int]$matches[2]
}

$fps=24 #nastavim za vsak slučaj, če ne bomo iz videa pridobili framerate, potem ne nižamo framerate
#framerate na napravi deluje preverjetno tudi z 50 fps!! Je pa npr 1minuta videa 14mb namesto 10mb, če je 25 fps. Torej ni obvezno zmanjševanje, ampak zgolj, če bi želel manjšo datoteko!
# Izločimo framerate (npr. 25 fps, 50 tbr, itd.)
if ($videoInfo -match "(\d+(?:\.\d+)?) fps") {
    $fps = [double]$matches[1]
    Write-Host "Framerate: $fps fps"
} else {
    Write-Warning "Framerate could not be determined."
}

Write-Host "Detected input video size: Width=${origW} and Height=${origH}."

# =====================
# BLACK BAR DETECTION (cropdetect)
# Rarely video has hardcoded black bars, but if it has, we can use cropdetect to find the active video area
# =====================

Write-Host "🔍 Detecting active video area using cropdetect ..."

$tempCropList = @()

# Poženi ffmpeg cropdetect za prvih (no 30sec kasneje) ~10 sekund (npr. 250 frame-ov)
& .\ffmpeg-mod.exe -ss 0:30:00 -t 10 -i "$InputFile" -vf cropdetect -frames:v 250 -an -f null - 2>&1 | ForEach-Object {
    if ($_ -match "crop=(\d+:\d+:\d+:\d+)") {
        $tempCropList += $matches[1]
    }
}

# Če najdemo vsaj nekaj cropov
if ($tempCropList.Count -gt 0) {
    # Najdi najpogostejši crop
    $mostCommonCrop = $tempCropList | Group-Object | Sort-Object Count -Descending | Select-Object -First 1 -ExpandProperty Name

    Write-Host "✅ Using detected crop area: $mostCommonCrop"

    # Razbij vrednosti
    $parts = $mostCommonCrop -split ":"
    $CropDetect_origW = [int]$parts[0]
    $CropDetect_origH = [int]$parts[1]
    $offsetX = [int]$parts[2]
    $offsetY = [int]$parts[3]
} else {
    Write-Warning "⚠️ Cropdetect could not find useful values. Using original width and height."
    $CropDetect_origW = $origW
    $CropDetect_origH = $origH
    $offsetX = 0
    $offsetY = 0
}

Write-Host "Detected Crop detect values: CropDetect_origW=$($CropDetect_origW), CropDetect_origH=$($CropDetect_origH), offsetX=$($offsetX) and offsetY=$($offsetY)"

# =====================  INTERPOLACIJA NA 6:5  =====================
    # ------- vhodne vrednosti ----------------------------------
    $p        = $CropAdjustPercent / 100.0          # 0–1
    $targetAR = $targetWidth / $targetHeight                               # 1.2 (6/5 je 288/240) - dodal vsaj to, če bo kdo res popravljal kodo 240x288, da bo popravil tudi tu

    # aktivna slika po cropdetect-u (odstranim staro črnino)
    $Wa = $CropDetect_origW
    $Ha = $CropDetect_origH
    $r  = [double]$Wa / $Ha

    # ------- skrajni točki  (LETTER ⇄ CROP) --------------------
    if ($r -ge $targetAR) {
        # slika je širša (ali točno 1.2)   – dodaj/poreži zgoraj‑spodaj
        $W_letter = $targetWidth
        $H_letter = [math]::Floor($W_letter / $r)  # < 240
        $H_crop   = $targetHeight
        $W_crop   = [math]::Ceiling($H_crop * $r)  # > 288
    } else {
        # slika je ožja – dodaj/poreži levo‑desno
        $H_letter = $targetHeight
        $W_letter = [math]::Floor($H_letter * $r)  # < 288
        $W_crop   = $targetWidth
        $H_crop   = [math]::Ceiling($W_crop / $r)  # > 240
    }

    # ------- linearna interpolacija dimenzij -------------------
    $W_int = [math]::Round((1-$p)*$W_letter + $p*$W_crop)
    $H_int = [math]::Round((1-$p)*$H_letter + $p*$H_crop)

    # zagotovimo sode številke (x264 zahteva)
    if ($W_int % 2) { $W_int-- }
    if ($H_int % 2) { $H_int-- }

    Write-Host "📏 Interpolation ($CropAdjustPercent %) : ${W_int}×${H_int}"

    # ------- gradnja filter‑chain --------------------------------
    $filters = @()
    # (1) odstranimo obstoječo črnino, če obstaja
    if (($Wa -ne $origW) -or ($Ha -ne $origH) -or $offsetX -ne 0 -or $offsetY -ne 0) {
        $filters += "crop=${Wa}:${Ha}:${offsetX}:${offsetY}"
    }
    # (2) scale na interpolirano velikost
    $filters += "scale=${W_int}:${H_int}:flags=lanczos"

    # (3) pad/crop da končno dobimo točno 288×240
    $padX = $targetWidth - $W_int
    $padY = $targetHeight - $H_int

    if ($padY -gt 0) {                # dodaj črnino zgoraj/spodaj
        $filters += "pad=${W_int}:${targetHeight}:0:$([math]::Floor($padY/2)):black"
    }
    elseif ($padY -lt 0) {            # odreži zgoraj/spodaj (center)
        $cropY = [math]::Floor((-1*$padY)/2)
        $filters += "crop=${W_int}:${targetHeight}:0:${cropY}"
    }

    if ($padX -gt 0) {                # dodaj črnino levo/desno
        $filters += "pad=${targetWidth}:${targetHeight}:$([math]::Floor($padX/2)):0:black"
    }
    elseif ($padX -lt 0) {            # odreži levo/desno (center)
        $cropX = [math]::Floor((-1*$padX)/2)
        $filters += "crop=${targetWidth}:${targetHeight}:${cropX}:0"
    }

    # (4) rotacija
    $filters += 'transpose=2'

    $vf = ($filters -join ',')

    #neobvezno zmanjšamo framerate (na čim bolj kvaliteten način, ne da skipamo frejme):
    if ($fps -gt 30) {
         #začasno izklopil, ker je počasnejša konverzija in ker imam dovolj prostora na SD kartici :)
         #$vf = "${vf},minterpolate=fps=24"
    }
    Write-Host "🎬 -vf ($CropAdjustPercent %) : $vf"

# ------------------ KONEC BLOKA --------------------------------


if ($SplitMinutes -eq 0) {

    $outFile = "{0}-p.{1}" -f $baseName, $ext
    #old: -vf "scale=-2:240:flags=lanczos,crop=288:240,transpose=2" `
    & .\ffmpeg-mod.exe -nostdin -y -fflags +genpts -avoid_negative_ts make_zero -vsync cfr `
        -i "$InputFile" -f avi `
        -vcodec libx264 -pix_fmt yuv420p `
        -g 14 -keyint_min 1 -sc_threshold 0 `
        -profile:v baseline -level 3.0 `
        -x264-params "imax=98304:pmax=65536:ipmax=163840:cabac=0:ref=1:scenecut=0:keyint=14:min-keyint=1:qp=22" `
        -vf $vf `
        -acodec pcm_s16le -ar 22050 -ac 2 -af "volume=$($SoundGain)dB" "$outFile"

} else {

    $segmentDuration = $SplitMinutes * 60
    for ($i = 0; $i -lt $totalSeconds; $i += $segmentDuration) {
        $outFile = "{0}-{1:D2}.{2}" -f $baseName, (($i / $segmentDuration)+1), $ext
        $start = [TimeSpan]::FromSeconds($i).ToString("hh\:mm\:ss")

        #old: -vf "scale=-2:240:flags=lanczos,crop=288:240,transpose=2" `
        & .\ffmpeg-mod.exe -nostdin -y -fflags +genpts -avoid_negative_ts make_zero -vsync cfr `
            -i "$InputFile" -ss $start -t $segmentDuration -f avi `
            -vcodec libx264 -pix_fmt yuv420p `
            -g 14 -keyint_min 1 -sc_threshold 0 `
            -profile:v baseline -level 3.0 `
            -x264-params "imax=98304:pmax=65536:ipmax=163840:cabac=0:ref=1:scenecut=0:keyint=14:min-keyint=1:qp=22" `
            -vf $vf `
            -acodec pcm_s16le -ar 22050 -ac 2 -af "volume=$($SoundGain)dB" "$outFile"
    }
}

#TODO:
#Currently, there is a bit of a problem when the full duration between one split and the next is set to a specific point to make the next split.
#How could we possibly improve this?

#Why didn't I use the one that makes splits faster:
#Add "-map 0 -segment_time 00:05:00 -f segment -reset_timestamps 1" before destination name, and "%02d" (fragment number) in the destination filename.
#
#e.g:
#ffmpeg-mod.exe -i source.mp4 -f avi -vcodec libx264 -vb 1500000 -r 14 -pix_fmt yuv420p -bufsize 25000k -maxrate 25000k -g 7 -refs 1 -qmin 18 -qmax 43 -profile:v baseline -x264-params imax=98304:pmax=65536:ipmax=163840 -vf "scale=-2:240, crop=288:240, transpose=2" -acodec pcm_s16le -ab 128k -ar 16000 -ac 1 -map 0 -segment_time 00:05:00 -f segment -reset_timestamps 1 dest%02d.avi
#The problem that arises after the above process is that often the first video does not work 01.avi, while the other videos work fine.

#Proposed solution:
#In my way, create the first "split" and name it 01_ok.avi
#use the faster method to create all splits
#finally delete 01.avi (which usually doesn't work) and rename 01_ok.avi to 01.avi

#TODO2:
# lower framerate e.g. from 50 to 24, to have a smaller file, because 24 is of course sufficient.
# I have already done it, it just needs to be added that the thing is called via a .bat parameter, which is then sent to .ps1 and taken into account :)
