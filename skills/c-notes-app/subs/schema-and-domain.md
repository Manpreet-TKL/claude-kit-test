# notes - domain model and schema (volatile)

Schema evolves; check `src/database/migrations/` for the current truth. Below is the current shape at a high level.

## Core tables

| Table          | Purpose | Notes |
|---             |---      |---    |
| `notes`        | A note. | `body` is plain text. `slug` auto-generated in `Note::boot('creating')`. Soft-deleted rows still count toward slug uniqueness. |
| `note_versions`| History. | Created on every update; never edited in place. |
| `note_links`   | Outbound links from one note to another. | Used for the "linked from" UI. |
| `note_types`   | Lookup table for `notes.type_id`. | Drives icon + colour. |
| `sections`     | Sub-headings within a note. | Used by search (title + section name). |
| `tags`         | Many-to-many with notes. | Tag names are case-insensitive on lookup. |
| `links`        | External hyperlinks anywhere in the body. | Extracted by parser, displayed in sidebar. |
| `users`        | App users. | Auth via local password; no SSO. |
| `roles`        | Authorisation roles. | Carries `default_on_create` flag - see SKILL.md. |
| `audit_logs`   | Every create/update/delete on a note. | Hard requirement; never bypass. |

## Soft delete contract

`Note` and `NoteVersion` use `SoftDeletes`. The default global scope excludes them. The slug uniqueness check **does not** apply the default scope - restoring a deleted note must not collide with a live one.

## Search invariants (don't break these)

- `Note::search($term)` is the only public search entry point.
- LIKE expression: `LOWER(title) LIKE %term%` OR `LOWER(sections.name) LIKE %term%`.
- `%` and `_` are escaped before binding so users can't accidentally write a wildcard.
- An empty / whitespace-only `$term` returns an empty collection (not "all notes").
- Body is intentionally not searched. If asked to add body search, surface the trade-off (RAM, latency) first.

## Audit invariants

`AuditLog::record($action, $note)` must run for every create / update / delete. The `Note` model observer handles this - don't call `DB::table('notes')` directly from anywhere.
