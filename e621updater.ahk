;E621 updater v9.2
;by (Ayo)Keito
;Last modified 08.01.2017
#SingleInstance ignore
#Include md5.ahk
#Include json.ahk
#Include String-object-file.ahk
preqscheck=1
AllExt=0
FromPics=0
FromTags=0
FromFavs=0
FromSync=0
WantAnotherFolder=0
IfNotExist exiftool.exe
	MsgBox,16,Critical file missing, exiftool.exe is missing. `nMake sure you extract all the files.`nApp will now exit.
    ifMsgBox Ok
        ExitApp
IfNotExist curl.exe
    SyncAvailable=0
	else
	SyncAvailable=1
if A_IsCompiled
    Menu, Tray, Icon, %A_ScriptFullPath%, -159
IfExist e621updater.ini
{
IniRead, PCAwake, e621updater.ini, Options, PCAwake
if PCAwake=ERROR
    {
    PCAwake=1
	ES_AWAYMODE_REQUIRED:=0x00000040
	ES_CONTINUOUS:=0x80000000
	ES_SYSTEM_REQUIRED:=0x00000001
	DllCall("SetThreadExecutionState","UInt",ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_AWAYMODE_REQUIRED)
	}
if PCAwake=1
    {
	ES_AWAYMODE_REQUIRED:=0x00000040
	ES_CONTINUOUS:=0x80000000
	ES_SYSTEM_REQUIRED:=0x00000001
    DllCall("SetThreadExecutionState","UInt",ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_AWAYMODE_REQUIRED)
    }
}
GUIRESTART:
Gui, Destroy
Gui, New
Gui, -Resize +MinSize410x480 -MaximizeBox
GuiClose(GuiHwnd) {
    ;If GUI is closed, ask if user wants to exit.
    MsgBox 4,Exit?, Are you sure you want to close the program?
    ifMsgBox No
        return true  ; true = 1
	else 
	    FileDelete %WhichFolder%\ImagesList
		FileDelete *.json
		ExitApp
}
;Getting folder input
IfExist e621updater.ini
{
IniRead, WhichFolder, e621updater.ini, Main, Folder
if WhichFolder=ERROR
    {
    WantAnotherFolder=1
	FileSelectFolder, WhichFolder, *%LastFolder%,2,Select your images folder:
	}
else
	LastFolder=%WhichFolder%
}
SetBatchLines, -1  ; Make the operation run at maximum speed.
StringLen, dircheck, WhichFolder
if dircheck<2
{
MsgBox,64,No folder selected, No working path. Using program directory.,3
WhichFolder:=A_ScriptDir
}
IniWrite, %WhichFolder%, e621updater.ini, Main, Folder
FileDelete %WhichFolder%\ImagesList
;Creating windows
Gui, Show, xCenter yCenter w410 h480, E621 updater v9.2
Gui, Add, ListBox, Choose1 vMyListBox x10 y30 w390 r8
Gui, Add, ListView, vFavListBox x10 y317 w390 r5 Grid NoSortHdr, ID|Rating|Size (KB)|Status
GuiControl, Hide, FavListBox
Gui, Add, ListView, vUpdListBox x10 y317 w390 r4 Grid NoSortHdr, Local name|Extracted MD5|Status
GuiControl, Hide, UpdListBox
Gui, Add, ListView, vTagListBox x10 y317 w390 r4 Grid NoSortHdr, Local name|Status
GuiControl, Show, TagListBox
;Getting files from directory, building index FILE and BOX, counting images in this block:
ImagesCount=0
GuiControl, -Redraw, MyListBox
FFileList := Array()
if AllExt=1
{
Loop, Files, %WhichFolder%\*.*,
{
    if InStr(A_LoopFileName, ".jpg") || InStr(A_LoopFileName, ".jpeg") || InStr(A_LoopFileName, ".png") || InStr(A_LoopFileName, ".webm") || InStr(A_LoopFileName, ".swf") || InStr(A_LoopFileName, ".gif")
	    {
		if InStr(A_LoopFileName, ".swp")
		{
		trash=1
		goto failsafe
		}
            FFileList.Push(A_LoopFileName)
		    GuiControl,, MyListBox, %A_LoopFileName%
            ImagesCount += 1
			failsafe:
		}
}
}
else
{
Loop, Files, %WhichFolder%\*.*,
{
    if InStr(A_LoopFileName, ".jpg") || InStr(A_LoopFileName, ".jpeg") || InStr(A_LoopFileName, ".png")
	    {
		if InStr(A_LoopFileName, ".swp")
		{
		trash=1
		goto failsafe2
		}
            FFileList.Push(A_LoopFileName)
		    GuiControl,, MyListBox, %A_LoopFileName%
            ImagesCount += 1
			failsafe2:
		}
}
}
;Finished INDEX and BOX
;Emptying GUI variables
CounterTimeLeft=0
TimePerFile=0
TimeNow=
totalsize=0
FilesPassed=0
FilesLeft=0
TimeLeftEstimate=0
NotFoundImagesCount=0
OnePercent=0
seenWarning=0
WantPreview=0
RenameAfterMD5=0
Done=0
MakeBackups=1
MyProgress=0
progressfull=100
DisableNet=0
;Building GUI
GuiControl, +Redraw, MyListBox
Gui, Add, Text, x10 y10, Local files in %WhichFolder%:
Gui, Add, Text, x+5 w200, - %ImagesCount% images found.
Gui, Add, GroupBox, x8 y145 w130 h103, Mode
if FromTags=1
    Gui, Add, Radio, Checked gWantTags x10 y165 vTags, Tagger mode
if FromTags=0
    Gui, Add, Radio, gWantTags x10 y165 vTags, Tagger mode
if FromPics=1
    Gui, Add, Radio, Checked gWantPics x10 y185 vPictures, Updater mode
if FromPics=0
    Gui, Add, Radio, gWantPics x10 y185 vPictures, Updater mode
if FromFavs=1
    Gui, Add, Radio, Checked gWantFavs x10 y205 vFavs, Downloader mode
if FromFavs=0
    Gui, Add, Radio, gWantFavs x10 y205 vFavs, Downloader mode
If FromSync=1
    Gui, Add, Radio, Checked gWantSync x10 y225 vSync, Sync mode
If FromSync=0
    Gui, Add, Radio, gWantSync x10 y225 vSync, Sync mode
If SyncAvailable=0
    GuiControl, Disabled, Sync,
Gui, Add, GroupBox, x145 y145 w255 h80, Options
Gui, Add, Checkbox, x150 y165 vRemover, Force remove old tags (compatibility)
Gui, Add, Button, x150 y165 w76 Disabled Hidden, Get API
Gui, Add, Checkbox, x150 y165 Checked Hidden gRatingCheckbox vEx, E
Gui, Add, Checkbox, x180 y165 Checked Hidden gRatingCheckbox vQu, Q
Gui, Add, Checkbox, x210 y165 Hidden gRatingCheckbox vSa, S
;Backup checkbox
IniRead, MakeBackups, e621updater.ini, Options, MakeBackups
if MakeBackups=ERROR
    {
    MakeBackups=0
	IniWrite, 0, e621updater.ini, Options, MakeBackups
	Gui, Add, Checkbox, Hidden x150 y165 gWantBackups vMakeBackups, Backup old files
	}
else
    {
    MakeBackups=1
	Gui, Add, Checkbox, Hidden Checked x150 y165 gWantBackups vMakeBackups, Backup old files
	}
Gui, Add, Checkbox, x150 y185 vMD, Get MD5
;Network checks checkbox
IniRead, DisableNet, e621updater.ini, Options, NetworkChecksDisabled
if DisableNet=ERROR
    {
    DisableNet=0
	IniWrite, 0, e621updater.ini, Options, NetworkChecksDisabled
	Gui, Add, Checkbox, gDisableNetwork x220 y185 vDisableNet, Disable network checks
	}
else
    {
    DisableNet=1
	Gui, Add, Checkbox, Checked gDisableNetwork x220 y185 vDisableNet, Disable network checks
	}
Gui, Add, Checkbox, Hidden Checked x250 y205 vAlsoTag, Tag after downloading
Gui, Add, Checkbox, gWantShutdownAfter x150 y205 vShutdownAfter, Shutdown after
Gui, Add, Checkbox, Disabled gWantMoreInfo x250 y205 vMoreInfo, More information

Gui, Add, Button, x144 y225 w76 Disabled Default, Start
Gui, Add, Button, x220 y225 w125, Choose Another Folder
Gui, Add, Button, Disabled x345 w56 y225, Pause

Gui, Add, Text, x10 y255 w60, Name:
Gui, Add, Edit, gNameEntered x45 y252 w165 vSyncName, Enter your account name
GuiControl, Hide, Name:
GuiControl, Hide, SyncName
Gui, Add, Text, x10 y275 w60, Filename:
Gui, Add, Edit, gUsernameEntered ReadOnly w200 vArtistName, Filename will be displayed here.
Gui, Add, Text, x215 y255, Images processed:
Gui, Add, Edit, x310 y250 w90 Disabled vDone, 0/%ImagesCount%
Gui, Add, Text, x215 y275, Images not found:
Gui, Add, Edit, x310 y272 w90 Disabled vNotFoundImagesCount, 0/%ImagesCount%
Gui, Add, Text, x215 y295 w90, Network:
Gui, Add, Edit, x270 y294 w130 ReadOnly vNetStat, Awaiting start

Gui, Add, Text, x10 y417 w80, Time elapsed:
Gui, Add, Edit, ReadOnly x80 y415 w55 vTimer, 00:00:00
Gui, Add, Text, x250 y417 w120, Estimated time left:
Gui, Add, Edit, ReadOnly x345 y415 w55 vTimerLeft, 00:00:00

Gui, Add, Progress, x10 y437 w390 h20 BackgroundSilver cYellow vMyProgress,0
Gui, Add, StatusBar,, Waiting to start.
;info gui fav
Gui, Add, Picture, vPic x411 y32 h150 w-1,
Gui, Add, Text, x440 y97 w152, Only favorites mode
Gui, Add, GroupBox, x410 y25 w152 h159, Preview
Gui, Add, Checkbox, x410 y10 Checked gWantPreview vWantPreview, Enable previews
GuiControl, , WantPreview, 0
GuiControl, Disable, WantPreview
Gui, Add, Text, x410 y190 w152, Filename:
Gui, Add, Edit, ReadOnly x410 y205 w150 vLoopFavName,
Gui, Add, Text, x410 y230 w152, URL:
Gui, Add, Edit, ReadOnly x410 y245 w150 vLoopFavUrl,
Gui, Add, Text, x410 y270 w150, Artists:
Gui, Add, Text, x410 y270 w150, Score:
GuiControl, Hide, Favorites:
Gui, Add, Text, x410 y270 w150, Extracted MD5:
GuiControl, Hide, Extracted MD5:
Gui, Add, Edit, ReadOnly x410 y285 w150 vLoopFavCount,
Gui, Add, Text, x410 y310 w150, Tags:
Gui, Add, Text, x410 y310 w150, Favorites:
GuiControl, Hide, Score:
Gui, Add, Text, x410 y310 w150, Artist:
GuiControl, Hide, Artist:
Gui, Add, Edit, ReadOnly x410 y325 w150 h130 vLoopFavScore,
;Gui, Add, Text, x410 y270 w152, Author(s):
;Gui, Add, Edit, ReadOnly x410 y285 w150 vJsonArtistFinal,
SB_SetParts(350)
SB_SetText("Ready to start!")
SB_SetText("by Keito", 2, cBlue)
If ImagesCount=0 ;No images? WTF m8
    {
    GuiControl, Disabled, Start,
	SB_SetText("No files found!")
	}
if FromTags=1
    gosub, WantTags
if FromPics=1
	gosub, WantPics
if FromFavs=1
    gosub, WantFavs
If FromSync=1
	gosub, WantSync
Gui, Submit, NoHide
Gui, Show
FromPics=0
FromTags=0
FromFavs=0
FromSync=0
return
;Gui Finished
ButtonStart:
SB_SetText("Working...")
FormatTime, NowDate, , LongDate
FileAppend, %NowDate%`n, after_log.txt,UTF-16
if trash=1
{
FileAppend, %NowDate%: Unwanted SWP files detected. You may want to remove them.`n, after_log.txt,UTF-16
}
TimeStatus := A_Now
FormatTime, TimeStatus, , HH:mm:ss
FileAppend, %TimeStatus% : Proccess started`n, after_log.txt,UTF-16
TimeBegin := a_tickcount
Gui, Submit, NoHide
GuiControl, Enabled, Pause,
GuiControl, Disabled, Tags,
GuiControl, Disabled, Sync,
GuiControl, Disabled, Pictures,
GuiControl, Disabled, Remover,
GuiControl, Disabled, MD,
GuiControl, Disabled, Start,
GuiControl, Disabled, Favs,
GuiControl, Disabled, Choose Another Folder,
GuiControl, Disabled, ShutdownAfter,
MD5URL = http://e621.net/post/show.json?md5=
IDURL = http://e621.net/post/show.json?id=
FAVURL = https://e621.net/favorite/create.json?id=
if Tags = 1 ;User wants to tag images
{
FileAppend, %TimeStatus% : Tagging mode`n, after_log.txt,UTF-16
Gui, Listview, TagListBox
Loop % FFileList.Length()
{
LoopReadLine := FFileList[A_Index]
tempstorage=%LoopReadLine%
;Emptying variables
newname=
Filename= 
retriesmd=0
Retries=0
JsonContents=
JsonArtistFinal=
MS=1000
JsonTagsFinal=
extractedMD5=
;Done
StringTrimRight, Filename, tempstorage, 4 ;filename without extension goes to %Filename%
LV_Add(, tempstorage, "Searching...")
LV_ModifyCol(1, "AutoHdr")
LV_ModifyCol(2, "AutoHdr")
LV_Modify(A_Index, "Vis")
LV_Modify(A_Index, "Select")
GuiControl, Choose, MyListBox, %tempstorage%
WORKINGURL=%MD5URL%%Filename% ;Building URL
GuiControl, , LoopFavName, %tempstorage%
GuiControl, , LoopFavUrl, %WORKINGURL%
if MD=1
    {
	if seenWarning=0
	    {
	    seenWarning=1
	    MsgBox 35,Rename files to their MD5s?, Do you want to rename your files to their MD5 hashes? You won't be able to find and tag them next time if you press no.
        ifMsgBox Yes
	        {
            RenameAfterMD5=1
			Gui, Submit, NoHide
	    	}
	    ifMsgBox No
	        {
	        RenameAfterMD5=0
			Gui, Submit, NoHide
	    	}
	    ifMsgBox Cancel
	        {
	        gui, destroy
	        goto GUIRESTART
	    	}
	    }
	else
	IfExist %WhichFolder%\%Filename%.jpg
	{
		pathToMD5:= Format("{1}\{2}.jpg", WhichFolder, Filename)
	    extractedMD5:= % FileMD5( pathToMD5 )
		retriesmd=0
		StringReplace, extractedMD5, extractedMD5, %A_Space%,, All ; Removing " if multiple artists
		StringReplace, extractedMD5, extractedMD5, `r`n,, All ; Removing " if multiple artists
		newname=%WhichFolder%\%extractedMD5%
		StringReplace, newname, newname, `r`n,, All ; Removing " if multiple artists
		WORKINGURL=%MD5URL%%extractedMD5%
	}
    IfExist %WhichFolder%\%Filename%.jpeg
	{
		pathToMD5:= Format("{1}\{2}.jpeg", WhichFolder, Filename)
	    extractedMD5:= % FileMD5( pathToMD5 )
		retriesmd=0
		StringReplace, extractedMD5, extractedMD5, %A_Space%,, All ; Removing  if multiple artists
		StringReplace, extractedMD5, extractedMD5, `r`n,, All ; Removing " if multiple artists
		newname=%WhichFolder%\%extractedMD5%
		StringReplace, newname, newname, `r`n,, All ; Removing " if multiple artists
		WORKINGURL=%MD5URL%%extractedMD5%
	}
    IfExist %WhichFolder%\%Filename%.png
	{
		pathToMD5:= Format("{1}\{2}.png", WhichFolder, Filename)
	    extractedMD5:= % FileMD5( pathToMD5 )
		retriesmd=0
		StringReplace, extractedMD5, extractedMD5, %A_Space%,, All ; Removing " if multiple artists
		StringReplace, extractedMD5, extractedMD5, `r`n,, All ; Removing " if multiple artists
		newname=%WhichFolder%\%extractedMD5%
		StringReplace, newname, newname, `r`n,, All ; Removing " if multiple artists
		WORKINGURL=%MD5URL%%extractedMD5%
	}
	}
if DisableNet=0
{
	netfail:
	;Checking network in this block:
	FileDelete mainpage.json
	UrlDownloadToFile, http://e621.net/ , mainpage.json
	FileGetSize, JsonSize, mainpage.json ;If file is empty, net is not working
	IfNotExist, mainpage.json
	    JsonSize=0
	if (JsonSize<5)
	{
 	    GuiControl,, NetStat, No connection
 	    Gui, Font, cRed
 	    GuiControl, Font, NetStat
	    MsgBox,21,Connection error, 30 seconds timeout. Check your connection and press Retry to continue, 30 
		;Checks Failed, notification with 30s timeout
		IfMsgBox, Retry
            ;Manual selection of "Retry"
            goto netfail
        IfMsgBox Timeout
            ;Timed out - NOT retry. "Timeout" instead.
            if Retries<3 ;If timed out 3 times - going to hell
		    {
			Retries+= 1
			MsgBox,,Connection error, Connection problem. Trying again... Attempt number %Retries% out of 3, 5
			;Notifying possible user, keeping it automatic, 5s delay
        	TimeStatus := A_Now
        	FormatTime, TimeStatus, , HH:mm:ss
			FileAppend, %TimeStatus% : Connection lost. Retrying.`n, after_log.txt,UTF-16
			goto netfail
			}
			else 
			{
		    ;Hell starts there. Notifying user, PAUSING script.
		    GuiControl,, BackgroundRed MyProgress, %MyProgress%
		    TrayTip, Connection Error, Connection problem. Automatically paused., Seconds, 30
            TimeStatus := A_Now
            FormatTime, TimeStatus, , HH:mm:ss
			FileAppend, %TimeStatus% : Connection problem. Failed to recover. Automatically paused.`n, after_log.txt,UTF-16
		    MsgBox,21,Connection error, Connection problem. Automatically paused.
			IfMsgBox, Retry
			    goto netfail
			IfMsgBox, Cancel
				MsgBox,48,Connection error, Aborted by user
		        GuiControl,, BackgroundRed MyProgress, %MyProgress%
		        pause
			}
        IfMsgBox Cancel ;Manual selection of "Cancel"
        	;Notifying user, PAUSING script.
        	MsgBox,48,Connection error, Aborted by user
			GuiControl,, BackgroundRed MyProgress, %MyProgress%
			pause
	}
GuiControl,, NetStat, Online
Gui, Font, cGreen
GuiControl, Font, NetStat
}
FileDelete working.json
JsonSize=0
retriesmd=0
;Finished checking network.
retryaftermd:
StringReplace, WORKINGURL, WORKINGURL, `r`n,, All
UrlDownloadToFile, %WORKINGURL% , working.json
FileGetSize, JsonSize, working.json ;File exist checks
IfNotExist, working.json ;Internet is working but the JSON is empty - file not found, skipping:
    JsonSize=0
if JsonSize<5
{
	if (MD=1 and retriesmd=0)
	{
	    WORKINGURL=%MD5URL%%Filename%
	    StringReplace, WORKINGURL, WORKINGURL, `r`n,, All
	    retriesmd=1
	    goto retryaftermd
	}
	    GuiControl,, LoopFavCount, Image not found on e621
        GuiControl,, LoopFavScore, Image not found on e621
		LV_Modify(A_Index, , tempstorage, "Image not found")
	    LV_ModifyCol(1, "AutoHdr")
		LV_ModifyCol(2, "AutoHdr")
	    Done += 1
	    NotFoundImagesCount += 1
	    GuiControl,, Done, %Done%/%ImagesCount%
	    GuiControl,, NotFoundImagesCount, %NotFoundImagesCount%/%ImagesCount%
	    FileCreateDir, %WhichFolder%\NotFound
	    FileMove, %WhichFolder%\%tempstorage%, %WhichFolder%\NotFound, 1
	    OnePercent := ImagesCount / progressfull
        MyProgress := Done / OnePercent
        GuiControl,, MyProgress, %MyProgress%
	    goto NotFound
}
;Getting artist(s) in that block:
;Getting artists object from JSON
FileRead, JsonContents, working.json
jsonartists := JSON.Load(JsonContents)
jsonartists.JsonContents := Func("jsonartists_JsonContents")
JsonArtistsObject := jsonartists.JsonContents()
jsonartists_JsonContents(this) {
   return % this.artist
}
;Parsing object into string
MultipleArtistTemp := StrObj(JsonArtistsObject)
JsonArtistFinal := StrObj(JsonArtistsObject)
StringReplace, JsonArtistFinal, JsonArtistFinal, `r`n, , All
StringTrimRight, JsonArtistFinal, JsonArtistFinal, 1
StringReplace, JsonArtistFinal, JsonArtistFinal, conditional_dnp`,, , All ; Removing conditional_dnp from artists
StringReplace, JsonArtistFinal, JsonArtistFinal, avoid_posting`,, , All ; Removing avoid_posting from artists
StringReplace, JsonArtistFinal, JsonArtistFinal, unknown_artist`,, , All ; Removing unknown_artist from artists
GuiControl,, LoopFavCount, %JsonArtistFinal% ;Finished filtering. %JsonArtistFinal% finalised.
LV_Modify(A_Index, , tempstorage, "Image found, getting data")
LV_ModifyCol(1, "AutoHdr")
LV_ModifyCol(2, "AutoHdr")
;Finished getting artist(s).
;Getting tags in this block:
FileRead, JsonContents, working.json
jsontags := JSON.Load(JsonContents)
jsontags.JsonContents := Func("jsontags_JsonContents")
JsonTagsFinal := jsontags.JsonContents()
jsontags_JsonContents(this) {
   return % this.tags
}
StringReplace, JsonTagsFinal, JsonTagsFinal, %A_SPACE%, `,, All
GuiControl,, LoopFavScore, %JsonTagsFinal% ;%JsonTagsFinal% finalised.
LV_Modify(A_Index, , tempstorage, "Data loaded, tagging...")
LV_ModifyCol(1, "AutoHdr")
LV_ModifyCol(2, "AutoHdr")
;Finished getting tags.
;Remove existing tags
if remover=1
    {
    IfExist %WhichFolder%\%Filename%.jpg
        RunWait, exiftool.exe -api PNGEarlyXMP -all= %WhichFolder%\%Filename%.jpg -overwrite_original_in_place -q,,Hide,
    IfExist %WhichFolder%\%Filename%.jpeg
        RunWait, exiftool.exe -api PNGEarlyXMP -all= %WhichFolder%\%Filename%.jpeg -overwrite_original_in_place -q,,Hide,
    IfExist %WhichFolder%\%Filename%.png
        RunWait, exiftool.exe -api PNGEarlyXMP -all= %WhichFolder%\%Filename%.png -overwrite_original_in_place -q,,Hide,
	}
;Add tags
IfExist %WhichFolder%\%Filename%.jpg ; To JPG
{
	Run, exiftool.exe -api PNGEarlyXMP -sep `, -q -P -xmp-dc:subject="%JsonTagsFinal%" -xmp-dc:creator="%JsonArtistFinal%" %WhichFolder%\%Filename%.jpg -overwrite_original_in_place, ,Hide,
	if (RenameAfterMD5=1 and retriesmd=0)
	    {
	    FileMove, %WhichFolder%\%Filename%.jpg, %newname%.jpg, 1
		FileAppend, Renamed %WhichFolder%\%Filename%.jpg to %newname%.jpg`n, renamed_files.txt,UTF-16
		}
}
IfExist %WhichFolder%\%Filename%.jpeg ; To JPEG
{
	Run, exiftool.exe -api PNGEarlyXMP -sep `, -q -P -xmp-dc:subject="%JsonTagsFinal%" -xmp-dc:creator="%JsonArtistFinal%" %WhichFolder%\%Filename%.jpeg -overwrite_original_in_place, ,Hide,
	if (RenameAfterMD5=1 and retriesmd=0)
	    {
	    FileMove, %WhichFolder%\%Filename%.jpeg, %newname%.jpeg, 1
		FileAppend, Renamed %WhichFolder%\%Filename%.jpeg to %newname%.jpeg`n, renamed_files.txt,UTF-16
		}
}
IfExist %WhichFolder%\%Filename%.png ; To PNG
{
	Run, exiftool.exe -api PNGEarlyXMP -sep `, -q -P -xmp-dc:subject="%JsonTagsFinal%" -xmp-dc:creator="%JsonArtistFinal%" %WhichFolder%\%Filename%.png -overwrite_original_in_place, ,Hide,
	if (RenameAfterMD5=1 and retriesmd=0)
	    {
	    FileMove, %WhichFolder%\%Filename%.png, %newname%.png, 1
		FileAppend, Renamed %WhichFolder%\%Filename%.png to %newname%.png`n, renamed_files.txt,UTF-16
		}
}
Done += 1 ; Image done, preparing for the next one
GuiControl,, Done, %Done%/%ImagesCount%
SetFormat, Float, 0.4
OnePercent := ImagesCount / progressfull
MyProgress := (Done / OnePercent)
MyProgress:=Round(MyProgress)
GuiControl,, MyProgress, %MyProgress%
LV_Modify(A_Index, , tempstorage, "Tagged!")
NotFound: ; Going there if file wasn't found on e621. Going to pick another file from the loop.
;time counter!
LV_Modify(A_Index, "-Select")
SetFormat, Float, 1
TimeNow := A_TickCount - TimeBegin
TimeNow := TimeNow / MS
FormatSeconds(NumberOfSeconds)  ; Convert the specified number of seconds to hh:mm:ss format.
{
    time = 19990101  ; *Midnight* of an arbitrary date.
    time += %NumberOfSeconds%, seconds
    FormatTime, mmss, %time%, mm:ss
    return NumberOfSeconds//3600 ":" mmss
}
GuiControl,, Timer, % FormatSeconds(TimeNow)
TimePassed=0
TimePassed := % FormatSeconds(TimeNow)
;time counter ends!
;time left
FilesPassed += 1
FilesLeft := (ImagesCount - FilesPassed)
CounterTimeLeft=0
SetFormat, Float, 1
TimePerFile := (TimeNow / FilesPassed)
TimeLeftEstimate := (FilesLeft * TimePerFile)
FormatSecondsLeft(NumberOfSeconds)  ; Convert the specified number of seconds to hh:mm:ss format.
{
    time = 19990101  ; *Midnight* of an arbitrary date.
    time += %NumberOfSeconds%, seconds
    FormatTime, mmss, %time%, mm:ss
    return NumberOfSeconds//3600 ":" mmss
}
GuiControl,, TimerLeft, % FormatSecondsLeft(TimeLeftEstimate)
;time left ends
if setpause=1
    {
	MsgBox,64,Pause, Paused by user. Press OK to continue.
        ifMsgBox OK
            setpause=0
	}
}
TagsEnd:
Gui Flash ; No more files in loop. Finishing.
GuiControl,, cGreen MyProgress, %MyProgress%
FileDelete *.json
FileDelete %WhichFolder%\ImagesList
TimeStatus := A_Now
FormatTime, TimeStatus, , HH:mm:ss
FileAppend, %TimeStatus% : After %TimePassed%: %Done%/%ImagesCount% images processed. %NotFoundImagesCount% images not found`n, after_log.txt,UTF-16
DllCall("SetThreadExecutionState","UInt",ES_CONTINUOUS)
SB_SetText("Finished!")
if ShutdownAfter=1
    {
	FileAppend, %TimeStatus% : Shutting down.`n, after_log.txt,UTF-16
	Shutdown, 13
	}
MsgBox,36,Finished, Finished working. Wanna close this app now?
    ifMsgBox No
	{   
	    Gui, Destroy
        goto GUIRESTART
	}
	else ExitApp
}
else if Pictures = 1 ;User wants to update pictures.
{
FileAppend, %TimeStatus% : Tagging mode`n, after_log.txt,UTF-16
Gui, Listview, UpdListBox
Loop % FFileList.Length()
{
LoopReadLine := FFileList[A_Index]
tempstorage=%LoopReadLine%
;Emptying variables
Filename= 
Retries=0
JsonContents=
MS=1000
JsonArtistFinal=
pathToMD5=
JsonTagsParsed=
JsonTagsParsedLength=0
JsonTagsFinal=
extractedMD5=
;Done
StringTrimRight, Filename, tempstorage, 4 ;filename without extension goes to %Filename%
WORKINGURL=%MD5URL%%Filename% ;Building URL
GuiControl, , LoopFavName, %tempstorage%
GuiControl, , LoopFavUrl, %WORKINGURL%
LV_Add(, Filename, "N/A", "Checking...")
LV_ModifyCol(1, 120)
LV_ModifyCol(2, 70)
LV_ModifyCol(3, "AutoHdr")
LV_Modify(A_Index, "Vis")
LV_Modify(A_Index, "Select")
if DisableNet=0
{
	netfail2:
	;Checking network in this block:
	FileDelete mainpage.json
	UrlDownloadToFile, http://e621.net/ , mainpage.json
	FileGetSize, JsonSize, mainpage.json ;If file is empty, net is not working
	IfNotExist, mainpage.json
	    JsonSize=0
	if (JsonSize<5)
	{
 	    GuiControl,, NetStat, No connection
 	    Gui, Font, cRed
 	    GuiControl, Font, NetStat
	    MsgBox,21,Connection error, 30 seconds timeout. Check your connection and press Retry to continue, 30 
		;Checks Failed, notification with 30s timeout
		IfMsgBox, Retry
            ;Manual selection of "Retry"
            goto netfail2
        IfMsgBox Timeout
            ;Timed out - NOT retry. "Timeout" instead.
            if Retries<3 ;If timed out 3 times - going to hell
		    {
			Retries+= 1
			MsgBox,,Connection error, Connection problem. Trying again... Attempt number %Retries% out of 3, 5
			;Notifying possible user, keeping it automatic, 5s delay
        	TimeStatus := A_Now
        	FormatTime, TimeStatus, , HH:mm:ss
			FileAppend, %TimeStatus% : Connection lost. Retrying.`n, after_log.txt,UTF-16
			goto netfail2
			}
			else 
			{
		    ;Hell starts there. Notifying user, PAUSING script.
		    GuiControl,, BackgroundRed MyProgress, %MyProgress%
		    TrayTip, Connection Error, Connection problem. Automatically paused., Seconds, 30
            TimeStatus := A_Now
            FormatTime, TimeStatus, , HH:mm:ss
			FileAppend, %TimeStatus% : Connection problem. Failed to recover. Automatically paused.`n, after_log.txt,UTF-16
		    MsgBox,21,Connection error, Connection problem. Automatically paused.
			IfMsgBox, Retry
			    goto netfail2
			IfMsgBox, Cancel
				MsgBox,48,Connection error, Aborted by user
		        GuiControl,, BackgroundRed MyProgress, %MyProgress%
		        pause
			}
        IfMsgBox Cancel ;Manual selection of "Cancel"
        	;Notifying user, PAUSING script.
        	MsgBox,48,Connection error, Aborted by user
			GuiControl,, BackgroundRed MyProgress, %MyProgress%
			pause
	}
GuiControl,, NetStat, Online
Gui, Font, cGreen
GuiControl, Font, NetStat
}
if DisableNet=1
    GuiControl,, NetStat, Disabled
	GuiControl, Disabled, NetStat
FileDelete working.json
JsonSize=0
;Finished checking network.
StringReplace, WORKINGURL, WORKINGURL, `r`n,, All
UrlDownloadToFile, %WORKINGURL% , working.json
FileGetSize, JsonSize, working.json ;File exist checks
IfNotExist, working.json ;Internet is working but the JSON is empty - file not found, searching using MD5
    JsonSize=0
if (JsonSize<5)
    {
	GuiControl, , LoopFavCount, Image not found on e621
	IfExist %WhichFolder%\%Filename%.jpg
		pathToMD5:= Format("{1}\{2}.jpg", WhichFolder, Filename)
	    extractedMD5:= % FileMD5( pathToMD5 )
		StringReplace, extractedMD5, extractedMD5, `r`n,, All
		WORKINGURL=%MD5URL%%extractedMD5%
		UrlDownloadToFile, %WORKINGURL%, working.json ;Getting JSON for MD5
    IfExist %WhichFolder%\%Filename%.jpeg
		pathToMD5:= Format("{1}\{2}.jpeg", WhichFolder, Filename)
	    extractedMD5:= % FileMD5( pathToMD5 )
		StringReplace, extractedMD5, extractedMD5, `r`n,, All
		WORKINGURL=%MD5URL%%extractedMD5%
		UrlDownloadToFile, %WORKINGURL%, working.json
    IfExist %WhichFolder%\%Filename%.png
		pathToMD5:= Format("{1}\{2}.png", WhichFolder, Filename)
	    extractedMD5:= % FileMD5( pathToMD5 )
		StringReplace, extractedMD5, extractedMD5, `r`n,, All
		WORKINGURL=%MD5URL%%extractedMD5%
	UrlDownloadToFile, %WORKINGURL%, working.json
	FileGetSize, JsonSize, working.json
	LV_Modify(A_Index, , Filename, extractedMD5, "NA, using extracted MD5")
	IfNotExist, working.json ;Internet is working but the JSON is empty - file not found, skipping:
        JsonSize=0
	if JsonSize<5
	    {
		LV_Modify(A_Index, , Filename, extractedMD5, "Not found!")
	    Done += 1
	    GuiControl,, Done, %Done%/%ImagesCount%
	    OnePercent := ImagesCount / progressfull
        MyProgress := Done / OnePercent
        GuiControl,, MyProgress, %MyProgress%
        goto NotFound2
	    }
	LV_Modify(A_Index, , Filename, extractedMD5, "Found using extracted MD5!")
    goto foundbymd5
	}
foundbymd5:
;Found file using MD5
;Getting image status
GuiControl, , LoopFavScore, %extractedMD5%
FileRead, JsonContents, working.json
StringReplace, JsonContents, JsonContents, invalid URL, , All
jsonstatus := JSON.Load(JsonContents)
jsonstatus.JsonContents := Func("jsonstatus_JsonContents")
JsonFileStatus := jsonstatus.JsonContents()
jsonstatus_JsonContents(this) {
   return % this.status
}
;if status is "deleted"
if JsonFileStatus=deleted
    {
	LV_Modify(A_Index, , Filename, extractedMD5, "Removed from e621. Getting reason...")
	FileRead, JsonContents, working.json
	GuiControl, , LoopFavName, %tempstorage%
    GuiControl, , LoopFavUrl, %WORKINGURL%
	StringReplace, JsonContents, JsonContents, invalid URL, , All
	jsonreason := JSON.Load(JsonContents)
	jsonreason.JsonContents := Func("jsonreason_JsonContents")
	JsonDeleteReason := jsonreason.JsonContents()
	jsonreason_JsonContents(this) {
    return % this.delreason
    }
	IfInString, JsonDeleteReason, takedown ;If deleted with "takedown" in reason
	{
	    LV_Modify(A_Index, , Filename, extractedMD5, "Removed - takedown")
		Done += 1
	    GuiControl,, Done, %Done%/%ImagesCount%
	    OnePercent := ImagesCount / progressfull
        MyProgress := Done / OnePercent
        GuiControl,, MyProgress, %MyProgress%
	    goto NotFound2
	}
	else
	    IfNotInString, JsonDeleteReason, takedown ;If deleted with NO "takedown" in reason
		{
			LV_Modify(A_Index, , Filename, extractedMD5, "Searching for parents")
			FileRead, JsonContents, working.json
			StringReplace, JsonContents, JsonContents, invalid URL, , All
			jsonid := JSON.Load(JsonContents)
			jsonid.JsonContents := Func("jsonid_JsonContents")
			ParentID := jsonid.JsonContents()
			jsonid_JsonContents(this) {
    		return % this.parent_id
		    }
			LV_Modify(A_Index, , Filename, extractedMD5, "Parent post found!")
			WORKINGURL=%IDURL%%ParentID%
			GuiControl, , LoopFavUrl, %WORKINGURL%
			UrlDownloadToFile, %WORKINGURL%, working.json
			FileRead, JsonContents, working.json
			StringReplace, JsonContents, JsonContents, invalid URL, , All
			jsonstatus2 := JSON.Load(JsonContents)
			jsonstatus2.JsonContents := Func("jsonstatus2_JsonContents")
			JsonFileStatus2 := jsonstatus2.JsonContents()
			jsonstatus2_JsonContents(this) {
    		return % this.status
		    }
			IfInString, JsonFileStatus2, active ;If parent is ACTIVE we're downloading it
			{
				FileRead, JsonContents, working.json
				StringReplace, JsonContents, JsonContents, invalid URL, , All
				LV_Modify(A_Index, , Filename, extractedMD5, "File updated.")
				FileRead, JsonContents, working.json
				StringReplace, JsonContents, JsonContents, invalid URL, , All
	            JsonNewFileUrl := JSON.Load(JsonContents)
			    JsonNewFileUrl.JsonContents := Func("JsonNewFileUrl_JsonContents")
			    FileURL := JsonNewFileUrl.JsonContents()
			    JsonNewFileUrl_JsonContents(this) {
    		    return % this.file_url
		        }
				JsonNewFileMD5 := JSON.Load(JsonContents)
			    JsonNewFileMD5.JsonContents := Func("JsonNewFileMD5_JsonContents")
			    NewFileMD5 := JsonNewFileMD5.JsonContents()
			    JsonNewFileMD5_JsonContents(this) {
    		    return % this.md5
		        }
				JsonNewFileExt := JSON.Load(JsonContents)
			    JsonNewFileExt.JsonContents := Func("JsonNewFileExt_JsonContents")
			    NewFileExt := JsonNewFileExt.JsonContents()
			    JsonNewFileExt_JsonContents(this) {
    		    return % this.file_ext
		        }
				DownloadedFilename=%NewFileMD5%.%NewFileExt%
				UrlDownloadToFile, %FileURL%, %WhichFolder%\%DownloadedFilename%
				NotFoundImagesCount += 1
				if MakeBackups=1
				    {		
                    FileCreateDir, %WhichFolder%\Backup			
					FileMove, %WhichFolder%\%tempstorage%, %WhichFolder%\Backup\%tempstorage%, 1
					}
	    	    GuiControl,, NotFoundImagesCount, %NotFoundImagesCount%/%ImagesCount%
				if AlsoTag=1
				{
				WORKINGURL=%MD5URL%%NewFileMD5%
				GuiControl, , LoopFavUrl, %WORKINGURL%
				StringReplace, WORKINGURL, WORKINGURL, `r`n,, All
				UrlDownloadToFile, %WORKINGURL% , working.json
				;Getting artists object from JSON
				FileRead, JsonContents, working.json
				jsonartistsupd := JSON.Load(JsonContents)
				jsonartistsupd.JsonContents := Func("jsonartistsupd_JsonContents")
				JsonArtistsObject := jsonartistsupd.JsonContents()
				jsonartistsupd_JsonContents(this) {
				   return % this.artist
				}
				;Parsing object into string
				MultipleArtistTemp := StrObj(JsonArtistsObject)
				JsonArtistFinal := StrObj(JsonArtistsObject)
				StringReplace, JsonArtistFinal, JsonArtistFinal, `r`n, , All
				StringTrimRight, JsonArtistFinal, JsonArtistFinal, 1
				StringReplace, JsonArtistFinal, JsonArtistFinal, conditional_dnp`,, , All ; Removing conditional_dnp from artists
				StringReplace, JsonArtistFinal, JsonArtistFinal, avoid_posting`,, , All ; Removing avoid_posting from artists
				StringReplace, JsonArtistFinal, JsonArtistFinal, unknown_artist`,, , All ; Removing unknown_artist from artists
				;Finished getting artist(s).
				GuiControl, , LoopFavCount, %JsonArtistFinal%
				;Getting tags in this block:
				FileRead, JsonContents, working.json
				jsontagsupd := JSON.Load(JsonContents)
				jsontagsupd.JsonContents := Func("jsontagsupd_JsonContents")
				JsonTagsObject := jsontagsupd.JsonContents()
				jsontagsupd_JsonContents(this) {
				   return % this.tags
				}
				StringReplace, JsonTagsObject, JsonTagsObject, %A_SPACE%, `,, All
				;Finished getting tags.
				Run, exiftool.exe -api PNGEarlyXMP -sep `, -q -P -xmp-dc:subject="%JsonTagsObject%" -xmp-dc:creator="%JsonArtistFinal%" %WhichFolder%\%DownloadedFilename% -overwrite_original_in_place, ,Hide,
				}
			}
			else ;If it's not active, it means it's probably deleted forever. I'm too lazy to go deeper.
			{
			    LV_Modify(A_Index, , Filename, extractedMD5, "No parents found. Skipped.")
			    Done += 1
	    	    GuiControl,, Done, %Done%/%ImagesCount%
	    	    OnePercent := ImagesCount / progressfull
        	    MyProgress := Done / OnePercent
        	    GuiControl,, MyProgress, %MyProgress%
	   		    goto NotFound2
			}	
		}
		else
		    {
			LV_Modify(A_Index, , Filename, extractedMD5, "Unknown reason. Skipped.")
			Done += 1
	    	GuiControl,, Done, %Done%/%ImagesCount%
	 	    OnePercent := ImagesCount / progressfull
       	    MyProgress := Done / OnePercent
       	    GuiControl,, MyProgress, %MyProgress%
		    goto NotFound2
		    }
	}
else
{
LV_Modify(A_Index, , Filename, "N/A", "File exists on server. Skipped.")
}
Done += 1 ; Image done, preparing for the next one
GuiControl,, Done, %Done%/%ImagesCount%
SetFormat, Float, 0.4
OnePercent := (ImagesCount / progressfull)
MyProgress := (Done / OnePercent)
MyProgress:=Round(MyProgress)
GuiControl,, MyProgress, %MyProgress%
NotFound2: ; Going there if file wasn't found on e621. Going to pick another file from the loop.
;time counter!
LV_Modify(A_Index, "-Select")
extractedMD5="N/A"
SetFormat, Float, 1
TimeNow := A_TickCount - TimeBegin
TimeNow := TimeNow / MS
FormatSec0nds(NumberOfSeconds)  ; Convert the specified number of seconds to hh:mm:ss format.
{
    time = 19990101  ; *Midnight* of an arbitrary date.
    time += %NumberOfSeconds%, seconds
    FormatTime, mmss, %time%, mm:ss
    return NumberOfSeconds//3600 ":" mmss
}
TimePassed=0
TimePassed := % FormatSec0nds(TimeNow)
GuiControl,, Timer, % FormatSec0nds(TimeNow)
;time counter ends!
;time left
FilesPassed += 1
FilesLeft := (ImagesCount - FilesPassed)
CounterTimeLeft=0
SetFormat, Float, 1
TimePerFile := (TimeNow / FilesPassed)
TimeLeftEstimate := (FilesLeft * TimePerFile)
FormatSec0ndsLeft(NumberOfSeconds)  ; Convert the specified number of seconds to hh:mm:ss format.
{
    time = 19990101  ; *Midnight* of an arbitrary date.
    time += %NumberOfSeconds%, seconds
    FormatTime, mmss, %time%, mm:ss
    return NumberOfSeconds//3600 ":" mmss
}
GuiControl,, TimerLeft, % FormatSec0ndsLeft(TimeLeftEstimate)
;time left ends
if setpause=1
    {
	MsgBox,64,Pause, Paused by user. Press OK to continue.
        ifMsgBox OK
            setpause=0
	}
}
PicturesEnd:
GuiControl,, cGreen MyProgress, %MyProgress%
FileDelete *.json
FileDelete %WhichFolder%\ImagesList
TimeStatus := A_Now
FormatTime, TimeStatus, , HH:mm:ss
FileAppend, %TimeStatus% : After %TimePassed%: %Done%/%ImagesCount% images processed. %NotFoundImagesCount% images updated`n, after_log.txt,UTF-16
DllCall("SetThreadExecutionState","UInt",ES_CONTINUOUS)
SB_SetText("Finished!")
if ShutdownAfter=1
    {
	FileAppend, %TimeStatus% : Shutting down.`n, after_log.txt,UTF-16
	Shutdown, 13
	}
MsgBox,36,Finished, Finished working. Wanna close this app now?
    ifMsgBox No
	{
	    Gui, Destroy
        goto GUIRESTART
	}
	else ExitApp
}
else if Sync = 1 ;User wants to update pictures.
{
FileAppend, %TimeStatus% : Sync mode`n, after_log.txt,UTF-16
Gui, Listview, UpdListBox
Loop % FFileList.Length()
{
LoopReadLine := FFileList[A_Index]
tempstorage=%LoopReadLine%
;Emptying variables
Filename= 
Retries=0
JsonContents=
MS=1000
JsonArtistFinal=
pathToMD5=
JsonTagsParsed=
JsonTagsParsedLength=0
JsonTagsFinal=
extractedMD5=
;Done
StringTrimRight, Filename, tempstorage, 4 ;filename without extension goes to %Filename%
IfInString, Filename, .
    StringReplace, Filename, Filename, .,, All
WORKINGURL=%MD5URL%%Filename% ;Building URL
GuiControl, , LoopFavName, %tempstorage%
GuiControl, , LoopFavUrl, %WORKINGURL%
GuiControl, +ReadOnly, ArtistName
GuiControl, +ReadOnly, SyncName
IniWrite, %SyncName%, e621updater.ini, Downloader, Username
IniWrite, %ArtistName%, e621updater.ini, Downloader, API
LV_Add(, Filename, "N/A", "Checking...")
LV_ModifyCol(1, 120)
LV_ModifyCol(2, 70)
LV_ModifyCol(3, "AutoHdr")
LV_Modify(A_Index, "Vis")
LV_Modify(A_Index, "Select")
GuiControl,, NetStat, Online
Gui, Font, cGreen
GuiControl, Font, NetStat
FileDelete working.json
JsonSize=0
;Finished checking network.
StringReplace, WORKINGURL, WORKINGURL, `r`n,, All
UrlDownloadToFile, %WORKINGURL% , working.json
FileGetSize, JsonSize, working.json ;File exist checks
IfNotExist, working.json ;Internet is working but the JSON is empty - file not found, searching using MD5
    JsonSize=0
if (JsonSize<5)
    {
	GuiControl, , LoopFavCount, Image not found on e621
	IfExist %WhichFolder%\%Filename%.jpg
		pathToMD5:= Format("{1}\{2}.jpg", WhichFolder, Filename)
	    extractedMD5:= % FileMD5( pathToMD5 )
		StringReplace, extractedMD5, extractedMD5, `r`n,, All
		WORKINGURL=%MD5URL%%extractedMD5%
		UrlDownloadToFile, %WORKINGURL%, working.json ;Getting JSON for MD5
    IfExist %WhichFolder%\%Filename%.jpeg
		pathToMD5:= Format("{1}\{2}.jpeg", WhichFolder, Filename)
	    extractedMD5:= % FileMD5( pathToMD5 )
		StringReplace, extractedMD5, extractedMD5, `r`n,, All
		WORKINGURL=%MD5URL%%extractedMD5%
		UrlDownloadToFile, %WORKINGURL%, working.json
    IfExist %WhichFolder%\%Filename%.png
		pathToMD5:= Format("{1}\{2}.png", WhichFolder, Filename)
	    extractedMD5:= % FileMD5( pathToMD5 )
		StringReplace, extractedMD5, extractedMD5, `r`n,, All
		WORKINGURL=%MD5URL%%extractedMD5%
	    UrlDownloadToFile, %WORKINGURL%, working.json
    IfExist %WhichFolder%\%Filename%.swf
		pathToMD5:= Format("{1}\{2}.swf", WhichFolder, Filename)
	    extractedMD5:= % FileMD5( pathToMD5 )
		StringReplace, extractedMD5, extractedMD5, `r`n,, All
		WORKINGURL=%MD5URL%%extractedMD5%
	    UrlDownloadToFile, %WORKINGURL%, working.json
    IfExist %WhichFolder%\%Filename%.webm
		pathToMD5:= Format("{1}\{2}.webm", WhichFolder, Filename)
	    extractedMD5:= % FileMD5( pathToMD5 )
		StringReplace, extractedMD5, extractedMD5, `r`n,, All
		WORKINGURL=%MD5URL%%extractedMD5%
	    UrlDownloadToFile, %WORKINGURL%, working.json
	FileGetSize, JsonSize, working.json
	LV_Modify(A_Index, , Filename, extractedMD5, "NA, using extracted MD5")
	IfNotExist, working.json ;Internet is working but the JSON is empty - file not found, skipping:
        JsonSize=0
	if JsonSize<5
	    {
		LV_Modify(A_Index, , Filename, extractedMD5, "Not found!")
	    Done += 1
	    GuiControl,, Done, %Done%/%ImagesCount%
	    OnePercent := ImagesCount / progressfull
        MyProgress := Done / OnePercent
        GuiControl,, MyProgress, %MyProgress%
		NotFoundImagesCount += 1
		GuiControl,, NotFoundImagesCount, %NotFoundImagesCount%
        goto NotFound22
	    }
	LV_Modify(A_Index, , Filename, extractedMD5, "Found using extracted MD5!")
    goto foundbymd52
	}
foundbymd52:
;Found file using MD5
;Getting image status
GuiControl, , LoopFavScore, %extractedMD5%
FileRead, JsonContents, working.json
StringReplace, JsonContents, JsonContents, invalid URL, , All
jsonstatusid := JSON.Load(JsonContents)
jsonstatusid.JsonContents := Func("jsonstatusid_JsonContents")
JsonFileStatusId := jsonstatusid.JsonContents()
jsonstatusid_JsonContents(this) {
   return % this.id
}
Run, curl.exe -k -d login=%SyncName% -d password_hash=%ArtistName% -d id=%JsonFileStatusId% https://e621.net/favorite/create.json,,Hide,
LV_Modify(A_Index, , Filename, extractedMD5, "Post found and favorited!")
Done += 1 ; Image done, preparing for the next one
GuiControl,, Done, %Done%/%ImagesCount%
SetFormat, Float, 0.4
OnePercent := (ImagesCount / progressfull)
MyProgress := (Done / OnePercent)
MyProgress:=Round(MyProgress)
GuiControl,, MyProgress, %MyProgress%
NotFound22: ; Going there if file wasn't found on e621. Going to pick another file from the loop.
;time counter!
LV_Modify(A_Index, "-Select")
extractedMD5="N/A"
SetFormat, Float, 1
TimeNow := A_TickCount - TimeBegin
TimeNow := TimeNow / MS
FormatSec0nds1(NumberOfSeconds)  ; Convert the specified number of seconds to hh:mm:ss format.
{
    time = 19990101  ; *Midnight* of an arbitrary date.
    time += %NumberOfSeconds%, seconds
    FormatTime, mmss, %time%, mm:ss
    return NumberOfSeconds//3600 ":" mmss
}
TimePassed=0
TimePassed := % FormatSec0nds1(TimeNow)
GuiControl,, Timer, % FormatSec0nds1(TimeNow)
;time counter ends!
;time left
FilesPassed += 1
FilesLeft := (ImagesCount - FilesPassed)
CounterTimeLeft=0
SetFormat, Float, 1
TimePerFile := (TimeNow / FilesPassed)
TimeLeftEstimate := (FilesLeft * TimePerFile)
FormatSec0ndsLeft1(NumberOfSeconds)  ; Convert the specified number of seconds to hh:mm:ss format.
{
    time = 19990101  ; *Midnight* of an arbitrary date.
    time += %NumberOfSeconds%, seconds
    FormatTime, mmss, %time%, mm:ss
    return NumberOfSeconds//3600 ":" mmss
}
GuiControl,, TimerLeft, % FormatSec0ndsLeft1(TimeLeftEstimate)
;time left ends
if setpause=1
    {
	MsgBox,64,Pause, Paused by user. Press OK to continue.
        ifMsgBox OK
            setpause=0
	}
}
GuiControl,, cGreen MyProgress, %MyProgress%
FileDelete *.json
FileDelete %WhichFolder%\ImagesList
TimeStatus := A_Now
FormatTime, TimeStatus, , HH:mm:ss
FileAppend, %TimeStatus% : After %TimePassed%: %Done%/%ImagesCount% images processed.`n, after_log.txt,UTF-16
DllCall("SetThreadExecutionState","UInt",ES_CONTINUOUS)
SB_SetText("Finished!")
if ShutdownAfter=1
    {
	FileAppend, %TimeStatus% : Shutting down.`n, after_log.txt,UTF-16
	Shutdown, 13
	}
MsgBox,36,Finished, Finished working. Wanna close this app now?
    ifMsgBox No
	{
	    Gui, Destroy
        goto GUIRESTART
	}
	else ExitApp
}
else if Favs = 1 ;User wants to download favorites
{
FileAppend, %TimeStatus% : Favorites download mode`n, after_log.txt,UTF-16
Gui, Listview, FavListBox
;Emptying variables
Filename= 
Retries=0
JsonContents=
MS=1000
JsonArtistFinal=
JsonTagsParsed=
JsonTagsParsedLength=0
JsonTagsFinal=
extractedMD5=
page = 0
DownloaderIndex = 0
LoopFavCount = 0
LoopFavScore = 0
NotFoundImagesCount = 0
ExistFiles = 0
q = 100
totalsize = 0
filesize = 0
favcheck = 0
filerating = 
IDURL = http://e621.net/post/show.json?id=
favfileurls := Object()
favfileratings := Object()
favfilenamesfull := Object()
favtagslist := Object()
favartistslist := Object()
favids := Object()
favprevs := Object()
favfilesize := Object()
favfavcount := Object()
favscore := Object()
MultipleTagsTemp =
JsonTagsFinal =
GuiControl, +ReadOnly, ArtistName,
IniWrite, %ArtistName%, e621updater.ini, Downloader, Username
SB_SetText("Getting favorites list from e621. Wait.")
FavoritesCycle:
page += 1
url := Format("https://e621.net/post/index.json?limit={1}&tags=fav:{2}&page={3}", q, ArtistName, page)
UrlDownloadToFile, % url, favorites.json
FileGetSize, JsonSize, favorites.json
IfNotExist, favorites.json
	JsonSize=0
if (JsonSize<5)
    goto FavoritesAll
FileRead, favorites, favorites.json
result := JSON.Load(favorites)
Loop,  % q
{
filerating = % result[A_Index].rating
IF Ex=0
{
    If filerating=e
    {
        goto SkipFileFav
    }
}
IF Qu=0
{
    IF filerating=q
    {
        goto SkipFileFav
    }
}
IF Sa=0
{
    IF filerating=s
    {
        goto SkipFileFav
    }
}
	favfilename = % result[A_Index].md5
	favfileres = % result[A_Index].file_ext
	favfilenamefull=%favfilename%.%favfileres%
	StringLen, favcheck, favfilenamefull
	if favcheck>2
	{
	    IfExist %WhichFolder%\%favfilenamefull%
	        {
	        Done += 1
	        NotFoundImagesCount += 1
			ExistFiles += 1
			GuiControl,, NetStat, %ExistFiles%
	        GuiControl,, Done, %Done%
	        GuiControl,, NotFoundImagesCount, %NotFoundImagesCount%
		    }
	    else
	        {
	        favfileurls.Insert(result[A_Index].file_url)
		    favfilenamesfull.InsertAt(favfilenamesfull.Length() + 1, favfilenamefull)
			favids.Insert(result[A_Index].id)
			favfileratings.Insert(result[A_Index].rating)
			;favfilesize.Insert(result[A_Index].file_size)
			onefilessize:= (result[A_Index].file_size / 1024)
            onefilessize:=Round(onefilessize)
			favfilesize.InsertAt(favfilesize.Length() + 1, onefilessize)
			filesize = % result[A_Index].file_size
			totalsize += %filesize%
			favfavcount.Insert(result[A_Index].fav_count)
			favscore.Insert(result[A_Index].score)
			if WantPreview=1
			{
			favprevs.Insert(result[A_Index].preview_url)
			}
			if AlsoTag=1
			{
			favtagslist.Insert(result[A_Index].tags)
			favartistslist.Insert(result[A_Index].artist)
			}
		    GuiControl,, FavListBox, % result[A_Index].file_url
	        Done += 1
	        GuiControl,, Done, %Done%
	        }
	}
    else goto FavoritesAll
SkipFileFav:
}
goto FavoritesCycle
FavoritesAll:
filessize:= (totalsize / 1048576)
filessize:=Round(filessize)
GuiControl, , - Waiting for data, - %filessize% MB to download
SB_SetText("Downloading favorites.")
Loop % favfileurls.Length()
{
;Gui, Add, ListView, vFavListBox x10 y317 h100 w390 r5 Grid NoSortHdr, MD5|Rating|Author|Size
LoopFavID := favids[A_Index]
LoopFavRating := favfileratings[A_Index]
LoopFavSize := favfilesize[A_Index]
LoopFavUrl := favfileurls[A_Index]
LoopFavName := favfilenamesfull[A_Index]
GuiControl, , LoopFavName, %LoopFavName%
GuiControl, , LoopFavUrl, %LoopFavUrl%
LoopFavCount := favfavcount[A_Index]
LoopFavScore := favscore[A_Index]
LoopFavPreview := favprevs[A_Index]
WORKINGURL=%IDURL%%LoopFavID% ;Building URL
GuiControl, , LoopFavCount, %LoopFavCount%
GuiControl, , LoopFavScore, %LoopFavScore%
if WantPreview=1
{
UrlDownloadToFile, %LoopFavPreview%, %A_Temp%\%LoopFavName%
GuiControl,, Pic, %A_Temp%\%LoopFavName%
}
LV_Add(, LoopFavID, LoopFavRating, LoopFavSize, "Downloading...")
LV_ModifyCol(1, "AutoHdr")
LV_ModifyCol(2, "AutoHdr")
LV_ModifyCol(3, "AutoHdr")
LV_Modify(A_Index, "Vis")
LV_Modify(A_Index, "Select")
UrlDownloadToFile, %LoopFavUrl%, %WhichFolder%\%LoopFavName%
NotFoundImagesCount += 1
GuiControl,, NotFoundImagesCount, %NotFoundImagesCount%
LV_Modify(A_Index, , LoopFavID, LoopFavRating, LoopFavSize, "Saved")
if AlsoTag=1
{
LV_Modify(A_Index, , LoopFavID, LoopFavRating, LoopFavSize, "Saved. Tagging...")
StringReplace, WORKINGURL, WORKINGURL, `r`n,, All
UrlDownloadToFile, %WORKINGURL% , working.json
;Getting artists object from JSON
FileRead, JsonContents, working.json
jsonartistsfav := JSON.Load(JsonContents)
jsonartistsfav.JsonContents := Func("jsonartistsfav_JsonContents")
JsonArtistsObject := jsonartistsfav.JsonContents()
jsonartistsfav_JsonContents(this) {
   return % this.artist
}
;Parsing object into string
MultipleArtistTemp := StrObj(JsonArtistsObject)
JsonArtistFinal := StrObj(JsonArtistsObject)
StringReplace, JsonArtistFinal, JsonArtistFinal, `r`n, , All
StringTrimRight, JsonArtistFinal, JsonArtistFinal, 1
StringReplace, JsonArtistFinal, JsonArtistFinal, conditional_dnp`,, , All ; Removing conditional_dnp from artists
StringReplace, JsonArtistFinal, JsonArtistFinal, avoid_posting`,, , All ; Removing avoid_posting from artists
StringReplace, JsonArtistFinal, JsonArtistFinal, unknown_artist`,, , All ; Removing unknown_artist from artists
;Finished getting artist(s).
GuiControl, , JsonArtistFinal, %JsonArtistFinal%
;Getting tags in this block:
FileRead, JsonContents, working.json
jsontagsfav := JSON.Load(JsonContents)
jsontagsfav.JsonContents := Func("jsontagsfav_JsonContents")
JsonTagsObject := jsontagsfav.JsonContents()
jsontagsfav_JsonContents(this) {
   return % this.tags
}
StringReplace, JsonTagsObject, JsonTagsObject, %A_SPACE%, `,, All
;Finished getting tags.
Run, exiftool.exe -api PNGEarlyXMP -sep `, -q -P -xmp-dc:subject="%JsonTagsObject%" -xmp-dc:creator="%JsonArtistFinal%" %WhichFolder%\%LoopFavName% -overwrite_original_in_place, ,Hide,
LV_Modify(A_Index, , LoopFavID, LoopFavRating, LoopFavSize, "Saved & tagged")
LV_ModifyCol(4, "AutoHdr")
}
GuiControl,, Pic,
FileDelete %A_Temp%\%LoopFavName%
if setpause=1
    {
	MsgBox,64,Pause, Paused by user. Press OK to continue.
        ifMsgBox OK
            setpause=0
	}
LV_Modify(A_Index, "-Select")
SetFormat, Float, 0.4
OnePercent := (Done / progressfull)
MyProgress := (NotFoundImagesCount / OnePercent)
MyProgress:=Round(MyProgress)
GuiControl,, MyProgress, %MyProgress%
SetFormat, Float, 1
GuiControl, , Filename: %LoopFavName%, Filename:
}
FavsEnd:
Gui Flash ; No more files in loop. Finishing.
GuiControl,, cGreen MyProgress, %MyProgress%
FileDelete *.json
FileDelete %WhichFolder%\ImagesList
TimeStatus := A_Now
FormatTime, TimeStatus, , HH:mm:ss
FileAppend, %TimeStatus% : After %TimePassed%: %Done% images found in favorites of %ArtistName%. %NotFoundImagesCount% images downloaded.`n, after_log.txt,UTF-16
DllCall("SetThreadExecutionState","UInt",ES_CONTINUOUS)
SB_SetText("Finished!")
if ShutdownAfter=1
    {
	FileAppend, %TimeStatus% : Shutting down.`n, after_log.txt,UTF-16
	Shutdown, 13
	}
MsgBox,36,Finished, Finished working. Wanna close this app now?
    ifMsgBox No
	{   
	    Gui, Destroy
        goto GUIRESTART
	}
	else ExitApp
}
;Technical
WantShutdownAfter:
    if not A_IsAdmin
    {
	MsgBox,4,Admin rights required, You should restart app as admin to use this feature. Do you want to restart?
        ifMsgBox Yes
		{
        Run *RunAs "%A_ScriptFullPath%"  ; Requires v1.0.92.01+
        ExitApp
		}
        else
		{
		GuiControl, , ShutdownAfter, 0
		GuiControl, Disabled, ShutdownAfter,
		}
    }
	return
	
Debug:
    return

WantPics:
	if AllExt=1
    {
    AllExt:=0
	FromPics=1
	FromFavs=0
	FromSync=0
	FromTags=0
	Asked=0
	Gui, Destroy
    goto GUIRESTART
    }
    GuiControl, Hide, Remover,
    GuiControl, Hide, MD,
	GuiControl, , Username:, Filename:
	GuiControl, , API key:, Filename:
	GuiControl, , E621 data:, Status:
    GuiControl, , Images not found:, Images updated:
	GuiControl, , Images done:, Images not found:
	GuiControl, , Images found:, Images processed:
	GuiControl, +ReadOnly, ArtistName,
	GuiControl, , ArtistName, Filename will be displayed here.
	GuiControl, Move, DisableNet, x150 y185 
	GuiControl, Show, MakeBackups
	GuiControl, , Done, 0/%ImagesCount%
    GuiControl, , NotFoundImagesCount, 0/%ImagesCount%
	GuiControl, Show, UpdListBox
	GuiControl, Hide, FavListBox
	GuiControl, Hide, TagListBox
	GuiControl, Show, AlsoTag
	GuiControl, , AlsoTag, Tag after updating
	GuiControl, Move, AlsoTag, x250 y205
	GuiControl, Show, DisableNet
	GuiControl, Hide, Ex
	GuiControl, Hide, Qu
	GuiControl, Hide, Sa
	GuiControl, Show, Time elapsed:
	GuiControl, Show, Estimated time left:
	GuiControl, Show, Timer
	GuiControl, Show, TimerLeft
	GuiControl, Show, MoreInfo
	GuiControl, Move, MoreInfo, x250 y165
	GuiControl, , Images skipped:, Network:
	GuiControl, Move, NetStat, x270 y294 w130
	GuiControl, -Disabled, NetStat
	GuiControl, , NetStat, Awaiting start
	;Extracted MD5:
	GuiControl, Show, Extracted MD5:
	GuiControl, Hide, Favorites:
	GuiControl, Hide, Artists:
	GuiControl, Move, LoopFavScore, x410 y285 w150 h20
	;Artist
	;GuiControl, Show, Artist:
	GuiControl, Hide, Score:
	GuiControl, Hide, Tags:
	;GuiControl, Move, LoopFavCount, x410 y325 w150 h20
	GuiControl, Hide, LoopFavCount
	GuiControl, , WantPreview, 0
    GuiControl, Disable, WantPreview
	GuiControl, Show, Only favorites mode
	GuiControl, Enabled, Start
	GuiControl, Disable Hide, Get API
	GuiControl, Hide, Name:
    GuiControl, Hide, SyncName
	return
	
WantTags:
	if AllExt=1
    {
    AllExt=0
	FromPics=0
	FromFavs=0
	FromSync=0
	FromTags=1
	Asked=0
	Gui, Destroy
    goto GUIRESTART
    }
    GuiControl, Show, Remover,
    GuiControl, Show, MD,
	GuiControl, , Username:, Filename:
	GuiControl, , API key:, Filename:
	GuiControl, +ReadOnly, ArtistName,
	GuiControl, , ArtistName, Filename will be displayed here.
    GuiControl, , Images updated:, Images not found:
    GuiControl, , Images done:, Images not found:
	GuiControl, , Images found:, Images processed:
	GuiControl, , Done, 0/%ImagesCount%
    GuiControl, , NotFoundImagesCount, 0/%ImagesCount%
	GuiControl, Move, DisableNet, x220 y185
	GuiControl, Hide, MakeBackups
	GuiControl, Show, TagListBox
	GuiControl, Hide, FavListBox
	GuiControl, Hide, UpdListBox
	GuiControl, Hide, Ex
	GuiControl, Hide, Qu
	GuiControl, Hide, AlsoTag
	GuiControl, Show, DisableNet
	GuiControl, Hide, Sa
	GuiControl, Show, Time elapsed:
	GuiControl, Show, Estimated time left:
	GuiControl, Show, Timer
	GuiControl, Show, TimerLeft
	GuiControl, Show, MoreInfo
	GuiControl, Move, MoreInfo, x250 y205
	GuiControl, , Images skipped:, Network:
	GuiControl, Move, NetStat, x270 y294 w130
	GuiControl, -Disabled, NetStat
	GuiControl, , NetStat, Awaiting start
	;Artists
	GuiControl, Show, Artists:
	GuiControl, Hide, Extracted MD5:
	GuiControl, Hide, Favorites:
	GuiControl, Show, LoopFavCount
    GuiControl, Move, LoopFavCount, x410 y285 w150
	;Tags
	GuiControl, Show, Tags:
	GuiControl, Hide, Score:
	GuiControl, Hide, Artist:
	GuiControl, Move, LoopFavScore, x410 y325 w150 h130
	GuiControl, , WantPreview, 0
    GuiControl, Disable, WantPreview
	GuiControl, Show, Only favorites mode
	GuiControl, Enabled, Start
	GuiControl, Disable Hide, Get API
	GuiControl, Hide, Name:
    GuiControl, Hide, SyncName
	return
	
WantFavs:
	if AllExt=1
    {
    AllExt=0
	FromPics=0
	FromFavs=1
	FromSync=0
	FromTags=0
	Asked=0
	Gui, Destroy
    goto GUIRESTART
    }
    GuiControl, Hide, Remover,
    GuiControl, Hide, MD,
	GuiControl, , Filename:, Username:
	GuiControl, , API key:, Username:
	GuiControl, -ReadOnly, ArtistName,
	GuiControl, , ArtistName, ERROR
	IniRead, ArtistName, e621updater.ini, Downloader, Username
	if ArtistName=ERROR
        {
        ArtistName=Enter your username here
        GuiControl, , ArtistName, Enter your username here
	    }
    else
        {
	    GuiControl, , ArtistName, %ArtistName%
	    }
	GuiControl, , Status:, E621 data:
	GuiControl, , Images processed:, Images found:
    GuiControl, , Images not found:, Images done:
	GuiControl, Move, DisableNet, x150 y185 
	GuiControl, Hide, MakeBackups
	GuiControl, Hide, TagListBox
	GuiControl, Hide, UpdListBox
	GuiControl, Show, FavListBox
	GuiControl, Show, Ex
	GuiControl, Show, Qu
	GuiControl, Show, Sa
	GuiControl, Show, AlsoTag
	GuiControl, Move, AlsoTag, x250 y205
	GuiControl, , AlsoTag, Tag after downloading
	GuiControl, Hide, DisableNet
	GuiControl, Hide, Time elapsed:
	GuiControl, Hide, Estimated time left:
	GuiControl, Hide, Timer
	GuiControl, Hide, TimerLeft
	GuiControl, , Network:, Images skipped: 
    GuiControl, Move, NetStat, x310 y295 w90
	GuiControl, Disabled, NetStat
	GuiControl, Enabled, Start
	GuiControl, , NetStat, 0
	GuiControl, ,  - %ImagesCount% images found., - Waiting for data
	GuiControl, Show, MoreInfo
	GuiControl, Move, MoreInfo, x150 y185
	;Favcount
	GuiControl, Show, Favorites:
    GuiControl, Hide, Artists:
	GuiControl, Hide, Extracted MD5:
	GuiControl, Move, LoopFavScore, x410 y285 w150 h20
	;Score
	GuiControl, Show, Score:
	GuiControl, Hide, Artist:
	GuiControl, Hide, Tags:
	GuiControl, Show, LoopFavCount
	GuiControl, Move, LoopFavCount, x410 y325 w150 h20
	GuiControl, , WantPreview, 1
    GuiControl, Enable, WantPreview
	GuiControl, Hide, Only favorites mode
	GuiControl, Hide, Name:
	GuiControl, Disable Hide, Get API
    GuiControl, Hide, SyncName
	return
	
WantSync:
    GuiControl, , Filename:, API key:
	GuiControl, , Username:, API key:
	IniRead, SyncName, e621updater.ini, Downloader, Username
	if SyncName=ERROR
        {
        SyncName=Enter your username here
        GuiControl, , SyncName, Enter your username here
	    }
    else
        {
	    GuiControl, , SyncName, %SyncName%
	    }
	IniRead, ArtistName, e621updater.ini, Downloader, API
	if ArtistName=ERROR
        {
        ArtistName=
        GuiControl, , ArtistName,
	    }
    else
        {
	    GuiControl, , ArtistName, %ArtistName%
	    }
	GuiControl, -ReadOnly, ArtistName,
	GuiControl, Show, UpdListBox
	GuiControl, Hide, FavListBox
	GuiControl, Hide, TagListBox
	GuiControl, Show, Name:
    GuiControl, Show, SyncName
	GuiControl, Hide, Ex
	GuiControl, Hide, Qu
	GuiControl, Hide, Sa
	GuiControl, Hide, Remover,
	GuiControl, Enabled, Start
    GuiControl, Hide, MD,
	GuiControl, Hide, MakeBackups
	GuiControl, Hide, DisableNet
	GuiControl, Hide, AlsoTag
	GuiControl, Hide, MoreInfo
	GuiControl, Disabled, NetStat
	GuiControl, Enabled, Get API
	GuiControl, Show, Get API
	if AllExt=0
	{
    AllExt=1
	FromPics=0
	FromFavs=0
	FromSync=1
	FromTags=0
	Gui, Submit, NoHide
	Gui, Destroy
    goto GUIRESTART
    }
    return
	
DisableNetwork:
    Gui, Submit, NoHide
    if DisableNet=1
    {
	IniWrite, 1, e621updater.ini, Options, NetworkChecksDisabled
    GuiControl, , NetStat, Disabled
	GuiControl, Disable, NetStat,
	return
	}
	else
	{
	IniDelete, e621updater.ini, Options, NetworkChecksDisabled
	GuiControl, , NetStat, Awaiting start
	GuiControl, Enable, NetStat,
	return
	}
	
WantBackups:
    Gui, Submit, NoHide
    if MakeBackups=1
    {
	IniWrite, 1, e621updater.ini, Options, MakeBackups
	return
	}
	else
	{
	IniDelete, e621updater.ini, Options, MakeBackups
	return
	}
	
UsernameEntered:
    Gui, Submit, NoHide
    If Favs=1
	    if NOT ArtistName="Enter your username here" 
        {
        GuiControl, Enabled, Start
		IniWrite, %ArtistName%, e621updater.ini, Downloader, Username
	    return
	    }
		else return
	If Sync=1
		if NOT SyncName="Enter your username here" 
        {
        GuiControl, Enabled, Start
		IniWrite, %ArtistName%, e621updater.ini, Downloader, API
	    return
	    }
		else return
	else return
	
NameEntered:
	If Sync=1
		if NOT SyncName="Enter your username here" 
        {
        GuiControl, Enabled, Start
		IniWrite, %SyncName%, e621updater.ini, Downloader, Username
	    return
	    }
	else return

RatingCheckbox:
    Gui, Submit, NoHide
    if Ex=0
	{
	    if Qu=0
		{
		    if Sa=0
			{
			    GuiControl, Disabled, Start,
			    MsgBox,64,Ratings error, At least one rating should be enabled
				return
			}
		}
	}
	else
	{
	GuiControl, Enabled, Start,
	}
	return

ButtonPause:
    setpause=1
	
WantMoreInfo:
    Gui, Submit, NoHide
    if MoreInfo=1
	    {
		Gui, Show, xCenter yCenter w573 h480, E621 updater v4
		Gui, Submit, NoHide
		return
		}
	else
		{
		Gui, Show, xCenter yCenter w410 h480, E621 updater v4
		Gui, Submit, NoHide
		return
		}

WantPreview:
    Gui, Submit, NoHide
    if WantPreview=0
	    {
		GuiControl,, Pic, w0 h0
		return
		}
	else
	    {
		GuiControl,, Pic, w150 h150
		GuiControl,, Pic, %A_Temp%\%LoopFavName%
		return
		}
	return
	
ButtonChooseAnotherFolder:
        IniRead, LastFolder, e621updater.ini, Main, Folder
	    IniDelete, e621updater.ini, Main, Folder
		WantAnotherFolder=1
        Gui, Destroy
        goto GUIRESTART

ButtonGetAPI:
    Gui, APIGet: New, -MaximizeBox -MinimizeBox +Owner, Getting API key...
	Gui, APIGet: -Resize +MinSize210x90
	Gui, APIGet: Show, xCenter yCenter w210 h90, Getting API key...
	IniRead, APIName, e621updater.ini, Downloader, Username
	if APIName=ERROR
        {
	    APIName=
	    }
	Gui, Add, Text, x10 y15 w60, Name:
    Gui, Add, Edit, x45 y13 w160 vAPIName,
	Gui, Add, Text, x10 y40 w60, Password:
    Gui, Add, Edit, x65 y38 w140 vAPIPass,
	Gui, Add, Button, x6 y60 w200 gGO Default, GO
	Gui, APIGet: Submit, NoHide
	Gui, Submit, NoHide
	return
	
GO:
    Gui, APIGet: Submit, NoHide
	Gui, Submit, NoHide
    UURL = http://e621.net/user/login.xml?name=
	PURL = &password=
	apifullurl= %UURL%%APIName%%PURL%%APIPass%
    UrlDownloadToFile, %apifullurl%, api.xml
	FileRead, APIContents, api.xml
	FileDelete api.xml
	IfInString, APIContents, users type="array"
        {
		StringGetPos, APIpos, APIContents, hash=`"
		APIpos+=6
		StringTrimLeft, APIContents, APIContents, %APIpos%
		StringGetPos, APIpos, APIContents, `" name=`"
		APIpos-=7
		StringTrimRight, APIContents, APIContents, %APIpos%
		IniWrite, %APIContents%, e621updater.ini, Downloader, API
		IniWrite, %APIName%, e621updater.ini, Downloader, Username
		SyncName=%APIName%
		ArtistName=%APIContents%
		MsgBox,64,Login Success, Logged in, API extracted. Change modes to see the changes in your GUI.
		Gui, APIGet: Destroy
		return
		}
	else
	    {
	    MsgBox,16,Login Failed, Wrong username or password!
		}
	return
;@"
;MsgBox,36,Finished, Finished working. Wanna close this app now?

