

/* Credits
Key details regarding DLL calls sourced from, or pulled directly from, these discussions:
https://www.autohotkey.com/boards/viewtopic.php?f=6&t=4606
@just me  -  @iPhilip  -  @guest3456
https://www.autohotkey.com/boards/viewtopic.php?f=83&t=79220
@Tigerlily  -  @CloakerSmoker  -  @jNizM
*/

/** ### Description - Monitor Class
 * This class focuses on providing methods for obtaining information about the size, dimensions,
 * position and DPI of the monitors. The parent script can obtain information about a monitor using:
 * - a single point {@link Monitor.GetFromPoint}
 * - a window's hwnd {@link Monitor.GetFromWindow}
 * - a rectangle (left, top, right, bottom) {@link Monitor.GetFromRect}
 * - dimensions (x, y, w, h) {@link Monitor.GetFromDimensions}
 * - the current position of the mouse pointer {@link Monitor.GetFromMouse}
 *
 * When retrieving information about a monitor, there are three numbers you can use.
 * - The "HMON" ("hmon") which is the monitor's handle (similar to HWND).
 * - The monitor "number", which is assigned by the Operating System. When using this number,
 * prepend it with an 's', e.g. `Monitor['s3']`
 * - The `index`, which is assigned by this script. The indices begin at 1 and increment by 1.
 *
 * In addition to those methods for obtaining the details about a monitor, `Monitor` provides
 * these additional methods:
 * - Refresh {@link Monitor.Refresh} - refreshes the monitor details
 * - __Enum {@link Monitor.__Enum} - enumerates the monitors. Compatible with `For` loops, i.e.
 * `For unit in Monitor`
 * - IntersectRect {@link Monitor.IntersectRect} - returns the intersection of two rectangles
 * - OnDPIChange {@link Monitor.OnDPIChange} - provides a simple way to define a handler function
 * for WM_DPICHANGED messages
 * - SplitHorizontal {@link Monitor.SplitHorizontal} - splits the width of a monitor into segments
 * - SplitVertical {@link Monitor.SplitVertical} - splits the height of a monitor into segments
 * - ToggleModes {@link Monitor.ToggleModes} - provides a simple way to toggle DPI AWARENESS CONTEXT
 * and mouse coordinate mode.
 * - WinMoveByMouse {@link Monitor.WinMoveByMouse} - moves a window by the mouse pointer, ensuring
 * that the window stays within the visible area of the monitor.
 *
 * Note that the Monitor class does not return an instance object. All properties and methods
 * inhere in the class. You do not need to call `Monitor.__New()`; it is called automatically
 * when the class is first accessed. However, you may wish to call it if you want to use
 * different input parameters (other than the default). You can also call `Monitor.Refresh()`
 * at any time to use new input parameters.
 */
class Monitor {

    class Unit {

        /** ### Description - Monitor.Unit.prototype
         * This class is the constructor for the monitor objects used within this script. When you
         * `Get` a monitor object, you are getting an instance of this class's prototype.
         *
         * Within the context of this script, you shouldn't need to call this class constructor.
         * I have placed this class at the beginning so you can see the properties and methods
         * available from the monitor objects.
         *
         * ### Instance properties
         * The main property is `prototype.__Item`. This is a map object that contains the details
         * about the monitor. These map objects are not case sensitive. There are two nested
         * map objects, `display` and `work`. The `display` area is the entire visual area used by
         * the monitor. The `work` area is the monitor's display area but excluding things like
         * taskbars and docked windows.
         *
         * ### Enumeration
         * You can enumare a `Monitor.Unit` object with a simple `for` loop. No special syntax or
         * usage needed.
         *
         * ### Methods
         * - `Monitor.Unit.prototype.SplitVertical()` - calls `Monitor.SplitVertical()` for the monitor.
         * This splits the height of a monitor into segments, and returns the dimensions of the
         * resulting interior rectangles as an array of map objects.
         * - `Monitor.Unit.prototype.SplitHorizontal()` - calls `Monitor.SplitHorizontal()` for the monitor.
         * This splits the width of a monitor into segments, and returns the dimensions of the
         * resulting interior rectangles as an array of map objects.
         */
        __NeW(hmon) {
            ; (monitorInfo = 40 byte struct) + (monitorInfoEX = 64 bytes)
            NumPut("uint", 104, monitorInfoEX := Buffer(104))
            if DllCall("user32\GetMonitorInfo", "ptr", hmon, "ptr", monitorInfoEX) {
                this.__Item := Map()
                this.__Item.CaseSense := false
                this.__Item.Set('display', Map(), 'work', Map())
                this.__Item['display'].CaseSense := false
                this.__Item['display'].Set(
                    'left', NumGet(monitorInfoEX, 4, "int")
                  , 'top', NumGet(monitorInfoEX, 8, "int")
                  , 'right', NumGet(monitorInfoEX, 12, "int")
                  , 'bottom', NumGet(monitorInfoEX, 16, "int")
                  , 'width', NumGet(monitorInfoEX, 12, "int") - NumGet(monitorInfoEX, 4, "int")
                  , 'height', NumGet(monitorInfoEX, 16, "int") - NumGet(monitorInfoEX, 8, "int")
                )
                this.__Item['work'].CaseSense := false
                this.__Item['work'].Set(
                    'left', NumGet(monitorInfoEX, 20, "int")
                  , 'top', NumGet(monitorInfoEX, 24, "int")
                  , 'right', NumGet(monitorInfoEX, 28, "int")
                  , 'bottom', NumGet(monitorInfoEX, 32, "int")
                  , 'width', NumGet(monitorInfoEX, 28, "int") - NumGet(monitorInfoEX, 20, "int")
                  , 'height', NumGet(monitorInfoEX, 32, "int") - NumGet(monitorInfoEX, 24, "int")
                )
                this.__Item.Set(
                    'hmon', hmon
                  , 'name', StrGet(monitorInfoEX.ptr + 40, 32)
                  , 'primary', NumGet(monitorInfoEX, 36, "uint")
                  , 'number', RegExReplace(StrGet(monitorInfoEX.ptr + 40, 32), '.*(\d+)$', '$1')
                  , 'dpi', Monitor.GetDpi(hmon)
                )
                this.hmon := hmon
                this.DefineProp('__Enum', {Call: ((self, param*) => self.__Item.__Enum(param*))})
                if this.__Item['primary']
                    Monitor.primary := this
                return
            }
            Monitor._errors.Push(Map('hmon',Monitor._ProcessError(A_LastError, 'DllCall(`'user32\GetMonitorInfo`', `'ptr`', hmon, `'ptr`', monitorInfoEX) failed')))
        }

        /** ### Description - Monitor.Unit.prototype.SplitVertical()
         * This splits the height of a monitor into segments, and returns the dimensions
         * of the resulting interior rectangles as an array of map objects.
         * @param {Integer} segmentCount - the number of segments to split the monitor into
         * @param {VarRef} [outVar] - the variable to store the results
         * @param {Boolean} [useWorkArea=true] - whether to use the work area or the general area
         * @returns {Array} - You have the choice of using the VarRef `outVar`, and/or to receive a return
         * value. The result is the same in either case. The result is an array of Map objects, where
         * each map has items 'top' and 'bottom'. The array object has these additional
         * properties:
         * - `segment` - the length of each segment
         * - `area` - the area used by the function (work area or display area of the monitor)
         */
        SplitVertical(segmentCount, &outVar?, useWorkArea := true) => Monitor.SplitVertical(this['hmon'], segmentCount, &outVar??Unset, useWorkArea)

        /** ### Description - Monitor.Unit.prototype.SplitHorizontal()
         * This splits the width of a monitor into segments, and returns the dimensions
         * of the resulting interior rectangles as an array of map objects.
         * @param {Integer} segmentCount - the number of segments to split the monitor into
         * @param {VarRef} [outVar] - the variable to store the results
         * @param {Boolean} [useWorkArea=true] - whether to use the work area or the general area
         * @returns {Array} - You have the choice of using the VarRef `outVar`, and/or to receive a return
         * value. The result is the same in either case. The result is an array of Map objects, where
         * each map has items 'left' and 'right'. The array object has these additional
         * properties:
         * - `segment` - the length of each segment
         * - `area` - the area used by the function (work area or display area of the monitor)
         */
        SplitHorizontal(segmentCount, &outVar?, useWorkArea := true) => Monitor.SplitHorizontal(this['hmon'], segmentCount, &outVar??Unset, useWorkArea)
    }

    /** ### Description - Monitor.Refresh()
     * Refreshes the monitor details.
     *
     * ### Sorting
     * When referring to "Sorting" in the context of this script, these concepts are relevant:
     * - Sorting impacts the order in which `Monitor.Unit` objects are presented when enumerating
     * `Monitor` in a for loop.
     * - Sorting impacts which `Monitor.Unit` object is retrieved when using `Monitor.Get(number)`,
     * or simply `Monitor[number]`.
     * - Sorting defines the `index` assigned to each `Monitor.Unit` object.
     *
     * The default sorting follows this process:
     * - The primary monitor is 1
     * - The remaining monitors are placed based on the position of the left-edge of the monitor.
     * Index "2" is the lowest, "3" the next lowest, and so on. If two monitors have the same
     * left-edge position, the monitor with the lesser top-edge position is placed first. (Reminder:
     * the lesser top-edge position is physically above a greater top-edge position.)
     *
     * So if we have three non-primary monitors with these values for the "left" edge of the monitor:
     * a) -1910, b) 70, c) 2050
     * The order would be: 1: primary, 2: a, 3: b, 4: c
     *
     * If not using the default sorting, the input sorter function should follow this process:
     * - Enumerate `Monitor.__Item`. You can do this with a simple `for` loop. See
     * `Monitor._MonSorter()` for an example. Within the loop, evaluate your desired order and push
     * the monitor objects into the array `Monitor.sorted`.
     * - If you want the primary monitor to be index 1, include a conditional statement inside
     * of the `for` loop to `continue` when the primary monitor is encountered (skip it).
     * Then, after enumerating the others, apply `Monitor.sorted.InsertAt(1, primaryMonObject)`.
     *
     * ### Errors
     * The default handling of errors depends on where the errors occurs. If the error occurs
     * during the process of `Monitor._EnumDisplayMonitors()`, the error is stored in the
     * `Monitor._errors` array. These will be displayed in a gui window for debugging purposes.
     * You can disable this behavior by passing an error handling function to `errorHandler` when
     * calling `Monitor.Refresh()`. Be aware that the first time `Monitor` is referenced, it will
     * go through the enumeration sequence including the error sequence, as that process is defined
     * within `Monitor.__New()`. If you want to prevent the user from seeing the error window,
     * the first reference to `Monitor` should be `Monitor.__New()` including your error handling
     * function.
     *
     * Other errors are thrown when they occur / are currently unhandled and will use the interpreter's
     * error handling. Use try-catch blocks within the parent script to control errors.
     *
     * ### DPI Awareness Context
     * An awareness context of -4 tells the Windows API that this application is per-monitor DPI
     * aware. What that means is, we are telling the API that we will handle DPI scaling on our own,
     * and so the system does not do any scaling for us. This is desirable when we want to set the
     * baseline coordinates and dimensions for our windows and controls. However, it also means
     * that if we are relying on these coordinates for sizing or positioning of windows and
     * controls, we must take into account DPI scaling per monitor. For the purposes of getting the
     * position and dimensions of the monitors, we don't want to have the API scale the values. If
     * you have a reason to use a different value, pass in your selected value to
     * `DPI_AWARENESS_CONTEXT`.
     *
     * ### DPI Awareness Enumeration
     * According to
     * {@link https://learn.microsoft.com/en-us/windows/win32/api/windef/ne-windef-dpi_awareness}
     * the windows API does not provide a direct function to detect if a thread is set to
     * 'DPI_AWARENESS_PER_MONITOR_AWARE_V2' or 'DPI_AWARENESS_UNAWARE_GDISCALED'. To overcome this
     * limitation, `Monitor.__New()` calls
     * `DllCall("SetThreadDpiAwarenessContext", "ptr", -4|-5, "ptr")` for both -4 and -5
     * individually, then retrieves the DPI_AWARENESS value with
     * `DllCall("GetThreadDpiAwarenessContext", "ptr")`. According to my tests, it seems this
     * value is constant between application runs. However, since there does not seem to be
     * official documentation addressing the matter, I elected to have the script retrieve
     * new values every run to minimize risk of an error due to variation. These values are stored
     * within `Monitor.Enum.DPI_AWARENESS`. The values are used by `Monitor.ToggleModes()`.
     * This allows `Monitor.ToggleModes()` to provide the correct integer value for the current
     * thread's per-monitor DPI awareness context.
     *
     * @param {function} [sorter] - a function that sorts the monitors. See above notes for details.
     * @param {Integer} [DPI_AWARENESS_CONTEXT=-4] - the DPI awareness context used during initialization
     * @param {function} [errorHandler] - a function that handles errors that occur during the
     * execution of `Monitor._enumDisplayMonitors()`
     */
    static Refresh(sorter := ObjBindMethod(Monitor, '_MonSorter'), DPI_AWARENESS_CONTEXT := -4, errorHandler?) => Monitor.__New(sorter, DPI_AWARENESS_CONTEXT, errorHandler??Unset)

    /** ### Description - Monitor.__Enum()
     * Using `Monitor` within a `For` loop will iterate through the `Monitor.sorted` array. Each
     * item in the array is a `Monitor.Unit` object.
     */
    static __Enum(param*) => Monitor.sorted.__Enum(param*)

    /** ### Description - Monitor.Get()
     * @param {Integer} hmon - one of the following: the monitor's `hmon`, the script-assigned
     * `index` value, or the system-assigned monitor number prepended with an 's' (e.g. 's1', 's6', etc.)
     * @returns {Object} - the `Monitor.Unit` object
     */
    static Get(hmon) => Monitor[hmon]

    /** ### Description - Monitor.GetDpi()
     * Gets the DPI of a monitor or window. At least one of `hmon` or `hwnd` must be provided.
     * Both can also be provided. The Windows API function `GetDpiForMonitor` returns the DPI for
     * the x and y axis as separate values, and is not DPI aware. The `GetDpiForWindow` function
     * returns the DPI for the window, and is DPI aware; be conscientious of how you intend to
     * handle DPI scaling. The default value -4 disables system DPI scaling. Using the default, this
     * function will return the DPI value for the monitor with which the window has the greatest
     * area of intersection.
     * @param {Integer} [hmon] - the `hmon` value of the monitor
     * @param {Integer} [hwnd] - the `hwnd` value of the window
     * @param {VarRef} [outVar] - the variable to store the results
     * @param {Integer} [DPI_AWARENESS_CONTEXT=-4] - the DPI awareness context
     * @returns {Map} - the DPI values as a Map('x', dpiX, 'y', dpiY, 'win', dpiWin) The value
     * assigned to the VarRef is equivalent to the return value.
     * {@see https://learn.microsoft.com/en-us/windows/win32/api/shellscalingapi/nf-shellscalingapi-getdpiformonitor}
     * {@see https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getdpiforwindow}
     */
    static GetDpi(hmon?, hwnd?, &outVar?, DPI_AWARENESS_CONTEXT := -4) {
        Monitor.ToggleModes(&original, 'dpi', DPI_AWARENESS_CONTEXT)
        if IsSet(hmon) {
            if DllCall("Shcore\GetDpiForMonitor", (A_PtrSize = 4 ? 'Ptr' : 'UInt'), Number(hmon) < 100 ? Monitor[hmon]['hmon'] : Number(hmon) , "UInt", Monitor.Enum.MDT.DEFAULT, "UInt*", &dpiX := 0, "UInt*", &dpiY := 0, "UInt")
                throw Error('GetDpiForMonitor failed. hmon: ' hmon '`r`n' Monitor._FormatError(A_LastError), -1)
        }
        Monitor.ToggleModes(, original)
        return outVar := Map('x', dpiX??Unset, 'y', dpiY??Unset, 'win', IsSet(hwnd) ? DllCall("User32\GetDpiForWindow", "Ptr", Number(hwnd), "UInt") : Unset)
    }

    /** ### Description - Monitor.GetFromDimensions()
     * Gets the monitor object using the dimensions of a rectangle.
     * @param {Integer} x - the x-coordinate of the top-left corner of the rectangle
     * @param {Integer} y - the y-coordinate of the top-left corner of the rectangle
     * @param {Integer} w - the width of the rectangle
     * @param {Integer} h - the height of the rectangle
     * @returns {Object} - the `Monitor.Unit` object
     */
    static GetFromDimensions(x, y, w, h) => Monitor.GetFromRect(x, y, x+w, y+h)

    /** ### Description - Monitor.GetFromMouse()
     * Gets the monitor object using the position of the mouse pointer (at the time the function is called).
     * @param {VarRef} [mouseX] - the variable to store the x-coordinate of the mouse pointer
     * @param {VarRef} [mouseY] - the variable to store the y-coordinate of the mouse pointer
     * @returns {Object} - the `Monitor.Unit` object
     */
    static GetFromMouse(&mouseX?, &mouseY?) {
        DllCall("User32.dll\GetCursorPos", "Ptr", PT := Buffer(A_PtrSize))
        return Monitor.GetFromPoint(mouseX := NumGet(PT, 'Int'), mouseY := NumGet(PT, 4, 'Int'))
    }

    /** ### Description - Monitor.GetFromPoint()
     * Gets the monitor object based on the coordinates of a point.
     * @param {Integer} x - the x-coordinate of the point
     * @param {Integer} y - the y-coordinate of the point
     * @returns {Object} - the `Monitor.Unit` object
     * {@see https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-monitorfrompoint}
     */
    static GetFromPoint(x, y) => Monitor[DllCall("User32\MonitorFromPoint", 'Ptr', Monitor.DataTypes.Point(x, y), 'UInt', 0 , 'Ptr')]

    /** ### Description - Monitor.GetFromRect()
     * Gets the monitor object using a bounding rectangle.
     * @param {Integer} left - the left edge of the rectangle
     * @param {Integer} top - the top edge of the rectangle
     * @param {Integer} right - the right edge of the rectangle
     * @param {Integer} bottom - the bottom edge of the rectangle
     * @returns {Object} - the `Monitor.Unit` object
     * {@see https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-monitorfromrect}
     */
    static GetFromRect(left, top, right, bottom) => Monitor[DllCall("User32.dll\MonitorFromRect", "Ptr", Monitor.DataTypes.Rect(left, top, right, bottom), "UInt", 0, "UPtr")]

    /** ### Description - Monitor.GetFromHwnd()
     * Gets the monitor object using a windows `hwnd`.
     * @param {Integer} hwnd - a window's `hwnd`
     * @returns {Object} - the `Monitor.Unit` object
     * {@see  https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-monitorfromwindow}
     */
    static GetFromWindow(hwnd) => Monitor[DllCall("User32.dll\MonitorFromWindow", "Ptr", hwnd, "UInt", 0, "UPtr")]

    static IntersectRect(r1, r2) {
        rect := Buffer(16, 0)
        if DLLCall('User32.dll\IntersectRect', 'Ptr', rect, 'Ptr', r1, 'Ptr', r2)
            return Monitor.DataTypes.RectGet(rect)
    }

    /** ### Description - Monitor.OnDPIChange()
     * @see {@link https://learn.microsoft.com/en-us/windows/win32/hidpi/wm-dpichanged}
     * Provides a simple way to define a handler function for WM_DPICHANGED messages. Just pass
     * a callback function to this method. If you find that your callback function isn't being called
     * when expected, ensure that you call `DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")`
     * before creating the GUI. Your order of operations should go like this:
     * - Call `DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")`
     * - Create the GUI window.
     * - Call `Monitor.OnDPIChange(callback)`
     * The callback function will receive these parameters:
     * - `newDPI` - the new DPI value
     * - `rect` - the new monitor rectangle
     * - `msg` - the message number
     * - `hwnd` - the window handle
     * @param {function} callback - the callback function
     */
    static OnDPIChange(callback) {
        OnMessage(Monitor.Enum.WM_DPICHANGED, _OnDPIChange_.Bind(callback))
        _OnDPIChange_(callback, wParam, lParam, msg, hwnd) => callback(wParam & 0xFFFF, Monitor.DataTypes.RectGet(lParam), msg, hwnd)
    }

    /** ### Description - Monitor.SplitHorizontal()
     * This splits the width of a monitor into segments, and returns the dimensions
     * of the resulting interior rectangles as an array of map objects.
     * @param {Integer} hmon - one of the following: the monitor's `hmon`, the script-assigned
     * `index` value, or the system-assigned monitor number prepended with an 's' (e.g. 's1', 's6', etc.)
     * @param {Integer} segmentCount - the number of segments to split the monitor into
     * @param {VarRef} [outVar] - the variable to store the results
     * @param {Boolean} [useWorkArea=true] - whether to use the work area or the display area
     * @returns {Array} - You have the choice of using the VarRef `outVar`, and/or to receive a return
     * value. The result is the same in either case. The result is an array of Map objects, where
     * each map has items 'left' and 'right'. The array object has these additional properties:
     * - `segment` - the length of each segment
     * - `area` - the area used by the function (work area or display area of the monitor)
     */
    static SplitHorizontal(hmon, segmentCount, &outVar?, useWorkArea := true) {
        mon := Monitor[hmon], outVar := [], segment := outVar.segment := (useWorkArea ? (mon['work']['right'] - mon['work']['left']) / segmentCount : (mon['display']['right'] - mon['display']['left']) / segmentCount)
        left := (useWorkArea ? mon['work']['left'] : mon['display']['left']), outVar.area := (useWorkArea ? mon['work'] : mon['display'])
        Loop segmentCount
            outVar.Push(Map('left', left, 'right', left + segment)), left += segment
        return outVar
    }

    /** ### Description - Monitor.SplitVertical()
     * This splits the height of a monitor into segments, and returns the dimensions
     * of the resulting interior rectangles as an array of map objects.
     * @param {Integer} hmon - one of the following: the monitor's `hmon`, the script-assigned
     * `index` value, or the system-assigned monitor number prepended with an 's' (e.g. 's1', 's6', etc.)
     * @param {Integer} segmentCount - the number of segments to split the monitor into
     * @param {VarRef} [outVar] - the variable to store the results
     * @param {Boolean} [useWorkArea=true] - whether to use the work area or the display area
     * @returns {Array} - You have the choice of using the VarRef `outVar`, and/or to receive a return
     * value. The result is the same in either case. The result is an array of Map objects, where
     * each map has items 'top' and 'bottom'. The array object has these additional properties:
     * - `segment` - the length of each segment
     * - `area` - the area used by the function (work area or display area of the monitor)
     */
    static SplitVertical(hmon, segmentCount, &outVar?, useWorkArea := true) {
        mon := Monitor[hmon], outVar := [], segment := outVar.segment := (useWorkArea ? (mon['work']['bottom'] - mon['work']['top']) / segmentCount : (mon['display']['bottom'] - mon['display']['top']) / segmentCount)
        top := (useWorkArea ? mon['work']['top'] : mon['display']['top']), outVar.area := (useWorkArea ? mon['work'] : mon['display'])
        Loop segmentCount
            outVar.Push(Map('top', top, 'bottom', top + segment)), top += segment
        return outVar
    }

    /** ### Description - Monitor.ToggleModes()
     * This method toggles the modes of various settings. For this script, the modes of interest are:
     * - `mouse` - toggles the mouse coordinate mode
     * - `dpi` - toggles the DPI awareness context
     * @param {VarRef} [currentValues] - a variable to store the current values of the settings
     * @param {Array} modes - `modes` can be an array of values, or simply just list all of the
     * values within the function call without the array brackets. The setting name is first, then
     * the value. This function only supports 'dpi' and 'mouse' at this time.
     * @example
     * ; set both the `dpi` and `mouse` settings to new values
     * Monitor.ToggleModes(&originalValues, 'dpi', -4, 'Mouse', 'Screen')
     * ; do work
     * ; return  the settings to their original values
     * Monitor.ToggleModes(, originalValues)
     * @
     */
    static ToggleModes(&currentValues?, modes*) {
        currentValues := Map()
        if type(modes[1]) = 'Map' {
            arr := []
            for k, v in modes[1]
                arr.Push(k), arr.Push(v)
            modes := arr
        } else if (Mod(modes.length, 2) != 0)
            throw Error('There should be a single value for each mode. Here`'s your input:`r`n' Monitor._Stringify(modes), -1)
        Loop modes.length / 2 {
            mode := StrLower(modes[A_Index * 2 - 1]), val := modes[A_Index * 2]
            switch mode {
                case 'mouse':
                    currentValues.Set('mouse', CoordMode('Mouse', val))
                case 'dpi':
                    ; Retrieve the DPI awareness context for the current thread
                    dpiContext := DllCall("GetThreadDpiAwarenessContext", "ptr")
                    ; See top notes above Monitor.__New() for explanation of this section
                    if Monitor.Enum.DPI_AWARENESS.Has(dpiContext)
                        currentValues.Set('dpi', Monitor.Enum.DPI_AWARENESS[dpiContext])
                    else
                        currentValues.Set('dpi', Monitor.Enum.DPI_AWARENESS[DllCall("GetAwarenessFromDpiAwarenessContext", "ptr", dpiContext, "int")])
                    ; Set thread DPI awareness to input value
                    DllCall("SetThreadDpiAwarenessContext", "ptr", (IsNumber(val) ? Number(val) : Monitor.Enum.DPI_AWARENESS_CONTEXT[val]), "ptr")
                ; case 'hiddenwindows':
                ;     currentValues.Set(mode, DetectHiddenWindows(val))
                ; case 'titlematch':
                ;     currentValues.Set(mode, SetTitleMatchMode(val))
                ; case 'tooltip':
                ;     currentValues.Set(mode, CoordMode('Tooltip', val))
            }
        }
    }

    /** ### Description - Monitor.WinMoveByMouse()
     * A helper function for getting a new position for a window as a function of the mouse's
     * current position. This function restricts the window's new position to being within the
     * visible area of the monitor. Using the default value for `useWorkArea`, this also accounts
     * for the taskbar and other docked windows. `offsetMouse` and `offsetEdgeOfMonitor` provide
     * some control over the new position relative to the mouse pointer or the edge of the monitor.
     * Use this when moving something on-screen next to the mouse pointer.
     * @param {Integer} hwnd - the handle of the window
     * @param {Boolean} [useWorkArea=true] - whether to use the work area or the display area
     * @param {Boolean} [moveImmediately=true] - whether to move the window immediately
     * @param {Object} [offsetMouse={x:5,y:5}] - the offset from the mouse's current position
     * @param {Object} [offsetEdgeOfMonitor={x:50,y:50}] - the offset from the monitor's edge
     * @returns {Map} - a map object with the new x and y coordinates as `Map('x', <new x>, 'y', <new y>)`
     */
    static WinMoveByMouse(hwnd, useWorkArea := true, moveImmediately := true, offsetMouse := {x:5,y:5}, offsetEdgeOfMonitor := {x:50,y:50}) {
        mon := Monitor.GetFromMouse(&mX, &mY)[useWorkArea ? 'work' : 'display']
        WinGetPos(&wX, &wY, &wW, &wH, Number(hwnd))
        if (mX + offsetMouse.x + wW > mon['right'])
            x := mon['right'] - wW - offsetEdgeOfMonitor.x
        else if (mX + offsetMouse.x + wW < mon['left'])
            x := mon['left'] + offsetEdgeOfMonitor.x
        else
            x := mX + offsetMouse.x
        if (mY + offsetMouse.y + wH > mon['bottom'])
            y := mon['bottom'] - wH - offsetEdgeOfMonitor.y
        else if (mY + offsetMouse.y + wH < mon['top'])
            y := mon['top'] + offsetEdgeOfMonitor.y
        else
            y := mY + offsetMouse.y
        if moveImmediately
            WinMove(x, y, , , Number(hwnd))
        return Map('x', x, 'y', y)
    }

    /** ### Enumeration
     * {@see https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-monitorfromrect}
     * {@see https://learn.microsoft.com/en-us/windows/win32/api/windef/ne-windef-dpi_awareness}
     * {@see https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setthreaddpiawarenesscontext}
     */
    class Enum {
        static WM_DPICHANGED := 0x02E0
        static MONITOR_DEFAULTTONULL := 0x00000000
        static MONITOR_DEFAULTTOPRIMARY := 0x00000001
        static MONITOR_DEFAULTTONEAREST := 0x00000002
        static MDT := {
              EFFECTIVE_DPI: 0
            , ANGULAR_DPI: 1
            , RAW_DPI: 2
            , DEFAULT: 0
        }
        static DPI_AWARENESS_CONTEXT := Map(
            'DPI_AWARENESS_UNAWARE', -1
          , 'DPI_AWARENESS_SYSTEM_AWARE', -2
          , 'DPI_AWARENESS_PER_MONITOR_AWARE', -3
          , 'DPI_AWARENESS_PER_MONITOR_AWARE_V2', -4
          , 'DPI_AWARENESS_UNAWARE_GDISCALED', -5
        )
        static DPI_AWARENESS := Map(
            -1, 'DPI_AWARENESS_INVALID'
          , 0, -1 ; 'DPI_AWARENESS_UNAWARE'
          , 1, -2 ; 'DPI_AWARENESS_SYSTEM_AWARE'
          , 2, -3 ; 'DPI_AWARENESS_PER_MONITOR_AWARE'
        )
    }

    /* ** ** ** Internal methods ** ** ** */

    /** @see {@link Monitor.Refresh} */
    static __New(sorter := ObjBindMethod(Monitor, '_MonSorter'), DPI_AWARENESS_CONTEXT := -4, errorHandler?) {

        ; prepare containers
        Monitor.scriptPath := A_LineFile
        Monitor.__Item := Map()
        Monitor.__Item.CaseSense := false
        Monitor.sorted := []
        Monitor._errors := []

        ; Get DPI awareness values for the current thread, see note above `Monitor.Refresh()`
        originalDPIContext := DllCall("GetThreadDpiAwarenessContext", "ptr")
        DllCall("SetThreadDpiAwarenessContext", "ptr", -5, "ptr")
        Monitor.Enum.DPI_AWARENESS.Set(DllCall("GetThreadDpiAwarenessContext", "ptr"), 'DPI_AWARENESS_UNAWARE_GDISCALED')
        DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
        Monitor.Enum.DPI_AWARENESS.Set(DllCall("GetThreadDpiAwarenessContext", "ptr"), 'DPI_AWARENESS_PER_MONITOR_AWARE_V2')
        ; Set DPI Awareness Context
        if DPI_AWARENESS_CONTEXT != -4
            DllCall("SetThreadDpiAwarenessContext", "ptr", DPI_AWARENESS_CONTEXT, "ptr")

        ; Enumerate monitors
        Monitor._EnumDisplayMonitors(sorter)
        ; Apply sorted order
        for unit in Monitor.sorted {
            unit['index'] := A_Index
            Monitor.__Item.Set('s' unit['number'], unit, A_Index, unit, String(unit['hmon']), unit)
        }

        ; Return to thread's original DPI Awareness Context
        if Monitor.Enum.DPI_AWARENESS.Has(originalDPIContext)
            DllCall("SetThreadDpiAwarenessContext", "ptr", Monitor.Enum.DPI_AWARENESS[originalDPIContext], "ptr")
        else
            DllCall("SetThreadDpiAwarenessContext", "ptr", Monitor.Enum.DPI_AWARENESS[DllCall("GetAwarenessFromDpiAwarenessContext", "ptr", originalDPIContext, "int")], "ptr")

        if Monitor._errors.length {
            if IsSet(errorHandler)
                errorHandler(Monitor._errors)
            else
                Monitor._ErrorWindowConstructor()
        }
    }

    static _MonitorEnumProc(hmon, hDC, pRECT, objectAddr) {
        Monitor.__Item.Set(hmon, Monitor.Unit(hmon))
        return true
    }
    static _cbMonitorEnumProc := CallbackCreate(ObjBindMethod(Monitor, '_MonitorEnumProc'), , 4)
    /** ### Description - Monitor._EnumDisplayMonitors()
     * If you need to refresh the monitor details, use `Monitor.Refresh()` instead.
     * This method implements Microsoft's `_EnumDisplayMonitors` function.
     * {@see https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-Enumdisplaymonitors}
     * credits to @tigerlily
     * {@see https://www.autohotkey.com/boards/viewtopic.php?f=83&t=79220}
     */
    static _EnumDisplayMonitors(sorter?) {
        if !(DllCall("user32\EnumDisplayMonitors", "ptr", 0, "ptr", 0, "ptr", Monitor._cbMonitorEnumProc, "ptr", ObjPtr(Monitor.Unit.prototype.__New), "uint"))
            return Monitor._ProcessError(A_LastError, "_EnumDisplayMonitors failed")
        if IsSet(sorter)
            sorter()
    }

    static _MonSorter() {
        i := 2
        for hmon, unit in Monitor.__Item {
            if unit['primary']
                continue
            if !Monitor.sorted.length {
                Monitor.sorted.length := MonitorGetCount()
                Monitor.sorted[1] := unit
                continue
            }
            currentItemLeft := unit['display']['left']
            flag_insert := false
            for item in Monitor.sorted {
                if !IsSet(item) || !item
                    continue
                containerItemLeft := item['display']['left']
                if currentItemLeft < containerItemLeft {
                    Monitor.sorted.InsertAt(A_Index, unit)
                    flag_insert := true
                    break
                } else if currentItemLeft = containerItemLeft {
                    flag_insert := true
                    currentItemTop := unit['display']['top'], containerItemTop := item['display']['top']
                    if currentItemTop <= containerItemTop
                        Monitor.sorted.InsertAt(A_Index, unit)
                    else
                        Monitor.sorted.InsertAt(A_Index+1, unit)
                    break
                }
            }
            if !flag_insert
                Monitor.sorted[i] := unit
            i++
        }
        Monitor.sorted.InsertAt(1, Monitor.primary)
        Monitor.sorted.length := MonitorGetCount()
    }

    static _ProcessError(err := 0, errMsg?, errWhat := -2, errExtra?) {
        if err
            return OSError(err)
        else {
            if IsSet(errMsg)
                return Error(errMsg, errWhat, errExtra??'')
            else
                return 1
        }
    }

    static _ErrorWindowConstructor() {
        g := Gui('+Owner +Resize')
        str := 'One or more errors occured. Details:`r`n`r`n'
        for item in Monitor._errors {
            for k, v in item
                str .= Format('hmon for which the error occurred: {1}`r`nError:`r`n{2}{3}', k, Monitor._FormatError(v), (A_Index = item.length ? '' : '`r`n`r`n'))
        }
        g.Add('Edit', 'w800 vedit', str)
        g.Add('Button', 'w100', 'Copy').OnEvent('Click', _Copy_)
        _Copy_(ctrl, *) {
            A_Clipboard := ctrl.gui['edit'].Text
            initial := CoordMode('Mouse', 'Screen')
            MouseGetPos(&x, &y)
            Tooltip('Copied!', x, y)
            SetTimer(Tooltip, -2000)
            CoordMode('Mouse', initial)
        }
        g.Show('x200 y200')
    }

    static _Stringify(obj, delim := '`r`n') {
        str := ''
        switch type(obj) {
            case 'Map', 'Object':
                if type(obj) = 'Object'
                    obj.DefineProp('__Enum', {Call: ((self, params*) => self.OwnProps())})
                for k, v in obj {
                    if IsObject(v)
                        str .= Format('Key: {2}{1}Value: {3}{1}', delim, k, Monitor._Stringify(v))
                    else {
                        try
                            str .= Format('Key: {2}{1}Value: {3}{1}', delim, k, String(v))
                        catch
                            str .= Format('Key: {2}{1}Value: Could not stringify value{1}', delim, k)
                    }
                }
            case 'Array':
                i := 0
                for item in obj {
                    i++
                    if IsObject(item)
                        str .= Format('Index: {2}{1}Value: {3}{1}', delim, i, Monitor._Stringify(item))
                    else {
                        try
                            str .= Format('Index: {2}{1}Value: {3}{1}', delim, i, StrinG(item))
                        catch
                            str .= Format('Index: {2}{1}Value: Could not stringify value{1}', delim, i)
                    }
                }
            default:
                if obj.HasMethod('__Enum') {
                    try {
                        for k, v in obj {
                            if IsObject(v)
                                str .= Format('Key: {2}{1}Value: {3}{1}', delim, k, Monitor._Stringify(v))
                            else {
                                try
                                    str .= Format('Key: {2}{1}Value: {3}{1}', delim, k, String(v))
                                catch
                                    str .= Format('Key: {2}{1}Value: Could not stringify value{1}', delim, k)
                            }
                        }
                    } catch
                        throw Error('An error occurred when attempting to enumerate the object.`r`nLine: ' A_LineNumber '`r`nFile: ' A_LineFile '`r`nFunction: ' A_ThisFunc, -1)
                }
                throw Error('The input object does not have an ``__Enum`` method', -1)
        }
        return Trim(str, delim)
    }

    static _FormatError(err) {
        extra := (err.Extra ? 'Extra: ' err.Extra '`n' : '')
        return (
            'Message: ' err.message '`n'
            'What: ' err.What '`n'
            extra
            'File: ' err.File '`n'
            'Line: ' err.Line '`n'
            'Stack: ' err.Stack
        )
    }

    class DataTypes {
        static Point(a,b) => ((a & 0xFFFFFFFF) | (b << 32))
        static RectFromDimensions(x, y, w, h) => Monitor.DataTypes.Rect(x, y, x+w, y+h)
        static Rect(left, top, right, bottom) {
            rect := Buffer(16, 0)
            NumPut('Int', left, rect, 0)
            NumPut('Int', top, rect, 4)
            NumPut('Int', right, rect, 8)
            NumPut('Int', bottom, rect, 12)
            return rect
        }
        static RectGet(rect) => Map('left', NumGet(rect, 0, 'Int'), 'top', NumGet(rect, 4, 'Int'), 'right', NumGet(rect, 8, 'Int'), 'bottom', NumGet(rect, 12, 'Int'))
    }
}

