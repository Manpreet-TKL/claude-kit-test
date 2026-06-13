# API / xAPI

The xAPI documents itself: the OpenAPI 3.0+ spec is generated from PHP 8 attributes on the code, so
docs and implementation never drift. Don't hand-maintain a separate spec file.

## Attribute-driven spec

Annotate every resource class and public property (including constructor-promoted ones) with
`#[OAT\Schema]` / `#[OAT\Property]`; generate with `php artisan oe:generate-xapi-spec`; browse at
`/xapi/swagger`.

```php
#[OAT\Schema(title: 'Patient', type: 'object', required: ['id'])]
class PatientResource extends BaseDTOResource
{
    public function __construct(
        #[OAT\Property(property: 'id', type: 'integer', format: 'int64',
            minimum: 1, example: 12345, readOnly: true)]
        public int $id,
    ) {}
}
```

- Every property gets description, type, format, constraints (maxLength/minimum), nullability, example.
- Union types: `oneOf:` with multiple `new OAT\Schema(ref: ...)`. Arrays: `items: new OAT\Items(ref: ...)`.
- Code-system detail endpoints auto-document — no hand-written attributes.

## Resources

API responses are built from Resources that map from DTOs and present a consistent, framework-facing edge.
- Extend `BaseDTOResource` (uses `MapsResourceFromDTO`).
- Patient-related resources extend `OwnedByPatientResource` and document the patient relationship as a `oneOf` of full resource or `ReferenceResource` (a future rename to `BelongsToPatientResource` is under consideration).
- Use a `ReferenceResource` (lightweight `{link}` object, RESTful URI like `/oe2/Patient/12345`) to represent a resource by link instead of embedding it.
- xAPI patient routes bind `{patient}` → `PatientDTO` centrally (`Route::bind` in `XapiServiceProvider`); controllers accept `PatientDTO $patient` and do no manual lookup.
- Units not in SNOMED use UCUM (`"system": "http://unitsofmeasure.org"`).

## Response contract

- Wrap successes in the standard envelope: `data` (resource or collection), `meta` (`ResponseMetadata`: `version`, `generated_at`, `request_id`), `links` (`self`, `related[]`).
- Errors use `ErrorResponse` → array of `ErrorObject` (required `status` = HTTP code as string, `code` app-specific, `title` human-readable; optional `detail`, `source`).
- Paginate with the cursor-based `PaginatedResponse` (`meta.pagination`: base64 `cursor`, `has_more`, `count`, `total_estimate`).
- Document a distinct HTTP status response per outcome, each mapped to the right schema (e.g. `200` → resource, `404` → `ErrorResponse`).

## Validation

- Every resource must ship complete documentation **and** pass contract tests asserting its output matches its declared schema, example data is valid, no deprecated fields leak to production, and reference links resolve (`assertSchemaCompliant`, `assertExampleDataValid`, `assertValidUrl`, `assertRouteExists`).
- CI must pass OpenAPI validation, coverage, and lint before merge:

  ```bash
  php artisan openapi:validate --strict --check-examples
  php artisan openapi:coverage --minimum=95
  php artisan openapi:lint --fix-formatting
  ```

---
Source: OpenAPI Documentation & Standards (3062398978).
