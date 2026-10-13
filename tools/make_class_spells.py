"""Writes Data/ClassSpells.lua: every class spell a trainer teaches, the level
it is learned at and its rank, for class training (Logic/ClassTraining.lua).

Run from the repository root with the Forever client's game tables exported
as CSV (SkillLine, SkillLineAbility, SpellLevels, SpellName, Spell,
SpellMisc, Talent and ChrClasses):

    python tools/make_class_spells.py <client tables folder> [--build X.Y.Z.N]

What it keeps: spells on a class's own skill lines (the three trees and
the general one) that the client says are learned the usual way, from
level 2 on, that are not passive, not a talent and not a rune. Later ranks
of a talent spell (Pyroblast Rank 2) stay: the game offers them only to a
character with the rank before, and so does the addon.

What it can't know: what a trainer charges, and which spells a quest
teaches instead (a warlock's demons, a hunter's pet spells). QUEST_TAUGHT
leaves out the Classic ones; anything else is put right by the first visit
to a trainer, which the addon reads and keeps.

The same tool and output are in Blackthornes Butler and Blackthornes
Equipment. Never edit the output by hand; rerun this.
"""

import csv
import re
import sys
from collections import defaultdict
from pathlib import Path

CLASSES = {
    1: "WARRIOR", 2: "PALADIN", 3: "HUNTER", 4: "ROGUE", 5: "PRIEST",
    7: "SHAMAN", 8: "MAGE", 9: "WARLOCK", 11: "DRUID",
}

# Skill lines with category 7 (class) that are not a class's own spells.
NOT_CLASS_LINES = {"Engraving", "Runes", "Poisons", "Pet - Imp"}

# Class spells a quest teaches in Classic, never a trainer.
QUEST_TAUGHT = {
    697, 712, 691, 1122, 18540,             # warlock: Voidwalker, Succubus, Felhunter, Inferno, Ritual of Doom
    1515, 883, 2641, 982, 6991, 5149,       # hunter: Tame Beast, Call Pet, Dismiss Pet, Revive Pet, Feed Pet, Beast Training
    5487, 1066,                             # druid: Bear Form, Aquatic Form
    7328,                                   # paladin: Redemption
    71, 2458,                               # warrior: Defensive Stance, Berserker Stance
}

# The races Classic had, by ID (the bit is ID - 1), for spells only some
# races learn (a mage's teleports).
RACES = [1, 2, 3, 4, 5, 6, 7, 8, 10, 11]

MAX_LEVEL = 60
PASSIVE = 0x40
HIDDEN = 0x80


def rows(folder, name):
    with open(Path(folder) / f"{name}.csv", newline="", encoding="utf-8") as handle:
        yield from csv.DictReader(handle)


def num(value):
    try:
        return int(value or 0)
    except ValueError:
        return 0


def race_list(low, high):
    mask = (num(low) & 0xFFFFFFFF) | ((num(high) & 0xFFFFFFFF) << 32)
    if mask == 0:
        return None
    races = [race for race in RACES if mask >> (race - 1) & 1]
    if len(races) == len(RACES):
        return None
    return races


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build(folder):
    lines = {}
    for row in rows(folder, "SkillLine"):
        if row["CategoryID"] == "7" and row["DisplayName_lang"] not in NOT_CLASS_LINES \
                and not row["DisplayName_lang"].startswith("Pet - "):
            lines[row["ID"]] = row["DisplayName_lang"]

    talents = set()
    for row in rows(folder, "Talent"):
        for key, value in row.items():
            if (key == "SpellID" or key.startswith("SpellRank_")) and num(value):
                talents.add(num(value))

    names = {num(row["ID"]): row["Name_lang"] for row in rows(folder, "SpellName")}
    # A talent's own effect (Frostbite's freeze, Impact's stun) shares the
    # talent's name and has no rank; nobody learns it at a trainer.
    talent_names = {names.get(spell) for spell in talents}

    levels = {}
    for row in rows(folder, "SpellLevels"):
        if row["DifficultyID"] == "0":
            levels[num(row["SpellID"])] = num(row["BaseLevel"])

    subtext = {num(row["ID"]): row["NameSubtext_lang"] for row in rows(folder, "Spell")}
    attributes = {}
    for row in rows(folder, "SpellMisc"):
        if row["DifficultyID"] == "0":
            attributes[num(row["SpellID"])] = num(row["Attributes_0"])

    # Every rank on a class's lines, talents too, so a later rank can name
    # the one before it (Pyroblast Rank 2 needs the talent's Rank 1).
    ranks = {}
    abilities = [row for row in rows(folder, "SkillLineAbility") if row["SkillLine"] in lines]
    for row in abilities:
        spell = num(row["Spell"])
        rank = re.match(r"Rank (\d+)$", subtext.get(spell) or "")
        mask = num(row["ClassMask"])
        if rank and names.get(spell):
            for class_id, token in CLASSES.items():
                if mask >> (class_id - 1) & 1:
                    key = (token, names[spell], int(rank.group(1)))
                    ranks[key] = min(ranks.get(key, spell), spell)

    spells = defaultdict(dict)
    for row in abilities:
        if row["SkillLine"] not in lines or row["AcquireMethod"] != "0":
            continue
        spell = num(row["Spell"])
        level = levels.get(spell, 0)
        name = names.get(spell)
        if not name or level < 2 or level > MAX_LEVEL or spell in talents or spell in QUEST_TAUGHT:
            continue
        if attributes.get(spell, 0) & (PASSIVE | HIDDEN):
            continue
        rank = re.match(r"Rank (\d+)$", subtext.get(spell) or "")
        if not rank and name in talent_names:
            continue
        races = race_list(row["RaceMasks_0"], row["RaceMasks_1"])
        mask = num(row["ClassMask"])
        for class_id, token in CLASSES.items():
            if mask >> (class_id - 1) & 1:
                number = int(rank.group(1)) if rank else 0
                before = ranks.get((token, name, number - 1)) if number > 1 else None
                spells[token][spell] = (level, number, name, races, before)
    # A spell and its own effect can both be listed (Immolation Trap, Touch
    # of Weakness): one name, rank and level is one spell, the first ID.
    for token, listed in spells.items():
        seen = {}
        for spell in sorted(list(listed)):
            level, rank, name, races, _ = listed[spell]
            key = (name, rank, level)
            if key in seen:
                del listed[spell]
            else:
                seen[key] = spell
    return spells


def write(spells, out, build_name):
    parts = [
        "-- Data/ClassSpells.lua",
        "-- Every class spell a trainer teaches on Forever: the level it is learned",
        "-- at and its rank, from the Forever client's game tables" + (f" (build {build_name})." if build_name else "."),
        "-- Costs are not in them: the addon learns those at a trainer.",
        "--",
        "-- Generated by tools/make_class_spells.py, never typed by hand.",
        "",
        "local _, ns = ...",
        "",
        "-- [CLASS] = { { spell ID, level, rank (0 for none), English name, races or nil,",
        "-- the rank before's spell ID }, ... }, by level. `races` lists the race IDs that",
        "-- learn it (a mage's teleports); the rank before is learned first.",
        "ns.CLASS_SPELLS = {",
    ]
    for token in sorted(spells):
        parts.append(f"    {token} = {{")
        entries = sorted(spells[token].items(), key=lambda item: (item[1][0], item[1][2], item[1][1], item[0]))
        for spell, (level, rank, name, races, before) in entries:
            races_text = "{ " + ", ".join(str(race) for race in races) + " }" if races else "nil"
            tail = f", {before}" if before else ""
            parts.append(f"        {{ {spell}, {level}, {rank}, {lua_string(name)}, {races_text}{tail} }},")
        parts.append("    },")
    parts.append("}")
    Path(out).write_text("\n".join(parts) + "\n", encoding="utf-8")


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    build_name = None
    if "--build" in argv:
        index = argv.index("--build")
        build_name = argv[index + 1]
        del argv[index:index + 2]
    spells = build(argv[0])
    write(spells, "Data/ClassSpells.lua", build_name)
    for token in sorted(spells):
        print(f"{token}: {len(spells[token])} spells")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
