# xAPI webhooks and BI / data warehouse

## Webhook subscribers (xAPI)

Event-driven push so external systems subscribe instead of polling. Managed at `Admin->System->Webhook Subscribers`.

- **Event types** (unless stated otherwise, three per subscription): **Created** (element first recorded), **Modified** (existing element altered), **Deleted** (existing element removed).
- **Configuration** needs two inputs: the event types to monitor, and the **endpoint URL** for delivery.
- **Payload**: lightweight; identifies what changed and includes **API URLs** to the relevant data. E.g. an allergy notification carries a URL to the specific clinical event that triggered it, plus a URL to retrieve the patient's full allergy list.
- Request/response formats, auth, and available endpoints: see the API specification documentation (not in this guide).
- New xAPI additions or custom webhook implementations follow the standard **Change Request** process.

### Coverage

- **v26.0.x** notifications supported for: allergies, risks, clinic outcomes, diagnoses, clinical events.
- **v26.1.x** (TBD in source): Referrals (RTT), Operation bookings.

## Data warehouse / Business Intelligence

- ToukanLabs can provide a **direct connection to the OpenEyes MySQL database** for inclusion in a Trust data warehouse / BI tooling.
- Recommended source for ad-hoc end-user reporting is a copy of the LIVE database - the **REPORTS** database - but that extra environment is **out of scope for standard deployments**.
- The **SUPPORT** database (used by the OE support team) can double as a reports database without a new environment, **subject to restrictions and by agreement**.
