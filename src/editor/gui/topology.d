module editor.gui.topology;

import std.algorithm;
import std.math;

import basics.topology;
import basics.user;
import editor.gui.okcancel;
import file.language;
import gui;
import gui.option;
import graphic.color;
import level.level;
import tile.occur;

class TopologyWindow : OkCancelWindow {
private:
    immutable int _oldXl;
    immutable int _oldYl;
    NumPick _left;
    NumPick _right;
    NumPick _top;
    NumPick _bottom;
    Equation _eqXDec;
    Equation _eqXHex;
    Equation _eqYDec;
    Equation _eqYHex;
    BoolOption _torusX;
    BoolOption _torusY;

    NumPick _red, _green, _blue;
    enum thisXl = 480;

public:
    this(Level level)
    {
        super(new Geom(0, 0, thisXl, 290, From.CENTER),
            Lang.winTopologyTitle.transl);
        _oldXl = level.topology.xl;
        _oldYl = level.topology.yl;
        makeTopologyChildren(level);
        makeColorChildren(level);
    }

protected:
    override void selfWriteChangesTo(Level level) const
    {
        level.topology.resize(suggestedXl, suggestedYl);
        level.topology.setTorusXY(_torusX.checked, _torusY.checked);

        immutable Point moveAllTilesBy = ()
        {
            Point ret = Point(_left.number, _top.number);
            // Defend against going over the max, but allow shifting
            // by adding and removing similar same area on opposing sides.
            if (_right.number == 0) {
                immutable defend = abs(_oldXl - suggestedXl);
                ret.x = clamp(ret.x, -defend, +defend);
            }
            if (_bottom.number == 0) {
                immutable defend = abs(_oldYl - suggestedYl);
                ret.y = clamp(ret.y, -defend, defend);
            }
            return ret;
        }();
        if (moveAllTilesBy != Point(0, 0)) {
            void fun(Occurrence occ)
            {
                occ.loc = level.topology.wrap(occ.loc + moveAllTilesBy);
            }
            level.terrain.each!fun;
            level.gadgets[].each!(occList => occList.each!fun);
        }
        level.bgRed = _red.number;
        level.bgGreen = _green.number;
        level.bgBlue = _blue.number;
    }

    override void calcSelf()
    {
        if (_left.execute || _right.execute) {
            _eqXDec.change = suggestedXl - _oldXl;
            _eqXHex.change = suggestedXl - _oldXl;
        }
        if (_top.execute || _bottom.execute) {
            _eqYDec.change = suggestedYl - _oldYl;
            _eqYHex.change = suggestedYl - _oldYl;
        }
    }

private:
    @property int suggestedXl() const
    {
        return clamp(_oldXl + _left.number + _right.number,
                     Level.minXl, Level.maxXl);
    }

    @property int suggestedYl() const
    {
        return clamp(_oldYl + _top.number + _bottom.number,
                     Level.minYl, Level.maxYl);
    }

    void makeTopologyChildren(Level level)
    {
        enum butX   = 100f;
        enum textXl = 80f;
        enum boolXl = thisXl - 3*20 - 100; // 100 is super's button xlg
        void label(in float y, in Lang cap)
        {
            addChild(new Label(new Geom(20, y, textXl, 20), cap.transl));
        }
        label( 30, Lang.winTopologyL);
        label( 50, Lang.winTopologyR);
        label( 80, Lang.winTopologyU);
        label(100, Lang.winTopologyD);

        NumPick newSidePick(in float y, in int valMax)
        {
            assert (valMax > 0);
            NumPickConfig cfg;
            cfg.sixButtons = true;
            cfg.digits     = 5; // four digits and a minus sign
            cfg.stepSmall  = 2;
            cfg.stepMedium = 0x10;
            cfg.stepBig    = 0x80;
            cfg.min = -valMax;
            cfg.max = +valMax;
            return new NumPick(new Geom(butX, y, 180, 20), cfg);
        }
        _left   = newSidePick( 30, Level.maxXl);
        _right  = newSidePick( 50, Level.maxXl);
        _top    = newSidePick( 80, Level.maxYl);
        _bottom = newSidePick(100, Level.maxYl);
        _eqXDec = new Equation( 30, _oldXl, Equation.Format.dec);
        _eqXHex = new Equation( 50, _oldXl, Equation.Format.hex);
        _eqYDec = new Equation( 80, _oldYl, Equation.Format.dec);
        _eqYHex = new Equation(100, _oldYl, Equation.Format.hex);
        _torusX = new BoolOption(new Geom(20, 140, boolXl, 20),
                                 Lang.winTopologyTorusX.transl);
        _torusY = new BoolOption(new Geom(20, 170, boolXl, 20),
                                 Lang.winTopologyTorusY.transl);
        _torusX.checked = level.topology.torusX;
        _torusY.checked = level.topology.torusY;
        addChildren(_left, _right, _top, _bottom,
                    _eqXDec, _eqXHex,
                    _eqYDec,   _eqYHex, _torusX, _torusY);
    }

    void makeColorChildren(Level level)
    {
        auto newPick(in float y, in int startValue, in Lang desc)
        {
            NumPickConfig cfg;
            cfg.digits     = 3; // the first one is '0x'
            cfg.sixButtons = true;
            cfg.hex        = true;
            cfg.max        = 0xFF;
            cfg.stepMedium = 0x04;
            cfg.stepBig    = 0x10;
            enum colorPickXl = 120 + 40 + 10;
            auto ret = new NumPick(new Geom(140, y, colorPickXl, 20,
                From.TOP_RIGHT), cfg);
            ret.number = startValue;
            this.addChild(ret);
            this.addChild(new Label(new Geom(20, y,
                xlg-colorPickXl - 100 - 80, 20), // -100 for OK, -80 for spaces
                desc.transl));
            return ret;
        }
        _red = newPick(ylg-80, level.bgRed, Lang.winLooksRed);
        _green = newPick(ylg-60, level.bgGreen, Lang.winLooksGreen);
        _blue = newPick(ylg-40, level.bgBlue, Lang.winLooksBlue);
    }
}

/* private class Equation: The geoms are hardcoded to allow for exactly 4
 * digits in the old value, the change, and the result. The maximal level
 * size is 5 C++ screens in each direction: 3200 x 2000 pixels. These values
 * fit into 4 digits, and into 3 hex digits with a leading "0x" subscript,
 * because 0xFFF == 16^^3 - 1 == 4095 > 3200.
 */
private class Equation : Element {
private:
    Label _old, _sign, _change, _equals, _result;
    immutable Format _decOrHex;
    immutable int _oldValue;

public:
    enum Format { dec, hex }
    enum valueMax = 16^^3;

    this(in float y, in int oldValue, in Format decOrHex)
    in {
        static assert (Level.maxXl < valueMax);
        static assert (Level.maxYl < valueMax);
    }
    body {
        super(new Geom(20f, y, 150f, 20f, From.TOP_RIGHT));
        undrawColor = color.guiM; // erase old labels before writing
        _oldValue = oldValue;
        _decOrHex = decOrHex;
        _old    = new Label(new Geom(110, 0, 40, 0, From.TOP_RIGHT));
        _sign   = new Label(new Geom( 95, 0, 15, 0, From.TOP_RIGHT));
        _change = new Label(new Geom( 55, 0, 40, 0, From.TOP_RIGHT));
        _equals = new Label(new Geom( 40, 0, 15, 0, From.TOP_RIGHT), "=");
        _result = new Label(new Geom(  0, 0, 40, 0, From.TOP_RIGHT));
        _old.text = formatEquationString(_oldValue);
        addChildren(_old, _sign, _change, _equals, _result);
        change = 0;
    }

    @property void change(in int aChange)
    {
        _sign  .text = (aChange >= 0 ? "+" : "\u2212"); // unicode minus sign
        _change.text = formatEquationString(aChange.abs);
        _result.text = formatEquationString(_oldValue + aChange);
        _sign  .color = (aChange == 0 ? color.guiText : color.guiTextOn);
        _change.color = _sign.color;
        _result.color = _change.color;
        reqDraw();
    }

protected:
    override void drawSelf()
    {
        undraw();
        super.drawSelf();
    }

private:
    string formatEquationString(int val)
    {
        assert (val.abs < valueMax);
        if (val == 0)
            return "0";
        else if (val < 0)
            return "< 0";
        string ret;
        while (val != 0) {
            int lastDigit = val % (_decOrHex == Format.dec ? 10 : 16);
            val -= lastDigit;
            val /= (_decOrHex == Format.dec ? 10 : 16);
            ret = "0123456789ABCDEF"[lastDigit] ~ ret;
        }
        return _decOrHex == Format.dec ? ret
            :  "\u2080\u2093" ~ ret; // subscript 0x
    }
}
