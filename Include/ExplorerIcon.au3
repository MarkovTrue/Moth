#include-once

#include <WinAPI.au3>

; ============================================================
; ExplorerIcon – иконка файла, как её показывает Проводник
; ============================================================
; Разбирает ассоциации в реестре (UserChoice, ProgID, CurVer, PerceivedType),
; ярлыки и папки. Возвращает файл и индекс иконки, саму иконку не грузит.


; Иконка файла, как её показывает проводник: [2, файл иконки, индекс]. Для .lnk - иконка ярлыка,
; для папки и расширения - по ассоциации в реестре
Func _ExplorerIcon_Get($sFile)
	Local $iOldExpand = Opt("ExpandEnvStrings", 1)
	Local $sRegDefault = "", $sDefIcon = "", $sExecutable, $sExt, $aTargetIcon, $aLinkInfo, $hSearch, $sIconFile, $iIcon = 0, $iError = 0, $aRet[3]

	If StringInStr(FileGetAttrib($sFile & "\"), "D") Then
		$sRegDefault = RegRead("HKCR\Folder", "")

		If $sRegDefault <> "" Then
			$sDefIcon = RegRead("HKCR\Folder\DefaultIcon", "")
		EndIf
	Else
		$sExt = StringRegExpReplace($sFile, '^.*\.', '.')

		If $sExt = ".exe" And FileExists($sFile) Then
			Opt("ExpandEnvStrings", $iOldExpand)

			$aRet[0] = 2
			$aRet[1] = $sFile
			$aRet[2] = 0
			Return $aRet
		EndIf

		If $sExt = ".lnk" Then
			$aLinkInfo = FileGetShortcut($sFile)

			If Not @error Then
				Opt("ExpandEnvStrings", $iOldExpand)

				If Not FileExists($aLinkInfo[4]) Then
					$aTargetIcon = _ExplorerIcon_Get($aLinkInfo[0])

					If Not @error Then
						$aLinkInfo[4] = $aTargetIcon[1]
						$aLinkInfo[5] = $aTargetIcon[2]
					EndIf
				EndIf

				If $aLinkInfo[5] > 0 Then
					$aLinkInfo[5] = BitNOT($aLinkInfo[5])
				ElseIf $aLinkInfo[5] < 0 Then
					$aLinkInfo[5] = BitNOT($aLinkInfo[5]) + 1
				EndIf

				$aRet[0] = 2
				$aRet[1] = $aLinkInfo[4]
				$aRet[2] = $aLinkInfo[5]
				Return $aRet
			EndIf
		EndIf

		If $sExt = $sFile Then
			$hSearch = FileFindFirstFile($sFile & ".*")
			$sExt = StringRegExpReplace(FileFindNextFile($hSearch), '^.*\.', '.')
			$sFile &= $sExt
			FileClose($hSearch)
		EndIf

		; Старое место ассоциации, до UserChoice
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
		; Версионный ProgID (так регистрирует Adobe): иконка у текущей версии
		$sDefIcon = RegRead("HKCR\" & $sRegDefault & "\CurVer", "")

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
			$iIcon = 0
		Else
			Local $aDefIconSplit = StringSplit($sDefIcon, ",")

			If IsArray($aDefIconSplit) Then
				$sIconFile = $aDefIconSplit[1]

				If $aDefIconSplit[0] > 1 Then
					$iIcon = $aDefIconSplit[2]
				EndIf
			Else
				$iError = 1
			EndIf
		EndIf
	Else
		$sIconFile = $sFile
		$iIcon = 0
	EndIf

	$sIconFile = StringRegExpReplace($sIconFile, '\A"+|"+\z', '')
	If Not FileExists($sIconFile) And Not FileExists(@SystemDir & "\" & $sIconFile) Then
		$sExecutable = _WinAPI_FindExecutable($sFile)

		If FileExists($sExecutable) Then
			$sIconFile = $sExecutable
		EndIf
	EndIf

	Opt("ExpandEnvStrings", $iOldExpand)

	$aRet[0] = 2
	$aRet[1] = $sIconFile
	$aRet[2] = $iIcon
	Return SetError($iError, 0, $aRet)
EndFunc   ;==>_ExplorerIcon_Get
