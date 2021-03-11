# snack.py: maps C extension module _snack to proper python types in module
# snack.
# The first section is a very literal mapping.
# The second section contains convenience classes that amalgamate
# the literal classes and make them more object-oriented.

"""
This module provides the NEWT Windowing toolkit API for Python
This is a lightweight text-mode windowing library, based on slang.

Classes:

 - Widget  
 - Button  
 - CompactButton
 - Checkbox
 - SingleRadioButton
 - Listbox
 - Textbox
 - TextboxReflowed
 - Label
 - Scale
 - Entry
 - Form
 - Grid
 - SnackScreen
 - RadioGroup
 - RadioBar
 - ButtonBar
 - GridFormHelp
 - GridForm
 - CheckboxTree
 - Clistbox

Functions:

 - ListboxChoiceWindow
 - ButtonChoiceWindow
 - EntryWindow
"""

import _snack
import types
import string

from _snack import FLAG_DISABLED, FLAGS_SET, FLAGS_RESET, FLAGS_TOGGLE, FD_READ, FD_WRITE, FD_EXCEPT

LEFT = (-1, 0)
DOWN = (-1, -1)
CENTER = (0, 0)
UP = (1, 1)
RIGHT = (1, 0)

snackArgs = {"append":-1}

class Widget:
    """Base class for NEWT toolkit - Do not use directly

    methods:

     - Widget(self)
     - setCallback(self, obj, data = None) : 
          The callback for when object activated.
          data is passed to obj.
    """
    def setCallback(self, obj, data = None):
        if data:
            self.w.setCallback(obj, data)
        else:
            self.w.setCallback(obj)
            
    def __init__(self):
        raise NotImplementedError

class Button(Widget):
    """Basic button class, takes button text as parameter

    method:

     - Button(self, text): returns a button
    """
    def __init__(self, text):
        self.w = _snack.button(text)

class CompactButton(Widget):
    """Compact Button class (less frilly button decoration).

    methods:

     - CompactButton(self,text) : create button, with text.
    """
    def __init__(self, text):
        self.w = _snack.compactbutton(text)

class Checkbox(Widget):
    """A checkbox.

    methods:
    
      - Checkbox(self, text, isOn = 0) : text, and boolean as to default value
      - setValue(self)                 : set value
      - value(self, value)             : return checkbox value
      - selected(self)                 : returns boolean
      - setFlags(self, flag, sense)    : set flags

      flags:  FLAG_DISABLED, FLAGS_SET, FLAGS_RESET
    """
    def value(self):
        return self.w.checkboxValue

    def selected(self):
        return self.w.checkboxValue != 0

    def setFlags (self, flag, sense):

        return self.w.checkboxSetFlags(flag, sense)

    def setValue (self, value):
        return self.w.checkboxSetValue(value)

    def __init__(self, text, isOn = 0):
        self.w = _snack.checkbox(text, isOn)

class SingleRadioButton(Widget):
    """Single Radio Button.

    methods:
    
     -  SingleRadioButton(text, group, isOn = 0)  : create button
     -  selected(self)                            : returns bool, whether or not is selected.
    """
    
    def selected(self):
        return self.w.key == self.w.radioValue;
    
    def __init__(self, text, group, isOn = 0):
        if group:
            self.w = _snack.radiobutton(text, group.w, isOn)
        else:
            self.w = _snack.radiobutton(text, None, isOn)

class Listbox(Widget):
    """Listbox class.

    methods:

     - Listbox(self, height, scroll = 0, returnExit = 0, width = 0, showCursor = 0, multiple = 0, border = 0)
     - insert(self, text, item, before) : insert element; before = key to item to insert before, or None.
     - delete(self, item)               : delete item from list.
     - replace(self, text,item)         : Replace a given item's text
     - current(self)                    : returns currently selected item
     - getSelection(self)               : returns a list of selected items
     - setCurrent(self,i tem)           : select current.
     - clear(self)                      : clear listbox
    """
    
    def append(self, text, item):
        key = self.w.listboxAddItem(text)
        self.key2item[key] = item
        self.item2key[item] = key

    def insert(self, text, item, before):
        if (not before):
            key = self.w.listboxInsertItem(text, 0)
        else:
            key = self.w.listboxInsertItem(text, self.item2key[before])
        self.key2item[key] = item
        self.item2key[item] = key

    def delete(self, item):
        self.w.listboxDeleteItem(self.item2key[item])
        del self.key2item[self.item2key[item]]
        del self.item2key[item]

    def replace(self, text, item):
        key = self.w.listboxInsertItem(text, self.item2key[item])
        self.w.listboxDeleteItem(self.item2key[item])
        del self.key2item[self.item2key[item]]
        self.item2key[item] = key
        self.key2item[key] = item

    def current(self):
        return self.key2item[self.w.listboxGetCurrent()]

    def getSelection(self):
        selection = []
        list = self.w.listboxGetSelection()
        for key in list:
            selection.append(self.key2item[key])
        return selection

    def setCurrent(self, item):
        self.w.listboxSetCurrent(self.item2key[item])

    def clear(self):
        self.key2item = {}
        self.item2key = {}        
        self.w.listboxClear()

    def __init__(self, height, scroll = 0, returnExit = 0, width = 0, showCursor = 0, multiple = 0, border = 0):
        self.w = _snack.listbox(height, scroll, returnExit, showCursor, multiple, border)
        self.key2item = {}
        self.item2key = {}
        if (width):
            self.w.listboxSetWidth(width)

class Textbox(Widget):
    """Textbox, container for text.

    methods:

     - Textbox(self, width, height, scroll = 0, wrap = 0): scroll, wrap are flags
                                   include scroll bars, or text wrap.
     - setText(text) : set text.
     - setHeight(height): set height.
    """
    
    def setText(self, text):
        self.w.textboxText(text)

    def setHeight(self, height):
        self.w.textboxHeight(height)

    def __init__(self, width, height, text, scroll = 0, wrap = 0):
        self.w = _snack.textbox(width, height, text, scroll, wrap)

class TextboxReflowed(Textbox):

    def __init__(self, width, text, flexDown = 5, flexUp = 10, maxHeight = -1):
        (newtext, width, height) = reflow(text, width, flexDown, flexUp)
        if maxHeight != -1 and height > maxHeight:
            Textbox.__init__(self, width, maxHeight, newtext, 1)
        else:
            Textbox.__init__(self, width, height, newtext, 0)

class Label(Widget):
    """A Label (simple text).

    methods:

     - Label(self,text)   : create label
     - setText(self,text) : change text.
     - setColors(self, colorset) : change individual colors
    """
    def setText(self, text):
        self.w.labelText(text)

    def __init__(self, text):
        self.w = _snack.label(text)

    def setColors(self, colorset):
        self.w.labelSetColors(colorset)

class Scale(Widget):
    """A Scale (progress bar).

    methods:

     - Scale(self,width, total) : create scale; width: size on screen, fullamount: integer.
     - set(self,amount)         : set amount to integer.
    """
    def set(self, amount):
        self.w.scaleSet(amount)

    def __init__(self, width, total):
        self.w = _snack.scale(width, total)

class Entry(Widget):
    """Entry widget.

    methods:

     - Entry(self, width, text = "", hidden = 0, password = 0, scroll = 1, returnExit = 0)
          constructor. hidden doesn't show text, password stars it out,
          scroll includes scroll bars;
          if returnExit is set, return from Form when exiting this element, else
           proceed to next entry widget.
     - value(self): return value.
     - set(text, cursorAtEnd = 1) : set the text
     - setFlags (flag, sense) : flags can be FLAG_DISABLED, FLAGS_SET, FLAGS_RESET, FLAGS_TOGGLE
    """
    def value(self):
        return self.w.entryValue

    def set(self, text, cursorAtEnd = 1):
        return self.w.entrySetValue(text, cursorAtEnd)

    def setFlags (self, flag, sense):
        return self.w.entrySetFlags(flag, sense)

    def __init__(self, width, text = "", hidden = 0, password = 0, scroll = 1, 
         returnExit = 0):
        self.w = _snack.entry(width, text, hidden, password, scroll, returnExit)


# Form uses hotkeys
hotkeys = { "F1" : _snack.KEY_F1, "F2" : _snack.KEY_F2, "F3" : _snack.KEY_F3, 
            "F4" : _snack.KEY_F4, "F5" : _snack.KEY_F5, "F6" : _snack.KEY_F6, 
            "F7" : _snack.KEY_F7, "F8" : _snack.KEY_F8, "F9" : _snack.KEY_F9, 
            "F10" : _snack.KEY_F10, "F11" : _snack.KEY_F11, 
            "F12" : _snack.KEY_F12, "ESC" : _snack.KEY_ESC,
            "ENTER": _snack.KEY_ENTER, "SUSPEND" : _snack.KEY_SUSPEND,
            "BACKSPACE": _snack.KEY_BACKSPACE, "DELETE": _snack.KEY_DELETE,
            "INSERT": _snack.KEY_INSERT,
             " " : ord(" ") }

for n in hotkeys.keys():
    hotkeys[hotkeys[n]] = n
for o,c in [ (ord(c),c) for c in string.ascii_letters+string.digits ]:
    hotkeys[c] = o
    hotkeys[o] = c

class Form:
    """ Base Form class, from which Grid, etc. inherit

    methods:

     - Form(self, helpArg = None) : constructor. 
     - addHotKey(self, keyname) : keynames of form "F1" through "F12", "ESC"
     - add(self, widget) : Add a widget
     - run(self): run a  form, expecting input
     - draw(self): draw form.
     - setTimer(self, timer) : add a timer
     - watchFile(self, file, flags) : watch a named file
     - setCurrent (self, co): Set a given widget as the current focus
    """
    def addHotKey(self, keyname):
        self.w.addhotkey(hotkeys[keyname])

    def add(self, widget):
        if widget.__dict__.has_key('hotkeys'):
            for key in widget.hotkeys.keys():
                self.addHotKey(key)

        if widget.__dict__.has_key('gridmembers'):
            for w in widget.gridmembers:
                self.add(w)
        elif widget.__dict__.has_key('w'):
            self.trans[widget.w.key] = widget
            return self.w.add(widget.w)
        return None

    def run(self):
        (what, which) = self.w.run()
        if (what == _snack.FORM_EXIT_WIDGET):
            return self.trans[which]
        elif (what == _snack.FORM_EXIT_TIMER):
            return "TIMER"
        elif (what == _snack.FORM_EXIT_FDREADY):
            return self.filemap[which]

        return hotkeys[which]

    def draw(self):
        self.w.draw()
        return None

    def __init__(self, helpArg = None):
        self.trans = {}
        self.filemap = {}
        self.w = _snack.form(helpArg)
        # we do the reference count for the helpArg in python! gross
        self.helpArg = helpArg

    def setCurrent (self, co):
        self.w.setcurrent (co.w)

    def setTimer (self, timer):
        self.w.settimer (timer)

    def watchFile (self, file, flags):
        self.filemap[file.fileno()] = file
        self.w.watchfd (file.fileno(), flags)

class Grid:
    """Grid class.

    methods:

     - place(self,x,y): Return what is placed at (x,y)
     - setField(self, what, col, row, padding = (0, 0, 0, 0),
                anchorLeft = 0, anchorTop = 0, anchorRight = 0,
                anchorBottom = 0, growx = 0, growy = 0):
                used to add widget 'what' to grid.
     - Grid(self, *args): eg. g = Grid(2,3) for 2x3 grid
    """
    def place(self, x, y):
        return self.g.place(x, y)

    def setField(self, what, col, row, padding = (0, 0, 0, 0),
         anchorLeft = 0, anchorTop = 0, anchorRight = 0,
         anchorBottom = 0, growx = 0, growy = 0):
        self.gridmembers.append(what)
        anchorFlags = 0
        if (anchorLeft):
            anchorFlags = _snack.ANCHOR_LEFT
        elif (anchorRight):
            anchorFlags = _snack.ANCHOR_RIGHT

        if (anchorTop):
            anchorFlags = anchorFlags | _snack.ANCHOR_TOP
        elif (anchorBottom):
            anchorFlags = anchorFlags | _snack.ANCHOR_BOTTOM

        gridFlags = 0
        if (growx):
            gridFlags = _snack.GRID_GROWX
        if (growy):
            gridFlags = gridFlags | _snack.GRID_GROWY

        if (what.__dict__.has_key('g')):
            return self.g.setfield(col, row, what.g, padding, anchorFlags,
                       gridFlags)
        else:
            return self.g.setfield(col, row, what.w, padding, anchorFlags)
    
    def __init__(self, *args):
        self.g = apply(_snack.grid, args)
        self.gridmembers = []

colorsets = { "ROOT" : _snack.COLORSET_ROOT,
              "BORDER" : _snack.COLORSET_BORDER,
              "WINDOW" : _snack.COLORSET_WINDOW,
              "SHADOW" : _snack.COLORSET_SHADOW,
              "TITLE" : _snack.COLORSET_TITLE,
              "BUTTON" : _snack.COLORSET_BUTTON,
              "ACTBUTTON" : _snack.COLORSET_ACTBUTTON,
              "CHECKBOX" : _snack.COLORSET_CHECKBOX,
              "ACTCHECKBOX" : _snack.COLORSET_ACTCHECKBOX,
              "ENTRY" : _snack.COLORSET_ENTRY,
              "LABEL" : _snack.COLORSET_LABEL,
              "LISTBOX" : _snack.COLORSET_LISTBOX,
              "ACTLISTBOX" : _snack.COLORSET_ACTLISTBOX,
              "TEXTBOX" : _snack.COLORSET_TEXTBOX,
              "ACTTEXTBOX" : _snack.COLORSET_ACTTEXTBOX,
              "HELPLINE" : _snack.COLORSET_HELPLINE,
              "ROOTTEXT" : _snack.COLORSET_ROOTTEXT,
              "EMPTYSCALE" : _snack.COLORSET_EMPTYSCALE,
              "FULLSCALE" : _snack.COLORSET_FULLSCALE,
              "DISENTRY" : _snack.COLORSET_DISENTRY,
              "COMPACTBUTTON" : _snack.COLORSET_COMPACTBUTTON,
              "ACTSELLISTBOX" : _snack.COLORSET_ACTSELLISTBOX,
              "SELLISTBOX" : _snack.COLORSET_SELLISTBOX }

class SnackScreen:
    """A Screen;

    methods:

    - Screen(self) : constructor
    - finish(self)
    - resume(self)
    - suspend(self)
    - doHelpCallback(self,arg) call callback with arg
    - helpCallback(self,cb): Set help callback
    - suspendcallback(self,cb, data=None) : set callback. data=data to pass to cb.
    - openWindow(self,left, top, width, height, title): Open a window.
    - pushHelpLine(self,text): put help line on screen. Returns current help line if text=None
    - setColor(self, colorset, fg, bg): Set foreground and background colors;
            colorset = key from snack.colorsets,
            fg & bg = english color names defined by S-Lang
                (ref: S-Lang Library C Programmer's Guide section:
                8.4.4.  Setting Character Attributes)
    """
    def __init__(self):
        _snack.init()
        (self.width, self.height) = _snack.size()
        self.pushHelpLine(None)

    def finish(self):
        return _snack.finish()

    def resume(self):
        _snack.resume()

    def suspend(self):
        _snack.suspend()

    def doHelpCallback(self, arg):
        self.helpCb(self, arg)
    
    def helpCallback(self, cb):
        self.helpCb = cb
        return _snack.helpcallback(self.doHelpCallback)

    def suspendCallback(self, cb, data = None):
        if data:
            return _snack.suspendcallback(cb, data)
        return _snack.suspendcallback(cb)

    def openWindow(self, left, top, width, height, title):
        return _snack.openwindow(left, top, width, height, title)

    def pushHelpLine(self, text):
        if (not text):
            return _snack.pushhelpline("*default*")
        else:
            return _snack.pushhelpline(text)

    def popHelpLine(self):
        return _snack.pophelpline()

    def drawRootText(self, left, top, text):
        return _snack.drawroottext(left, top, text)

    def centeredWindow(self, width, height, title):
        return _snack.centeredwindow(width, height, title)

    def gridWrappedWindow(self, grid, title, x = None, y = None):
        if x and y:
            return _snack.gridwrappedwindow(grid.g, title, x, y)

        return _snack.gridwrappedwindow(grid.g, title)

    def popWindow(self, refresh = True):
        if refresh:
            return _snack.popwindow()
        return _snack.popwindownorefresh()

    def refresh(self):
        return _snack.refresh()

    def setColor(self, colorset, fg, bg):
        if colorset in colorsets:
            return _snack.setcolor(colorsets[colorset], fg, bg)
        else:
           # assume colorset is an integer for the custom color set
           return _snack.setcolor(colorset, fg, bg)

def reflow(text, width, flexDown = 5, flexUp = 5):
    """ returns a tuple of the wrapped text, the actual width, and the actual height
    """
    return _snack.reflow(text, width, flexDown, flexUp)

# combo widgets

class RadioGroup(Widget):
    """ Combo widget: Group of Radio buttons

    methods:

     - RadioGroup(self): constructor.
     - add(self,title, value, default = None): add a button. Returns button.
     - getSelection(self) : returns value of selected button | None    
    """
    def __init__(self):
        self.prev = None
        self.buttonlist = []

    def add(self, title, value, default = None):
        if not self.prev and default == None:
            # If the first element is not explicitly set to
            # not be the default, make it be the default
            default = 1
        b = SingleRadioButton(title, self.prev, default)
        self.prev = b
        self.buttonlist.append((b, value))
        return b

    def getSelection(self):
        for (b, value) in self.buttonlist:
            if b.selected(): return value
        return None


class RadioBar(Grid):
    """ Bar of Radio buttons, based on Grid.

    methods:

    - RadioBar(self, screen, buttonlist) : constructor.
    - getSelection(self): return value of selected button 
    """

    def __init__(self, screen, buttonlist):
        self.list = []
        self.item = 0
        self.group = RadioGroup()
        Grid.__init__(self, 1, len(buttonlist))
        for (title, value, default) in buttonlist:
            b = self.group.add(title, value, default)
            self.list.append((b, value))
            self.setField(b, 0, self.item, anchorLeft = 1)
            self.item = self.item + 1

    def getSelection(self):
        return self.group.getSelection()
    

# you normally want to pack a ButtonBar with growx = 1

class ButtonBar(Grid):
    """ Bar of buttons, based on grid.

    methods:

     - ButtonBar(screen, buttonlist,buttonlist, compact = 0):
     - buttonPressed(self, result):  Takes the widget returned by Form.run and looks to see
                     if it was one of the widgets in the ButtonBar.
    """
    def __init__(self, screen, buttonlist, compact = 0):
        self.list = []
        self.hotkeys = {}
        self.item = 0
        Grid.__init__(self, len(buttonlist), 1)
        for blist in buttonlist:
            if (type(blist) == types.StringType):
                title = blist
                value = string.lower(blist)
            elif len(blist) == 2:
                (title, value) = blist
            else:
                (title, value, hotkey) = blist
                self.hotkeys[hotkey] = value

            if compact:
                b = CompactButton(title)
            else:
                b = Button(title)
            self.list.append((b, value))
            self.setField(b, self.item, 0, (1, 0, 1, 0))
            self.item = self.item + 1

    def buttonPressed(self, result):    
        if self.hotkeys.has_key(result):
            return self.hotkeys[result]

        for (button, value) in self.list:
            if result == button:
                return value
        return None


class GridFormHelp(Grid):
    """ Subclass of Grid, for the help form text.

    methods:

     - GridFormHelp(self, screen, title, help, *args) :
     - add (self, widget, col, row, padding = (0, 0, 0, 0),
            anchorLeft = 0, anchorTop = 0, anchorRight = 0,
            anchorBottom = 0, growx = 0, growy = 0):
     - runOnce(self, x = None, y = None):  pop up the help window
     - addHotKey(self, keyname):
     - setTimer(self, keyname):
     - create(self, x = None, y = None):
     - run(self, x = None, y = None):
     - draw(self):
     - runPopup(self):
     - setCurrent (self, co):
    """
    def __init__(self, screen, title, help, *args):
        self.screen = screen
        self.title = title
        self.form = Form(help)
        self.childList = []
        self.form_created = 0
        args = list(args)
        args[:0] = [self]
        apply(Grid.__init__, tuple(args))

    def add(self, widget, col, row, padding = (0, 0, 0, 0),
            anchorLeft = 0, anchorTop = 0, anchorRight = 0,
            anchorBottom = 0, growx = 0, growy = 0):
        self.setField(widget, col, row, padding, anchorLeft,
                      anchorTop, anchorRight, anchorBottom,
                      growx, growy);
        self.childList.append(widget)

    def runOnce(self, x = None, y = None):
        result = self.run(x, y)
        self.screen.popWindow()
        return result

    def addHotKey(self, keyname):
        self.form.addHotKey(keyname)

    def setTimer(self, keyname):
        self.form.setTimer(keyname)

    def create(self, x = None, y = None):
        if not self.form_created:
            self.place(1,1)
            for child in self.childList:
                self.form.add(child)
            self.screen.gridWrappedWindow(self, self.title, x, y)
            self.form_created = 1

    def run(self, x = None, y = None):
        self.create(x, y)
        return self.form.run()

    def draw(self):
        self.create()
        return self.form.draw()
    
    def runPopup(self):
        self.create()
        self.screen.gridWrappedWindow(self, self.title)
        result = self.form.run()
        self.screen.popWindow()
        return result

    def setCurrent (self, co):
        self.form.setCurrent (co)

class GridForm(GridFormHelp):
    """ GridForm class (extends GridFormHelp):

    methods:

     - GridForm(self, screen, title, *args):
    """
    def __init__(self, screen, title, *args):
        myargs = (self, screen, title, None) + args
        apply(GridFormHelp.__init__, myargs)

class CheckboxTree(Widget):
    """ CheckboxTree combo widget,

    methods:

     - CheckboxTree(self, height, scroll = 0, width = None, hide_checkbox = 0, unselectable = 0)
                    constructor.
     - append(self, text, item = None, selected = 0):
     - addItem(self, text, path, item = None, selected = 0):
     - getCurrent(self):
     - getSelection(self):
     - setEntry(self, item, text):
     - setCurrent(self, item):
     - setEntryValue(self, item, selected = 1):
     - getEntryValue(self, item):
    """ 
    def append(self, text, item = None, selected = 0):
        self.addItem(text, (snackArgs['append'], ), item, selected)
    
    def addItem(self, text, path, item = None, selected = 0):
        if item is None:
            item = text
        key = self.w.checkboxtreeAddItem(text, path, selected)
        self.key2item[key] = item
        self.item2key[item] = key

    def getCurrent(self):
        curr = self.w.checkboxtreeGetCurrent()
        return self.key2item[curr]

    def __init__(self, height, scroll = 0, width = None, hide_checkbox = 0, unselectable = 0):
        self.w = _snack.checkboxtree(height, scroll, hide_checkbox, unselectable)
        self.key2item = {}
        self.item2key = {}
        if (width):
            self.w.checkboxtreeSetWidth(width)

    def getSelection(self):
        selection = []
        list = self.w.checkboxtreeGetSelection()
        for key in list:
            selection.append(self.key2item[key])
        return selection

    def setEntry(self, item, text):
        self.w.checkboxtreeSetEntry(self.item2key[item], text)

    def setCurrent(self, item):
        self.w.checkboxtreeSetCurrent(self.item2key[item])

    def setEntryValue(self, item, selected = 1):
        self.w.checkboxtreeSetEntryValue(self.item2key[item], selected)

    def getEntryValue(self, item):
        return self.w.checkboxtreeGetEntryValue(self.item2key[item])

def ListboxChoiceWindow(screen, title, text, items, 
            buttons = ('Ok', 'Cancel'), 
            width = 40, scroll = 0, height = -1, default = None,
            help = None):
    """
    - ListboxChoiceWindow(screen, title, text, items, 
            buttons = ('Ok', 'Cancel'), 
            width = 40, scroll = 0, height = -1, default = None,
            help = None):
    """
    if (height == -1): height = len(items)

    bb = ButtonBar(screen, buttons)
    t = TextboxReflowed(width, text)
    l = Listbox(height, scroll = scroll, returnExit = 1)
    count = 0
    for item in items:
        if (type(item) == types.TupleType):
            (text, key) = item
        else:
            text = item
            key = count

        if (default == count):
            default = key
        elif (default == item):
            default = key

        l.append(text, key)
        count = count + 1

    if (default != None):
        l.setCurrent (default)

    g = GridFormHelp(screen, title, help, 1, 3)
    g.add(t, 0, 0)
    g.add(l, 0, 1, padding = (0, 1, 0, 1))
    g.add(bb, 0, 2, growx = 1)

    rc = g.runOnce()

    return (bb.buttonPressed(rc), l.current())

def ButtonChoiceWindow(screen, title, text, 
               buttons = [ 'Ok', 'Cancel' ], 
               width = 40, x = None, y = None, help = None):
    """
     - ButtonChoiceWindow(screen, title, text, 
               buttons = [ 'Ok', 'Cancel' ], 
               width = 40, x = None, y = None, help = None):
    """
    bb = ButtonBar(screen, buttons)
    t = TextboxReflowed(width, text, maxHeight = screen.height - 12)

    g = GridFormHelp(screen, title, help, 1, 2)
    g.add(t, 0, 0, padding = (0, 0, 0, 1))
    g.add(bb, 0, 1, growx = 1)
    return bb.buttonPressed(g.runOnce(x, y))

def EntryWindow(screen, title, text, prompts, allowCancel = 1, width = 40,
        entryWidth = 20, buttons = [ 'Ok', 'Cancel' ], help = None):
    """
    EntryWindow(screen, title, text, prompts, allowCancel = 1, width = 40,
        entryWidth = 20, buttons = [ 'Ok', 'Cancel' ], help = None):
    """
    bb = ButtonBar(screen, buttons);
    t = TextboxReflowed(width, text)

    count = 0
    for n in prompts:
        count = count + 1

    sg = Grid(2, count)

    count = 0
    entryList = []
    for n in prompts:
        if (type(n) == types.TupleType):
            (n, e) = n
            if (type(e) in types.StringTypes):
                e = Entry(entryWidth, e)
        else:
            e = Entry(entryWidth)

        sg.setField(Label(n), 0, count, padding = (0, 0, 1, 0), anchorLeft = 1)
        sg.setField(e, 1, count, anchorLeft = 1)
        count = count + 1
        entryList.append(e)

    g = GridFormHelp(screen, title, help, 1, 3)

    g.add(t, 0, 0, padding = (0, 0, 0, 1))
    g.add(sg, 0, 1, padding = (0, 0, 0, 1))
    g.add(bb, 0, 2, growx = 1)

    result = g.runOnce()

    entryValues = []
    count = 0
    for n in prompts:
        entryValues.append(entryList[count].value())
        count = count + 1

    return (bb.buttonPressed(result), tuple(entryValues))

class CListbox(Grid):
    """Clistbox convenience class.

    methods:

     - Clistbox(self, height, cols, cols_widths, scroll = 0)       : constructor
     - colFormText(self, col_text, align = None, adjust_width = 0) : column text.
     - append(self, col_text, item, col_text_align = None)         :
     - insert(self, col_text, item, before, col_text_align = None)
     - delete(self, item)
     - replace(self, col_text, item, col_text_align = None)
     - current(self) : returns current item
     - setCurrent(self, item): sets an item as current
     - clear(self): clear the listbox
     
     Alignments may be LEFT, RIGHT, CENTER, None
    """
    def __init__(self, height, cols, col_widths, scroll = 0,
                 returnExit = 0, width = 0, col_pad = 1,
                 col_text_align = None, col_labels = None,
                 col_label_align = None, adjust_width=0):

        self.cols = cols
        self.col_widths = col_widths[:]
        self.col_pad = col_pad
        self.col_text_align = col_text_align

        if col_labels != None:        
            Grid.__init__(self, 1, 2)
            box_y = 1

            lstr = self.colFormText(col_labels, col_label_align,
                                                adjust_width=adjust_width)
            self.label = Label(lstr)
            self.setField(self.label, 0, 0, anchorLeft=1)

        else:
            Grid.__init__(self, 1, 1)
            box_y = 0
            

        self.listbox = Listbox(height, scroll, returnExit, width)
        self.setField(self.listbox, 0, box_y, anchorRight=1)

    def colFormText(self, col_text, align = None, adjust_width=0):
        i = 0
        str = ""
        c_len = len(col_text)
        while (i < self.cols) and (i < c_len):
        
            cstr = col_text[i]
            cstrlen = _snack.wstrlen(cstr)
            if self.col_widths[i] < cstrlen:
                if adjust_width:
                    self.col_widths[i] = cstrlen
                else:
                    cstr = cstr[:self.col_widths[i]]

            delta = self.col_widths[i] - _snack.wstrlen(cstr)
                        
            if delta > 0:
                if align == None:
                    a = LEFT
                else:
                    a = align[i]

                if a == LEFT:
                    cstr = cstr + (" " * delta)
                if a == CENTER:
                    cstr = (" " * (delta / 2)) + cstr + \
                        (" " * ((delta + 1) / 2))
                if a == RIGHT:
                    cstr = (" " * delta) + cstr

            if i != c_len - 1:
                pstr = (" " * self.col_pad)
            else:
                pstr = ""

            str = str + cstr + pstr
    
            i = i + 1
    
        return str

    def append(self, col_text, item, col_text_align = None):
        if col_text_align == None:
            col_text_align = self.col_text_align
        text = self.colFormText(col_text, col_text_align)
        self.listbox.append(text, item)

    def insert(self, col_text, item, before, col_text_align = None):
        if col_text_align == None:
            col_text_align = self.col_text_align
        text = self.colFormText(col_text, col_text_align)
        self.listbox.insert(text, item, before)

    def delete(self, item):
        self.listbox.delete(item)

    def replace(self, col_text, item, col_text_align = None):
        if col_text_align == None:
            col_text_align = self.col_text_align
        text = self.colFormText(col_text, col_text_align)
        self.listbox.replace(text, item)

    def current(self):
        return self.listbox.current()

    def setCurrent(self, item):
        self.listbox.setCurrent(item)

    def clear(self):
        self.listbox.clear()

def customColorset(x):
    return 30 + x
