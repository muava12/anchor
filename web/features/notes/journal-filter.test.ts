import { describe, expect, it } from "vitest";
import { findJournalTagId, notesForBoard } from "./journal-filter";
import type { Note } from "./types";

const note = (id: string, tagIds: string[] = []): Note =>
  ({ id, tagIds }) as Note;

const JOURNAL = "tag-journal";

describe("findJournalTagId", () => {
  it("matches the tag named journal in any casing", () => {
    expect(findJournalTagId([{ id: "a", name: "Journal" }])).toBe("a");
    expect(findJournalTagId([{ id: "b", name: "JOURNAL" }])).toBe("b");
  });

  it("returns null when no tag is named journal", () => {
    expect(findJournalTagId([{ id: "a", name: "ideas" }])).toBeNull();
    expect(findJournalTagId([])).toBeNull();
  });
});

describe("notesForBoard", () => {
  const notes = [note("n1"), note("n2", [JOURNAL])];

  it("keeps every note when the switch is off", () => {
    expect(
      notesForBoard(notes, {
        hideJournal: false,
        journalTagId: JOURNAL,
        isSearching: false,
      }),
    ).toHaveLength(2);
  });

  it("drops journal notes when the switch is on", () => {
    const kept = notesForBoard(notes, {
      hideJournal: true,
      journalTagId: JOURNAL,
      isSearching: false,
    });
    expect(kept.map((n) => n.id)).toEqual(["n1"]);
  });

  it("brings journal notes back while searching", () => {
    expect(
      notesForBoard(notes, {
        hideJournal: true,
        journalTagId: JOURNAL,
        isSearching: true,
      }),
    ).toHaveLength(2);
  });

  it("does nothing when the workspace has no journal tag", () => {
    expect(
      notesForBoard(notes, {
        hideJournal: true,
        journalTagId: null,
        isSearching: false,
      }),
    ).toHaveLength(2);
  });

  it("does not change the array it is given", () => {
    const input = [note("n1"), note("n2", [JOURNAL])];
    notesForBoard(input, {
      hideJournal: true,
      journalTagId: JOURNAL,
      isSearching: false,
    });
    expect(input).toHaveLength(2);
  });
});
