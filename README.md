# Monitor Class

### Credits
Key details regarding DLL calls were sourced from or pulled directly from the following discussions:
- [AutoHotkey Forum](https://www.autohotkey.com/boards/viewtopic.php?f=6&t=4606)
  - Contributors: `@just me`, `@iPhilip`, `@guest3456`
- [AutoHotkey Forum - DPI Awareness](https://www.autohotkey.com/boards/viewtopic.php?f=83&t=79220)
  - Contributors: `@Tigerlily`, `@CloakerSmoker`, `@jNizM`
- [JSON class](https://github.com/thqby/ahk2_lib/blob/master/JSON.ahk), [ComVar](https://github.com/thqby/ahk2_lib/blob/master/ComVar.ahk), [Promise](https://github.com/thqby/ahk2_lib/blob/master/Promise.ahk), [WebView2](https://github.com/thqby/ahk2_lib/blob/master/WebView2/WebView2.ahk)
  - Author: `Thqby`
---

## Repository Contents
### Root directory
- cMonitor.ahk - The script containing the `Monitor` class.
### Directory Example-WM_DPICHANGED
Contains all files necessary to demonstrate implementing the `Monitor.OnDPIChange` method using
`Thqby's WebView2`. As I was creating the script, I hadn't thought of sharing it in this way (it's a personal project) so it requires a number of dependencies to run. But you can look at the example script file to get an idea of how it works, I included comments. See section `Monitor.OnDPIChange` below for more details.
### Directory Test-Interface
Contains a script I wrote to test `Monitor` so I can verify the functions work as intended after making updates. It also contains one dependency, which is a function that scrapes AHK class scripts and returns the name of each class method, and the method parameters. I'm quite proud of that one so feel free to use it. (It might incorrectly identify single-line fat-arrow function calls (not method definitions) as methods. I can't remember if I fixed that or if I just worked around it.) The testing interface script may not load correctly at the moment. I'll review it at a later time.

## Description

This class provides methods for obtaining information about monitor size, dimensions, position, and DPI. The parent script can gather monitor information using:

- A single point: `Monitor.GetFromPoint`
- A window's `hwnd`: `Monitor.GetFromWindow`
- A rectangle (left, top, right, bottom): `Monitor.GetFromRect`
- Dimensions (x, y, w, h): `Monitor.GetFromDimensions`
- Current position of the mouse pointer: `Monitor.MouseGetMonitor`

### Identifiers
When retrieving monitor information, three key identifiers are used:

1. **HMON**: The monitor's handle (similar to `HWND`).
2. **Monitor Number**: Assigned by the OS, prefixed with `s` (e.g., `Monitor['s3']`).
3. **Index**: Assigned by this script, beginning at 1 and incrementing by 1.

### Additional Methods

- `Monitor.Refresh`: Refreshes the monitor details.
- `Monitor.__Enum`: Enumerates the monitors; compatible with `For` loops (e.g., `For unit in Monitor`).
- `Monitor.IntersectRect`: Returns the intersection of two rectangles.
- `Monitor.OnDPIChange`: Sets up a handler function for `WM_DPICHANGED` messages.
- `Monitor.SplitHorizontal`: Splits the width of a monitor into segments.
- `Monitor.SplitVertical`: Splits the height of a monitor into segments.
- `Monitor.ToggleModes`: Toggles DPI awareness context and mouse coordinate mode.
- `Monitor.WinMoveByMouse`: Moves a window by the mouse pointer, ensuring it stays within the visible area of the monitor.

> **Note**: The `Monitor` class does not return an instance object. All properties and methods belong to the class itself. `Monitor.__New()` is called automatically when the class is first accessed, but it can be called manually to set different input parameters. `Monitor.Refresh()` can also be called anytime to use new input parameters.

---

## Monitor.Unit Class

### Description - Monitor.Unit.prototype

This class constructs the monitor objects used within the script. When you `Get` a monitor object, an instance of this class's prototype is returned.

In general, calling this class constructor directly isn’t necessary. The class is placed at the beginning so you can see the properties and methods available within monitor objects.

### Instance Properties

The main property is `prototype.__Item`, which is a map object containing details about the monitor. These map objects are not case-sensitive and contain two nested map objects:

- **Display**: Represents the entire visual area of the monitor.
- **Work**: Represents the monitor's display area, excluding elements like taskbars and docked windows.

### Enumeration

You can enumerate a `Monitor.Unit` object with a simple `for` loop without any special syntax.

### Methods

- `Monitor.Unit.prototype.SplitVertical()`: Calls `Monitor.SplitVertical()` for the monitor, splitting the height into segments and returning the resulting rectangles as an array of map objects.
- `Monitor.Unit.prototype.SplitHorizontal()`: Calls `Monitor.SplitHorizontal()` for the monitor, splitting the width into segments and returning the resulting rectangles as an array of map objects.


## Monitor.Refresh Method

### Description
The `Monitor.Refresh()` method updates the monitor details, ensuring any changes to monitor configurations are reflected.

### Sorting

Sorting affects:

1. The order in which `Monitor.Unit` objects appear when enumerating `Monitor` in a for loop.
2. The `Monitor.Unit` object retrieved when using `Monitor.Get(number)` or `Monitor[number]`.
3. The `index` assigned to each `Monitor.Unit` object.

**Default Sorting**:
- The primary monitor is assigned index `1`.
- Non-primary monitors are ordered by the position of their left-edge, from lowest to highest.
  - If two monitors have the same left-edge position, the monitor with the lesser top-edge position is first (a lesser top-edge is physically above a greater one).

Example:
- Given three non-primary monitors with left-edge positions:
  a) -1910, b) 70, c) 2050
  The order would be:
  - `1`: Primary monitor
  - `2`: Monitor a
  - `3`: Monitor b
  - `4`: Monitor c

**Custom Sorting**:
To implement custom sorting, define a sorter function that enumerates `Monitor.__Item`. The sorter function should:
- Evaluate the desired order for each monitor object.
- Insert non-primary monitors into an array (`Monitor.sorted`) in the desired order.
- Optionally set the primary monitor as index `1` using `Monitor.sorted.InsertAt(1, primaryMonObject)` after enumerating the others.

### Error Handling

Errors are handled based on where they occur:
- Errors during `Monitor._EnumDisplayMonitors()` are stored in the `Monitor._errors` array and displayed in a GUI window for debugging. This display can be disabled by passing a custom error handling function to `errorHandler` when calling `Monitor.Refresh()`.
- Other errors are thrown immediately and rely on the interpreter’s error handling. Wrap calls to `Monitor.Refresh()` in `try-catch` blocks to manage errors.

> **Note**: `Monitor.__New()` is called on the first reference to `Monitor`, which includes the enumeration and error sequence. To prevent the error window from displaying to users, make the first call `Monitor.__New()` with your custom error handler.

### DPI Awareness Context

A DPI awareness context of `-4` signals the Windows API that the application is per-monitor DPI aware, meaning the script manages DPI scaling directly. This is ideal when setting baseline coordinates and dimensions for windows and controls.

If using a different DPI awareness context is necessary, pass the desired context as `DPI_AWARENESS_CONTEXT`.

### DPI Awareness Enumeration

To detect per-monitor DPI awareness context, `Monitor.__New()` uses:
- `DllCall("SetThreadDpiAwarenessContext", "ptr", -4|-5, "ptr")` for both `-4` and `-5`.
- Retrieves DPI awareness with `DllCall("GetThreadDpiAwarenessContext", "ptr")`.

The values are stored in `Monitor.Enum.DPI_AWARENESS` and are referenced by `Monitor.ToggleModes()` for setting the correct DPI awareness context.

### Parameters
- `sorter` *(function)*: Function that sorts monitors (optional, default: `_MonSorter`).
- `DPI_AWARENESS_CONTEXT` *(Integer)*: DPI awareness context during initialization (default: `-4`).
- `errorHandler` *(function)*: Function to handle errors in `Monitor._EnumDisplayMonitors()` (optional).

## Monitor.__Enum Method

### Description
Using `Monitor` within a `For` loop will iterate through the `Monitor.sorted` array, where each item is a `Monitor.Unit` object.

---

## Monitor.Get Method

### Description
Retrieves a `Monitor.Unit` object based on the specified monitor identifier.

### Parameters
- `hmon` *(Integer)*: One of the following options:
  - The monitor's `hmon` value.
  - The script-assigned `index` value.
  - The system-assigned monitor number, prefixed with an 's' (e.g., `'s1'`, `'s6'`, etc.).

### Returns
- *(Object)*: The `Monitor.Unit` object associated with the specified `hmon`.

---

## Monitor.GetDpi Method

### Description
Gets the DPI of a monitor or window. Either `hmon` or `hwnd` must be provided; both can also be supplied. The method leverages the Windows API `GetDpiForMonitor` to fetch DPI values for the x and y axes (not DPI aware) and `GetDpiForWindow` to obtain the DPI of a window (DPI aware).

When using the default `DPI_AWARENESS_CONTEXT` of `-4`, system DPI scaling is disabled, and the DPI value returned corresponds to the monitor with which the window has the most significant overlap.

### Parameters
- `hmon` *(Integer, optional)*: The `hmon` value of the monitor.
- `hwnd` *(Integer, optional)*: The `hwnd` value of the window.
- `outVar` *(VarRef, optional)*: The variable where the results will be stored.
- `DPI_AWARENESS_CONTEXT` *(Integer, default: -4)*: Sets the DPI awareness context.

### Returns
- *(Map)*: The DPI values as a map object containing:
  - `'x'`: DPI for the x-axis.
  - `'y'`: DPI for the y-axis.
  - `'win'`: DPI for the window, if `hwnd` is provided.

> **References**:
> - [GetDpiForMonitor - Microsoft Documentation](https://learn.microsoft.com/en-us/windows/win32/api/shellscalingapi/nf-shellscalingapi-getdpiformonitor)
> - [GetDpiForWindow - Microsoft Documentation](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getdpiforwindow)

## Monitor.GetFromDimensions Method

### Description
Retrieves the `Monitor.Unit` object using the dimensions of a rectangle.

### Parameters
- `x` *(Integer)*: The x-coordinate of the top-left corner of the rectangle.
- `y` *(Integer)*: The y-coordinate of the top-left corner of the rectangle.
- `w` *(Integer)*: The width of the rectangle.
- `h` *(Integer)*: The height of the rectangle.

### Returns
- *(Object)*: The `Monitor.Unit` object.

---

## Monitor.GetFromPoint Method

### Description
Gets the `Monitor.Unit` object based on the coordinates of a specific point.

### Parameters
- `x` *(Integer)*: The x-coordinate of the point.
- `y` *(Integer)*: The y-coordinate of the point.

### Returns
- *(Object)*: The `Monitor.Unit` object.

> **Reference**: [MonitorFromPoint - Microsoft Documentation](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-monitorfrompoint)

---

## Monitor.GetFromRect Method

### Description
Retrieves the `Monitor.Unit` object using a bounding rectangle.

### Parameters
- `left` *(Integer)*: The left edge of the rectangle.
- `top` *(Integer)*: The top edge of the rectangle.
- `right` *(Integer)*: The right edge of the rectangle.
- `bottom` *(Integer)*: The bottom edge of the rectangle.

### Returns
- *(Object)*: The `Monitor.Unit` object.

> **Reference**: [MonitorFromRect - Microsoft Documentation](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-monitorfromrect)

---

## Monitor.GetFromWindow Method

### Description
Retrieves the `Monitor.Unit` object using a window's `hwnd`.

### Parameters
- `hwnd` *(Integer)*: The `hwnd` value of the window.

### Returns
- *(Object)*: The `Monitor.Unit` object.

> **Reference**: [MonitorFromWindow - Microsoft Documentation](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-monitorfromwindow)

---

## Monitor.IntersectRect Method

### Description
Determines the intersection of two rectangles.

### Parameters
- `r1` *(Buffer)*: The first rectangle.
- `r2` *(Buffer)*: The second rectangle.

### Returns
- *(Object)*: The intersection as a rectangle, retrieved using `Monitor.DataTypes.RectGet(rect)`.

## Monitor.MouseGetMonitor Method

### Description
Gets the `Monitor.Unit` object based on the current position of the mouse pointer at the time the function is called.

### Parameters
- `mouseX` *(VarRef, optional)*: Variable to store the x-coordinate of the mouse pointer.
- `mouseY` *(VarRef, optional)*: Variable to store the y-coordinate of the mouse pointer.

### Returns
- *(Object)*: The `Monitor.Unit` object.

---

## Monitor.OnDPIChange Method

### Description
Provides a straightforward way to define a handler function for `WM_DPICHANGED` messages. Pass a callback function to this method. Ensure `DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")` is called before creating the GUI for the callback to work correctly.

**Order of Operations**:
1. Call `DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")`.
2. Create the GUI window.
3. Call `Monitor.OnDPIChange(callback)`.

The callback function will receive:
- `newDPI`: The new DPI value.
- `rect`: The recommended `left`, `top`, `right`, and `bottom` values to scale the window.
- `msg`: The message number.
- `hwnd`: The window handle.

### Parameters
- `callback` *(function)*: The callback function to handle `WM_DPICHANGED`.

### Example using WebView2
Within the `Example-WM_DPICHANGED` directory you can download a set of files that implements this method using a Gui window containing a WebView2 control. I hope it serves as a decent example.

> **Reference**: [WM_DPICHANGED - Microsoft Documentation](https://learn.microsoft.com/en-us/windows/win32/hidpi/wm-dpichanged)

---

## Monitor.SplitHorizontal Method

### Description
Splits the width of a monitor into a specified number of horizontal segments, returning the dimensions of each segment as an array of map objects.

### Parameters
- `hmon` *(Integer)*: One of the following:
  - The monitor's `hmon` value.
  - The script-assigned `index` value.
  - The system-assigned monitor number prefixed with an 's' (e.g., `'s1'`, `'s6'`).
- `segmentCount` *(Integer)*: The number of segments to split the monitor width into.
- `outVar` *(VarRef, optional)*: Variable to store the resulting array.
- `useWorkArea` *(Boolean, default: `true`)*: If `true`, splits the work area; otherwise, splits the display area.

### Returns
- *(Array)*: An array of map objects representing each segment. Each map includes:
  - `'left'`: The left edge of the segment.
  - `'right'`: The right edge of the segment.

The array also includes:
- `segment`: The length of each segment.
- `area`: The area used by the function (either the work area or display area of the monitor).

## Monitor.SplitVertical Method

### Description
Splits the height of a monitor into a specified number of vertical segments, returning the dimensions of each segment as an array of map objects.

### Parameters
- `hmon` *(Integer)*: One of the following:
  - The monitor's `hmon` value.
  - The script-assigned `index` value.
  - The system-assigned monitor number prefixed with an 's' (e.g., `'s1'`, `'s6'`).
- `segmentCount` *(Integer)*: The number of segments to split the monitor height into.
- `outVar` *(VarRef, optional)*: Variable to store the resulting array.
- `useWorkArea` *(Boolean, default: `true`)*: If `true`, splits the work area; otherwise, splits the display area.

### Returns
- *(Array)*: An array of map objects representing each segment. Each map includes:
  - `'top'`: The top edge of the segment.
  - `'bottom'`: The bottom edge of the segment.

The array also includes:
- `segment`: The height of each segment.
- `area`: The area used by the function (either the work area or display area of the monitor).

---

## Monitor.ToggleModes Method

### Description
This method toggles modes for various settings, specifically `mouse` coordinate mode and `dpi` awareness context.

### Parameters
- `currentValues` *(VarRef, optional)*: A variable to store the current values of the toggled settings.
- `modes` *(Array or List of Parameters)*: Modes to toggle, provided as key-value pairs. Supported modes are:
  - `'dpi'`: Toggles DPI awareness context.
  - `'mouse'`: Toggles mouse coordinate mode.

### Example
```ahk
; Set both `dpi` and `mouse` settings to new values
Monitor.ToggleModes(&originalValues, 'dpi', -4, 'Mouse', 'Screen')
; Perform operations
; Restore original settings
Monitor.ToggleModes(, originalValues)
```

## Monitor.WinMoveByMouse Method

### Description
A helper function to reposition a window based on the current position of the mouse. This function ensures the window remains within the visible area of the monitor. By default, it takes into account the work area, including taskbars and docked windows. Adjust `offsetMouse` and `offsetEdgeOfMonitor` to control the window’s position relative to the mouse pointer or the monitor's edge. This is especially useful for positioning a window next to the mouse pointer.

### Parameters
- `hwnd` *(Integer)*: The handle of the window.
- `useWorkArea` *(Boolean, default: `true`)*: Whether to use the work area or the display area.
- `moveImmediately` *(Boolean, default: `true`)*: Whether to move the window immediately.
- `offsetMouse` *(Object, default: `{x:5, y:5}`)*: Offset from the mouse’s current position.
- `offsetEdgeOfMonitor` *(Object, default: `{x:50, y:50}`)*: Offset from the monitor’s edge.

### Returns
- *(Map)*: A map object containing the new `x` and `y` coordinates:
  - `'x'`: New x-coordinate for the window.
  - `'y'`: New y-coordinate for the window.

---

## Additional References

- [MonitorFromRect - Microsoft Documentation](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-monitorfromrect)
- [DPI Awareness - Microsoft Documentation](https://learn.microsoft.com/en-us/windows/win32/api/windef/ne-windef-dpi_awareness)
- [SetThreadDpiAwarenessContext - Microsoft Documentation](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setthreaddpiawarenesscontext)
