module verify.counter;

// Called from verify.cmdargs noninteractively, or from the GUI VerifyMenu.

import std.algorithm;
import std.array;
import std.format;
import enumap;

import basics.globconf; // remember results if playername == username
import basics.user; // Result, update results if our own replay solves
import file.filename;
import verify.tested;

// Pass such an object to VerifyCounter.
interface VerifyPrinter {
    // If true: When we verify a single replay filename (either directly
    // because you've asked on the commandline, or recursively), and the
    // replay's level exists and is good (playable), we look at
    // the level's directory, and add all levels from this directory to the
    // coverage requirement. With writeLevelsNotCovered, we can
    // later output the difference between the requirement and covered levels.
    abstract bool printCoverage();

    // Print lines from the verifier somewhere.
    // Refactoring idea: Make this into an output range, so that VerifyCounter
    // doesn't have to allocate the string, but merely passes the results of
    // formattedWrite to us. I haven't defined my own output ranges yet.
    abstract void log(string);
}

class VerifyCounter {
private:
    VerifyPrinter vp;

    Enumap!(verify.tested.Status, int) _stats; // number of replays per stat
    int _trophiesUpdated; // number of checkmarks updated with better results

    string[] levelDirsToCover;
    MutFilename[] levelsCovered; // this may contain duplicates until output

public:
    this(VerifyPrinter aVp)
    {
        assert (aVp);
        vp = aVp;
    }

    void writeCSVHeader()
    {
        vp.log("Result,Replay filename,Level filename,"
            ~  "Player,Saved,Required,Skills,Phyus");
    }

    void verifyOneReplay(Filename fn)
    {
        verifyImpl(fn);
    }

    void writeStatistics()
    {
        vp.log("");
        vp.log(format!"Statistics from %d replays:"(_stats.byValue.sum));
        foreach (Status st, int nr; _stats) {
            if (nr <= 0)
                continue;
            vp.log(format!"%5dx %s: %s"(nr, statusWord[st], statusDesc[st]));
        }
        if (_trophiesUpdated)
            vp.log(format!"%d checkmarks for player `%s' updated."
            (_trophiesUpdated, userName));
    }

    void writeLevelsNotCovered()
    {
        if (! vp.printCoverage)
            return;
        // levelsCovered may contain duplicates. Remove duplicates.
        levelsCovered = levelsCovered.sort!fnLessThan.uniq.array;
        MutFilename[] levelsToCover = levelDirsToCover.sort().uniq
            .map!(dirString => new VfsFilename(dirString))
            .map!(fn => fn.findFiles)
            .joiner
            .filter!(fn => fn.preExtension == 0) // no _order.X.txt
            .array;
        levelsToCover.sort!fnLessThan;
        immutable totalLevelsToCover = levelsToCover.length;
        // We assume that every level that (we have tested positive)
        // has also (been found with the directory search).
        // Under this assumption, levelsCovered is a subset of levelsToCover.
        // Because both levelsCovered and levelsToCover are sort.uniq.array,
        // we can generate list of not-covered levels with the following algo.
        MutFilename[] levelsNotCovered = [];
        while (levelsToCover.length) {
            if (levelsCovered.empty) {
                levelsNotCovered ~= levelsToCover;
                levelsToCover = [];
                break;
            }
            else if (levelsCovered[0] == levelsToCover[0])
                levelsCovered = levelsCovered[1 .. $];
            else
                levelsNotCovered ~= levelsToCover[0];
            levelsToCover = levelsToCover[1 .. $];
        }
        // Done algo. levelsToCover and levelsCovered are clobbered.
        if (levelsNotCovered.length > 0) {
            vp.log("");
            vp.log(format!"These %d levels have no proof:"(
                levelsNotCovered.length));
            levelsNotCovered.each!(fn => vp.log(fn.rootless));
        }
        vp.log("");
        vp.log("Directory coverage: ");
        if (levelsNotCovered.empty)
            vp.log(totalLevelsToCover.format!"All %d levels are solvable.");
        else
            vp.log(format!"%d of %d levels are solvable, %d may be unsolvable."
                (totalLevelsToCover - levelsNotCovered.length,
                 totalLevelsToCover,  levelsNotCovered.length));
    }

private:
    void verifyImpl(Filename fn)
    {
        auto tested = new TestedReplay(fn);
        vp.log(tested.toString);
        _stats[tested.status] += 1;
        _trophiesUpdated += tested.maybeAddTrophy();
        rememberCoverage(tested);
    }

    void rememberCoverage(in TestedReplay tested)
    {
        if (! vp.printCoverage || ! tested.levelFilename)
            return;
        if (! levelDirsToCover.canFind(tested.levelFilename.dirRootless)) {
            levelDirsToCover ~= tested.levelFilename.dirRootless;
            levelDirsToCover = levelDirsToCover.sort().uniq.array;
            // This sorting-arraying is expensive, but usually, we have very
            // few different level dirs per run. Therefore, we rarely enter
            // this branch.
        }
        if (tested.solved) {
            // This is more expensive, but maybe still not enough to opitmize
            // away the sort-arraying.
            levelsCovered = (levelsCovered ~ MutFilename(tested.levelFilename))
                .sort!fnLessThan.uniq.array;
        }
    }
}
