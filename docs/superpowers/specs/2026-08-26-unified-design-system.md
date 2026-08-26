# Unified Design System & Page Redesign — Design Spec

Date: 2026-08-26
Status: Approved

## Purpose

Make the app look and feel like one coherent product instead of a set of
independently-styled screens. Requested scope: login page, dashboard, CVL
Record details, CVL Edit Record, dialogs app-wide, and Application
Details (`service_details_page.dart`) — plus making buttons, text fields,
and dropdowns uniform across the whole app, not just those six screens
(a shared `ThemeData` cannot be scoped to a subset of pages).

## Current-state findings (from a full-codebase UI audit)

No `theme/` directory or style-constants file exists anywhere in `lib/`.
All theming is one line in `lib/main.dart`:

```dart
theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
```

No `AppBarTheme`, `ElevatedButtonThemeData`, `InputDecorationTheme`,
`CardTheme`, or `DialogTheme` overrides exist. Every screen falls back to
raw Material 3 defaults and re-implements its own ad hoc styling on top,
independently. Concretely:

- **Brand mismatch**: the app icon (`assets/logo/app_launcher.png`) uses
  a distinct blue (`#1A7FC5`, sampled directly from the asset), but the
  theme seed is `Colors.deepPurple` — no visual relationship between the
  app's own icon and its in-app color scheme.
- **4 different text-field decoration styles**: bare
  `InputDecoration(labelText:)` (login, claimant info, CVL edit — the
  majority), one with an added `hintText` (CVL edit contact field), one
  with a `prefixText: '₱ '` (claimant info amount field), and one fully
  custom pill search field (`cvl_search_page.dart`: a `Material` wrapper
  with `borderRadius: circular(28)` around a `TextField` with
  `OutlineInputBorder(borderSide: none)`, `filled/fillColor`, custom
  `contentPadding`) — unique, not reused anywhere else.
- **4 button widget types used near-interchangeably** for what is
  functionally the same "primary action" role, with no shared
  padding/shape/elevation override on any of them: `ElevatedButton(.icon)`
  (login, dashboard, service_details, claimant_info, capture_id,
  confirm_identity, confirm_claim, stop_page, sign_signature,
  preview_page — the dominant pattern), `FilledButton(.icon)`
  (cvl_lookup_page Edit, cvl_edit_page Save, qr_actions dialogs,
  SetQrSheet, cvl_search_page bottom sheet), `OutlinedButton.icon`
  (cvl_lookup_page/cvl_search_page QR actions, cvl_edit_page
  Change/Retake Photo, capture_id_page), and `IconButton.filledTonal`
  (cvl_search_page result-row actions).
- **3 independently-reimplemented "label/value section card" widgets**:
  `service_details_page.dart`'s `_SectionCard` (label column width
  `140`, label style `color: colorScheme.outline`),
  `cvl_lookup_page.dart`'s `_SectionCard` (label column width `120`,
  label style `fontWeight: w600`, no color), and
  `cvl_edit_page.dart`'s `_ReadOnlySection` (same 120/w600 style as
  cvl_lookup's, copy-pasted). Same visual job, three divergent
  implementations.
- **5+ near-duplicate `AlertDialog`s**: exit-confirm (verbatim-duplicated
  in `login_page.dart` and `dashboard_page.dart`), logout-confirm
  (`dashboard_page.dart`), a generic message dialog
  (`qr_actions.dart:showQrMessageDialog`), remove-QR confirm and
  set-QR-confirm/rejection dialogs (`qr_actions.dart`). Inconsistent
  emphasis rule: exit/logout use a plain `TextButton` for the confirm
  action; remove/set-QR use `FilledButton` for theirs — no deliberate
  distinction between destructive and non-destructive actions.
- **Cards**: default `Card` (no override) everywhere except
  `cvl_search_page.dart`'s `_ResultCard`, which alone sets
  `elevation: 0`, `color: surfaceContainerLow`,
  `shape: RoundedRectangleBorder(circular(16))`,
  `clipBehavior: antiAlias` — the only "flat card" look in the app,
  and arguably the nicest one already in use.
- **Hardcoded colors bypassing the theme**: `Colors.red` (login inline
  error text), `Colors.red.shade50` (`stop_page.dart` background),
  `Colors.grey` (login version-string footer), `Colors.white` /
  `Colors.black` / `Colors.white54` / `Colors.greenAccent` (photo
  viewers' black scaffold/appbar, `SetQrSheet`'s scan-success overlay).
- **Spacing**: page-level content padding is `16` in most detail/list/
  form screens but `24` in login/dashboard; inline `SizedBox` spacing
  values (`8`/`12`/`16`/`24`) are chosen ad hoc per screen with no shared
  constant.

## Scope

**In scope:**
1. A real `ThemeData` (`lib/core/theme/app_theme.dart`) driving color,
   buttons, text fields/dropdowns, cards, dialogs, app bar, snackbar —
   applied once in `main.dart`, affecting every screen in the app (not
   just the six named ones — a shared theme cannot be partial).
2. A small set of shared widgets to stop the 3-way section-card
   duplication and the 5-way dialog duplication.
3. Visual pass on the six explicitly named screens: Login, Dashboard,
   CVL Record details, CVL Edit Record, all dialogs app-wide, and
   Application Details.
4. Replacing the hardcoded colors listed above with theme references.

**Out of scope (explicitly deferred):**
- Dark theme / dark `ColorScheme` (per prior decision — light only, this
  round).
- Any screen not named above and not touched incidentally by the shared
  theme/widgets — e.g. the claimant-info/capture-ID/confirm-claim flow
  gets the *automatic* benefit of the new button/field/card theme, but
  is not getting a bespoke layout redesign in this pass.
- Any backend/API change — this is UI-only.
- Restructuring navigation, information architecture, or adding new
  screens/features.

## 1. Theme foundation — `lib/core/theme/app_theme.dart`

New file exporting a single `AppTheme.light` (`ThemeData`), assigned to
`MaterialApp.theme` in `main.dart`, replacing the current inline
`ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple))`.

- **Color**: `ColorScheme.fromSeed(seedColor: Color(0xFF1A7FC5), brightness: Brightness.light)`.
- **`AppBarTheme`**: `backgroundColor: colorScheme.surface`,
  `foregroundColor: colorScheme.onSurface`, `elevation: 0`,
  `scrolledUnderElevation: 2`, `centerTitle: false` (matches existing
  left-aligned titles — not changing that convention), consistent
  `titleTextStyle` from `textTheme.titleLarge`.
- **`InputDecorationTheme`**: `filled: true`,
  `fillColor: colorScheme.surfaceContainerHighest`,
  `border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)`,
  `enabledBorder`: same, `focusedBorder`: same shape with
  `BorderSide(color: colorScheme.primary, width: 2)`,
  `errorBorder`/`focusedErrorBorder`: same shape,
  `BorderSide(color: colorScheme.error[, width: 2])`,
  `contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)`.
  This is what unifies every `TextFormField` and `DropdownButtonFormField`
  in the app — including CVL Edit's two text fields and its gender
  dropdown, and both claimant-info dropdowns — without touching their
  call sites (no per-field `InputDecoration` overrides needed once this
  lands; existing per-field overrides that only set `labelText`/
  `hintText`/`prefixText`/`inputFormatters` keep working unchanged since
  those aren't decoration-shape properties).
- **Button themes** (`ElevatedButtonThemeData`, `FilledButtonThemeData`,
  `OutlinedButtonThemeData`, `TextButtonThemeData`): shared `style` base —
  `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))`,
  `minimumSize: const Size(64, 48)`,
  `padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12)`,
  `textStyle: textTheme.labelLarge`. This does not change *which* widget
  type a given call site uses (that is a semantic-weight decision, see
  "Button semantics" below) — it makes whichever type is chosen look
  consistent everywhere.
- **`CardTheme`**: `elevation: 0`, `color: colorScheme.surfaceContainerLow`,
  `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))`,
  `clipBehavior: Clip.antiAlias`, `margin: EdgeInsets.zero` (call sites
  keep controlling their own vertical spacing via explicit `SizedBox`s,
  matching current practice, rather than relying on `Card`'s own margin).
  This adopts `cvl_search_page.dart`'s `_ResultCard` look app-wide;
  that widget's now-redundant explicit overrides get simplified to a
  plain `Card()` once the theme covers them.
- **`DialogTheme`**: `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))`,
  `titleTextStyle`/`contentTextStyle` from `textTheme`.
- **`SnackBarThemeData`**: `behavior: SnackBarBehavior.floating`,
  `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))`.
- **`useMaterial3: true`** (explicit, matches current implicit default —
  stated so it isn't silently lost in a future Flutter upgrade).

### Button semantics (a rule, not new code)

To stop the 4-button-types-picked-arbitrarily problem without inventing
a fifth widget: adopt a documented convention (as a doc-comment on
`AppTheme`, and applied when touching each call site in this pass) —

- `FilledButton`: the single primary/highest-emphasis action on a
  screen or dialog (Save, Submit, Set QR, Edit-as-primary-CTA).
- `OutlinedButton`: secondary actions that are still a deliberate choice
  (Change Photo, Remove QR Code, Cancel-with-visual-weight).
- `TextButton`: low-emphasis / dismissive actions (Cancel in a dialog,
  "OK" on an informational dialog).
- `ElevatedButton`: **not used going forward** — every current
  `ElevatedButton`/`ElevatedButton.icon` call site touched in this pass
  (or naturally encountered) becomes `FilledButton`/`FilledButton.icon`,
  since Material 3 treats `FilledButton` as the modern equivalent and
  having both in the same app is itself a source of the inconsistency
  found in the audit. Screens outside the six explicitly named ones keep
  their existing `ElevatedButton` calls working (nothing breaks — it's
  just no longer the recommended pattern for *new* or *touched* code).
- `IconButton.filledTonal`: keep for compact icon-only row actions
  (`cvl_search_page.dart`'s per-row QR/Edit icons) — not a competing
  pattern, a different use case (icon-only vs labeled).

## 2. Shared widgets

New file `lib/core/widgets/confirm_dialog.dart`:

```dart
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async { ... }
```

Returns `true` only if the confirm action was tapped. Confirm button is
`FilledButton` normally, `FilledButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError)`
when `isDestructive`. Cancel is always a `TextButton`. Replaces, at each
call site (behavior-preserving — same title/message copy, same return
semantics each site already handles):
- `login_page.dart`'s exit-confirm.
- `dashboard_page.dart`'s exit-confirm and logout-confirm
  (logout marked `isDestructive: true`; exit is not).
- `qr_actions.dart`'s remove-QR confirm (`isDestructive: true`) and the
  set-QR "Assign this code?" confirm (not destructive).

A companion `showMessageDialog(context, {title, message})` (single
"OK" button, `TextButton`) replaces `qr_actions.dart`'s
`showQrMessageDialog` and the `SetQrSheet` rejection dialog — same file,
since both are trivial single-button variants of the same underlying
`AlertDialog` shape.

New file `lib/core/widgets/info_card.dart`:

```dart
class InfoCard extends StatelessWidget {
  const InfoCard({required this.title, required this.rows});
  final String title;
  final Map<String, String> rows;   // empty rows entry omits that line, matching current _SectionCard behavior
}
```

(No `trailing`/action-slot parameter — nothing in this pass's scope
needs one; adding it speculatively would be unused complexity. Add it
later if a real call site needs it.)

One shared label/value row layout (label column width `130` — splitting
the difference between the two current values rather than arbitrarily
picking one; label style `TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)`,
merging both current styles' intent). Replaces all three existing
`_SectionCard`/`_ReadOnlySection` implementations
(`service_details_page.dart`, `cvl_lookup_page.dart`, `cvl_edit_page.dart`) —
each call site keeps its own `rows` map construction (the
`if (record.x.isNotEmpty) 'Label': record.x` conditional-inclusion
pattern already in use), only the rendering widget is shared.

No new spacing-constants file: with the theme now owning card/button/
field sizing, the remaining ad hoc `SizedBox`/`EdgeInsets` spacing
between page sections is a cosmetic nit, not a source of visible
inconsistency — deferred rather than adding a token file for marginal
benefit.

## 3. Page-by-page changes

### Login (`login_page.dart`)
- Add the app logo (`assets/logo/app_launcher.png`, already bundled) at
  the top of the form, above the title — the login screen is the app's
  first impression and currently has no branding at all.
- Title/subtitle switch from a hardcoded `TextStyle` to
  `textTheme.headlineSmall`/`bodyMedium`.
- Inline error text: `Colors.red` → `colorScheme.error`.
- Version-string footer: `Colors.grey` → `colorScheme.onSurfaceVariant`.
- Exit-confirm dialog → `showConfirmDialog`.
- Remove the two `TextFormField`s' now-redundant styling (they already
  only set `labelText`, so no change needed there beyond what the theme
  provides automatically) — login/password fields, "remember me"
  checkbox, and the submit button keep their current structure, just
  restyled by the new theme.

### Dashboard (`dashboard_page.dart`)
- Keep the `Card > ListTile` menu structure (functionally fine) — restyle
  via the new `CardTheme` automatically, plus add a small colored
  leading-icon container (`CircleAvatar` or a tinted rounded box using
  `colorScheme.primaryContainer`) per menu item for visual hierarchy the
  current bare `Icon` doesn't provide.
- Exit-confirm and logout-confirm dialogs → `showConfirmDialog`
  (logout `isDestructive: true`).
- Welcome header keeps using `textTheme.headlineSmall`/`bodyMedium`
  (already theme-correct, no change).

### CVL Record details (`cvl_lookup_page.dart`)
- `_SectionCard` → shared `InfoCard`.
- `_QrCodeSection`'s QR image container: **keeps its explicit
  `Colors.white` background** — this is a scanability requirement (a QR
  code needs real white/black contrast and a quiet zone regardless of
  app theme, not a styling choice) — but its `BorderRadius.circular(8)`
  becomes `circular(12)` to match the new card/button radius language
  used everywhere else.
- `_ActionButtons` (Edit / Set QR Code / Remove QR Code): Edit becomes
  the primary `FilledButton.icon`; Set/Remove QR Code becomes
  `OutlinedButton.icon` — already matches current widget choice, so this
  is confirmation not a change, now with theme-consistent styling.

### CVL Edit Record (`cvl_edit_page.dart`)
- `_ReadOnlySection` → shared `InfoCard`.
- Text fields, gender dropdown: no call-site change needed — inherit the
  new `InputDecorationTheme` automatically (existing `hintText`/
  `inputFormatters`/`validator` on the contact field keep working as-is).
- Save button stays `FilledButton.icon` (primary action); Change/Retake
  Photo stays `OutlinedButton.icon` (secondary) — confirms current choice
  under the new button-semantics rule.

### Dialogs app-wide
- Every `AlertDialog` confirm/message dialog identified in the audit
  (login exit, dashboard exit/logout, `qr_actions.dart`'s four dialogs)
  routes through `showConfirmDialog`/`showMessageDialog`. `SetQrSheet`'s
  in-sheet "Set QR code?" confirm and its rejection dialog are included
  (same file, same helpers).

### Application Details (`service_details_page.dart`)
- `_SectionCard` → shared `InfoCard`.
- `_ErrorView`'s message `Text`: hardcoded `TextStyle(fontSize: 16)` →
  `textTheme.bodyLarge`.
- `_DocumentsSection`/`_DocumentThumbnail`: no structural change — the
  new `CardTheme` restyles the container automatically; thumbnail
  loading/error builders unchanged.
- `_ImageViewerPage`: keeps its black background/white foreground — a
  full-screen photo viewer being black is a deliberate, still-correct
  choice (matches `PhotoPreviewPage`'s existing precedent in
  `cvl_lookup`), not a theme violation to fix.
- Trailing "Scan Another" `ElevatedButton.icon` → `FilledButton.icon`
  per the button-semantics rule.

## Risks / non-goals called out explicitly

- **Visual regression risk on untouched screens**: the new
  `InputDecorationTheme`/button themes apply globally, so screens not
  named in scope (claimant info, capture ID, confirm identity/claim,
  sign signature, stop page, preview page) will visibly change too —
  this is intended (uniformity is the point) but means the "blast
  radius" of this change is the whole app, not six files. Each such
  screen is not getting a bespoke layout pass, only inheriting the new
  primitives.
- **`stop_page.dart`'s `Colors.red.shade50` background**: flagged in the
  audit but that screen isn't in the named scope; left as a follow-up
  candidate, not fixed in this pass, to keep scope bounded to what was
  asked.
- **No automated visual regression tooling** exists for this app (no
  golden-image tests) — verification for this change is manual
  (`flutter analyze` + existing widget tests + running the app) rather
  than pixel-diffed.
