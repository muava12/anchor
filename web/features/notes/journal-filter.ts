import type { TagLabel } from "@/features/tags/types";
import type { Note } from "./types";

/** The tag name that marks a note as a journal entry. */
const JOURNAL_TAG_NAME = "journal";

/**
 * The id of the tag named `journal`, compared case-insensitively.
 *
 * The mobile app uses the same rule, so a note hidden on the phone is hidden
 * on the web too. Null means the workspace has no journal tag yet.
 */
export function findJournalTagId(tags: Iterable<TagLabel>): string | null {
  for (const tag of tags) {
    if (tag.name.toLowerCase() === JOURNAL_TAG_NAME) return tag.id;
  }
  return null;
}

/**
 * The notes the board may show.
 *
 * The switch is a browse filter, not a search filter: a search brings journal
 * notes back, so a person can still find an entry by its words. A missing tag
 * id leaves every note alone.
 */
export function notesForBoard(
  notes: Note[],
  {
    hideJournal,
    journalTagId,
    isSearching,
  }: {
    hideJournal: boolean;
    journalTagId: string | null;
    isSearching: boolean;
  },
): Note[] {
  if (!hideJournal || isSearching || journalTagId === null) return notes;
  return notes.filter((note) => !(note.tagIds ?? []).includes(journalTagId));
}
