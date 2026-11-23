---
status: accepted
date: 2026-02-15
---

# Publish quick actions as dynamic shortcuts on the widget URI

Android shows the app's quick actions when the user long-presses the
launcher icon. The fork publishes them dynamically from
`MainActivity.publishShortcuts` instead of the static `res/xml/shortcuts.xml`
file. Each quick action targets the home widget's URI scheme with the
widget launch action: `anchorwidget://note/new`,
`anchorwidget://note/new?checklist=1`, and `anchorwidget://journal/new`.

The `home_widget` plugin hands those URIs to the Flutter side on cold and
warm starts, so a quick action tap works in both cases. The static file
route worked only on cold start: the wrapper activity stashed the shortcut
type and the engine drained it at boot. Tapping a quick action while the
app ran in the background returned to the home screen and opened nothing.

## Considered Options

- Keep static `res/xml/shortcuts.xml`. This works on cold start only,
  hard-codes `targetPackage` and `targetClass`, and keeps the
  `ShortcutWrapperActivity` trampoline plus the `moek.anchor.notex/shortcuts`
  channel.
- Publish dynamic shortcuts that launch like the widget's buttons. This
  reuses the widget plumbing that already handles cold and warm starts and
  follows the anchor-plus approach. Quick actions appear after the first
  app launch instead of at install.

## Consequences

The `ShortcutWrapperActivity`, `ShortcutLaunchChannel`, and the
`shortcuts.xml` file are removed. `homeWidgetRouteForUri` gains the
`checklist` query parameter and the `journal/new` host. The Flutter side
adds `NoteEditScreen.startAsChecklist`, which opens a new note with a
checklist line.
