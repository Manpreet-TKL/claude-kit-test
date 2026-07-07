# OE validator catalogue (volatile)

In `protected/components/OE*Validator*` and `protected/validators/`. Prefer them over hand-rolled `validate*` methods. Grep before quoting - the list drifts.

## Date / time

- `OEFuzzyDateValidator` - `YYYY` / `YYYY-MM` / `YYYY-MM-DD` all valid.
- `OEFuzzyDateRange` - fuzzy-date range comparison.
- `OEDateValidatorNotFuture` - must be <= today.
- `OEDateValidatorNotHistorical` - must be >= today.
- `OEDateCompareValidator` - compare two date attributes.
- `OEDatetimeValidator` - strict datetime.
- `OETimeValidator` - strict time of day.

## Phone / strings

- `OEPhoneNumberValidator` - phone number format (UK + international).
- `OEStringByteSizeWithinRangeValidator` - byte-aware length check (works around multibyte miscounts).

## Conditional requireds

- `OEAtLeastOneRequiredValidator` - at least one of these fields must be set.
- `OERequiredIfOtherAttributesEmptyValidator` - required only if the named attributes are all empty.
- `OERequiredTogetherValidator` - if any one is set, all of them must be set.
- `OEMaxOneSetValidator` - at most one of the named attributes may be set.
- `RequiredIfFieldValidator` - required when another field equals a given value.

## Enums

- `OEEnumValidator` - value must be a member of the named PHP 8.1 enum.

## When to write a custom validator

If a check is only ever used by one model and the rule isn't about a clinical-safety invariant, an inline `validate*` method is fine. **Anything reused across modules belongs in `protected/components/OE*Validator*`.**
