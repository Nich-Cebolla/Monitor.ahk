#SingleInstance Force

/* 
Tested on 2.0.17
If you run it, I recommend running it in a a temporary directory somewhere. The WebView2 controller will
create a User Data folder within A_ScriptDir, so it'll just be a bit easier to clean up after if things
are separate.

After the GUI launches, try click-and-dragging it around to different monitors. The position of the Webview2 controller
should remain constant relative to the Gui. If it doesn't please let me know.

To run this script, you will need to include the following files (which are in this folder in this repository).
*/
#Include WebView2.ahk
#Include Promise.ahk
#Include ComVar.ahk
#Include cJSON.ahk
#Include cArray.ahk
#Include cMonitor.ahk
#Include gMenuBarConstructor.ahk

i := Form()

class Form {
    config := {
        path: {
            dll: 'WebView2Loader.dll'
          , userData: A_ScriptDir
          , userForm: 'files:///' A_ScriptDir '/index.html'
        }
      , gui: {
            title: 'Office-Tools.Form'
          , bgColor: ''
          , opt: '+Resize -DPIScale'
          , marginX: 0
          , marginY: 0
          , menus: []
        }
      , font: {
            size: 11
          , family: 'Consolas'
          , color: 'Black'
          , opt: 'Q5'
        }
    }

    pos := {
        wv:{offset:{bottom:75}}
      , gui:{
            offset:{monitorEdge:{top:10,left:5,bottom:70,right:5}}
          , multiplier: {width:0.5}
        }
    }
    dpi := {initial: '', previous: '', current: '', ratio:1}

    __New() {
        OnExit(_OnExit_.Bind(this))
        ; Set thread DPI awareness to -4
        Monitor.ToggleModes(, 'dpi', -4)

        ; Creating variable references to instance properties; this performs better and saves keystrokes
        optPath := this.config.path, optGui := this.config.gui, optFont := this.config.font

        ; Set GUI properties
        g := this.g := Gui(optGui.opt, optGui.title)
        g.marginX := optGui.marginX, g.marginY := optGui.marginY, (optGui.bgColor ? g.BackColor := optGui.bgColor : '')
        g.SetFont(Format('{} {} {}', (optFont.size ? 's' optFont.size : ''), (optFont.color ? 'c' optFont.color : ''), optFont.opt), (optFont.family ? optFont.family : Unset))

        ; Define the callback for `OnMessage`
        _OnDPIChange_(self, newDPI, recommendedRect, msg, hwnd) {
            g := self.g, dpi := self.dpi
            ; The WM_DPICHANGED message includes a pointer to a RECT that contains the API's recommended dimensions to resize the window.
            ; I do use that RECT here, it seems to work just fine.
            g.Move( , , recommendedRect['right'] - recommendedRect['left'], recommendedRect['bottom'] - recommendedRect['top'])
            ; When I was writing and testing this, I found that I need to modify the dpi ratio by a factor of 0.9 for best results.
            ; I have not started investigating why. For reference, my laptop's primary display is 120 DPI, and my two external monitors
            ; are 96
            dpi.ratio := newDPI / dpi.current*.90
            dpi.previous := dpi.current, dpi.current := newDPI
            g.GetClientPos( , , &w, &h)
            self.wvc.Bounds := Monitor.DataTypes.Rect(0, 0, w, h - self.pos.wv.offset.bottom*dpi.ratio)
        }
        ; Set WM_DPICHANGED handler
        Monitor.OnDPIChange(_OnDPIChange_.Bind(this))

        ; Getting initial DPI
        unit := Monitor[1], mon := unit['work']
        this.dpi.current := this.dpi.initial := unit['dpi']['x']

        ; This creates a menu bar. I included this in this example to demonstrate that the method is compatible with menu bars.
        this._SetMenuCallbacks()
        bar := g.MenuBar := MenuBarConstructor(this.config.gui.menus, this)

        ; Displaying the GUI. When working towards creating an app that is DPI-aware, it's best to use
        ; relative values for size and position. I don't use any hard-coded size/position values in this
        ; script, except the configuration at the top.
        monitorEdgeOffset := this.pos.gui.offset.monitorEdge
        g.Show(Format('x{1} y{2} w{3} h{4}'
            , x := mon['left']+monitorEdgeOffset.left
            , y := mon['top']+monitorEdgeOffset.top
            , w := mon['width']*this.pos.gui.multiplier.width
            , h := mon['height'] - monitorEdgeOffset.top - monitorEdgeOffset.bottom
        ))
        ; This confused me at first when learning to use Thqby's WebView2, but this text control is actually going
        ; to become the container for our WebView2 Controller.
        g.Add('Text', Format('x0 y0 w{} h{} vwvController', w, h-this.pos.wv.offset.bottom))
        g['wvController'].wvc := this.wvc := WebView2.CreateControllerAsync(g['wvController'].hwnd).await2()
        this.wv := g['wvController'].CoreWebView2
        g['wvController'].nwr := wv.NewWindowRequested(_NewWindowRequestedHandler_)
        wv.Navigate(optPath.userForm)

        _NewWindowRequestedHandler_(wv2, arg) {
            deferral := arg.GetDeferral()
            arg.NewWindow := wv2
            deferral.Complete()
        }

        _OnExit_(self, exitReason, exitCode) {
            try
                self.DeleteProp('wvc')
            try
                self.g.Destroy()
        }
    }
    
    ; notes to self
    ; callback params: ItemName, ItemPos, MyMenu
    ; selectedfile := FileSelect('S 16', A_ScriptDir '\Log_' FormatTime(A_Now, "yyyyMMdd_HHmmss") '.txt') <- returns a string path
    _SetMenuCallbacks() {
        menus := this.config.gui.menus
        menus.length := 5
        menus[1] := ['File', 'New', _New_, 'Open', _Open_, 'Save', _Save_, 'Save As', _SaveAs_, 'Exit', _Exit_]
        menus[2] := ['Edit', 'Undo', _Undo_, 'Redo', _Redo_, 'Check Spelling', _CheckSpelling_]
        menus[3] := ['View', 'Zoom In', _ZoomIn_, 'Zoom Out', _ZoomOut_, 'Zoom Custom', _ZoomCustom_, 'Set Color Preferences', _SetColorPreferences_]
        menus[4] := ['Options', 'Preferences', _Preferences_, 'Keyboard Shortcuts', _KeyboardShortcuts_, 'Advanced', _Advanced_]
        menus[5] := ['Help', 'About', _About_, 'Tutorials', _Tutorials_, 'User Documentation', _UserDocumentation_, 'Developer Documentation', _DeveloperDocumentation_]

        _New_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _Open_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _Save_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _SaveAs_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _Exit_(self, itemName, itemPos, menuObj) {
            ExitApp()
        }
        _Undo_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _Redo_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _CheckSpelling_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _ZoomIn_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _ZoomOut_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _ZoomCustom_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _SetColorPreferences_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _Preferences_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _KeyboardShortcuts_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _Advanced_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _About_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _Tutorials_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _UserDocumentation_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
        _DeveloperDocumentation_(self, itemName, itemPos, menuObj) {
            MsgBox(itemName)
        }
    }
}
