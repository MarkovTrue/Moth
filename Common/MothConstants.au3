#include-once

; ============================================================================
;  MothConstants.au3
;  Что умеет движок и не настраивает пользователь: фильтры ресайза, окна-приёмники.
;  Настройки пользователя - в Moth.ini. Подключается из MothCommon.au3
; ============================================================================

; Фильтры ресайза, индекс - последнее число команды (percent_50_0 - Lanczos).
; Фото - Lanczos или RobidouxSharp, графика - Catrom или Mitchell, пиксель-арт - Point или Box
Global Const $gc_aResizeFilters = ['Lanczos', 'RobidouxSharp', 'Catrom', 'Mitchell', 'Point', 'Box']

; Окна-приёмники CopyDataQueue: очередь заданий Moth и первое окно Menu
; (пути остальных файлов выделения)
Global Const $gc_sIpcMoth = 'Moth.Queue.7F3A'
Global Const $gc_sIpcMenu = 'Moth.Menu.7F3A'
