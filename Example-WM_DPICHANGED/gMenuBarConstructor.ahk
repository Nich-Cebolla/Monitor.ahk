
class MenuBarConstructor {

    /** ### Description - MenuBarConstructor()
     * This class is used to create a menu bar with the specified menus.
     * @param {Array} menus - An array of arrays. For each nested array, the first item in the
     * array represents the display name for the menu. Each subsequent item in the array contains
     * alternating menu item names and callbacks for the previous menu item. The alternating items
     * begins with a item name, the next is the first item's callback, and so on.
     * @returns {MenuBar} - A MenuBar object with the specified menus.
     */
    static Call(menus, self, &container?) {
        menuItems := Map()
        bar := MenuBar()
        for item in menus {
            menuName := item.RemoveAt(1)
            menuItems.Set(menuName, Menu())
            m := menuItems[menuName]
            Loop item.length / 2
                m.Add(item[A_Index * 2 - 1], item[A_Index * 2].Bind(self))
            bar.Add(menuName, m)
        }
        return bar
    }
}