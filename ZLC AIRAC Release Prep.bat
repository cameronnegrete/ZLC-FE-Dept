@ECHO OFF

:ReadMe
rem If you are just setting up this batch file for the first time or need to make edits:
rem      1) Be sure the appropriate variables are set appropriately. At the time of writing this instruction, you only need to set the CustomZlcAliasFileLink variable.
rem      2) Go to the WritingZLCGeojsonPrefFiles function and edit the Rename_FE-Buddy_Output_GeoJSONs.csv and CRC_GeoJSON_Defaults.txt to your own preferences.
rem              note: the CRC_GeoJSON_Defaults.txt needs to have these characters escaped using a carrot symbol ^ including the quotes: "[{}}]"
rem                         example: ^"^[^{^}^]^"

setlocal enabledelayedexpansion

set THIS_VERSION=1.0.0
set SCRIPT_NAME=ZLC AIRAC Release Prep
TITLE !SCRIPT_NAME! (v!THIS_VERSION!)
rem This is where the URL to find the "GITHUB RAW FILE" custom ZLC-alias.txt file should go. Example: "CustomZlcAliasFileLink=https://raw.githubusercontent.com/cameronnegrete/ZLC-FE-Dept/main/ZLC-Alias.txt"
set "CustomZlcAliasFileLink=https://raw.githubusercontent.com/cameronnegrete/ZLC-FE-Dept/main/ZLC-Alias.txt"

:QUARTERBACK
	CALL :SelectFEBuddyOutputFolder
	CALL :SystemConfigMSG
		CALL :FEBuddySelectedDirectory
		CALL :PythonInstallCheck
		CALL :cUrlCheck
		CALL :TempFolderCreation
		CALL :UploadToVNASFolderCreation
		CALL :WritingSetSefaultsPY
		CALL :WritingFEBDefaultsPY
		CALL :WritingFileHandlerPY
		CALL :WritingGeoJsonPY
		CALL :WritingZLCGeojsonPrefFiles
		CALL :DownloadZLCCustomAliasFiles
		pause
	CALL :MoveAndRenameGeoJsons
	CALL :SetZLCDefaultsToGeoJsons
	CALL :CompileFinalAliasFile
	CALL :MoveFinalizedFiles
	CALL :DoneWithScript

:SelectFEBuddyOutputFolder
	ECHO.
	ECHO.
	ECHO Please select the FE-Buddy Output folder.
	ECHO.
	ECHO This folder should begin with the words "FE-Buddy_Output", otherwise will result in an error.

	:: Launches Windows Folder Browser window to have the user select a directory and then saves that directory to the "Selected_FE-Buddy_Directory" variable.
	set Selected_FE-Buddy_Directory=NOT_DEFINED
	set "psCommand=(New-Object -ComObject Shell.Application).BrowseForFolder(0, 'Select the FE-Buddy Output Folder', 0, 0).Self.Path"
		for /f "usebackq delims=" %%I in (`powershell -command "%psCommand%"`) do set "Selected_FE-Buddy_Directory=%%I"

		:: If user clicked cancel or nothing at all, it exits the Command Prompt window.
		IF "!Selected_FE-Buddy_Directory!"=="NOT_DEFINED" EXIT
		
		:: Extract the folder name from the selected path
		for %%F in ("!Selected_FE-Buddy_Directory!") do set "folderName=%%~nxF"

		:: Check if the folder name begins with "FE-BUDDY_Output"
		if not "!folderName:~0,15!"=="FE-BUDDY_Output" (
			cls
			ECHO.
			ECHO.
			ECHO                -------------
			ECHO                   WARNING
			ECHO                -------------
			ECHO.
			echo The selected folder does not begin with "FE-BUDDY_Output".
			echo Please select the correct folder.
			echo.
			echo Press any key to exit and try again...
			pause > NUL
			exit
		)

:SystemConfigMSG

	CLS
	
	ECHO.
	ECHO.
	ECHO      --------------------------
	ECHO          CONFIGURING SYSTEM
	ECHO      --------------------------
	ECHO.
	ECHO.
	ECHO.
	goto :eof

:FEBuddySelectedDirectory
	ECHO    -FE-Buddy Output Folder directory selected by you:
	echo             !Selected_FE-Buddy_Directory!
	echo.
	goto :eof

:PythonInstallCheck
	
	ECHO    -Checking Python installation...
	
	:: Checkst to see if Python is installed and if it isn't, displays an error to the user
	:: instructoring them how to install it along with opening their default web browser up to the install page.
	python --version > nul 2>&1
	
	if %errorlevel% == 0 (
		echo            -Python is installed and available in PATH.
		echo.
		goto :eof
	) else (
		:: Checks the users system to see if it is 32 or 64 bit for later use.
		set "ProgramFilesPath=%ProgramFiles(x86)%"
		if "%ProgramFilesPath%"=="" (
			SET BIT=32
		) else (
			SET BIT=64
		)
		
		CLS
		
		ECHO.
		ECHO.
		ECHO               -------
		ECHO                ERROR
		ECHO               -------
		ECHO.
		ECHO Python does not appear to be installed on your computer.
		ECHO.
		ECHO Python is required to perform certain parts of this process.
		ECHO Please go to https://www.python.org/downloads/windows/ and download the latest release and install in.
		ECHO      -This page should have already opened in your default web browser.
		ECHO.
		ECHO   It is recommended to download the "Windows installer (!BIT!-bit)"
		ECHO.
		ECHO.
		ECHO IMPORTANT:
		ECHO      When you install Python, be sure "ADD PYTHON TO PATH" is checked in the installation
		ECHO      wizard prior to selecting "INSTALL NOW".
		ECHO.
		ECHO Press any key to exit...
		
		START "" https://www.python.org/downloads/windows/
		
		PAUSE>NUL
		
		exit
	)

:cUrlCheck
	
	ECHO    -Checking cURL installation...
	
	:: Checkst to see if cURL is installed and if it isn't, displays an error to the user
	:: instructoring them how to install it.
	where /q curl
	if %errorlevel% neq 0 (
		ECHO.
		ECHO.
		ECHO               -------
		ECHO                ERROR
		ECHO               -------
		ECHO.
		ECHO cURL does not appear to be installed on your computer.
		ECHO.
		ECHO cURL is required to perform certain parts of this process.
		ECHO Please go to https://curl.se/download.html and download the latest release and install it.
		ECHO      -This page should have already opened in your default web browser.
		ECHO.
		ECHO Press any key to exit...
		START "" https://curl.se/download.html
		PAUSE>NUL
		exit
	) else (
	    echo            -cURL is installed.
		echo.
		goto :eof
	)

:TempFolderCreation
	
	ECHO    -Configuring temp folder...
	
	SET BatchTempFolderDirectory=%temp%\ZLC_AIRAC_RELEASE_PREP_temp
	
	if exist "!BatchTempFolderDirectory!" ( 
		RD /S /Q "!BatchTempFolderDirectory!"
		MD "!BatchTempFolderDirectory!"
		echo            -previous temp folder found and reset
		echo.
	) else (
		MD "!BatchTempFolderDirectory!"
		echo            -temp folder created
		echo.
	)


	MD "!BatchTempFolderDirectory!\DefaultSetter"
		MD "!BatchTempFolderDirectory!\DefaultSetter\DefaultSetterOutput"
		MD "!BatchTempFolderDirectory!\DefaultSetter\modules"
	MD "!BatchTempFolderDirectory!\DefaultSetterPrefs"
	MD "!BatchTempFolderDirectory!\Aliases"
	MD "!BatchTempFolderDirectory!\GeoJSONs"
		MD "!BatchTempFolderDirectory!\GeoJSONs\Finalized GeoJSONs"
	
	goto :eof

:UploadToVNASFolderCreation
	
	ECHO    -Configuring UPLOAD_TO_vNAS folder inside the selected FE-Buddy Output folder...
	
	if exist "!Selected_FE-Buddy_Directory!\UPLOAD_TO_vNAS" ( 
		RD /S /Q "!Selected_FE-Buddy_Directory!\UPLOAD_TO_vNAS"
		MD "!Selected_FE-Buddy_Directory!\UPLOAD_TO_vNAS"
			MD "!Selected_FE-Buddy_Directory!\UPLOAD_TO_vNAS\VIDEO_MAPS"
		echo            -previous UPLOAD_TO_vNAS folder found and reset
		echo.
	) else (
		MD "!Selected_FE-Buddy_Directory!\UPLOAD_TO_vNAS"
			MD "!Selected_FE-Buddy_Directory!\UPLOAD_TO_vNAS\VIDEO_MAPS"
		echo            -UPLOAD_TO_vNAS folder created
		echo.
	)

:WritingSetSefaultsPY

	:: SPECIAL THANKS to Kyle Rodgers (MisterRodg) for creating this python file as a temp fix for setting Defaults into the FE-Buddy output CRC GeoJSON files!
	::      Check out his GitHub here: https://github.com/misterrodg
	::            Specific Default Setter repo: https://github.com/misterrodg/FEB-DefaultSetter
	
	:: Creates the setdefaults.py file in the primary DefaultSetter directory.
	(
		ECHO import argparse
		ECHO.
		ECHO from modules.FEBDefaults import FEBDefaults
		ECHO from modules.FileHandler import FileHandler
		ECHO from modules.GeoJSON import GeoJSON
		ECHO.
		ECHO.
		ECHO def processDefaults^(filePath^):
		ECHO     print^("\nGetting Defaults from FEB Defaults File"^)
		ECHO     febDefaults = FEBDefaults^(filePath^)
		ECHO     return febDefaults.defaults
		ECHO.
		ECHO.
		ECHO def processFiles^(sourceDir, useSourceLocal, outputDir, useOutputLocal, defaultsArray^):
		ECHO     fileHandler = FileHandler^(^)
		ECHO     fileHandler.checkDir^(outputDir, useOutputLocal^)
		ECHO     fileHandler.deleteAllInSubdir^(".geojson", outputDir, useOutputLocal^)
		ECHO     fileList = fileHandler.searchForType^(".geojson", sourceDir, useSourceLocal^)
		ECHO     numFiles = str^(len^(fileList^)^)
		ECHO     print^(f"Found {numFiles} .geojson files in {sourceDir}"^)
		ECHO     fileCount = 0
		ECHO     for f in fileList:
		ECHO         fileData = fileHandler.splitFolderFile^(f, sourceDir^)
		ECHO         folder = fileData[0]
		ECHO         fileName = fileData[1].replace^(".geojson", ""^)
		ECHO         defaults = next^(
		ECHO             ^(item for item in defaultsArray if item["fileName"] == fileData[1]^), False
		ECHO         ^)
		ECHO         if defaults:
		ECHO             print^(f^"[{str^(fileCount + 1^)}/{numFiles}] Processing {fileName}.geojson^"^)
		ECHO             GeoJSON^(sourceDir, outputDir, fileName, defaults["default"]^)
		ECHO             fileCount += 1
		ECHO     print^("\n>>>>> Defaults are now set. Files located in " + outputDir + "<<<<<\n"^)
		ECHO.
		ECHO.
		ECHO def main^(^):
		ECHO     # Set up Defaults
		ECHO     SOURCE_DIR = "feb_source"
		ECHO     OUTPUT_DIR = "output"
		ECHO     FEB_DEFAULTS = "vNAS_Defaults.txt"
		ECHO     # Set up Argmument Handling
		ECHO     parser = argparse.ArgumentParser^(description="FEB-DefaultSetter"^)
		ECHO     parser.add_argument^(
		ECHO         "--sourcedir", type=str, help="The path to the source directory."
		ECHO     ^)
		ECHO     parser.add_argument^(
		ECHO         "--outputdir", type=str, help="The path to the output directory."
		ECHO     ^)
		ECHO     parser.add_argument^(
		ECHO         "--defaultsfile", type=str, help="The filename of the FEB Defaults File."
		ECHO     ^)
		ECHO     args = parser.parse_args^(^)
		ECHO     sourceDir = SOURCE_DIR
		ECHO     useSourceLocal = True
		ECHO     outputDir = OUTPUT_DIR
		ECHO     useOutputLocal = True
		ECHO     febDefaults = "./" + sourceDir + "/" + FEB_DEFAULTS
		ECHO     if args.sourcedir ^^!= None:
		ECHO         sourceDir = args.sourcedir
		ECHO         useSourceLocal = False
		ECHO     if args.outputdir ^^!= None:
		ECHO         outputDir = args.outputdir
		ECHO         useOutputLocal = False
		ECHO     febDefaults = args.defaultsfile if args.defaultsfile ^^!= None else febDefaults
		ECHO     print^("\nInitializing DefaultSetter"^)
		ECHO     # Read the defaults from the FEB List
		ECHO     defaultsArray = processDefaults^(febDefaults^)
		ECHO     # Process the files from the FEB List
		ECHO     processFiles^(sourceDir, useSourceLocal, outputDir, useOutputLocal, defaultsArray^)
		ECHO.
		ECHO.
		ECHO if __name__ == "__main__":
		ECHO     main^(^)
	)>"!BatchTempFolderDirectory!\DefaultSetter\setdefaults.py"
	goto :eof

:WritingFEBDefaultsPY
	:: Creates the FEBDefaults.py file in the primary DefaultSetter\modules directory.
	(
		ECHO class FEBDefaults:
		ECHO     def __init__^(self, filePath^):
		ECHO         self.defaultFilePath = filePath
		ECHO         self.defaults = []
		ECHO         self.read^(^)
		ECHO.
		ECHO     def add^(self, fileName, default^):
		ECHO         newItem = {"fileName": fileName, "default": default}
		ECHO         self.defaults.append^(newItem^)
		ECHO.
		ECHO     def read^(self^):
		ECHO         currentFile = ""
		ECHO         currentDefaults = ""
		ECHO         with open^(self.defaultFilePath^) as lines:
		ECHO             for line in lines:
		ECHO                 if line.endswith^(".geojson\n"^):
		ECHO                     currentFile = line.strip^(^)
		ECHO                 if line.startswith^('{"type":"Feature",'^):
		ECHO                     withoutComma = line.rstrip^(",\n"^)
		ECHO                     currentDefaults = withoutComma.strip^(^)
		ECHO                 if currentFile ^^!= "" and currentDefaults ^^!= "":
		ECHO                     self.add^(currentFile, currentDefaults^)
		ECHO                     currentFile = ""
		ECHO                     currentDefaults = ""
		ECHO.
		ECHO.
	)>"!BatchTempFolderDirectory!\DefaultSetter\modules\FEBDefaults.py"
	goto :eof

:WritingFileHandlerPY
	:: Creates the FileHandler.py file in the primary DefaultSetter\modules directory.
	(
		ECHO import os
		ECHO.
		ECHO.
		ECHO class FileHandler:
		ECHO     def __init__^(self^):
		ECHO         self.localPath = os.getcwd^(^)
		ECHO.
		ECHO     def checkDir^(self, subdirPath, useLocal=True^):
		ECHO         result = False
		ECHO         dirPath = self.localPath + "/" + subdirPath if useLocal == True else subdirPath
		ECHO         os.makedirs^(name=dirPath, exist_ok=True^)
		ECHO         if os.path.exists^(dirPath^):
		ECHO             result = True
		ECHO         return result
		ECHO.
		ECHO     def deleteAllInSubdir^(self, fileType, subdirPath=None, useLocal=True^):
		ECHO         # As it stands, this will only ever delete items in the named subfolder where this script runs.
		ECHO         # Altering this function could cause it to delete the entire contents of other folders where you wouldn't want it to.
		ECHO         # Alter this at your own risk.
		ECHO         if subdirPath ^^!= None:
		ECHO             deletePath = ^(
		ECHO                 self.localPath + "/" + subdirPath if useLocal == True else subdirPath
		ECHO             ^)
		ECHO             for f in os.listdir^(deletePath^):
		ECHO                 if f.endswith^(fileType^):
		ECHO                     os.remove^(os.path.join^(deletePath, f^)^)
		ECHO.
		ECHO     def searchForType^(self, fileType, subdirPath=None, useLocal=True^):
		ECHO         result = []
		ECHO         searchPath = self.localPath if useLocal == True else subdirPath
		ECHO         if subdirPath ^^!= None and useLocal == True:
		ECHO             searchPath += "/" + subdirPath
		ECHO         for dirpath, subdirs, files in os.walk^(searchPath^):
		ECHO             result.extend^(
		ECHO                 os.path.join^(dirpath, f^) for f in files if f.endswith^(fileType^)
		ECHO             ^)
		ECHO         return result
		ECHO.
		ECHO     def splitFolderFile^(self, fullPath, subdirPath=None^):
		ECHO         result = []
		ECHO         split = os.path.split^(fullPath^)
		ECHO         searchPath = self.localPath
		ECHO         if subdirPath ^^!= None:
		ECHO             searchPath += "/" + subdirPath
		ECHO         result.append^(split[0].replace^(searchPath, ""^)^)
		ECHO         result.append^(split[1]^)
		ECHO         return result
		ECHO.
	)>"!BatchTempFolderDirectory!\DefaultSetter\modules\FileHandler.py"
	goto :eof

:WritingGeoJsonPY
	:: Creates the GeoJSON.py file in the primary DefaultSetter\modules directory.
	(
		ECHO import json
		ECHO.
		ECHO.
		ECHO class GeoJSON:
		ECHO     def __init__^(self, sourceFolder, outputFolder, fileName, defaults^):
		ECHO         self.fileName = sourceFolder + "/" + fileName + ".geojson"
		ECHO         self.outputFileName = outputFolder + "/" + fileName + ".geojson"
		ECHO         self.defaults = json.loads^(defaults^)
		ECHO         self.read^(^)
		ECHO.
		ECHO     def read^(self^):
		ECHO         with open^(self.fileName, "r"^) as geoJsonFile:
		ECHO             data = json.load^(geoJsonFile^)
		ECHO             data["features"].insert^(0, self.defaults^)
		ECHO             with open^(self.outputFileName, "w"^) as outputFile:
		ECHO                 json.dump^(data, outputFile, separators=^(",", ":"^), indent=None^)
		ECHO.
	)>"!BatchTempFolderDirectory!\DefaultSetter\modules\GeoJSON.py"
	goto :eof

:WritingZLCGeojsonPrefFiles
	(
	ECHO APT_symbols.geojson,ERAM_FILTER 10_AIRPORT SYMBOLS.geojson
	ECHO APT_text.geojson,ERAM_FILTER 10_AIRPORT TEXT.geojson
	ECHO ARTCC BOUNDARIES-HIGH_lines.geojson,ERAM_FILTER 01_ALL ARTCC BOUNDARIES-HIGH.geojson
	ECHO ARTCC BOUNDARIES-LOW_lines.geojson,ERAM_FILTER 01_ALL ARTCC BOUNDARIES-LOW.geojson
	ECHO AWY-HIGH_lines^(DME Cutoff^).geojson,ERAM_FILTER 05_AWY-HIGH_LINES.geojson
	ECHO AWY-HIGH_symbols.geojson,ERAM_FILTER 05_AWY-HIGH_SYMBOLS.geojson
	ECHO AWY-HIGH_text.geojson,ERAM_FILTER 05_AWY-HIGH_TEXT.geojson
	ECHO AWY-LOW_lines^(DME Cutoff^).geojson,ERAM_FILTER 15_AWY-LOW_LINES.geojson
	ECHO AWY-LOW_symbols.geojson,ERAM_FILTER 15_AWY-LOW_SYMBOLS.geojson
	ECHO AWY-LOW_text.geojson,ERAM_FILTER 15_AWY-LOW_TEXT.geojson
	ECHO NDB_symbols.geojson,ERAM_FILTER 13_NDB SYMBOLS.geojson
	ECHO NDB_text.geojson,ERAM_FILTER 13_NDB TEXT.geojson
	ECHO VOR_symbols.geojson,ERAM_FILTER 13_VOR SYMBOLS.geojson
	ECHO VOR_text.geojson,ERAM_FILTER 13_VOR TEXT.geojson
	ECHO WX STATIONS_text.geojson,ERAM_FILTER 09_ALL WX STATIONS TEXT.geojson
	)>"!BatchTempFolderDirectory!\DefaultSetterPrefs\Rename_FE-Buddy_Output_GeoJSONs.csv"

	(
		ECHO ERAM_FILTER 01_ALL ARTCC BOUNDARIES-HIGH.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isLineDefaults^":true,^"bcg^":1,^"filters^":^[1^],^"style^":^"Solid^",^"thickness^":3^}^},
		ECHO.
		ECHO ERAM_FILTER 01_ALL ARTCC BOUNDARIES-LOW.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isLineDefaults^":true,^"bcg^":1,^"filters^":^[1^],^"style^":^"Solid^",^"thickness^":3^}^},
		ECHO.
		ECHO ERAM_FILTER 05_AWY-HIGH_LINES.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isLineDefaults^":true,^"bcg^":5,^"filters^":^[5^],^"style^":^"Solid^",^"thickness^":1^}^},
		ECHO.
		ECHO ERAM_FILTER 05_AWY-HIGH_SYMBOLS.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isSymbolDefaults^":true,^"bcg^":5,^"filters^":^[5^],^"style^":^"airwayIntersections^",^"size^":1^}^},
		ECHO.
		ECHO ERAM_FILTER 05_AWY-HIGH_TEXT.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isTextDefaults^":true,^"bcg^":5,^"filters^":^[5^],^"size^":1,^"underline^":false,^"opaque^":false,^"xOffset^":12,^"yOffset^":0^}^},
		ECHO.
		ECHO ERAM_FILTER 09_ALL WX STATIONS TEXT.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isTextDefaults^":true,^"bcg^":9,^"filters^":^[9^],^"size^":1,^"underline^":false,^"opaque^":false,^"xOffset^":12,^"yOffset^":0^}^},
		ECHO.
		ECHO ERAM_FILTER 10_AIRPORT SYMBOLS.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isSymbolDefaults^":true,^"bcg^":10,^"filters^":^[10^],^"style^":^"airport^",^"size^":1^}^},
		ECHO.
		ECHO ERAM_FILTER 10_AIRPORT TEXT.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isTextDefaults^":true,^"bcg^":10,^"filters^":^[10^],^"size^":1,^"underline^":false,^"opaque^":false,^"xOffset^":12,^"yOffset^":0^}^},
		ECHO.
		ECHO ERAM_FILTER 13_NDB SYMBOLS.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isSymbolDefaults^":true,^"bcg^":13,^"filters^":^[13^],^"style^":^"ndb^",^"size^":1^}^},
		ECHO.
		ECHO ERAM_FILTER 13_NDB TEXT.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isTextDefaults^":true,^"bcg^":13,^"filters^":^[13^],^"size^":1,^"underline^":false,^"opaque^":false,^"xOffset^":12,^"yOffset^":0^}^},
		ECHO.
		ECHO ERAM_FILTER 13_VOR SYMBOLS.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isSymbolDefaults^":true,^"bcg^":13,^"filters^":^[13^],^"style^":^"vor^",^"size^":1^}^},
		ECHO.
		ECHO ERAM_FILTER 13_VOR TEXT.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isTextDefaults^":true,^"bcg^":13,^"filters^":^[13^],^"size^":1,^"underline^":false,^"opaque^":false,^"xOffset^":12,^"yOffset^":0^}^},
		ECHO.
		ECHO ERAM_FILTER 15_AWY-LOW_LINES.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isLineDefaults^":true,^"bcg^":15,^"filters^":^[15^],^"style^":^"Solid^",^"thickness^":1^}^},
		ECHO.
		ECHO ERAM_FILTER 15_AWY-LOW_SYMBOLS.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isSymbolDefaults^":true,^"bcg^":15,^"filters^":^[15^],^"style^":^"airwayIntersections^",^"size^":1^}^},
		ECHO.
		ECHO ERAM_FILTER 15_AWY-LOW_TEXT.geojson
		ECHO ^{^"type^":^"Feature^",^"geometry^":^{^"type^":^"Point^",^"coordinates^":^[90.0,180.0^]^},^"properties^":^{^"isTextDefaults^":true,^"bcg^":15,^"filters^":^[15^],^"size^":1,^"underline^":false,^"opaque^":false,^"xOffset^":12,^"yOffset^":0^}^},
	)>"!BatchTempFolderDirectory!\DefaultSetterPrefs\CRC_GeoJSON_Defaults.txt"
	goto :eof

:DownloadZLCCustomAliasFiles

	ECHO    -Downloading the ZLC Custom Alias File from GitHub.
	
	set "FILE_URL=!CustomZlcAliasFileLink!"
	set "OUTPUT_FILE=!BatchTempFolderDirectory!\Aliases\01_ZLC_CUSTOM_ALIASES.txt"
	
	rem This code would be needed if a token was needed to access the alias file on github.
	rem curl -sS -H "Authorization: token !GITHUB_TOKEN!" -L !FILE_URL! -o "!OUTPUT_FILE!"
	
	curl -sS -L !FILE_URL! -o "!OUTPUT_FILE!"
	
		if not "%errorlevel%" equ "0" (
		ECHO.
		ECHO.
		ECHO.
		ECHO                -------------
		ECHO                   WARNING
		ECHO                -------------
		ECHO.
		ECHO Failed to download the ZLC Custom Alias from here:
		ECHO !FILE_URL!
		ECHO.
		ECHO Attempt to fix this issue by ensuring that this link works by taking you
		ECHO to the current ZLC Custom Alias file on GitHub.
		ECHO.
		ECHO Press any key to exit...
		pause > nul
		exit
		) else (
			set "found=false"
			:: Call PowerShell to search for the line
			for /f "delims=" %%i in ('powershell -Command "(Get-Content '!OUTPUT_FILE!') -like '.FeUseOnly*'"') do (
			    set "found=true"
			)

			:: Display result based on 'found' flag
			if "!found!"=="true" (
			    echo            -Downloaded and verified.
				echo.
			) else (
				ECHO.
				ECHO.
				ECHO.
				ECHO                -------------
				ECHO                   WARNING
				ECHO                -------------
				ECHO.
				ECHO Failed to properly download the ZLC Custom Alias from here:
				ECHO !FILE_URL!
				ECHO.
				ECHO Attempt to fix this issue by ensuring that this link works by taking you
				ECHO to the current ZLC Custom Alias file on GitHub.
				ECHO.
				ECHO Batch Script troubleshooting: The downloaded file does not contain the string .FeUseOnly
				ECHO and therefore either did not download, downloaded a 404 error, or not the alias file itself.
				ECHO.
				ECHO Press any key to exit...
				pause > nul
				exit
			)
		)
	goto :eof

:MoveAndRenameGeoJsons
	ECHO    -Moving GeoJSONs from FE-Buddy Output folder to a Temp folder then renaming them...
	
	:: Define the paths
	set "csv_path=!BatchTempFolderDirectory!\DefaultSetterPrefs\Rename_FE-Buddy_Output_GeoJSONs.csv"
	set "destination_directory=!BatchTempFolderDirectory!\GeoJSONs"
	
	
	:: Read the CSV file
	set /a WARNING_COUNT=0
	for /f "tokens=1,2 delims=," %%a in (!csv_path!) do (
		set "current_name=%%a"
		set "new_name=%%b"
		
		:: Define full source and destination file paths
		set "current_file_dir_and_name=!Selected_FE-Buddy_Directory!\CRC\!current_name!"
		set "new_file_dir_and_name=!BatchTempFolderDirectory!\GeoJSONs\!new_name!"
		
		:: Extract file names without extensions
		for %%f in ("!current_file_dir_and_name!") do (
			set "current_file_name=%%~nf"
		)
		for %%f in ("!new_file_dir_and_name!") do (
			set "new_file_name=%%~nf"
		)
		
		:: Check if the source file exists and copy it if it does
		if exist "!current_file_dir_and_name!" (
			copy "!current_file_dir_and_name!" "!new_file_dir_and_name!">nul
			echo             !current_file_name!   -^>   !new_file_name!
		) else (
			echo             WARNING:   !current_file_name!.geojson not found.
			SET /A WARNING_COUNT=!WARNING_COUNT!+1
			
		)
	)
	
	if not "!WARNING_COUNT!"=="0" (
		echo                  NOTE: geojsons that are not found will just not be exported to the Upload-to-vNAS folder.
	)
	
	ECHO.
	goto :eof

:SetZLCDefaultsToGeoJsons

	ECHO.
	ECHO.
	ECHO.
	ECHO      ---------------------------------------------------------
	ECHO          Adding the ZLC CRC Default Values to the GeoJSONs
	ECHO      ---------------------------------------------------------
	ECHO.
	ECHO.
	:: Runs the setdefaults.py and passes in the directories of where to find the files,
	:: where to place the output files, and where the CRC defaults list is located.
	python.exe "!BatchTempFolderDirectory!\DefaultSetter\setdefaults.py" --sourcedir "!BatchTempFolderDirectory!\GeoJSONs" --outputdir "!BatchTempFolderDirectory!\GeoJSONs\Finalized GeoJSONs" --defaultsfile "!BatchTempFolderDirectory!\DefaultSetterPrefs\CRC_GeoJSON_Defaults.txt"
	ECHO.
	goto :eof

:CompileFinalAliasFile

	ECHO.
	ECHO.
	ECHO.
	ECHO      ---------------------------------------------------------
	ECHO          Adding the ZLC CRC Default Values to the GeoJSONs
	ECHO      ---------------------------------------------------------
	ECHO.
	ECHO.
	ECHO     Adding the following alias files to Combined_ZLC_Alias.txt

	TYPE "!BatchTempFolderDirectory!\Aliases\01_ZLC_CUSTOM_ALIASES.txt">"!BatchTempFolderDirectory!\Aliases\Combined_ZLC_Alias.txt"
	ECHO            -ZLC_CUSTOM_ALIASES.txt
	(
	ECHO.
	ECHO.
	)>>"!BatchTempFolderDirectory!\Aliases\Combined_ZLC_Alias.txt"
	
	TYPE "!Selected_FE-Buddy_Directory!\ALIAS\AWY_ALIAS.txt">>"!BatchTempFolderDirectory!\Aliases\Combined_ZLC_Alias.txt"
	ECHO            -AWY_ALIAS.txt
	(
	ECHO.
	ECHO.
	)>>"!BatchTempFolderDirectory!\Aliases\Combined_ZLC_Alias.txt"

	TYPE "!Selected_FE-Buddy_Directory!\ALIAS\FAA_CHART_RECALL.txt">>"!BatchTempFolderDirectory!\Aliases\Combined_ZLC_Alias.txt"
	ECHO            -FAA_CHART_RECALL.txt
	(
	ECHO.
	ECHO.
	)>>"!BatchTempFolderDirectory!\Aliases\Combined_ZLC_Alias.txt"
	
	TYPE "!Selected_FE-Buddy_Directory!\ALIAS\ISR_APT.txt">>"!BatchTempFolderDirectory!\Aliases\Combined_ZLC_Alias.txt"
	ECHO            -ISR_APT.txt
	(
	ECHO.
	ECHO.
	)>>"!BatchTempFolderDirectory!\Aliases\Combined_ZLC_Alias.txt"
	
	TYPE "!Selected_FE-Buddy_Directory!\ALIAS\ISR_NAVAID.txt">>"!BatchTempFolderDirectory!\Aliases\Combined_ZLC_Alias.txt"
	ECHO            -ISR_NAVAID.txt
	(
	ECHO.
	ECHO.
	)>>"!BatchTempFolderDirectory!\Aliases\Combined_ZLC_Alias.txt"
	
	TYPE "!Selected_FE-Buddy_Directory!\ALIAS\STAR_DP_Fixes_Alias.txt">>"!BatchTempFolderDirectory!\Aliases\Combined_ZLC_Alias.txt"
	ECHO            -STAR_DP_Fixes_Alias.txt
	(
	ECHO.
	ECHO.
	)>>"!BatchTempFolderDirectory!\Aliases\Combined_ZLC_Alias.txt"
	
	TYPE "!Selected_FE-Buddy_Directory!\ALIAS\TELEPHONY.txt">>"!BatchTempFolderDirectory!\Aliases\Combined_ZLC_Alias.txt"
	ECHO            -TELEPHONY.txt
	
	ECHO.
	ECHO.
	
	goto :eof

:MoveFinalizedFiles
	ECHO.
	ECHO.
	ECHO.
	ECHO                    ------------------------------
	ECHO                        Moving Finalized Files
	ECHO                    ------------------------------
	ECHO.
	ECHO.
	ECHO     Moving the finalized alias and videomaps ^(geojson^) files here:
	ECHO          !Selected_FE-Buddy_Directory!\UPLOAD_TO_vNAS
	
	type "!BatchTempFolderDirectory!\Aliases\Combined_ZLC_Alias.txt">"!Selected_FE-Buddy_Directory!\UPLOAD_TO_vNAS\Combined_ZLC_Alias.txt"
	MOVE /Y "!BatchTempFolderDirectory!\GeoJSONs\Finalized GeoJSONs\*.geojson" "!Selected_FE-Buddy_Directory!\UPLOAD_TO_vNAS\VIDEO_MAPS" >NUL 2>&1
	ECHO                 -Move complete

	goto :eof

:DoneWithScript

	
	if exist "!BatchTempFolderDirectory!" RD /S /Q "!BatchTempFolderDirectory!"
	
	ECHO.
	ECHO.
	ECHO.
	ECHO                    ------------
	ECHO                        DONE
	ECHO                    ------------
	ECHO.
	ECHO.
	ECHO This script has downloaded the latest ZLC Custom Alias commands from
	ECHO GitHub and added the FE-Buddy aliases to it into a Combined_ZLC_Alias.txt file
	ECHO.
	ECHO It also took the desired GeoJSON files output by FE-Buddy and added the ZLC CRC
	ECHO defaults to them and renamed them.
	ECHO.
	ECHO.
	ECHO These files have been moved to:
	ECHO !Selected_FE-Buddy_Directory!\UPLOAD_TO_vNAS
	ECHO.
	ECHO.
	ECHO Press any key to close this CMD Prompt window and have the UPLOAD_TO_vNAS folder.
	ECHO ...Otherwise, just close the prompt via the red-X in the top righthand corner.
	
	PAUSE>NUL
	
	start /B /WAIT explorer.exe "!Selected_FE-Buddy_Directory!\UPLOAD_TO_vNAS"

	EXIT
	