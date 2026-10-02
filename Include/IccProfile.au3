#include-once

#include <FileConstants.au3>

; ============================================================
; IccProfile - ICC-профиль картинки и проверка, что он равен sRGB.
;
; Картинка без профиля считается sRGB, поэтому профиль sRGB можно вырезать,
; и цвет не изменится. Любой другой профиль (Display P3, Adobe RGB, гамма 2.2,
; CMYK, профили с таблицами LUT) задаёт цвет, без него картинка поблёкнет или
; поплывёт. Такие профили сохраняются.
;
; Решение принимается по данным профиля, а не по названию: основные цвета
; и кривая яркости сравниваются с эталоном sRGB. Если хоть что-то не совпало
; или не распозналось, профиль считается не sRGB и остаётся.
;
; _IccProfile_FromFile($sPath)  - профиль из JPEG (APP2) или WEBP (чанк ICCP)
; _IccProfile_IsSrgb($dIcc)     - True, если профиль по данным равен sRGB
; ============================================================

; Допуск сравнения: основные цвета (XYZ, D50) и кривая яркости (0..1)
Global Const $__ICC_TOLERANCE = 0.003

; sRGB в PCS D50, как в профилях sRGB IEC61966-2.1: rXYZ, gXYZ, bXYZ
Global Const $__ICC_SRGB_XYZ[9] = [0.4361, 0.2225, 0.0139, 0.3851, 0.7169, 0.0971, 0.1431, 0.0606, 0.7141]


; Профиль из JPEG (сегменты APP2 ICC_PROFILE, собираются по номерам) или WEBP (чанк ICCP).
; Возвращает Binary, пустой - профиля нет.
; @error: 1 - файл не прочитан, 2 - не JPEG и не WEBP: профиль нужно искать иначе
Func _IccProfile_FromFile($sPath)
	Local $hFile = FileOpen($sPath, $FO_BINARY)
	If $hFile = -1 Then Return SetError(1, 0, Binary(''))
	Local $dData = FileRead($hFile)
	FileClose($hFile)
	If BinaryLen($dData) < 16 Then Return SetError(1, 0, Binary(''))

	If __IccProfile_U16($dData, 0) = 0xFFD8 Then Return __IccProfile_FromJpeg($dData)
	If BinaryToString(BinaryMid($dData, 1, 4)) = 'RIFF' And BinaryToString(BinaryMid($dData, 9, 4)) = 'WEBP' Then
		Return __IccProfile_FromWebp($dData)
	EndIf
	Return SetError(2, 0, Binary(''))
EndFunc   ;==>_IccProfile_FromFile


; True, если профиль по данным равен sRGB: пространство RGB, матрица без LUT,
; основные цвета и кривые всех трёх каналов совпадают с sRGB в пределах допуска
Func _IccProfile_IsSrgb($dIcc)
	Local $iLen = BinaryLen($dIcc)
	If $iLen < 132 Then Return False
	If BinaryToString(BinaryMid($dIcc, 17, 4)) <> 'RGB ' Then Return False

	Local $iCount = __IccProfile_U32($dIcc, 128)
	If $iCount < 1 Or 132 + $iCount * 12 > $iLen Then Return False

	; Смещения нужных тегов. С таблицами LUT (A2B*/B2A*) цвет считает не матрица,
	; ручаться за такой профиль нельзя
	Local $aOff[6] = [0, 0, 0, 0, 0, 0], $aSig[6] = ['rXYZ', 'gXYZ', 'bXYZ', 'rTRC', 'gTRC', 'bTRC']
	Local $sSig, $iOff
	For $i = 0 To $iCount - 1
		$sSig = BinaryToString(BinaryMid($dIcc, 133 + $i * 12, 4))
		$iOff = __IccProfile_U32($dIcc, 132 + $i * 12 + 4)
		If StringRegExp($sSig, '^(A2B|B2A)\d$') Then Return False
		For $j = 0 To 5
			If $sSig == $aSig[$j] Then $aOff[$j] = $iOff
		Next
	Next
	For $j = 0 To 5
		If $aOff[$j] = 0 Or $aOff[$j] + 20 > $iLen Then Return False
	Next

	; Основные цвета
	For $j = 0 To 2
		If BinaryToString(BinaryMid($dIcc, $aOff[$j] + 1, 4)) <> 'XYZ ' Then Return False
		For $k = 0 To 2
			If Abs(__IccProfile_S15F16($dIcc, $aOff[$j] + 8 + $k * 4) - $__ICC_SRGB_XYZ[$j * 3 + $k]) > $__ICC_TOLERANCE Then Return False
		Next
	Next

	; Кривые яркости: 65 точек от 0 до 1 против формулы sRGB
	Local $x, $y
	For $j = 3 To 5
		For $i = 0 To 64
			$x = $i / 64
			$y = __IccProfile_Curve($dIcc, $aOff[$j], $x)
			If @error Then Return False
			If Abs($y - __IccProfile_SrgbEotf($x)) > $__ICC_TOLERANCE Then Return False
		Next
	Next
	Return True
EndFunc   ;==>_IccProfile_IsSrgb


; ------------------------------------------------------------
; Внутреннее
; ------------------------------------------------------------

Func __IccProfile_FromJpeg($dData)
	Local $iLen = BinaryLen($dData), $iPos = 2, $iMarker, $iSegLen
	Local $aParts[256], $iTotal = 0, $iFound = 0
	While $iPos + 4 <= $iLen
		If __IccProfile_U8($dData, $iPos) <> 0xFF Then ExitLoop
		$iMarker = __IccProfile_U8($dData, $iPos + 1)
		If $iMarker = 0xFF Then ; заполнитель
			$iPos += 1
			ContinueLoop
		EndIf
		; Начало данных или конец файла: заголовки кончились
		If $iMarker = 0xDA Or $iMarker = 0xD9 Then ExitLoop
		If $iMarker = 0x01 Or ($iMarker >= 0xD0 And $iMarker <= 0xD7) Then
			$iPos += 2
			ContinueLoop
		EndIf
		$iSegLen = __IccProfile_U16($dData, $iPos + 2)
		If $iSegLen < 2 Or $iPos + 2 + $iSegLen > $iLen Then ExitLoop
		; APP2: "ICC_PROFILE\0", номер части, число частей, данные
		If $iMarker = 0xE2 And $iSegLen > 16 And BinaryToString(BinaryMid($dData, $iPos + 5, 12)) = 'ICC_PROFILE' & Chr(0) Then
			Local $iSeq = __IccProfile_U8($dData, $iPos + 16)
			$iTotal = __IccProfile_U8($dData, $iPos + 17)
			If $iSeq >= 1 Then
				$aParts[$iSeq] = BinaryMid($dData, $iPos + 19, $iSegLen - 16)
				$iFound += 1
			EndIf
		EndIf
		$iPos += 2 + $iSegLen
	WEnd
	If $iFound = 0 Then Return Binary('')

	; Части склеиваются по номерам; без какой-то части профиль битый - считаем, что его нет
	Local $dIcc = Binary('')
	For $i = 1 To ($iTotal > 0 ? $iTotal : $iFound)
		If Not IsBinary($aParts[$i]) Then Return Binary('')
		$dIcc &= $aParts[$i]
	Next
	Return $dIcc
EndFunc   ;==>__IccProfile_FromJpeg


Func __IccProfile_FromWebp($dData)
	Local $iLen = BinaryLen($dData), $iPos = 12, $iSize
	While $iPos + 8 <= $iLen
		$iSize = __IccProfile_U32LE($dData, $iPos + 4)
		If BinaryToString(BinaryMid($dData, $iPos + 1, 4)) = 'ICCP' Then Return BinaryMid($dData, $iPos + 9, $iSize)
		$iPos += 8 + $iSize + Mod($iSize, 2)
	WEnd
	Return Binary('')
EndFunc   ;==>__IccProfile_FromWebp


; Значение кривой TRC в точке $x (0..1). Типы curv (таблица или гамма) и para
Func __IccProfile_Curve($dIcc, $iOff, $x)
	Local $sType = BinaryToString(BinaryMid($dIcc, $iOff + 1, 4))
	If $sType = 'curv' Then
		Local $iN = __IccProfile_U32($dIcc, $iOff + 8)
		If $iN = 0 Then Return $x
		If $iN = 1 Then Return $x ^ (__IccProfile_U16($dIcc, $iOff + 12) / 256)
		If $iOff + 12 + $iN * 2 > BinaryLen($dIcc) Then Return SetError(1, 0, 0)
		Local $f = $x * ($iN - 1), $i0 = Int($f)
		If $i0 >= $iN - 1 Then Return __IccProfile_U16($dIcc, $iOff + 12 + ($iN - 1) * 2) / 65535
		Local $y0 = __IccProfile_U16($dIcc, $iOff + 12 + $i0 * 2) / 65535
		Local $y1 = __IccProfile_U16($dIcc, $iOff + 12 + ($i0 + 1) * 2) / 65535
		Return $y0 + ($y1 - $y0) * ($f - $i0)
	ElseIf $sType = 'para' Then
		Local $iFunc = __IccProfile_U16($dIcc, $iOff + 8)
		Local $aP[7] = [1, 1, 0, 0, 0, 0, 0], $aCount[5] = [1, 3, 4, 5, 7]
		If $iFunc < 0 Or $iFunc > 4 Then Return SetError(1, 0, 0)
		For $i = 0 To $aCount[$iFunc] - 1
			$aP[$i] = __IccProfile_S15F16($dIcc, $iOff + 12 + $i * 4)
		Next
		Local $g = $aP[0], $a = $aP[1], $b = $aP[2], $c = $aP[3], $d = $aP[4], $e = $aP[5], $ff = $aP[6]
		Switch $iFunc
			Case 0
				Return $x ^ $g
			Case 1
				Return ($a <> 0 And $x >= -$b / $a) ? __IccProfile_Pow($a * $x + $b, $g) : 0
			Case 2
				Return ($a <> 0 And $x >= -$b / $a) ? __IccProfile_Pow($a * $x + $b, $g) + $c : $c
			Case 3
				Return $x >= $d ? __IccProfile_Pow($a * $x + $b, $g) : $c * $x
			Case 4
				Return $x >= $d ? __IccProfile_Pow($a * $x + $b, $g) + $e : $c * $x + $ff
		EndSwitch
	EndIf
	Return SetError(1, 0, 0)
EndFunc   ;==>__IccProfile_Curve


Func __IccProfile_Pow($v, $g)
	Return $v <= 0 ? 0 : $v ^ $g
EndFunc   ;==>__IccProfile_Pow


; Кривая sRGB IEC 61966-2-1: из значения канала в линейную яркость
Func __IccProfile_SrgbEotf($x)
	Return $x <= 0.04045 ? $x / 12.92 : (($x + 0.055) / 1.055) ^ 2.4
EndFunc   ;==>__IccProfile_SrgbEotf


; Числа в профиле big-endian. Смещения от нуля
Func __IccProfile_U8($d, $iOff)
	Return Int(BinaryMid($d, $iOff + 1, 1))
EndFunc   ;==>__IccProfile_U8


Func __IccProfile_U16($d, $iOff)
	Return __IccProfile_U8($d, $iOff) * 256 + __IccProfile_U8($d, $iOff + 1)
EndFunc   ;==>__IccProfile_U16


Func __IccProfile_U32($d, $iOff)
	Return __IccProfile_U16($d, $iOff) * 65536 + __IccProfile_U16($d, $iOff + 2)
EndFunc   ;==>__IccProfile_U32


Func __IccProfile_U32LE($d, $iOff)
	Return __IccProfile_U8($d, $iOff) + __IccProfile_U8($d, $iOff + 1) * 256 + __IccProfile_U8($d, $iOff + 2) * 65536 + __IccProfile_U8($d, $iOff + 3) * 16777216
EndFunc   ;==>__IccProfile_U32LE


Func __IccProfile_S15F16($d, $iOff)
	Local $v = __IccProfile_U32($d, $iOff)
	If $v >= 2147483648 Then $v -= 4294967296
	Return $v / 65536
EndFunc   ;==>__IccProfile_S15F16
