# Appendices and references

> **Source gap:** the v1.1.1 export's body **ends at the Document Upload / HL7 MDM example** ("END OF DOCUMENT"). The appendices and a few late sections appear only in the Table of Contents and as inline cross-references — their full bodies are **not present** in this export. Use the live Confluence page for the real appendix tables. Listed below is what the TOC promises and the one worked example that *is* in the body.

## Referenced appendices (TOC only — bodies not in this export)

- **Appendix A – HL7 supported messages** — the HL7 message catalogue (ADT, Q21/K21, MDM, etc.). Referenced by demographics, appointments, and PAS-lookup sections.
- **Appendix B – PAS API** — PASAPI reference, including v2 GP/Practice import endpoints and examples. See the `c-pasapi` sibling skill for the actual PASAPI v2 contract.
- **Appendix C – Document Management Output** — correspondence/discharge PDF metadata (filename encoding + sidecar XML schema).
- **Appendix D – OpenEyes Desktop App Launcher** — the launcher utility used by FORUM and ImageNET (install/update, command-line params).
- **Appendix F – Document Upload Parameters** — definitions for the document-upload variables (`patient_identifier_type`, `patient_id`, `firm_id`, `document_subtype`, `laterality`, `unique_reference`, `document_date`, etc.). (No "Appendix E" in the TOC.)

Also TOC-listed with no body in this export: **PAS OUT**, **Event export to external systems (as PDF)**, **Configuration and Use of Webhooks / Documentation for the xAPI**, **COMPlog integration**, **Concentric Integration**, **DICOM (Medical Imaging Devices) Integration** + its supported-devices list, and a **Document Upload RESTful API**.

## HL7 MDM^T02 document-upload example (present in body)

Field mapping: `TXA` segment carries `document_date`, `unique_reference`, and `<filename>.<extension>`; `OBX` carries `document_subtype^laterality^firm_id` and the Base64 document data as `^^^Base64^<document_data>`.

```
MSH|^~\&|PAS|Ensemble|OpenEyes|Across|20160104110917||MDM^T02^MDM_T02|1130880405|P|2.4|39311933||AL|NE|GBR||||v3_5
EVN||20160104110827
PID|1||012345^^^BG-PDT^FACIL^RMC~0123456789^^^^NHS||TestSurname^TestForename^TestMiddlename^^MRS||19700101000000|F|||Address Line1^Address Line2^City^County^BL3 0JR^NSP^HOME^Q31||01204111111||012|M|CE|||||A|BOLTON|NSP||8||NSP||N||NSTS01
PD1|||GP Practice Address Line1^001^P88888|G3333333^GPSurname^AA^^^DR^^NATGP^^^123456
NK1|1|NOKSurname^NOKForname^^^MS|NOK|NOK Address Line1^NOK Address Line 2^NOK City^NOK County^BL4 0JR^NSP^HOME|01204222222||PRREL|19350211000000|||||||NSP|||||012|||||||||||||
PV1|1|O|E-CATARACTS^^^RMC01^^^^^Pooled All Eye Consultants|||||G3333333^GPSurname^AA^^^DR^^NATGP^^^123456~925888899999^GPSurname^AA^^^DR^^SDSID^SHA^^123456|C7777777^ConsSurname^A^^^MR^^GMC^^^200000999|130||||NSP|NSP|||NHS|206773999^^^PiMSOUTPAT|||||||||||||||||||||||||20160126130000|||||||
TXA||||20240528||||||||Doc123|||||||||||||Eyepic.png
OBX|||General^L^1||^^^Base64^DGEHRFdfgerrgFGDFGDF==
```

This maps the same fields as the file-drop conventions in `subs/correspondence.md`: identifier type / patient id in `PID`, firm/subtype/laterality in `OBX`, reference + date + filename in `TXA`.
