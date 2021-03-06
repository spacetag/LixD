module game.panel.base;

/* Panel: A large GUI element that features all the visible buttons
 * during gameplay.
 *
 * Some methods don't do anything depending on View.
 */

import std.algorithm;
import std.range;

import basics.user;
import basics.globals;
import game.core.view;
import game.panel.infobar;
import game.panel.nuke;
import game.panel.scores;
import game.panel.taperec;
import game.panel.tooltip;
import game.tribe;
import game.score;
import graphic.internal;
import gui;
import hardware.keyboard; // we need a different behavior of skill button
import hardware.keyset;
import hardware.mouse;    // execution and skill button warning sound
import hardware.sound;
import lix; // forward method of InfoBar to our users
import net.phyu;

class Panel : Element {
private:
    SkillButton[] _skills;
    SkillButton lastOnForRestoringAfterStateLoad;

    InfoBar stats;
    SaveStateButtons _ssbs;
    TapeRecorderButtons _trbs; // contains the singleplayer nuke button
    NukeButton _nukeMulti;
    BitmapButton _coolShades;
    ScoreGraph _scoreGraph;

public:
    this(in View aView, in int lixRequired)
    {
        super(new Geom(0, 0, gui.screenXlg, gui.panelYlg, From.BOTTOM));
        _skills.length = basics.user.skillSort.length;
        foreach (int id, ac; basics.user.skillSort) {
            _skills[id] = new SkillButton(new Geom(id * skillXl, 0,
                                     skillXl, skillYl, From.BOTTOM_LEFT));
            _skills[id].skill = ac;
            _skills[id].hotkey = basics.user.keySkill[skillSort[id]];
            addChild(_skills[id]);
        }
        auto barGeom = new Geom(0, 0, xlg - 4 * skillXl, ylg - skillYl);
        auto shadesGeom = new Geom(0, 0, skillXl, ylg - skillYl,
                                    From.TOP_RIGHT);

        if (aView.showTapeRecorderButtons && aView.showScoreGraph) {
            stats = new InfoBarMultiplayer(barGeom);
            // We don't have SaveStateButtons in this mode to preserve UI
            // space, and we don't have cool shades to preserve space
            shadesGeom = null;
            immutable ya = this.ylg * 0.6f;
            immutable yb = this.ylg - ya;
            _scoreGraph = new ScoreGraph(
                    new Geom(0, 0, 4 * skillXl, yb, From.TOP_RIGHT));
            _trbs = new TapeRecorderButtons(
                    new Geom(0, 0, 4 * skillXl, ya, From.BOTTOM_RIGHT));
            addChildren(stats, _scoreGraph, _trbs);
        }
        else if (aView.showTapeRecorderButtons) {
            stats = new InfoBarSingleplayer(barGeom, lixRequired);
            _ssbs = new SaveStateButtons(new Geom(shadesGeom.xlg, 0,
                4 * skillXl - shadesGeom.xlg, ylg - skillYl, From.TOP_RIGHT));
            _trbs = new TapeRecorderButtons(
                    new Geom(0, 0, 4*skillXl, skillYl, From.BOTTOM_RIGHT));
            addChildren(stats, _ssbs, _trbs);
        }
        else {
            // This is the branch for (yes score graph, no tape recorder).
            // Hack: Even if neither score graph or trbs shown, still
            // enter this branch: Show the score graph to fill the void.
            stats = new InfoBarMultiplayer(barGeom);
            _scoreGraph = new ScoreGraph(new Geom(0, 0, 4 * skillXl,
                                                  ylg - 20f, From.TOP_RIGHT));
            shadesGeom.from = From.BOTTOM_RIGHT;
            _nukeMulti = new NukeButton(new Geom(skillXl, 0,
                4 * skillXl - shadesGeom.xlg, 20f, From.BOTTOM_RIGHT),
                NukeButton.WideDesign.yes);
            addChildren(stats, _scoreGraph, _nukeMulti);
        }

        // Most modes have cool shades.
        if (shadesGeom) {
            _coolShades = new BitmapButton(shadesGeom,
                                           getInternal(fileImageGamePanel2));
            _coolShades.xf = 0;
            _coolShades.hotkey = basics.user.keyPingGoals;
            addChild(_coolShades);
        }
    }

    // call this from the Game
    void setLikeTribe(in Tribe tr, in Ac ploderToDisplay,
                      in bool overtimeRunning, in int overtimeRemainingInPhyus
    ) {
        if (tr is null)
            return;
        immutable bool multiNuking = tr.style != Style.garden
            && overtimeRunning && overtimeRemainingInPhyus == 0;
        foreach (b; _skills) {
            b.style = tr.style;
            if (b.skill.isPloder)
                b.skill = ploderToDisplay;
            // Since you're not allowed to assign skills when you want to nuke,
            // show 0 skills on the GUI even if we have more. But in
            // singleplayer, we want to see how many skills we have left.
            b.number = tr.nukePressed || multiNuking ? 0 : tr.skills[b.skill];
        }
        nuke.on = tr.nukePressed || multiNuking;
        nuke.overtimeRunning = overtimeRunning;
        nuke.overtimeRemainingInPhyus = overtimeRemainingInPhyus;
        if (_scoreGraph)
            _scoreGraph.ourStyle = tr.style;
        /*
        stats.set_tribe_local(tr);
        spec_tribe .set_text(tr->get_name());
        */
        makeCurrent(lastOnForRestoringAfterStateLoad);
    }

    void highlightFirstSkill()
    {
        assert (currentSkill is null);
        _skills.filter!(sk => sk.number != 0).takeOne.each!(
                                                (sk) { makeCurrent(sk); });
    }

    @property inout(SkillButton) currentSkill() inout
    {
        foreach (b; _skills)
            if (b.on && b.skill != Ac.nothing && b.number != 0)
                return b;
        return null;
    }

    void setSpeedNormal() { if (_trbs) _trbs.setSpeedNormal(); }
    void pause(bool b) { if (_trbs) _trbs.pause(b); }

    @property const {
        bool paused()             { return _trbs && _trbs.paused; }
        bool speedIsNormal()      { return ! _trbs || _trbs.speedIsNormal; }
        bool speedIsFast()        { return _trbs && _trbs.speedIsFast; }
        bool speedIsTurbo()       { return _trbs && _trbs.speedIsTurbo; }
        bool restart()            { return _trbs && _trbs.restart; }
        bool saveState()          { return _ssbs && _ssbs.saveState; }
        bool loadState()          { return _ssbs && _ssbs.loadState; }
        bool framestepBackOne()   { return _trbs && _trbs.framestepBackOne; }
        bool framestepBackMany()  { return _trbs && _trbs.framestepBackMany; }
        bool framestepAheadOne()  { return _trbs && _trbs.framestepAheadOne; }
        bool framestepAheadMany() { return _trbs && _trbs.framestepAheadMany; }
        bool nukeDoubleclicked()  { return nuke.doubleclicked; }
        bool coolShadesAreOn()    { return _coolShades && _coolShades.on; }
        bool coolShadesExecute()  { return _coolShades && _coolShades.execute;}
        bool zoomIn()             { return _trbs && _trbs.zoomIn
                                      || ! _trbs && keyZoomIn.keyTapped; }
        bool zoomOut()            { return _trbs && _trbs.zoomOut
                                      || ! _trbs && keyZoomOut.keyTapped; }
    }

    void describeTarget(in Lixxie l, int nr) { stats.describeTarget(l, nr); }
    void showInfo(in Tribe tr) { stats.showTribe(tr); }
    void dontShowSpawnInterval() { stats.dontShowSpawnInterval(); }
    void showSpawnInterval(in int si) { stats.showSpawnInterval(si); }
    void suggestTooltip(in Tooltip.ID id) { stats.suggestTooltip(id); }
    @property Phyu age(in Phyu phyu) { return stats.age = phyu; }

    void update(T)(T scoreRange)
        if (isInputRange!T && is (ElementType!T : const(Score)))
    {
        if (_scoreGraph)
            foreach (sc; scoreRange)
                _scoreGraph.update(sc);
    }

protected:
    override void calcSelf()
    {
        SkillButton oldSkill = currentSkill();
        _skills.filter!(sk => sk.execute && sk != oldSkill)
               .filter!(sk => sk.number != 0 || sk.hotkey.keyTapped).each!((sk)
        {
            makeCurrent(sk);
            if (sk.number != 0)
                hardware.sound.playLoud(Sound.PANEL);
            else
                hardware.sound.playQuiet(Sound.PANEL_EMPTY);
        });
        if (_coolShades && _coolShades.execute)
            _coolShades.on = ! _coolShades.on;
        suggestTooltips();
    }

private:
    @property float skillYl() const { return this.geom.ylg - 20; }
    @property float skillXl() const {
        return gui.screenXlg / (skillSort.length + 4);
    }

    inout(NukeButton) nuke() inout
    {
        assert (_trbs && _trbs.nuke || _nukeMulti);
        return _nukeMulti ? _nukeMulti : _trbs.nuke;
    }

    void makeCurrent(SkillButton skill)
    {
        if (currentSkill !is null)
            currentSkill.on = false;
        if (skill && skill.number != 0)
            skill.on = true;
        lastOnForRestoringAfterStateLoad = skill; // even if currently 0
    }

    void suggestTooltips()
    {
        if (nuke.isMouseHere)
            suggestTooltip(Tooltip.ID.nuke);
        if (_coolShades && _coolShades.isMouseHere)
            suggestTooltip(Tooltip.ID.coolShades);
    }
}
