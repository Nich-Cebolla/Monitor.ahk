#SingleInstance force
#Include ..\cJSON.ahk
#Include ..\cMonitor.ahk
#Include fnGetFnParams.ahk
#Include ..\cArray.ahk

ListLines 0
CoordMode('Mouse', 'Screen')
CoordMode('ToolTip', 'Screen')
A_MaxHotkeysPerInterval := 90000
A_HotkeyInterval := 900000
KeyHistory 0

class test_monitor {
    static scriptPath := Monitor.scriptPath
    static monCount := MonitorGetCount()
    static methods := Map()
    static listMethods := []
    static LVColumns := ['index', 'hmon', 'number', 'dpi-x', 'dpi-y']
    static errors := []
    static spawn := []
    static monitors := []
    static LVAHKColumns := ['hwnd']
    static spawnMap := Map()
    static hotkey := '!1'
    static outPath := A_ScriptDir '\out\' StrReplace(A_ScriptName, '.ahk', '') '_results_' FormatTime(A_Now, 'yyyy-MM-dd_HH-mm-ss') '.txt'
    static mainEditWidth := 450
    static listviewWidth := 1000
    static tabWidth := 550
    static __New() {
        DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
        _OnExit_(*) {
            try
                test_monitor.f.Close()
        }
        OnExit(_OnExit_)
        RegExMatchInfo.prototype.DefineProp('OwnProps', {Call: ((self, *) => self.__Enum())})
        test_monitor.f := FileOpen(test_monitor.outPath, 'a')
        test_monitor.f.Write('Results for ' A_ScriptName ' - ' FormatTime(A_Now, 'yyyy-MM-dd HH:mm:ss'))
        test_monitor.GetMonDetails()
        Monitor()
        test_monitor.SetLVColumns()
        test_monitor.SetMethods()
        test_monitor.SpawnWindows()
        test_monitor.Constructor()
    }

    static SetLVColumns() {
        mon := Monitor.Get(1)
        for k, v in mon[ 'display']
            test_monitor.LVColumns.push('display-' k)
        for k, v in mon['work']
            test_monitor.LVColumns.push('work-' k)
        test_monitor.LVColumns.Push('name')
    }

    static Constructor() {
        g := this.g := Gui('+Owner +Resize -DPIScale')
        g.marginX := 10
        g.marginY := 10
        g.SetFont('s11', 'Consolas')

        ; listview
        g.Add('ListView', Format('w{} r{} vlvmons', test_monitor.listviewWidth, test_monitor.monCount+1), test_monitor.LVColumns)
        for details in Monitor {
            info := []
            for k in test_monitor.LVColumns {
                if InStr(k, '-') {
                    split := StrSplit(k, '-')
                    info.push(details[split[1]][split[2]])
                } else
                    info.push(details[k])
            }
            g['lvmons'].Add(, info*)
        }
        Loop test_monitor.LVColumns.length
            g['lvmons'].ModifyCol(A_Index, 'AutoHdr')

        g.Add('ListView', Format('xs w{} vlvmonsahk r{}', test_monitor.listviewWidth, test_monitor.monCount+1), test_monitor.LVAHKColumns)
        Loop test_monitor.monitors.length
            g['lvmonsahk'].Add(, test_monitor.spawn[A_Index], test_monitor.monitors[A_Index]['info']*)
        Loop test_monitor.LVAHKColumns.length
            g['lvmonsahk'].ModifyCol(A_Index, 'AutoHdr')

        g.Add('Edit', 'Section w' test_monitor.mainEditWidth ' h500 vedit +wrap +HScroll')
        g.Add('Tab2', 'ys w' test_monitor.tabWidth ' h400 vtab', test_monitor.listMethods)
        g['tab'].GetPos(&tx, &ty, &tw, &th)
        g.DefineProp('tabDimensions', {Value: {x: tx, y: ty, w: tw, h: th}})
        g['tab'].UseTab(0)
        g.marginy := 20
        g.Add('Text', 'Section', '"Run" hotkey: ')
        g.marginY := 10
        g.Add('Edit', 'ys-3 w100 vhotkey', test_monitor.hotkey)
        g.Add('Button', 'ys-6 w100', 'Set Hotkey').OnEvent('Click', _H_ClickBtnHotkey_)
        g.marginX := 20
        g.Add('Checkbox', 'ys+1 vontop', 'Always on top').OnEvent('Click', ((ctrl, *) => ctrl.gui.Opt((ctrl.value ? '+AlwaysOnTop' : '-AlwaysOnTop'))))
        g.marginX := 10
        g.Add('Text', 'Section xs vtextdpi', 'DPI Awareness Context:')
        Loop 5
            g.Add('CheckBox', 'Section ys vchkdpi' A_Index (A_Index = 4 ? ' Checked' : ''), '-' A_Index).OnEvent('Click', _H_ClickChkDpi_)
        g['edit'].GetPos(&cx, &cy, &cw, &ch)
        g.Add('Button', Format('Section x10 y{} w100 vbtnpath', cy+ch+g.marginy), 'Set Path').OnEvent('Click', _H_ClickBtnPath_)
        g.Add('Edit', 'ys w980 veditpath', test_monitor.outPath)

        for method, container in test_monitor.methods {
            g['tab'].UseTab(method)
            params := container['params']
            ctrls := container['ctrls']
            for param in params {
                ctrls.Set(param, Map())
                split := StrSplit(param, ':=', '`r`s`t`n')
                ctrls[param].Set('text', g.Add('Text', Format('Section x{} y{} w150 h25', g.tabDimensions.x + 10, (A_Index = 1 ? g.tabDimensions.Y + 130 : 'p+35')) , split[1]))
                ctrls[param].Set('edit', g.Add('Edit', 'ys w200'))
                if split.length > 1
                    ctrls[param].Set('default', g.Add('Text', 'ys', 'Default: ' split[2]))
            }
            g.Add('Button', 'Section xs w100 vbtn' method '_run', 'Run').OnEvent('Click', _H_ClickBtnRun_.Bind(method))
            g.Add('Button', 'ys w100 vbtn' method '_runall', 'Run All').OnEvent('Click', _H_ClickBtnRunAll_.Bind(method))
        }

        g.show()
        g.Move(Monitor[1]['display']['right'] - test_monitor.listviewWidth - 50, 50, test_monitor.listviewWidth + 50)

        HotKey(test_monitor.hotkey, _H_ClickBtnRun_.Bind(''), 'On')


        _H_ClickChkDpi_(ctrl, *) {
            static lastChecked
            if !IsSet(lastChecked)
                lastChecked := g['chkdpi4']
            if ctrl.value {
                if ctrl.name != lastChecked.name {
                    lastChecked.value := false
                    lastChecked := ctrl
                }
                DllCall("SetThreadDpiAwarenessContext", "ptr", Number(ctrl.Text), "ptr")
            }
        }

        _H_ClickBtnPath_(ctrl, *) {
            path := ctrl.gui['editpath'].Text
            test_monitor.f.Close()
            test_monitor.f := FileOpen(path, 'a')
        }

        _H_ClickBtnRun_(method, *) {
            if !method
                method := g['tab'].Text
            switch method {
                case 'SplitHorizontal':
                    _H_MethodSplitHorizontal_()
                    return
                case 'SplitVertical':
                    _H_MethodSplitVertical_()
                    return
            }
            methodcontainer := test_monitor.methods[method]
            params := methodcontainer['params']
            ctrls := methodcontainer['ctrls']
            p := []
            initial := CoordMode('Mouse', 'Screen')
            MouseGetPos(&mx, &my)
            CoordMode('Mouse', initial)
            paramstr := 'Mouse: x: ' mx ', y: ' my
            for param in params {
                paramval := ctrls[param]['edit'].Text
                p.Push(paramval||Unset)
                paramstr .= '`r`n' param ': ' paramval||'Unset'
            }
            result := Monitor.%method%(p*)
            str := Format('Method: {}`r`nInput: {}`r`nResult: {}', method, paramstr, (IsObject(result) ? JSON.stringify(result,4) : result))
            g['edit'].Text := str '`r`n`r`n' g['edit'].Text
            test_monitor.f.Write('`n`n' str)
        }

        _H_MethodSplitHorizontal_() => _H_MethodSplit_('SplitHorizontal')
        _H_MethodSplitVertical_() => _H_MethodSplit_('SplitVertical')

        _H_MethodSplit_(type) {
            ctrls := test_monitor.methods[type]['ctrls']
            result := Monitor.SplitHorizontal(Number(ctrls['hmon']['edit'].Text), ctrls['segmentCount']['edit'].Text)
            g['edit'].Text := Format('Monitor display area:`r`n{}`r`nSegment size: {}`r`nResult:`r`n{}`r`n`r`n{}', JSON.Stringify(result.area,4), result.segment, JSON.Stringify(result,4), g['edit'].Text)
        }

        _H_ClickBtnRunAll_(method, ctrl, *) {
            methodcontainer := test_monitor.methods[method]
            params := methodcontainer['params']
            ctrls := methodcontainer['ctrls']
            finalstr := method
            resultstr := ''
            Loop test_monitor.monCount {
                i := A_Index
                p := []
                hwnd := test_monitor.spawn[i]
                hmon := test_monitor.monitors[A_Index]['hmon']
                WinGetPos(&wx, &wy, &ww, &wh, hwnd)
                paramstr := 'Window: ' hwnd '`r`nAssociated hmon: ' hmon '`r`nWindow dimensions:`r`n' Format('x: {}{}y: {}`r`nw: {}{}h: {}`r`nParams:', wx, _GetSpaces_(wx), wy, ww, _GetSpaces_(ww), wh)
                for param in params {
                    param := Trim(StrReplace(StrLower(param), '?', ''), ' ')
                    switch param {
                        case 'hwnd':
                            p.Push(test_monitor.spawn[i])
                        case 'hmon':
                            p.Push(test_monitor.monitors[i]['hmon'])
                        case 'x', 'left':
                            p.Push(wx)
                        case 'y', 'top':
                            p.Push(wy)
                        case 'w', 'h':
                            p.Push((param = 'w' ? ww : wh))
                        case 'right', 'bottom':
                            p.Push((param = 'right' ? wx+ww : wy+wh))
                        default:
                            p.Push(Unset)
                    }
                    try
                        var := p[-1]
                    catch
                        var := 'Unset'
                    paramstr .= Format('`r`n{}: {}', param, var)
                }
                result := Monitor.%method%(p*)
                resultstr .= '`r`n`r`n' paramstr '`r`nResult: ' (IsObject(result) ? JSON.stringify(result,4) : result)
                switch method {
                    case 'Get', 'GetFromDimensions', 'GetFromPoint', 'GetFromRect', 'GetFromWindow':
                        if result['hmon'] = hmon
                            finalStr .= Format('`r`n`r`nOK - Gui hmon: {}  = Result hmon: {}  ', hmon, result['hmon'])
                        else
                            finalStr .= Format('`r`n`r`nProblem - Gui hmon: {}  != Result hmon: {}  ', hmon, result['hmon'])
                }
            }
            g['edit'].Text := finalstr resultstr '`r`n`r`n' g['edit'].Text
            test_monitor.f.Write('`n`n' finalstr resultstr)
        }

        _H_ClickBtnHotkey_(*) {
            HotKey(test_monitor.hotkey, , 'Off')
            test_monitor.hotkey := g['hotkey'].Text
            HotKey(test_monitor.hotkey, _H_ClickBtnRun_.Bind(''), 'On')
        }

        _GetSpaces_(context) {
            str := ''
            Loop 8 - StrLen(context)
                str .= ' '
            return str
        }
    }

    static GetMonDetails() {
        test_monitor.monitors.length := test_monitor.monCount
        Loop test_monitor.monCount {
            MonitorGet(A_Index, &l, &t, &r, &b)
            MonitorGetWorkArea(A_Index, &wl, &wt, &wr, &wb)
            currentMon := test_monitor.monitors[A_Index] := Map('index',A_Index, 'display',Map('l',l,'t',t,'r',r,'b',b),'work',Map('l',wl,'t',wt,'r',wr,'b',wb), 'info', [])
            for hmon, details in Monitor {
                if details[ 'display']['left'] = l && details[ 'display']['top'] = t {
                    currentMon.Set('hmon', details['hmon'])
                    break
                }
            }
        }
        loopMon := test_monitor.monitors[1]
        for k, v in loopMon {
            if k = 'info'
                continue
            if IsObject(v) {
                for subk in v {
                    test_monitor.LVAHKColumns.Push(k '-' subk)
                    for mon in test_monitor.monitors
                        mon['info'].Push(mon[k][subk])
                }
            } else {
                test_monitor.LVAHKColumns.push(k)
                for mon in test_monitor.monitors
                    mon['info'].Push(mon[k])
            }
        }
    }

    static SetMethods() {
        content := FileRead(test_monitor.scriptPath)
        methods := test_monitor.methods
        listMethods := test_monitor.listMethods
        outfile := FileOpen(A_ScriptDir '\_tmonitor_out_' FormatTime(A_Now, 'yyyy-MM-dd_HH-mm-ss') '.txt', 'a')
        pos := 1
        while RegExMatch(content, 'static (?P<method>[\w\d_]+)\((?P<params>[^>\r\n]*)\)', &match, pos) {
            outfile.Write(Format('`n`nMatch: {}`nOriginal pos: {}`nNew pos: {}`nMatch length: {}`nContent: {}', JSON.stringify(match,4), pos, match.pos, StrLen(match[0]), SubStr(content, pos, match.pos + StrLen(match[0]) - pos)))
            pos := match.pos + StrLen(match[0])
            if SubStr(match['method'], 1, 1) = '_' || match['method'] = 'ToggleModes' || match['method'] = 'Refresh'
                continue
            if match['method'] = 'Point'
                break
            methods.Set(match['method'], match['params'])
        }
        for method, params in methods {
            params := GetFnParams(params)
            p := Map('params', params, 'ctrls', Map(), 'flag_optional', false)
            for param in params {
                if InStr(param, '?') || InStr(param, ':=')
                    p['flag_optional'] := true
            }
            methods.Set(method, p)
            listMethods.push(method)
        }
        outfile.Close()
    }

    static SpawnWindows() {
        Loop test_monitor.monCount {
            mon := test_monitor.monitors[A_Index]
            g := Gui('+Owner +Resize -DPIScale +AlwaysOnTop')
            g.SetFont('s12', 'Consolas')
            g.Add('Edit', 'w400 h400 vedit')
            test_monitor.spawn.push(g.hwnd)
            test_monitor.spawnMap.Set(g.hwnd, g)
            ; g.Show(Format('x{} y{} w500 h500', mon[ 'display']['l']+100, mon[ 'display']['t']+100))
            g.Show()
            g.Move(mon[ 'display']['l']+50, mon[ 'display']['t']+50, 500, 500)
            g.GetPos(&x, &y, &w, &h)
            g['edit'].Text := Format('WINDOW {1}`r`nHWND {2}`r`nWindow dimensions:`r`nx: {3:-6}y: {4}`r`nw: {5:-6}h: {6}`r`nMonitor details: {7}', A_Index, g.hwnd, x, y, w, h, JSON.stringify(mon,4))
        }
    }
}

test_monitor()
