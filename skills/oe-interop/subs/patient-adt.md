# Patient demographics, ADT, appointments

Two transports for both demographics and appointments: **HL7 v2.x** (Appendix A) and the **native OpenEyes RESTful PAS API** (Appendix B). Connect remaps all HL7 to the PAS API, so the PAS API bounds what is transferable. See `pasapi` for PASAPI v2 detail and `mcchannels` for the channels.

## Demographics / ADT

- **Inbound only.** Demographic updates cannot be pushed back to a PAS; to avoid drift, editing demographics inside OE is disabled.
- **Supported fields:** Hospital Number, NHS Number, Title, First/Last Name, Date of Birth, Date of Death, Primary Address, GP Code, GP Practice Code, Primary Telephone, Mobile Telephone, multiple Email Addresses, Next of Kin, Parent Contact Details (paediatric), Other Patient Contacts for Correspondence, Contact Preferences (Accessible Information Standards / AIS).
- **Not supported:** Allergy information, Alerts / risk information, multiple contact telephone numbers, secondary address(es).

## GP / practice data

- **PASAPI v1:** accepts only **GP code** and **GP Practice code**. OE holds current names/addresses by regularly importing full GP/Practice data from **NHS Digital** and resolving the codes against it.
- **PASAPI v2:** supports full GP and Practice details two ways — **direct import** via dedicated PASAPI GP and Practice endpoints, or **embedded** in the patient data imported from the PAS.

## Patient filtering (Specialty = Ophthalmology)

- Preferred: customer/Trust filters their feed to send only patients with a valid Ophthalmology appointment (Specialty Ophthalmology), for both registration and appointment messages.
- Fallback: where the Trust cannot filter (e.g. HL7 A08 updates), OE accepts all and **auto-discards** patients not already registered to Ophthalmology (i.e. not already in the OE DB).

## Patient PAS Lookup (optional HL7 Q21/K21)

- Use case: walk-in / Eye Casualty patient created in the PAS by the front desk, but no appointment booked, so no Ophthalmology HL7 was ever sent → patient absent from OE.
- When an OE patient search finds no record, OE can forward the query to another system (e.g. another PAS) via an **HL7 Q21/K21** message exchange **or** via the PAS API, so the record is usable immediately.

## Appointments / clinic lists

- Same two transports (HL7 v2.x / PAS API). Same Ophthalmology filtering recommendation applies to appointment feeds.

### Check-in (arrival)

- On an **A01** message OE sets the appointment to **"Arrived in the Clinic List"** and automatically **starts the patient pathway**.
- Two settings under `Admin->System->Settings->Worklists` must match the Connect channel config:
  - **PAS Appointment Patient Arrival Status Match Text** — the attribute *value* in inbound PAS API updates that signals arrival/check-in; when seen, the worklist check-in step is marked complete.
  - **PAS Appointment Patient Arrival Status Name** — the attribute *name* in inbound PAS API updates that confirms arrival/check-in; when seen, the check-in step is marked complete.
