(**********************************************************)
(* EPS Batch Update - AppleScript version                  *)
(* - Raw EPS replace for <50KB files                        *)
(* - Font mapping in Illustrator                            *)
(* - Legacy text refresh                                    *)
(* - Stray point removal via menu                           *)
(* - CMYK + Grayscale conversion via menu                   *)
(**********************************************************)

property fontMap : {{"Myriad-Roman", "NewCenturySchlbkLTStd-Roman"}, {"Myriad-Bold", "HelveticaLTStd-Bold"}, {"HelveticaLTStd-Roman-Bold", "HelveticaLTStd-Bold"}, {"Helvetica", "HelveticaLTStd-Roman"}, {"Helvetica-Bold", "HelveticaLTStd-Bold"}, {"Helvetica-Bold", "HelveticaLTStd-Bold"}, {"NewCenturySchlbk-Roman", "NewCenturySchlbkLTStd-Roman"}, {"NewCenturySchlbk-Italic", "NewCenturySchlbkLTStd-It"}, {"Helvetica-Oblique", "HelveticaLTStd-Obl"}, {"HelveticaNeue-Medium", "HelveticaNeueLTStd-Md"}, {"NewCenturySchlbk-Bold", "NewCenturySchlbkLTStd-Bd"}, {"Helvetica-Condensed-Bold", "HelveticaLTStd-BoldCond"}, {"HelveticaLTStd-RomanNeue-Medium", "HelveticaNeueLTStd-Md"}, {"Futura-Heavy", "FuturaStd-Heavy"}, {"ZapfDingbats", "ZapfDingbatsITC"}}

property fontMapBasic : {{"Myriad-Roman", "NewCenturySchlbkLTStd-Roman"}, {"Myriad-Bold", "HelveticaLTStd-Bold"}, {"HelveticaLTStd-Roman-Bold", "HelveticaLTStd-Bold"}, {"Helvetica", "HelveticaLTStd-Roman"}, {"Helvetica-Bold", "HelveticaLTStd-Bold"}, {"NewCenturySchlbk-Roman", "NewCenturySchlbkLTStd-Roman"}, {"NewCenturySchlbk-Italic", "NewCenturySchlbkLTStd-It"}, {"Helvetica-Oblique", "HelveticaLTStd-Obl"}, {"HelveticaNeue-Medium", "HelveticaNeueLTStd-Md"}, {"NewCenturySchlbk-Bold", "NewCenturySchlbkLTStd-Bd"}, {"moveto y show", "moveto   s 48 ge {y show} if"}, {"Helvetica-Condensed-Bold", "HelveticaLTStd-BoldCond"}, {"HelveticaLTStd-RomanLTStd-Roman", "HelveticaLTStd-Roman"}, {"HelveticaLTStd-RomanNeue-Medium", "HelveticaNeueLTStd-Md"}, {"Futura-Heavy", "FuturaStd-Heavy"}}

property rawSizeLimit : 50000

on run
	my requireAccessibility()
	tell application "Finder"
		set chosenFolder to choose folder with prompt "Choose a folder of EPS files to update..."
	end tell
	
	my bringToFront()
	set saveChoice to button returned of (display dialog "Save updated files to:" buttons {"Overwrite Original Files", "Choose Output Folder"} default button "Overwrite Original Files")
	if saveChoice is "Choose Output Folder" then
		tell application "Finder"
			set outputFolder to choose folder with prompt "Choose a folder to save updated EPS files..."
		end tell
	else
		set outputFolder to chosenFolder
	end if
	
	set epsFiles to my listEPSFiles(chosenFolder)
	if (count of epsFiles) = 0 then
		display dialog "No .eps files found in that folder." buttons {"OK"}
		return
	end if
	
	set rawReplaced to 0
	set rawReplaceErrors to {}
	set rgbFiles to {}
	
	repeat with thisFile in epsFiles
		if (size of thisFile) < rawSizeLimit then
			try
				if my rawReplaceInFile(thisFile, fontMapBasic) then
					set rawReplaced to rawReplaced + 1
				end if
			on error
				set end of rawReplaceErrors to (name of thisFile)
			end try
		end if
		
		try
			my processEPS(thisFile, outputFolder)
			if my isDocumentRGB() then set end of rgbFiles to (name of thisFile)
		on error errMsg
			display dialog "Failed processing: " & (name of thisFile) & return & errMsg buttons {"OK"}
		end try
	end repeat
	
	set summary to "Completed. " & (count of epsFiles) & " file(s) processed." & return
	
	if (count of rawReplaceErrors) > 0 then
		set summary to summary & "Raw EPS replace failed in:" & return & (my joinLines(rawReplaceErrors)) & return
	end if
	
	if (count of rgbFiles) > 0 then
		set summary to summary & "Files still in RGB:" & return & (my joinLines(rgbFiles)) & return
	end if
	
	display dialog summary buttons {"OK"}
end run

on bringToFront()
	try
		tell application "System Events"
			set frontmost of process (name of current application) to true
		end tell
	end try
end bringToFront

on requireAccessibility()
	set appPath to (POSIX path of (path to me))
	try
		tell application "System Events"
			tell process "Adobe Illustrator"
				set _ to frontmost
			end tell
		end tell
	on error errMsg number errNum
		display dialog "Accessibility/Automation permissions are required.

1) System Settings > Privacy & Security > Accessibility: enable this app:
   " & appPath & "
2) System Settings > Privacy & Security > Automation: allow this app to control Adobe Illustrator

If you recompiled the app, remove and re-add it in Accessibility.

Error " & errNum & ": " & errMsg buttons {"OK"}
		error number -128
	end try
end requireAccessibility

on listEPSFiles(theFolder)
	tell application "Finder"
		set theFiles to every file of theFolder whose name ends with ".eps"
	end tell
	return theFiles
end listEPSFiles

on rawReplaceInFile(theFile, theMap)
	set fileText to my readFile(theFile)
	set newText to fileText
	repeat with fontPair in theMap
		set findText to item 1 of fontPair
		set replaceText to item 2 of fontPair
		set newText to my replaceText(newText, findText, replaceText)
	end repeat
	if newText is not fileText then
		my writeFile(theFile, newText)
		return true
	end if
	return false
end rawReplaceInFile

on processEPS(theFile, outFolder)
	tell application "Adobe Illustrator"
		activate
		set prevInteraction to user interaction level
		set user interaction level to never interact
		open (theFile as alias) without dialogs
		set theDoc to current document
		
		my unlockAllLayers(theDoc)
		
		-- Stray points
		my removeStrayPoints()
		
		-- Font mapping
		my replaceFontsInDocument(theDoc)
		
		-- Legacy text refresh (best effort)
		my refreshLegacyText(theDoc)
		
		-- Color conversion
		my convertToCmykAndGrayscale()
		
		set outFilePath to ((outFolder as string) & (name of theFile))
		save theDoc in file outFilePath as eps
		close theDoc saving no
		set user interaction level to prevInteraction
	end tell
end processEPS

on unlockAllLayers(theDoc)
	try
		tell application "Adobe Illustrator"
			tell theDoc
				repeat with i from 1 to count of layers
					set thisLayer to layer i
					set locked of thisLayer to false
					set visible of thisLayer to true
				end repeat
			end tell
		end tell
	end try
end unlockAllLayers

on replaceFontsInDocument(theDoc)
	tell application "Adobe Illustrator"
		tell theDoc
			set allCharacters to (every character of every story)
			repeat with nextCharacter in allCharacters
				try
					set fontName to the name of (text font of nextCharacter)
					repeat with fontPair in fontMap
						if fontName is (item 1 of fontPair) then
							set text font of nextCharacter to text font (item 2 of fontPair) of application "Adobe Illustrator"
						end if
					end repeat
				end try
			end repeat
		end tell
	end tell
end replaceFontsInDocument

on refreshLegacyText(theDoc)
	tell application "Adobe Illustrator"
		tell theDoc
			repeat with i from 1 to count of text frames
				try
					set tf to text frame i
					set originalText to contents of tf
					set contents of tf to ""
					set contents of tf to originalText
				end try
			end repeat
		end tell
	end tell
end refreshLegacyText

on convertToCmykAndGrayscale()
	tell application "Adobe Illustrator" to activate
	try
		tell application "System Events"
			set frontmost of process "Adobe Illustrator" to true
		end tell
	end try
	delay 0.2
	
	tell application "System Events"
		tell process "Adobe Illustrator"
			tell menu bar 1
				tell menu bar item "File"
					tell menu "File"
						tell menu item "Document Color Mode"
							tell menu "Document Color Mode"
								click menu item "CMYK Color"
							end tell
						end tell
					end tell
				end tell
				
				tell menu bar item "Select"
					tell menu "Select"
						click menu item "All"
					end tell
				end tell
				
				tell menu bar item "Edit"
					tell menu "Edit"
						tell menu item "Edit Colors"
							tell menu "Edit Colors"
								click menu item "Convert to Grayscale"
							end tell
						end tell
					end tell
				end tell
			end tell
		end tell
	end tell
end convertToCmykAndGrayscale

on removeStrayPoints()
	tell application "Adobe Illustrator" to activate
	try
		tell application "System Events"
			set frontmost of process "Adobe Illustrator" to true
		end tell
	end try
	delay 0.2
	
	tell application "System Events"
		tell process "Adobe Illustrator"
			try
				tell menu bar 1
					tell menu bar item "Select"
						tell menu "Select"
							tell menu item "Object"
								tell menu "Object"
									click menu item "Stray Points"
								end tell
							end tell
						end tell
					end tell
				end tell
			end try
			delay 0.1
			
			-- delete selection (try Clear then Delete)
			try
				tell menu bar 1
					tell menu bar item "Edit"
						tell menu "Edit"
							click menu item "Clear"
						end tell
					end tell
				end tell
			end try
			try
				key code 51
			end try
		end tell
	end tell
end removeStrayPoints

on isDocumentRGB()
	try
		tell application "Adobe Illustrator"
			set theDoc to current document
			set cs to document color space of theDoc
		end tell
		return cs is RGB
	on error
		return false
	end try
end isDocumentRGB

on readFile(theFile)
	set resultingFile to theFile as string
	return read file resultingFile as text
end readFile

on writeFile(theFile, theText)
	try
		set theFile to theFile as string
		set theOpenedFile to open for access file theFile with write permission
		set eof of theOpenedFile to 0
		write theText to theOpenedFile starting at eof
		close access theOpenedFile
		return true
	on error
		try
			close access file theFile
		end try
		return false
	end try
end writeFile

on replaceText(thisText, searchString, replacementString)
	set AppleScript's text item delimiters to searchString
	set theItems to every text item of thisText
	set AppleScript's text item delimiters to replacementString
	set thisText to theItems as string
	set AppleScript's text item delimiters to {""}
	return thisText
end replaceText

on joinLines(theList)
	set AppleScript's text item delimiters to return
	set outText to theList as string
	set AppleScript's text item delimiters to {""}
	return outText
end joinLines
