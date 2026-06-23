# Models (Laravel / Eloquent — replatform)

Keep Eloquent models thin — define only what repositories need; business logic lives in services
(`dtos-services.md`).

## PhpDoc generics

Annotate `HasFactory` and every relation method with generics so static analysis (level 5) passes.

```php
/** @use HasFactory<\OELaravel\Database\Factories\EventFactory> */
use HasFactory;

/** @return BelongsTo<Firm, $this> */
public function firm()
{
    return $this->belongsTo(Firm::class);
}
```

## has() not whereRelationId()

Filter to related results with `has('relation', fn (Builder $q) => …)`, **not** `whereRelationId()` —
the closure form respects the related model's default scopes (critical for soft-deleting models like
`Event` / `Episode`).

```php
ExampleModel::has('relation', fn (Builder $q) => $q->whereId($id))->get();   // yes
// ExampleModel::whereRelationId($id)   // ignores the relation's default scope
```

## Casts and loading

- Declare casts in the `casts()` method:

  ```php
  protected function casts(): array { return ['event_date' => 'datetime', 'active' => 'boolean']; }
  ```

- **Eager loading (`with`) is multiple queries, not a join** — it avoids duplicate-row loading.
- To **order by a related column** you must add an explicit `join` (since `with` produces none) and
  `select` only the root model's columns. Resolve table names via `app(Model::class)->getTable()`:

  ```php
  $t  = app(Allergies::class)->getTable();
  $et = app(Event::class)->getTable();
  Allergies::select("{$t}.*")
      ->join($et, "{$t}.event_id", '=', "{$et}.id")
      ->with(['entries.allergy', 'event.episode'])
      ->orderBy('event.event_date', 'desc');
  ```

Conventions for when to bypass the ORM for performance are still being established.

---
Source: Laravel Models (3015835653).
