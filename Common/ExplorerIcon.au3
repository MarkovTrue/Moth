#include-once

#include <WinAPI.au3>


Func _FileGetIcon($sFile)
	Local $iOld_Opt_EES = Opt("ExpandEnvStrings", 1)
	Local $sRegDefault = "", $sDefIcon = "", $sExecutable, $sExt, $a_LinkInfo, $hSearch, $sIconFile, $nIcon = 0, $iError = 0, $aRet[3]

	If StringInStr(FileGetAttrib($sFile & "\"), "D") Then
		$sRegDefault = RegRead("HKCR\Folder", "")

		If $sRegDefault <> "" Then
			$sDefIcon = RegRead("HKCR\Folder\DefaultIcon", "")
		EndIf
	Else
		$sExt = StringRegExpReplace($sFile, '^.*\.', '.')

		If $sExt = ".exe" And FileExists($sFile) Then
			Opt("ExpandEnvStrings", $iOld_Opt_EES)

			Dim $aRet[3] = [2, $sFile, 0]
			Return $aRet
		EndIf

		If $sExt = ".lnk" Then
			$aLinkInfo = FileGetShortcut($sFile)

			If Not @error Then
				Opt("ExpandEnvStrings", $iOld_Opt_EES)

				If Not FileExists($aLinkInfo[4]) Then
					$a_LinkInfo = _FileGetIcon($aLinkInfo[0])

					If Not @error Then
						$aLinkInfo[4] = $a_LinkInfo[1]
						$aLinkInfo[5] = $a_LinkInfo[2]
					EndIf
				EndIf

				If $aLinkInfo[5] > 0 Then
					$aLinkInfo[5] = BitNOT($aLinkInfo[5])
				ElseIf $aLinkInfo[5] < 0 Then
					$aLinkInfo[5] = BitNOT($aLinkInfo[5]) + 1
				EndIf

				Dim $aRet[3] = [2, $aLinkInfo[4], $aLinkInfo[5]]
				Return $aRet
			EndIf
		EndIf

		If $sExt = $sFile Then
			$hSearch = FileFindFirstFile($sFile & ".*")
			$sExt = StringRegExpReplace(FileFindNextFile($hSearch), '^.*\.', '.')
			$sFile &= $sExt
			FileClose($hSearch)
		EndIf

		; Возможно устарело, пусть будет
		$sRegDefault = RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\" & $sExt, "ProgID")

		If $sRegDefault = "" Then
			$sRegDefault = RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\" & $sExt & "\UserChoice", "ProgID")
		EndIf

		If $sRegDefault = "" Then
			$sRegDefault = RegRead("HKCR\" & $sExt, "")
		EndIf

		If $sRegDefault <> "" Then
			$sDefIcon = RegRead("HKCR\" & $sRegDefault & "\DefaultIcon", "")

			If $sDefIcon = "" Then
				$sDefIcon = RegRead("HKCR\" & $sExt & "\DefaultIcon", "")
			EndIf
		Else
			$sRegDefault = RegRead("HKCR\" & $sExt, "PerceivedType")

			If $sRegDefault <> "" Then
				$sRegDefault = RegRead("HKCR\SystemFileAssociations\" & $sRegDefault & "\DefaultIcon", "")
			EndIf
		EndIf
	EndIf

	If $sDefIcon = "" And $sRegDefault <> "" Then
		$sDefIcon = RegRead("HKCR\" & $sRegDefault & "\CurVer", "") ; ADOBE PERVERSION....

		If $sDefIcon Then
			$sDefIcon = RegRead("HKCR\" & $sDefIcon & "\DefaultIcon", "")
		Else
			$sDefIcon = RegRead("HKCR\" & $sRegDefault & "\shell\open\command", "")
			$sDefIcon = StringReplace($sDefIcon, ' "%1"', '')
		EndIf
	EndIf

	If $sDefIcon = "" Then
		$sIconFile = "shell32.dll"
	ElseIf Not StringRegExp($sDefIcon, '\A"*%1"*\z') Then
		If StringRegExpReplace($sFile, "^.*\\", "") = "shell32.dll" Then
			$sIconFile = $sFile
			$nIcon = 0
		Else
			Local $aDefIconSplit = StringSplit($sDefIcon, ",")

			If IsArray($aDefIconSplit) Then
				$sIconFile = $aDefIconSplit[1]

				If $aDefIconSplit[0] > 1 Then
					$nIcon = $aDefIconSplit[2]
				EndIf
			Else
				$iError = 1
			EndIf
		EndIf
	Else
		$sIconFile = $sFile
		$nIcon = 0
	EndIf

	$sIconFile = StringRegExpReplace($sIconFile, '\A"+|"+\z', '')
	If Not FileExists($sIconFile) And Not FileExists(@SystemDir & "\" & $sIconFile) Then
		$sExecutable = _WinAPI_FindExecutable($sFile)

		If FileExists($sExecutable) Then
			$sIconFile = $sExecutable
		EndIf
	EndIf

	Opt("ExpandEnvStrings", $iOld_Opt_EES)

;~ 	If $nIcon > 0 Then
;~ 		$nIcon = BitNOT($nIcon)
;~ 	ElseIf $nIcon < 0 Then
;~ 		$nIcon = BitNOT($nIcon) + 1
;~ 	EndIf

	Dim $aRet[3] = [2, $sIconFile, $nIcon]
	Return SetError($iError, 0, $aRet)
EndFunc   ;==>_FileGetIcon
