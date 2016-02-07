module graphic.gadget.goal;

import std.algorithm; // max

import basics.help;
import basics.globals; // fileImageMouse
import basics.help; // len
import basics.topology;
import game.tribe;
import game.model.state;
import graphic.cutbit;
import graphic.gadget;
import graphic.internal;
import graphic.torbit;
import tile.pos;
import lix.enums;

/* owners are always drawn onto the goal, unless the owner is GARDEN.
 * When singleplayer time runs out, set drawWithNoSign.
 */

class Goal : GadgetWithTribeList {

    this(const(Topology) top, in ref GadPos levelpos) { super(top, levelpos); }
    this(in Goal rhs) { super(rhs); }

    override Goal clone() const { return new Goal(this); }

protected:

    override void drawStateExtras(Torbit t, in GameState s) const
    {
        drawOwners(t, s);
        drawNoSign(t, s);
    }

private:

    void drawOwners(Torbit mutableGround, in GameState state) const
    {
        assert (state);
        int offset = 0;
        int tribesLen = tribes(state).len;
        foreach (const(Tribe) t; tribes(state)) {
            if (t.style == Style.garden)
                continue;
            auto c = graphic.internal.getPanelInfoIcon(t.style);
            c.draw(mutableGround,
                x + tile.triggerX + tile.triggerXl / 2 - c.xl / 2
                  + (20 * offset++) - 10 * (tribesLen - 1),
                max(y, y + yl - 70),
                Ac.walker, 0);
        }
    }

    void drawNoSign(Torbit mutableGround, in GameState state) const
    {
        if (! state.goalsLocked)
            return;
        const(Cutbit) c = getInternal(fileImageMouse);
        c.draw(mutableGround,
            x + tile.triggerX + tile.triggerXl / 2 - c.xl / 2,
            y + tile.triggerY + tile.triggerYl / 2 - c.yl,
            2, 2); // (2,2) are the (xf,yf) of the international "no" sign
    }

}
// end class Goal
