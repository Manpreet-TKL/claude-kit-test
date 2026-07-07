# DTOs, services & repositories (replatform)

The re-platform layers business logic on DTOs, behind services, with repositories as the only door to
storage. None of this logic should know which ORM (Yii AR or Eloquent) is underneath.

## DTOs and mappers

DTOs represent data independently of the ORM so business logic isn't coupled to the storage layer.
- Generate standard model DTOs via the code-generation commands (seeded from the legacy model's properties); don't hand-write them.
- Map ORM <-> DTO through a `DTOMapper` resolved by `DTOMapperManager` (contracts in `OEShared\Contracts\DTOs\Mappers`). Name the mapper per framework:
  - Laravel core `OELaravel\DTOs\Mappers\[Name]Mapper`, module `OELaravel\Modules\[Module]\DTOs\Mappers\[Name]Mapper`
  - Yii core `OE\dto\mappers\[Name]Mapper`, module `OEModule\[Module]\dto\mappers\[Name]Mapper`
- Mappers resolve as **singletons** - mock them through the container, not by `new`:

  ```php
  $this->mock(MyDTOMapper::class, fn (Mockery\MockInterface $m) =>
      $m->shouldReceive('make')->once()->andReturn(new MyDTO()));
  ```

- For a concrete event-element DTO, define the matching `EventElementRepository` subclass (+ ORM concrete) so the DTO and its xAPI resource resolve automatically; `GenericEventElementDTO` covers any unmapped element.

## DTO casts and readonly

Only cast a DTO property when it needs a richer type than the raw attribute; otherwise pass through
unchanged (`null` stays `null`, no defaults injected).

```php
use OE\enums\AttributeCastType;
class EventMapper extends ActiveRecordDTOMapper {
    protected array $custom_casts = ['event_date' => AttributeCastType::DateTime];
}
```

Protect identity/association fields with the read-only traits, including the required `__clone` unset
(introduced Jan 2026 - adopt opportunistically):

```php
class AllergiesDTO extends BaseDTO implements EventElementDTO {
    use HasReadOnlyId; use HasReadOnlyEvent;  // also HasReadOnlyEventElement
    public function __clone() { unset($this->id); unset($this->event_id); unset($this->event); }
}
```

Set guarded values via `setId()` / `setEventId()` / `setEvent()` (null-checked).

## Service layer

Services are concrete `OEShared` classes that operate on DTOs.
- **MUST**: take dependencies via constructor injection; wrap write actions in transactions (nested supported via `TransactionManager`); have intent-revealing method names; be resolved via the container.
- **MUST NOT**: touch web application state; touch the data layer directly; be instantiated with `new`.

```php
public function __construct(protected AllergiesRepositoryContract $repo) {}
```

Event-owned services implement `EventOwnedReadService` / `EventOwnedWriteService` (`createEventFor`, `recordForEvent`).

## Repository layer

Repositories mediate **all** storage access and speak DTOs in and out.
- `store(DTO)` returns the saved primary key (or throws); the passed DTO is **not** mutated with saved state - re-fetch via the returned id.
- Reads use a chainable query object then a read method that maps rows to DTOs. Laravel base: `BaseEloquentRepository` with the `UsesQueryBuilder` trait.

```php
$id    = $repository->store($dto);
$saved = $repository->get($id);
```

---
Sources: DTOs (3079602181), Coding & Architecture Standards children - Service Layer, Repository Layer (3015540745).
