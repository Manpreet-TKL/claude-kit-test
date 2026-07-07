# Security & data integrity - "be paranoid"

The four "be paranoid" fundamentals from the Developer Checklist, plus scale and request-form validation.

## Validate all input

Validate every piece of user input before using it. For endpoints, validation belongs in a request
form object (see [request forms](#request-forms-validate-endpoints)); for models, in `rules()`
(see `models.md#validation-in-rules`).

## Authorise every action

Authorise every user action before performing it - check RBAC / access rules in the controller
before executing. *(replatform: via the `Gate` facade - see `auth.md`.)*

## Bind query parameters

Escape all DB query parameters - never string-concatenate SQL.

```php
$cmd->where('id = :id', [':id' => $id]);   // yes
// "WHERE id = " . $id                       // no
```

## Escape output

Correctly escape all output when it is rendered, to prevent XSS.

```php
echo CHtml::encode($patient->name);
```

## Audit actions

Provide auditing for actions where appropriate (see `clinical-safety.md#never-bypass-audit`).

## Design for scale

Ask "does it scale?" and use, as appropriate:
- **Pagination** for lists.
- **Eager loading** to cut query counts (`$model->with('relatedThing')->findAll(...)`).
- **Caching** for repeated reads.

## Request forms validate endpoints

Request forms **MUST** be used to validate requests for all new endpoints, and **SHOULD** be added
when changing/bug-fixing an existing endpoint.

```php
$form = new CreatePatientRequest($request->all());
if (!$form->validate()) { /* reject */ }
```

---
Source: Developer Checklist (2227634177).
