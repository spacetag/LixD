module basics.user;

/* User settings read from the user config file. This file differs from the
 * global config file, see globconf.d. Whenever the user file doesn't exist,
 * the default values from static this() are used.
 */

import std.typecons; // rebindable
import std.algorithm; // sort filenames before outputting them
import std.conv;
import std.file; // mkdirRecurse
import std.stdio;

import enumap;

import basics.alleg5;
import basics.globals;
import basics.globconf;
import basics.help;
import basics.nettypes;
import file.filename;
import file.date;
import file.io;
import file.log; // when writing to disk fails
import lix.enums;

/*  static this();
 *  void load();
 *  void save();
 *  const(Result) getLevelResult         (Filename);
 *  void          setLevelResultCarefully(Filename, Result, in int);
 */

private Result[Filename] results;

MutFilename fileLanguage;
int optionGroup = 0;

@property bool languageIsEnglish()
{
    Filename fn = fileLanguage;
    return fn == basics.globals.fileLanguageEnglish;
}

bool scrollEdge        = true;
bool scrollRight       = true;
bool scrollMiddle      = true;
bool replayCancel      = true;
int  replayCancelAt    = 30;
int  mouseSpeed        = basics.globals.mouseStandardDivisor;
int  scrollSpeedEdge   = basics.globals.mouseStandardDivisor / 2;
int  scrollSpeedClick  = basics.globals.mouseStandardDivisor / 2;
bool avoidBuilderQueuing   = true;
bool avoidBatterToExploder = false;
bool priorityInvertMiddle  = true;
bool priorityInvertRight   = true;

int  soundVolume       = 10;

bool screenWindowed    = false;
int  screenWindowedX   = 640;
int  screenWindowedY   = 480;

bool arrowsReplay      = true;
bool arrowsNetwork     = true;
bool ingameTooltips    = true;
bool showButtonHotkeys = true;

int  guiColorRed      = 0x60;
int  guiColorGreen    = 0x80;
int  guiColorBlue     = 0xB0;

bool editorHexLevelSize = false;
int  editorGridSelected  = 1;
int  editorGridCustom    = 8;

bool replayAutoSolutions = true;
bool replayAutoMulti     = true;

MutFilename singleLastLevel;
MutFilename networkLastLevel;
MutFilename replayLastLevel;

Style    networkLastStyle = Style.red;

MutFilename editorLastDirTerrain;
MutFilename editorLastDirSteel;
MutFilename editorLastDirHatch;
MutFilename editorLastDirGoal;
MutFilename editorLastDirDeco;
MutFilename editorLastDirHazard;

@property const(Ac[14]) skillSort() { return _skillSort; }

private Ac[14] _skillSort = [
    Ac.walker,
    Ac.jumper,
    Ac.runner,
    Ac.climber,
    Ac.floater,
    Ac.batter,
    Ac.exploder,
    Ac.blocker,
    Ac.cuber,
    Ac.builder,
    Ac.platformer,
    Ac.basher,
    Ac.miner,
    Ac.digger
];

int keyForceLeft       = ALLEGRO_KEY_S;
int keyForceRight      = ALLEGRO_KEY_F;
int keyScroll          = ALLEGRO_KEY_PAD_MINUS;
int keyPriorityInvert  = ALLEGRO_KEY_PAD_MINUS;
int keySpawnintSlower  = ALLEGRO_KEY_F4;
int keySpawnintFaster  = ALLEGRO_KEY_F5;
int keyPause           = ALLEGRO_KEY_SPACE;
int keyFrameBackMany   = ALLEGRO_KEY_1;
int keyFrameBackOne    = ALLEGRO_KEY_2;
int keyFrameAheadOne   = ALLEGRO_KEY_3;
int keyFrameAheadMany  = ALLEGRO_KEY_6;
int keySpeedFast       = ALLEGRO_KEY_4;
int keySpeedTurbo      = ALLEGRO_KEY_5;
int keyRestart         = ALLEGRO_KEY_F1;
int keyStateLoad       = ALLEGRO_KEY_F2;
int keyStateSave       = ALLEGRO_KEY_F3;
int keyZoom            = ALLEGRO_KEY_Y;
int keyNuke            = ALLEGRO_KEY_F12;
int keySpecTribe       = ALLEGRO_KEY_TAB;
int keyChat            = ALLEGRO_KEY_ENTER;
int keyGameExit        = ALLEGRO_KEY_ESCAPE;

int keyMenuOkay        = ALLEGRO_KEY_SPACE;
int keyMenuEdit        = ALLEGRO_KEY_F;
int keyMenuExport      = ALLEGRO_KEY_R;
int keyMenuDelete      = ALLEGRO_KEY_G;
int keyMenuUpDir       = ALLEGRO_KEY_A;
int keyMenuUpBy1       = ALLEGRO_KEY_S;
int keyMenuUpBy5       = ALLEGRO_KEY_W;
int keyMenuDownBy1     = ALLEGRO_KEY_D;
int keyMenuDownBy5     = ALLEGRO_KEY_E;
int keyMenuExit        = ALLEGRO_KEY_ESCAPE;
int keyMenuMainSingle  = ALLEGRO_KEY_F;
int keyMenuMainNetwork = ALLEGRO_KEY_D;
int keyMenuMainReplays = ALLEGRO_KEY_S;
int keyMenuMainOptions = ALLEGRO_KEY_A;

int keyEditorLeft        = ALLEGRO_KEY_S;
int keyEditorRight       = ALLEGRO_KEY_F;
int keyEditorUp          = ALLEGRO_KEY_E;
int keyEditorDown        = ALLEGRO_KEY_D;
int keyEditorCopy        = ALLEGRO_KEY_A;
int keyEditorDelete      = ALLEGRO_KEY_G;
int keyEditorGrid        = ALLEGRO_KEY_C;
int keyEditorSelectAll   = ALLEGRO_KEY_ALT;
int keyEditorSelectFrame = ALLEGRO_KEY_LSHIFT;
int keyEditorSelectAdd   = ALLEGRO_KEY_V;
int keyEditorBackground  = ALLEGRO_KEY_T;
int keyEditorForeground  = ALLEGRO_KEY_B;
int keyEditorMirror      = ALLEGRO_KEY_W;
int keyEditorRotate      = ALLEGRO_KEY_R;
int keyEditorDark        = ALLEGRO_KEY_N;
int keyEditorNoow        = ALLEGRO_KEY_M;
int keyEditorZoom        = ALLEGRO_KEY_Y;
int keyEditorHelp        = ALLEGRO_KEY_H;
int keyEditorMenuSize    = ALLEGRO_KEY_5;
int keyEditorMenuVars    = ALLEGRO_KEY_Q;
int keyEditorMenuSkills  = ALLEGRO_KEY_X;
int keyEditorAddTerrain  = ALLEGRO_KEY_SPACE;
int keyEditorAddSteel    = ALLEGRO_KEY_TAB;
int keyEditorAddHatch    = ALLEGRO_KEY_1;
int keyEditorAddGoal     = ALLEGRO_KEY_2;
int keyEditorAddDeco     = ALLEGRO_KEY_3;
int keyEditorAddHazard   = ALLEGRO_KEY_4;
int keyEditorExit        = ALLEGRO_KEY_ESCAPE;

Enumap!(Ac, int) keySkill;

static this()
{
    fileLanguage            = fileLanguageEnglish;

    keySkill[Ac.walker]     = ALLEGRO_KEY_D;
    keySkill[Ac.runner]     = ALLEGRO_KEY_LSHIFT;
    keySkill[Ac.basher]     = ALLEGRO_KEY_E;
    keySkill[Ac.builder]    = ALLEGRO_KEY_A;
    keySkill[Ac.platformer] = ALLEGRO_KEY_T;
    keySkill[Ac.digger]     = ALLEGRO_KEY_W;
    keySkill[Ac.miner]      = ALLEGRO_KEY_G;
    keySkill[Ac.blocker]    = ALLEGRO_KEY_X;
    keySkill[Ac.cuber]      = ALLEGRO_KEY_X;
    keySkill[Ac.imploder]   = ALLEGRO_KEY_V;
    keySkill[Ac.exploder]  = ALLEGRO_KEY_V;

    keySkill[Ac.climber]    = ALLEGRO_KEY_B;
    keySkill[Ac.floater]    = ALLEGRO_KEY_Q;
    keySkill[Ac.jumper]     = ALLEGRO_KEY_R;
    keySkill[Ac.batter]     = ALLEGRO_KEY_C;

    singleLastLevel  = dirLevelsSingle;
    networkLastLevel = dirLevelsNetwork;
    replayLastLevel  = dirReplays;

    editorLastDirTerrain = dirImages;
    editorLastDirSteel   = dirImages;
    editorLastDirHatch   = dirImages;
    editorLastDirGoal    = dirImages;
    editorLastDirDeco    = dirImages;
    editorLastDirHazard  = dirImages;
}

// ############################################################################

class Result {
    const(Date) built;
    int    lixSaved;
    int    skillsUsed;
    Update updatesUsed;

    this (const(Date) bu)
    {
        built = bu;
    }

    int opEquals(in Result rhs) const
    {
        return built       == rhs.built
            && lixSaved    == rhs.lixSaved
            && skillsUsed  == rhs.skillsUsed
            && updatesUsed == rhs.updatesUsed;
    }

    // Returns < 0 on a worse rhs result, > 0 for a better rhs result.
    // The user wouldn't want to replace an old solving result with
    // a new-built-using non-solving result.
    // To check in results into the database of solved levels, use
    // setLevelResult() from this module.
    int opCmp(in Result rhs) const
    {
        if (lixSaved != rhs.lixSaved)
            return lixSaved - rhs.lixSaved; // more lix saved is better
        if (skillsUsed != rhs.skillsUsed)
            return rhs.skillsUsed - skillsUsed; // fewer skills used is better
        if (updatesUsed != rhs.updatesUsed)
            return rhs.updatesUsed - updatesUsed; // less time taken is better
        return built.opCmp(rhs.built); // newer result better
    }

    unittest {
        Result a = new Result(Date.now());
        Result b = new Result(Date.now());
        a.lixSaved = 4;
        b.lixSaved = 5;
        assert (b > a);
        b.lixSaved = 4;
        assert (a >= b);
        b.updatesUsed = 1;
        assert (a > b);
    }
}

const(Result) getLevelResult(in Filename fn)
{
    Result* ret = (rebindable!(const Filename)(fn) in results);
    return ret ? (*ret) : null;
}

void setLevelResult(
    in Filename _fn,
    Result r,
) {
    auto fn = rebindable!(const Filename)(_fn);
    auto savedResult = (fn in results);
    if (savedResult is null
        || savedResult.built != r.built
        || *savedResult < r)
        results[fn] = r;
}

// ############################################################################

private Filename userFileName()
{
    return new Filename(dirDataUser.dirRootful
     ~ basics.help.escapeStringForFilename(userName)
     ~ filenameExtConfig);
}


void load()
{
    if (userName == null) {
        // This happens upon first start after installation.
        // Don't try to load anything, and don't log anything.
        return;
    }

    while (basics.globconf.userName.length > playerNameMaxLength) {
        userName = basics.help.backspace(userName);
    }

    IoLine[] lines;

    try {
        lines = fillVectorFromFile(userFileName());
    }
    catch (Exception e) {
        log("Can't load user configuration for `" ~ userName ~ "':");
        log("    -> " ~ e.msg);
        log("    -> Falling back to the unescaped filename `"
            ~ userName ~ filenameExtConfig ~ "'.");
        try {
            lines = fillVectorFromFile(new Filename(
                dirDataUser.dirRootful ~ userName ~ filenameExtConfig));
        }
        catch (Exception e) {
            log("    -> " ~ e.msg);
            log("    -> " ~ "Falling back to the default user configuration.");
            lines = null;
        }
    }

    results = null;

    foreach (i; lines) switch (i.type) {

    case '$':
        if      (i.text1 == userLanguage            ) fileLanguage     = new Filename(i.text2);

        else if (i.text1 == userSingleLastLevel     ) singleLastLevel  = new Filename(i.text2);
        else if (i.text1 == userNetworkLastLevel    ) networkLastLevel = new Filename(i.text2);
        else if (i.text1 == userReplayLastLevel     ) replayLastLevel  = new Filename(i.text2);

        else if (i.text1 == userEditorLastDirTerrain) editorLastDirTerrain = new Filename(i.text2);
        else if (i.text1 == userEditorLastDirSteel  ) editorLastDirSteel   = new Filename(i.text2);
        else if (i.text1 == userEditorLastDirHatch  ) editorLastDirHatch   = new Filename(i.text2);
        else if (i.text1 == userEditorLastDirGoal   ) editorLastDirGoal    = new Filename(i.text2);
        else if (i.text1 == userEditorLastDirDeco   ) editorLastDirDeco    = new Filename(i.text2);
        else if (i.text1 == userEditorLastDirHazard ) editorLastDirHazard  = new Filename(i.text2);
        break;

    case '#':
        if      (i.text1 == userOptionGroup         ) optionGroup          = i.nr1;

        else if (i.text1 == userMouseSpeed          ) mouseSpeed           = i.nr1;
        else if (i.text1 == userScrollSpeedEdge     ) scrollSpeedEdge      = i.nr1;
        else if (i.text1 == userScrollSpeedClick    ) scrollSpeedClick     = i.nr1;
        else if (i.text1 == userScrollEdge          ) scrollEdge           = i.nr1 > 0;
        else if (i.text1 == userScrollRight         ) scrollRight          = i.nr1 > 0;
        else if (i.text1 == userScrollMiddle        ) scrollMiddle         = i.nr1 > 0;
        else if (i.text1 == userReplayCancel        ) replayCancel         = i.nr1 > 0;
        else if (i.text1 == userReplayCancelAt      ) replayCancelAt       = i.nr1;
        else if (i.text1 == userAvoidBuilderQueuing ) avoidBuilderQueuing  = i.nr1 > 0;
        else if (i.text1 == userAvoidBatterToExploder) avoidBatterToExploder = i.nr1 > 0;
        else if (i.text1 == userPriorityInvertMiddle) priorityInvertMiddle = i.nr1 > 0;
        else if (i.text1 == userPriorityInvertRight ) priorityInvertRight  = i.nr1 > 0;

        else if (i.text1 == userScreenWindowed) screenWindowed = i.nr1 > 0;
        else if (i.text1 == userScreenWindowedX) screenWindowedX = i.nr1;
        else if (i.text1 == userScreenWindowedY) screenWindowedY = i.nr1;
        else if (i.text1 == userArrowsReplay  ) arrowsReplay   = i.nr1 > 0;
        else if (i.text1 == userArrowsNetwork ) arrowsNetwork  = i.nr1 > 0;
        else if (i.text1 == userIngameTooltips) ingameTooltips = i.nr1 > 0;
        else if (i.text1 == userShowButtonHotkeys) showButtonHotkeys = i.nr1 > 0;
        else if (i.text1 == userGuiColorRed   ) guiColorRed    = i.nr1;
        else if (i.text1 == userGuiColorGreen ) guiColorGreen  = i.nr1;
        else if (i.text1 == userGuiColorBlue  ) guiColorBlue   = i.nr1;
        else if (i.text1 == userSoundVolume   ) soundVolume    = i.nr1;

        else if (i.text1 == userReplayAutoSolutions) replayAutoSolutions = i.nr1 > 0;
        else if (i.text1 == userReplayAutoMulti    ) replayAutoMulti     = i.nr1 > 0;

        else if (i.text1 == userEditorHexLevelSize) editorHexLevelSize = i.nr1 > 0;
        else if (i.text1 == userEditorGridSelected) editorGridSelected = i.nr1;
        else if (i.text1 == userEditorGridCustom  ) editorGridCustom   = i.nr1;

        else if (i.text1 == userNetworkLastStyle) {
            try networkLastStyle = to!Style(i.nr1);
            catch (ConvException e)           networkLastStyle = Style.red;
            if (networkLastStyle < Style.red) networkLastStyle = Style.red;
        }

        else if (i.text1 == userKeyForceLeft     ) keyForceLeft      = i.nr1;
        else if (i.text1 == userKeyForceRight    ) keyForceRight     = i.nr1;
        else if (i.text1 == userKeyScroll        ) keyScroll         = i.nr1;
        else if (i.text1 == userKeyPriorityInvert) keyPriorityInvert = i.nr1;
        else if (i.text1 == userKeySpawnintSlower) keySpawnintSlower = i.nr1;
        else if (i.text1 == userKeySpawnintFaster) keySpawnintFaster = i.nr1;
        else if (i.text1 == userKeyPause         ) keyPause          = i.nr1;
        else if (i.text1 == userKeyFrameBackMany ) keyFrameBackMany  = i.nr1;
        else if (i.text1 == userKeyFrameBackOne  ) keyFrameBackOne   = i.nr1;
        else if (i.text1 == userKeyFrameAheadOne ) keyFrameAheadOne  = i.nr1;
        else if (i.text1 == userKeyFrameAheadMany) keyFrameAheadMany = i.nr1;
        else if (i.text1 == userKeySpeedFast     ) keySpeedFast      = i.nr1;
        else if (i.text1 == userKeySpeedTurbo    ) keySpeedTurbo     = i.nr1;
        else if (i.text1 == userKeyRestart       ) keyRestart        = i.nr1;
        else if (i.text1 == userKeyStateLoad     ) keyStateLoad      = i.nr1;
        else if (i.text1 == userKeyStateSave     ) keyStateSave      = i.nr1;
        else if (i.text1 == userKeyZoom          ) keyZoom           = i.nr1;
        else if (i.text1 == userKeyNuke          ) keyNuke           = i.nr1;
        else if (i.text1 == userKeySpecTribe     ) keySpecTribe      = i.nr1;
        else if (i.text1 == userKeyChat          ) keyChat           = i.nr1;
        else if (i.text1 == userKeyGameExit      ) keyGameExit       = i.nr1;

        else if (i.text1 == userKeyMenuOkay       ) keyMenuOkay        = i.nr1;
        else if (i.text1 == userKeyMenuEdit       ) keyMenuEdit        = i.nr1;
        else if (i.text1 == userKeyMenuExport     ) keyMenuExport      = i.nr1;
        else if (i.text1 == userKeyMenuDelete     ) keyMenuDelete      = i.nr1;
        else if (i.text1 == userKeyMenuUpDir      ) keyMenuUpDir       = i.nr1;
        else if (i.text1 == userKeyMenuUpBy1      ) keyMenuUpBy1       = i.nr1;
        else if (i.text1 == userKeyMenuUpBy5      ) keyMenuUpBy5       = i.nr1;
        else if (i.text1 == userKeyMenuDownBy1    ) keyMenuDownBy1     = i.nr1;
        else if (i.text1 == userKeyMenuDownBy5    ) keyMenuDownBy5     = i.nr1;
        else if (i.text1 == userKeyMenuExit       ) keyMenuExit        = i.nr1;
        else if (i.text1 == userKeyMenuMainSingle ) keyMenuMainSingle  = i.nr1;
        else if (i.text1 == userKeyMenuMainNetwork) keyMenuMainNetwork = i.nr1;
        else if (i.text1 == userKeyMenuMainReplays) keyMenuMainReplays = i.nr1;
        else if (i.text1 == userKeyMenuMainOptions) keyMenuMainOptions = i.nr1;

        else if (i.text1 == userKeyEditorLeft       ) keyEditorLeft        = i.nr1;
        else if (i.text1 == userKeyEditorRight      ) keyEditorRight       = i.nr1;
        else if (i.text1 == userKeyEditorUp         ) keyEditorUp          = i.nr1;
        else if (i.text1 == userKeyEditorDown       ) keyEditorDown        = i.nr1;
        else if (i.text1 == userKeyEditorCopy       ) keyEditorCopy        = i.nr1;
        else if (i.text1 == userKeyEditorDelete     ) keyEditorDelete      = i.nr1;
        else if (i.text1 == userKeyEditorGrid       ) keyEditorGrid        = i.nr1;
        else if (i.text1 == userKeyEditorSelectAll  ) keyEditorSelectAll   = i.nr1;
        else if (i.text1 == userKeyEditorSelectFrame) keyEditorSelectFrame = i.nr1;
        else if (i.text1 == userKeyEditorSelectAdd  ) keyEditorSelectAdd   = i.nr1;
        else if (i.text1 == userKeyEditorBackground ) keyEditorBackground  = i.nr1;
        else if (i.text1 == userKeyEditorForeground ) keyEditorForeground  = i.nr1;
        else if (i.text1 == userKeyEditorMirror     ) keyEditorMirror      = i.nr1;
        else if (i.text1 == userKeyEditorRotate     ) keyEditorRotate      = i.nr1;
        else if (i.text1 == userKeyEditorDark       ) keyEditorDark        = i.nr1;
        else if (i.text1 == userKeyEditorNoow       ) keyEditorNoow        = i.nr1;
        else if (i.text1 == userKeyEditorZoom       ) keyEditorZoom        = i.nr1;
        else if (i.text1 == userKeyEditorHelp       ) keyEditorHelp        = i.nr1;
        else if (i.text1 == userKeyEditorMenuSize   ) keyEditorMenuSize    = i.nr1;
        else if (i.text1 == userKeyEditorMenuVars   ) keyEditorMenuVars    = i.nr1;
        else if (i.text1 == userKeyEditorMenuSkills ) keyEditorMenuSkills  = i.nr1;
        else if (i.text1 == userKeyEditorAddTerrain ) keyEditorAddTerrain  = i.nr1;
        else if (i.text1 == userKeyEditorAddSteel   ) keyEditorAddSteel    = i.nr1;
        else if (i.text1 == userKeyEditorAddHatch   ) keyEditorAddHatch    = i.nr1;
        else if (i.text1 == userKeyEditorAddGoal    ) keyEditorAddGoal     = i.nr1;
        else if (i.text1 == userKeyEditorAddDeco    ) keyEditorAddDeco     = i.nr1;
        else if (i.text1 == userKeyEditorAddHazard  ) keyEditorAddHazard   = i.nr1;
        else if (i.text1 == userKeyEditorExit       ) keyEditorExit        = i.nr1;

        else {
            Ac ac = stringToAc(i.text1);
            if (ac != Ac.max) keySkill[ac] = i.nr1;
        }
        break;

    case '<': {
        auto fn = rebindable!(const Filename)(new Filename(i.text1));
        Result read = new Result(new Date(i.text2));
        read.lixSaved    = i.nr1;
        read.skillsUsed  = i.nr2;
        read.updatesUsed = Update(i.nr3);
        Result* old = (fn in results);
        if (! old || *old < read)
            results[fn] = read;
        break; }

    default:
        break;

    }
}



nothrow void save()
{
    if (userName == null) {
        log("User name is empty. User configuration will not be saved.");
        return;
    }
    else if (userName.escapeStringForFilename == null) {
        log("Can't save user configuration for user `" ~ "':");
        log("    -> None of these characters are allowed in filenames.");
    }
    try {
        auto ufn = userFileName();
        mkdirRecurse(ufn.dirRootful);
        std.stdio.File f = File(ufn.rootful, "w");

        void fwr(in IoLine line)
        {
            f.writeln(line);
            f.flush();
        }

        fwr(IoLine.Dollar(userLanguage, fileLanguage.rootless));
        fwr(IoLine.Hash(userOptionGroup, optionGroup));
        f.writeln();

        fwr(IoLine.Hash(userMouseSpeed,             mouseSpeed));
        fwr(IoLine.Hash(userScrollSpeedEdge,        scrollSpeedEdge));
        fwr(IoLine.Hash(userScrollSpeedClick,       scrollSpeedClick));
        fwr(IoLine.Hash(userScrollEdge,             scrollEdge));
        fwr(IoLine.Hash(userScrollRight,            scrollRight));
        fwr(IoLine.Hash(userScrollMiddle,           scrollMiddle));
        fwr(IoLine.Hash(userReplayCancel,           replayCancel));
        fwr(IoLine.Hash(userReplayCancelAt,         replayCancelAt));
        fwr(IoLine.Hash(userAvoidBuilderQueuing,    avoidBuilderQueuing));
        fwr(IoLine.Hash(userAvoidBatterToExploder,  avoidBatterToExploder));
        fwr(IoLine.Hash(userPriorityInvertMiddle,   priorityInvertMiddle));
        fwr(IoLine.Hash(userPriorityInvertRight,    priorityInvertRight));
        f.writeln();

        fwr(IoLine.Hash(userScreenWindowed,         screenWindowed));
        fwr(IoLine.Hash(userScreenWindowedX,        screenWindowedX));
        fwr(IoLine.Hash(userScreenWindowedY,        screenWindowedY));
        fwr(IoLine.Hash(userArrowsReplay,           arrowsReplay));
        fwr(IoLine.Hash(userArrowsNetwork,          arrowsNetwork));
        fwr(IoLine.Hash(userIngameTooltips,         ingameTooltips));
        fwr(IoLine.Hash(userShowButtonHotkeys,      showButtonHotkeys));
        fwr(IoLine.Hash(userGuiColorRed,            guiColorRed));
        fwr(IoLine.Hash(userGuiColorGreen,          guiColorGreen));
        fwr(IoLine.Hash(userGuiColorBlue,           guiColorBlue));
        f.writeln();

        fwr(IoLine.Hash(userSoundVolume,            soundVolume));
        f.writeln();

        fwr(IoLine.Hash(userReplayAutoSolutions,    replayAutoSolutions));
        fwr(IoLine.Hash(userReplayAutoMulti,        replayAutoMulti));
        f.writeln();

        fwr(IoLine.Hash(userEditorHexLevelSize,     editorHexLevelSize));
        fwr(IoLine.Hash(userEditorGridSelected,     editorGridSelected));
        fwr(IoLine.Hash(userEditorGridCustom,       editorGridCustom));
        f.writeln();

        fwr(IoLine.Dollar(userSingleLastLevel,        singleLastLevel.rootless));
        fwr(IoLine.Dollar(userNetworkLastLevel,       networkLastLevel.rootless));
        fwr(IoLine.Dollar(userReplayLastLevel,        replayLastLevel.rootless));
        fwr(IoLine.Hash(userNetworkLastStyle,         networkLastStyle));
        f.writeln();

        fwr(IoLine.Dollar(userEditorLastDirTerrain, editorLastDirTerrain.rootless));
        fwr(IoLine.Dollar(userEditorLastDirSteel,   editorLastDirSteel.rootless));
        fwr(IoLine.Dollar(userEditorLastDirHatch,   editorLastDirHatch.rootless));
        fwr(IoLine.Dollar(userEditorLastDirGoal,    editorLastDirGoal.rootless));
        fwr(IoLine.Dollar(userEditorLastDirDeco,    editorLastDirDeco.rootless));
        fwr(IoLine.Dollar(userEditorLastDirHazard,  editorLastDirHazard.rootless));
        f.writeln();

        fwr(IoLine.Hash(userKeyForceLeft,      keyForceLeft));
        fwr(IoLine.Hash(userKeyForceRight,     keyForceRight));
        fwr(IoLine.Hash(userKeyScroll,         keyScroll));
        fwr(IoLine.Hash(userKeyPriorityInvert, keyPriorityInvert));
        fwr(IoLine.Hash(userKeySpawnintSlower, keySpawnintSlower));
        fwr(IoLine.Hash(userKeySpawnintFaster, keySpawnintFaster));
        fwr(IoLine.Hash(userKeyPause,          keyPause));
        fwr(IoLine.Hash(userKeyFrameBackMany,  keyFrameBackMany));
        fwr(IoLine.Hash(userKeyFrameBackOne,   keyFrameBackOne));
        fwr(IoLine.Hash(userKeyFrameAheadOne,  keyFrameAheadOne));
        fwr(IoLine.Hash(userKeyFrameAheadMany, keyFrameAheadMany));
        fwr(IoLine.Hash(userKeySpeedFast,      keySpeedFast));
        fwr(IoLine.Hash(userKeySpeedTurbo,     keySpeedTurbo));
        fwr(IoLine.Hash(userKeyRestart,        keyRestart));
        fwr(IoLine.Hash(userKeyStateLoad,      keyStateLoad));
        fwr(IoLine.Hash(userKeyStateSave,      keyStateSave));
        fwr(IoLine.Hash(userKeyZoom,           keyZoom));
        fwr(IoLine.Hash(userKeyNuke,           keyNuke));
        fwr(IoLine.Hash(userKeySpecTribe,      keySpecTribe));
        fwr(IoLine.Hash(userKeyChat,           keyChat));
        fwr(IoLine.Hash(userKeyGameExit,       keyGameExit));

        foreach (Ac ac, int mappedKey; keySkill)
            if (mappedKey != 0)
                fwr(IoLine.Hash(acToString(ac), mappedKey));
        f.writeln();

        fwr(IoLine.Hash(userKeyMenuOkay,          keyMenuOkay));
        fwr(IoLine.Hash(userKeyMenuEdit,          keyMenuEdit));
        fwr(IoLine.Hash(userKeyMenuExport,        keyMenuExport));
        fwr(IoLine.Hash(userKeyMenuDelete,        keyMenuDelete));
        fwr(IoLine.Hash(userKeyMenuUpDir,         keyMenuUpDir));
        fwr(IoLine.Hash(userKeyMenuUpBy1,         keyMenuUpBy1));
        fwr(IoLine.Hash(userKeyMenuUpBy5,         keyMenuUpBy5));
        fwr(IoLine.Hash(userKeyMenuDownBy1,       keyMenuDownBy1));
        fwr(IoLine.Hash(userKeyMenuDownBy5,       keyMenuDownBy5));
        fwr(IoLine.Hash(userKeyMenuExit,          keyMenuExit));
        fwr(IoLine.Hash(userKeyMenuMainSingle,    keyMenuMainSingle));
        fwr(IoLine.Hash(userKeyMenuMainNetwork,   keyMenuMainNetwork));
        fwr(IoLine.Hash(userKeyMenuMainReplays,   keyMenuMainReplays));
        fwr(IoLine.Hash(userKeyMenuMainOptions,   keyMenuMainOptions));
        f.writeln();

        fwr(IoLine.Hash(userKeyEditorLeft,        keyEditorLeft));
        fwr(IoLine.Hash(userKeyEditorRight,       keyEditorRight));
        fwr(IoLine.Hash(userKeyEditorUp,          keyEditorUp));
        fwr(IoLine.Hash(userKeyEditorDown,        keyEditorDown));
        fwr(IoLine.Hash(userKeyEditorCopy,        keyEditorCopy));
        fwr(IoLine.Hash(userKeyEditorDelete,      keyEditorDelete));
        fwr(IoLine.Hash(userKeyEditorGrid,        keyEditorGrid));
        fwr(IoLine.Hash(userKeyEditorSelectAll,   keyEditorSelectAll));
        fwr(IoLine.Hash(userKeyEditorSelectFrame, keyEditorSelectFrame));
        fwr(IoLine.Hash(userKeyEditorSelectAdd,   keyEditorSelectAdd));
        fwr(IoLine.Hash(userKeyEditorBackground,  keyEditorBackground));
        fwr(IoLine.Hash(userKeyEditorForeground,  keyEditorForeground));
        fwr(IoLine.Hash(userKeyEditorMirror,      keyEditorMirror));
        fwr(IoLine.Hash(userKeyEditorRotate,      keyEditorRotate));
        fwr(IoLine.Hash(userKeyEditorDark,        keyEditorDark));
        fwr(IoLine.Hash(userKeyEditorNoow,        keyEditorNoow));
        fwr(IoLine.Hash(userKeyEditorZoom,        keyEditorZoom));
        fwr(IoLine.Hash(userKeyEditorHelp,        keyEditorHelp));
        fwr(IoLine.Hash(userKeyEditorMenuSize,    keyEditorMenuSize));
        fwr(IoLine.Hash(userKeyEditorMenuVars,    keyEditorMenuVars));
        fwr(IoLine.Hash(userKeyEditorMenuSkills,  keyEditorMenuSkills));
        fwr(IoLine.Hash(userKeyEditorAddTerrain,  keyEditorAddTerrain));
        fwr(IoLine.Hash(userKeyEditorAddSteel,    keyEditorAddSteel));
        fwr(IoLine.Hash(userKeyEditorAddHatch,    keyEditorAddHatch));
        fwr(IoLine.Hash(userKeyEditorAddGoal,     keyEditorAddGoal));
        fwr(IoLine.Hash(userKeyEditorAddDeco,     keyEditorAddDeco));
        fwr(IoLine.Hash(userKeyEditorAddHazard,   keyEditorAddHazard));
        fwr(IoLine.Hash(userKeyEditorExit,        keyEditorExit));

        f.writeln();
        foreach (key, r; results)
            fwr(IoLine.Angle(key.rootless,
                r.lixSaved, r.skillsUsed, r.updatesUsed, r.built.toString));
    }
    catch (Exception e) {
        log("Can't save user configuration for `" ~ userName ~ "':");
        log("    -> " ~ e.msg);
    }
}
