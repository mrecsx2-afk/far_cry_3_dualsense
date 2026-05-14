; ==============================================================================
;  FC3 DualSense Adaptive Triggers  —  v4.1 (Force UDP Loop)
;  Язык: AutoHotkey v2
;  Автор: Kirill
; ==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

; ── Настройки DSX UDP ─────────────────────────────────────────────────────────
DSX_IP := "127.0.0.1"
DSX_PORT := 6969
CONFIG_FILE := A_ScriptDir "\loadout.ini"
LOG_FILE := A_ScriptDir "\fc3_triggers.log"

; ── Процессы FC3 ──────────────────────────────────────────────────────────────
FC3_EXE := ["farcry3.exe", "farcry3_d3d11.exe"]

; ── Текущее состояние ─────────────────────────────────────────────────────────
global CurrentWeapon := "pistol"
global CurrentSlot   := 1
global IsDriving     := false
global TempEffectActive := ""

; ==============================================================================
;  ПРОФИЛИ ТРИГГЕРОВ (UDP API)
; ==============================================================================
global Presets := Map(
    "pistol", {name: "Пистолет", L2: [13, 4, 5, 0, 0, 0, 0, 0], R2: [16, 2, 7, 6, 0, 0, 0, 0]},
    "smg", {name: "Пистолет-пулемёт", L2: [13, 3, 5, 0, 0, 0, 0, 0], R2: [17, 3, 5, 15, 0, 0, 0, 0]},
    "shotgun", {name: "Дробовик", L2: [13, 3, 6, 0, 0, 0, 0, 0], R2: [16, 0, 8, 8, 0, 0, 0, 0]},
    "rifle", {name: "Винтовка", L2: [13, 4, 7, 0, 0, 0, 0, 0], R2: [17, 2, 6, 20, 0, 0, 0, 0]},
    "sniper", {name: "Снайперка", L2: [7, 0, 0, 0, 0, 0, 0, 0], R2: [14, 5, 8, 8, 8, 0, 0, 0]},
    "lmg", {name: "Пулемёт", L2: [13, 3, 5, 0, 0, 0, 0, 0], R2: [18, 0, 9, 6, 5, 20, 1, 0]},
    "bow", {name: "Лук", L2: [13, 2, 4, 0, 0, 0, 0, 0], R2: [14, 2, 7, 8, 8, 0, 0, 0]},
    "rpg", {name: "РПГ", L2: [13, 4, 6, 0, 0, 0, 0, 0], R2: [7, 0, 0, 0, 0, 0, 0, 0]},
    "grenade", {name: "Граната", L2: [0, 0, 0, 0, 0, 0, 0, 0], R2: [13, 0, 8, 0, 0, 0, 0, 0]},
    "drive", {name: "Вождение", L2: [13, 5, 8, 0, 0, 0, 0, 0], R2: [13, 2, 5, 0, 0, 0, 0, 0]},
    "sprint", {name: "Спринт", L2: [15, 0, 9, 2, 5, 0, 0, 0], R2: [15, 0, 9, 2, 5, 0, 0, 0]},
    "jump", {name: "Прыжок", L2: [7, 0, 0, 0, 0, 0, 0, 0], R2: [7, 0, 0, 0, 0, 0, 0, 0]},
    "loot", {name: "Взаимодействие", L2: [18, 0, 9, 8, 4, 30, 1, 0], R2: [18, 0, 9, 8, 4, 30, 1, 0]},
    "heal", {name: "Лечение", L2: [11, 200, 0, 0, 0, 0, 0, 0], R2: [11, 200, 0, 0, 0, 0, 0, 0]},
    "reset", {name: "Сброс", L2: [0, 0, 0, 0, 0, 0, 0, 0], R2: [0, 0, 0, 0, 0, 0, 0, 0]}
)

global WeaponList := ["pistol","smg","shotgun","rifle","sniper","lmg","bow","rpg","grenade"]
global Slots := Map(1,"pistol", 2,"rifle", 3,"shotgun", 4,"bow")

; ==============================================================================
;  ЗАГРУЗКА / СОХРАНЕНИЕ КОНФИГА
; ==============================================================================

LoadConfig() {
    global Slots, CONFIG_FILE
    if !FileExist(CONFIG_FILE) {
        SaveConfig()
        return
    }
    Slots[1] := IniRead(CONFIG_FILE, "Slots", "1", "pistol")
    Slots[2] := IniRead(CONFIG_FILE, "Slots", "2", "rifle")
    Slots[3] := IniRead(CONFIG_FILE, "Slots", "3", "shotgun")
    Slots[4] := IniRead(CONFIG_FILE, "Slots", "4", "bow")
}

SaveConfig() {
    global Slots, CONFIG_FILE
    IniWrite Slots[1], CONFIG_FILE, "Slots", "1"
    IniWrite Slots[2], CONFIG_FILE, "Slots", "2"
    IniWrite Slots[3], CONFIG_FILE, "Slots", "3"
    IniWrite Slots[4], CONFIG_FILE, "Slots", "4"
}

; ==============================================================================
;  ОТПРАВКА UDP ПАКЕТА В DSX (ПОСТОЯННЫЙ ЦИКЛ)
; ==============================================================================

ArrToStr(arr) {
    str := "["
    for i, val in arr
        str .= val . (i < arr.Length ? "," : "")
    return str . "]"
}

SendTriggersUDP(presetName) {
    global DSX_IP, DSX_PORT, Presets
    if !Presets.Has(presetName)
        presetName := "reset"
    p := Presets[presetName]
    payload := '{"instructions":[{"type":1,"parameters":' ArrToStr(p.L2) '},{"type":2,"parameters":' ArrToStr(p.R2) '}]}'
    return SendUDP(DSX_IP, DSX_PORT, payload)
}

SendUDP(IP, Port, Payload) {
    WSADATA := Buffer(400, 0)
    if DllCall("Ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", WSADATA)
        return false
    sock := DllCall("Ws2_32\socket", "Int", 2, "Int", 2, "Int", 17, "UPtr")
    if (sock == 0xFFFFFFFF)
        return false
    sockaddr := Buffer(16, 0)
    NumPut("UShort", 2, sockaddr, 0)
    NumPut("UShort", DllCall("Ws2_32\htons", "UShort", Port, "UShort"), sockaddr, 2)
    NumPut("UInt", DllCall("Ws2_32\inet_addr", "AStr", IP, "UInt"), sockaddr, 4)
    strBuf := Buffer(StrPut(Payload, "UTF-8"), 0)
    StrPut(Payload, strBuf, "UTF-8")
    sent := DllCall("Ws2_32\sendto", "UPtr", sock, "Ptr", strBuf, "Int", strBuf.Size - 1, "Int", 0, "Ptr", sockaddr, "Int", 16, "Int")
    DllCall("Ws2_32\closesocket", "UPtr", sock)
    DllCall("Ws2_32\WSACleanup")
    return sent > 0
}

WriteLog(msg) {
    global LOG_FILE
    FileAppend "[" FormatTime(A_Now, "HH:mm:ss") "] " msg "`n", LOG_FILE
}

; ЦИКЛ ПРИНУДИТЕЛЬНОЙ ОТПРАВКИ (Спасает от перебивания DSX)
ForceUDPUpdate() {
    global TempEffectActive, IsDriving, CurrentWeapon
    
    if !IsFC3Active()
        return ; Не спамим если свернуто

    activeProfile := ""
    if (TempEffectActive != "")
        activeProfile := TempEffectActive
    else if IsDriving
        activeProfile := "drive"
    else
        activeProfile := CurrentWeapon
        
    SendTriggersUDP(activeProfile)
}

; ==============================================================================
;  СИСТЕМА СОСТОЯНИЙ
; ==============================================================================

ApplySlot(slotNum) {
    global Slots, CurrentSlot, CurrentWeapon, IsDriving

    IsDriving := false 
    weapon := Slots.Has(slotNum) ? Slots[slotNum] : "rifle"
    
    CurrentSlot := slotNum
    CurrentWeapon := weapon

    TrayTip "Оружие [Слот " slotNum "]", Presets[weapon].name, 1
    WriteLog("Слот " slotNum " → " weapon)
    UpdateTrayTooltip()
}

ToggleDriving() {
    global IsDriving
    IsDriving := !IsDriving
    if IsDriving {
        TrayTip "Режим Вождения", "Активированы педали машины", 1
        WriteLog("Включен режим вождения")
    } else {
        ApplySlot(CurrentSlot)
    }
    UpdateTrayTooltip()
}

ApplyTempEffect(effectName, durationMs := 0) {
    global TempEffectActive
    TempEffectActive := effectName
    WriteLog("Временный эффект: " effectName)

    if durationMs > 0 {
        SetTimer RemoveTempEffect, -durationMs
    }
}

RemoveTempEffect() {
    global TempEffectActive
    TempEffectActive := ""
}

; ==============================================================================
;  СИСТЕМНЫЙ ТРЕЙ
; ==============================================================================

UpdateTrayTooltip() {
    global CurrentSlot, CurrentWeapon, IsDriving, Presets, Slots
    wName := Presets.Has(CurrentWeapon) ? Presets[CurrentWeapon].name : CurrentWeapon
    stateStr := IsDriving ? "ВОЖДЕНИЕ (Педали)" : ("Слот: [" CurrentSlot "]  " wName)
    A_IconTip := "FC3 PS5 Haptics`n" stateStr "`n1=" SlotName(1) "  2=" SlotName(2) "  3=" SlotName(3) "  4=" SlotName(4)
}

SlotName(n) {
    global Slots, Presets
    w := Slots.Has(n) ? Slots[n] : "?"
    return Presets.Has(w) ? Presets[w].name : w
}

BuildTrayMenu() {
    global Slots, WeaponList, Presets
    A_TrayMenu.Delete()
    A_TrayMenu.Add("FC3 DualSense Haptics (v4.1 Loop)", (*) => "")
    A_TrayMenu.Disable("FC3 DualSense Haptics (v4.1 Loop)")
    A_TrayMenu.Add()
    loop 4 {
        slotNum := A_Index
        slotMenu := Menu()
        curWeapon := Slots.Has(slotNum) ? Slots[slotNum] : "rifle"
        for wKey in WeaponList {
            wName := Presets[wKey].name
            label := (wKey = curWeapon) ? "✓  " wName : "    " wName
            slotMenu.Add(label, SetSlotWeapon.Bind(slotNum, wKey))
        }
        A_TrayMenu.Add("Слот " slotNum " — " SlotName(slotNum), slotMenu)
    }
    A_TrayMenu.Add()
    A_TrayMenu.Add("Выход", (*) => ExitApp())
    A_TrayMenu.Default := "FC3 DualSense Haptics (v4.1 Loop)"
}

SetSlotWeapon(slotNum, weaponKey, *) {
    global Slots
    Slots[slotNum] := weaponKey
    SaveConfig()
    BuildTrayMenu()
    UpdateTrayTooltip()
}

; ==============================================================================
;  ГОРЯЧИЕ КЛАВИШИ (FC3)
; ==============================================================================

IsFC3Active() {
    global FC3_EXE
    for exe in FC3_EXE
        if WinActive("ahk_exe " exe)
            return true
    return false
}

IsFC3Running() {
    global FC3_EXE
    for exe in FC3_EXE
        if WinExist("ahk_exe " exe)
            return true
    return false
}

#HotIf IsFC3Active()
~1:: ApplySlot(1)
~2:: ApplySlot(2)
~3:: ApplySlot(3)
~4:: ApplySlot(4)
WheelUp:: {
    global CurrentSlot, IsDriving
    if IsDriving 
        ToggleDriving()
    ApplySlot(Mod(CurrentSlot, 4) + 1)
}
WheelDown:: {
    global CurrentSlot, IsDriving
    if IsDriving 
        ToggleDriving()
    ApplySlot(CurrentSlot > 1 ? CurrentSlot - 1 : 4)
}
~5:: ToggleDriving()
~Space:: ApplyTempEffect("jump", 400)
~q:: ApplyTempEffect("heal", 2000)
~LShift:: ApplyTempEffect("sprint")
~LShift up:: RemoveTempEffect()
~e:: ApplyTempEffect("loot")
~e up:: RemoveTempEffect()
#HotIf

; ==============================================================================
;  МОНИТОРИНГ
; ==============================================================================

MonitorFC3() {
    static fc3WasActive := false
    fc3Active := IsFC3Running()

    if fc3Active && !fc3WasActive {
        WriteLog("FC3 обнаружена — профиль применён")
        fc3WasActive := true
        SetTimer ForceUDPUpdate, 50 ; Начинаем спамить UDP каждые 50мс!
    } else if !fc3Active && fc3WasActive {
        SetTimer ForceUDPUpdate, 0  ; Останавливаем спам
        SendTriggersUDP("reset")
        WriteLog("FC3 закрыта — триггеры сброшены")
        fc3WasActive := false
    }
}

; ==============================================================================
;  ЗАПУСК
; ==============================================================================

TraySetIcon A_AhkPath, 2
LoadConfig()
SendTriggersUDP("reset")
BuildTrayMenu()
UpdateTrayTooltip()
WriteLog("=== FC3 DualSense Haptics v4.1 запущен ===")

; Если игра УЖЕ запущена при старте скрипта
if IsFC3Running() {
    SetTimer ForceUDPUpdate, 50
}

SetTimer MonitorFC3, 2000
TrayTip "PS5 Haptics", "Готов. Жди Far Cry 3...", 1
Persistent
