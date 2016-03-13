module gui.picker.tiler;

import std.algorithm;
import std.array;
import std.range;

public import file.filename;
import basics.help;
import gui;

abstract class Tiler : Element {
private:
    Button[] _dirs;
    Button[] _files;
    int _top;

    bool _executeDir;
    bool _executeFile;
    int _executeDirID;
    int _executeFileID;

public:
    this(Geom g) { super(g); }

    final int len() const
    {
        return _dirs.len * dirSizeMultiplier + _files.len;
    }

    final T shiftedID(T)(in T id) const
    {
        return id < _dirs.len
            ? dirSizeMultiplier * id
            : dirSizeMultiplier * _dirs.len + (id - _dirs.len);
    }

    final void loadDirsFiles(Filename[] newDirs, Filename[] newFiles)
    {
        _dirs  = newDirs.map!(t => newDirButton(t)).array;
        _files = newFiles.enumerate!int
            .map!(pair => newFileButton(pair[1], pair[0]))
            .array;
        top = 0;
        reqDraw();
    }

    final @property int top() const { return _top; }
    final @property int top(int newTop)
    {
        newTop = min(newTop, len - pageLen);
        newTop = max(newTop, 0);
        if (newTop < _dirs.len * dirSizeMultiplier)
            newTop -= newTop % dirSizeMultiplier;
        if (_top != newTop) {
            _top = newTop;
            moveButtonsAccordingToTop();
        }
        return _top;
    }

protected:
    // dir buttons are larger than file buttons by dirSizeMultiplier
    @property int dirSizeMultiplier() const { return 2; }

    abstract @property int pageLen() const;
    abstract Button newDirButton (Filename data);
    abstract Button newFileButton(Filename data, in int fileID);
    abstract float buttonXg(in int shiftedIDOnPage) const;
    abstract float buttonYg(in int shiftedIDOnPage) const;

    override void calcSelf()
    {
        calcExecute(_dirs,  _executeDir,  _executeDirID);
        calcExecute(_files, _executeFile, _executeFileID);
    }

private:
    void moveButtonsAccordingToTop()
    {
        auto range = chain(_dirs, _files).enumerate!int;
        foreach (int unshifted, Button b; range) {
            immutable int shifted = shiftedID(unshifted);
            b.hidden = (shifted < top || shifted >= top + pageLen);
            if (! b.hidden)
                b.move(buttonXg(shifted - top), buttonYg(shifted - top));
        }
    }

    void calcExecute(const(Button[]) range, ref bool anyInRange, ref int which)
    {
        anyInRange = false;
        foreach (int i, const(Button) b; range)
            if (b.execute) {
                anyInRange = true;
                which = i;
            }
    }
}