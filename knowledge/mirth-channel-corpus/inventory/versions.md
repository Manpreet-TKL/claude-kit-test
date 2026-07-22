# Versions & shared lineage

## BridgeLink version by instance

- **4.4.2**: ENHT, Pennine, Portsmouth, Sussex, Wales
- **4.5.2**: Bedford, EK, Kingston, MEH, Newmedica, Optegra
- **4.6.1**: Bolton

## PASAPI version usage by instance
(V1 = OE <=8, V2 = OE 9-10, V3 = OE 11+)

- **Bedford**: V1, V2
- **Bolton**: V1, V2
- **EK**: V2
- **ENHT**: V2
- **Kingston**: V2
- **MEH**: V1, V2
- **Newmedica**: V1, V3
- **Optegra**: V2
- **Pennine**: V1
- **Portsmouth**: V2
- **Sussex**: V1, V2
- **Wales**: V1

## Channel IDs shared across instances (cloned lineage)
Same channel `id` in >1 instance = the channel was copied between sites.

- `06f0b8b8-5ea0-41a4-a0bc-04b89fb5193c` -> Bedford, Bolton, EK, Kingston, Pennine, Portsmouth, Sussex  (names: OpenEyes Correspondence / OpenEyes PAS Query / PAS OUT)
- `da67d2ba-db52-4f50-898b-b534d71450ab` -> EK, ENHT, Kingston, Pennine, Portsmouth, Wales  (names: DICOM / DICOM_11118)
- `04524f4d-5201-4c16-b66f-26c3d7783d85` -> ENHT, MEH, Optegra, Portsmouth  (names: DOCUMENT-OUT-Minestrone / Docman)
- `c14efd23-2c1c-4e53-a59f-dcfe0e727c3b` -> Bedford, Bolton, Optegra, Sussex  (names: DICOM / IOL)
- `d69815ee-68d1-4dcb-8896-8b12ba06a9c4` -> Bedford, Optegra, Portsmouth, Sussex  (names: PAS IN / PAS IN V2)
- `7a7288a3-5ade-46bc-921d-56baf0a6bf06` -> Bolton, ENHT, Wales  (names: PAS IN / PAS In)
- `375fe7b2-d55c-4c60-b66f-dc2000c8ea95` -> Bedford, Sussex  (names: Document Delivery / Document OUT)
- `6c3a10d1-968d-468e-9355-008946825b20` -> Kingston, Pennine  (names: OpenEyes PAS)
- `7a04b9d1-70ac-4008-b809-732b88267f5c` -> Bolton, EK  (names: CORRESPONDENCE OUT / Filedrop Correspondence)
- `ba5419a3-24a5-48a2-bd9b-5cb2072e87f4` -> Kingston, Pennine  (names: OpenEyes DICOM Channel)
- `eee5caa4-786f-451b-9a89-f00aeb46f935` -> Kingston, Pennine  (names: OpenEyes DICOM IOLMaster Channel)
- `f703f9cd-a6ee-42e6-8550-c6a9c3fb1c73` -> Bedford, Portsmouth  (names: Document Upload PP / General Documents IN)
