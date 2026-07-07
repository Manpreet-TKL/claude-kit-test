---
name: Default-on-create roles for new permissions
description: When adding a new role or permission to ToukanNotes, surface a "default-on-create" mechanism so the user-creation form pre-ticks it for new users.
type: feedback
originSessionId: d1f63703-2d21-4d81-8579-cb7a1ef931a2
---
When introducing a new role/permission in ToukanNotes (notes-test), the user wants it to be **ticked by default** on the create-user form unless I'm told otherwise. Existing users should usually be back-filled with the role too unless the role is sensitive.

**Why:** the user explicitly said "should be a default ticked permission when creating a new user" when granting a `stats_viewer` role. Their preferred pattern is "open by default, admins revoke for edge cases" rather than "closed by default, everyone has to be granted".

**How to apply:** the `roles` table carries a `default_on_create` boolean column (added 2026-05). The user-create form should iterate roles and use `$role->default_on_create` (falling back to `false`) as the initial checked state when `! $editUser`. When adding a new privilege role, decide upfront whether `default_on_create` should be true and seed it that way; backfill existing users in the same migration if the role is meant to be near-universal.
