# OpenEyes v10.0.30: typical usage and load profile

This is a reusable workload profile derived from OpenEyes **v10.0.30** access logs and checked against that application's source. Treat the clinical activity mix as a typical planning baseline. The figures are observed request counts from one web container in a group using sticky sessions, not universal capacity targets or counts of staff, patients or completed encounters. No client identifiers or capture dates are retained here.

The reference dataset contains **2,932,635 requests**, including **903,932 application requests**. Hour-of-day comparisons use 27 complete local days, comprising 19 weekdays and 8 weekend days; partial boundary days are excluded from those comparisons. Other totals cover the whole reference dataset. A sticky backend is not a random sample: individual staff, devices, integrations and rendering jobs can be unevenly distributed. Do not multiply its figures by the container count to estimate deployment totals.

Source baseline: OpenEyes tag `v10.0.30`, commit `77438f14e9f4124df8c66effb4bc2b6a28e44435`. Source paths below are relative to that repository. Findings about code behavior are distinct from hypotheses about observed failures.

## What people typically do

The foreground workload is dominated by opening patient summaries, working through clinic worklists and viewing or recording examinations. Staff also review and create documents, consent forms and correspondence; prescribe medication; record biometry, operation bookings and operation notes; and use checklists, messaging and patient queues. Patient summary and worklist views are useful starting points for representative performance tests because they bring together several areas of the clinical record.

Viewing existing records is prominent, but form submissions and workflow steps are also important. A GET followed by a POST to a create or update action is consistent with opening and submitting a form. Counts alone cannot prove that a clinical task completed successfully. Redirects, retries and repeated visits all remain requests. Referrers indicate context, not a reconstructed person's journey.

Much of the total workload is generated around those activities: image resolution, attachment retrieval, authentication support, external patient administration and automated document rendering. A test that only opens the main HTML page measures a narrower workload than a browser that lets the page finish loading its dependent requests.

## Overall traffic

| Traffic | Requests | Share of all |
| --- | --- | --- |
| Health checks | 470,813 | 16.05% |
| Application | 903,932 | 30.82% |
| Static assets | 1,401,851 | 47.80% |
| Apache internal | 156,039 | 5.32% |

The high static-asset count includes resources fetched by automated rendering. Health checks and Apache internal requests should have separate counters when assessing clinical activity. The health endpoint returned 200 throughout this reference dataset; that does not establish that every clinical workflow was healthy.

## Top 40 foreground, database-backed URLs

This table ranks **clinical page, search and form actions**, including submissions and redirects. It excludes identified Headless Chrome requests, background AJAX/polling, integration APIs, static files, file/image delivery, login/device-idle screens, administration and profile screens. The home landing page is also excluded because it principally supplies navigation/search scaffolding, rather than a targeted clinical database workload. This is the operational definition of foreground end-user URLs used here; it is not a ranking of every SQL-capable HTTP handler.

Controller/action case variants and query-style versus path-style record IDs are grouped. Counts include all statuses and methods, so they differ from a dashboard of successful page GETs. There are 98,003 requests in the qualifying foreground category; the first 40 groups account for 97,733. No session identity is available, and excluding explicit Headless Chrome does not prove that every remaining request was human.

`P`, `W`, `E`, `F`, `T` and `B` refer to the SQL evidence below. `GET candidate` means a candidate for carefully controlled warming, not a promise of a read-only request. `Form` means its GET and POST parts must be treated separately. `Workflow only` identifies actions unsuitable for blind warm-up replay.

| Rank | URL template | Requests | Methods | Activity | SQL / replay |
| --- | --- | --- | --- | --- | --- |
| 1 | `/patient/summary/:id` | 15,918 | GET 15,918 | Review patient summary and timeline | P; GET candidate |
| 2 | `/worklist/view` | 13,673 | GET 13,673 | View the clinic worklist and patient pathways | W; GET candidate |
| 3 | `/OphCiExamination/default/view/:id` | 8,641 | GET 8,641 | Review Examination | E; GET candidate |
| 4 | `/OphCiExamination/default/step/:id` | 7,034 | GET 3,275, POST 3,759 | Work through an examination workflow step | E/F; Workflow only |
| 5 | `/patient/search` | 5,583 | GET 5,583 | Search for a patient | P; GET candidate |
| 6 | `/OphCoDocument/Default/create` | 4,515 | GET 2,288, POST 2,227 | Create Document | F; Form |
| 7 | `/OphCoDocument/default/view/:id` | 3,872 | GET 3,872 | Review Document | E; GET candidate |
| 8 | `/OphTrConsent/default/view/:id` | 3,729 | GET 3,729 | Review Consent | E; GET candidate |
| 9 | `/OphCiExamination/Default/create` | 3,567 | GET 1,809, POST 1,758 | Create Examination | F; Form |
| 10 | `/OphCoCorrespondence/default/view/:id` | 3,165 | GET 3,165 | Review Correspondence | E; GET candidate |
| 11 | `/OphCoCorrespondence/Default/create` | 2,387 | GET 1,268, POST 1,119 | Create Correspondence | F; Form |
| 12 | `/OphCoChecklist/default/update/:id` | 2,369 | GET 1,247, POST 1,122 | Edit Checklist | F; Form |
| 13 | `/OphTrConsent/Default/create` | 1,942 | GET 989, POST 953 | Create Consent | F; Form |
| 14 | `/OphDrPrescription/default/view/:id` | 1,927 | GET 1,927 | Review Prescription | E; GET candidate |
| 15 | `/OphCoChecklist/default/view/:id` | 1,885 | GET 1,885 | Review Checklist | E; GET candidate |
| 16 | `/OphTrOperationnote/Default/create` | 1,804 | POST 852, GET 952 | Create Operation note | F; Form |
| 17 | `/OphInBiometry/default/view/:id` | 1,783 | GET 1,783 | Review Biometry | E; GET candidate |
| 18 | `/PatientTicketing/default` | 1,580 | GET 1,580 | Patient ticketing queues | T; GET candidate |
| 19 | `/OphCiExamination/default/update` | 1,213 | GET 603, POST 610 | Edit Examination | F; Form |
| 20 | `/OphCoMessaging/default/view/:id` | 1,198 | GET 1,198 | Review Message | E; GET candidate |
| 21 | `/OphCoCorrespondence/default/update` | 1,166 | GET 595, POST 571 | Edit Correspondence | F; Form |
| 22 | `/OphInBiometry/default/update/:id` | 1,150 | GET 625, POST 525 | Edit Biometry | F; Form |
| 23 | `/OphTrOperationbooking/Default/create` | 1,051 | GET 614, POST 437 | Create Operation booking | F; Form |
| 24 | `/OphTrOperationbooking/default/view/:id` | 904 | GET 904 | Review Operation booking | E; GET candidate |
| 25 | `/OphGeneric/default/view/:id` | 882 | GET 882 | Review Device Information | E; GET candidate |
| 26 | `/OphTrOperationbooking/whiteboard/view/:id` | 870 | GET 660, POST 210 | Whiteboard View | B; Workflow only |
| 27 | `/OphTrOperationnote/default/view/:id` | 870 | GET 870 | Review Operation note | E; GET candidate |
| 28 | `/OphCoChecklist/Default/create` | 742 | GET 742 | Resolve current checklist and redirect | F; Workflow only |
| 29 | `/OphCoMessaging/Default/create` | 578 | GET 296, POST 282 | Create Message | F; Form |
| 30 | `/OphInBiometry/Default/create` | 256 | GET 241, POST 15 | Create Biometry | F; Form |
| 31 | `/OphCoDocument/default/update` | 252 | GET 138, POST 114 | Edit Document | F; Form |
| 32 | `/OphTrOperationbooking/whiteboard/consentForm/:id` | 250 | POST 250 | Whiteboard Consent Form | B; Workflow only |
| 33 | `/OphTrLaser/Default/create` | 165 | POST 83, GET 82 | Create Laser | F; Form |
| 34 | `/OphDrPGDPSD/default/view/:id` | 153 | GET 153 | Review Drug Administration | E; GET candidate |
| 35 | `/OphDrPrescription/Default/create` | 129 | GET 65, POST 64 | Create Prescription | F; Form |
| 36 | `/OphTrOperationnote/Default/update/:id` | 124 | GET 81, POST 43 | Edit Operation note | F; Form |
| 37 | `/OphDrPrescription/default/update/:id` | 106 | GET 69, POST 37 | Edit Prescription | F; Form |
| 38 | `/OphDrPGDPSD/default/update` | 105 | GET 53, POST 52 | Edit Drug Administration | F; Form |
| 39 | `/OphTrLaser/default/view/:id` | 100 | GET 100 | Review Laser | E; GET candidate |
| 40 | `/OphTrIntravitrealinjection/Default/create` | 95 | GET 46, POST 49 | Create Intravitreal injection | F; Form |

| SQL evidence | v10.0.30 source and database work |
|---|---|
| P: patient | `protected/controllers/PatientController.php::actionSummary()` loads the patient, episodes, events and drafts and records an audit. `actionSearch()` uses `PatientSearch`, a database-backed result provider, and can redirect when exactly one patient matches. |
| W: worklist | `protected/controllers/WorklistController.php::actionView()` resolves current worklists, saved filters, counts, pathway types and settings through the worklist manager and ActiveRecord models. |
| E: event view | `protected/controllers/BaseEventTypeController.php::initWithEventId()` loads `Event`, its episode and patient. `initActionView()` and `actionView()` load elements and other event context and audit the view. The listed clinical modules inherit this behavior directly or through their event controller. |
| F: event form | The same base controller's `initActionCreate()` resolves patient, episode, draft and template data. `initActionUpdate()` loads the existing event and draft/template context. Module create/update handlers use these facilities, and POST normally validates and persists clinical data. Overrides matter, especially Checklist. |
| T: ticketing | `protected/modules/PatientTicketing/controllers/DefaultController.php::actionIndex()` queries tickets, queue context and associated patients. `/PatientTicketing/default` and `/PatientTicketing/default/index` are grouped. |
| B: whiteboard | `protected/modules/OphTrOperationbooking/controllers/WhiteboardController.php` loads whiteboard, booking and settings data. `actionView()` can call `loadData()` and persist derived whiteboard data. `actionConsentForm()` can create/load whiteboard data and renders a full consent page. |

These are source-confirmed database-backed routes. The access logs contain neither SQL statements nor query counts. A cache hit can change the actual SQL executed, and high request frequency does not establish high database cost.

Important exceptions when turning the table into a test:

1. `OphCiExamination/default/step` calls `ChecklistManager::addRequiredChecklists()` and the update workflow. A GET can perform workflow work and create required checklist state.
2. `OphCoChecklist/Default/create` locates the current checklist and redirects. It can cancel a pending deletion. Its 742 GETs were redirects, not 742 newly created checklists.
3. `patient/search` performed database-backed searches but all 5,583 requests in this grouped sample returned redirects. Follow the redirect and measure the search and resulting page separately.
4. Whiteboard view and consent actions can populate stored data. The observed consent-form requests were POSTs. Do not turn that row into an invented GET warm-up request.
5. Event views normally write audit/session data. Even a GET candidate is not equivalent to a read-only SQL query.

### Using the list for load tests or buffer-pool warming

1. Resolve placeholders from approved test fixtures. `:id` on an event action is an event ID, on patient summary it is a patient ID, and whiteboard actions need their booking/event context. Create actions commonly require `patient_id`; search requires its search term; worklists depend on current clinic, dates, filters and user permissions. These normalized route templates omit those values and are not complete replay URLs.
2. Start warming with authenticated, authorized GET candidates such as patient summary, worklist, examination view, document view, consent view and correspondence view. Select representative current patients/events rather than one record repeatedly. Set a small concurrency and observe database reads, buffer-pool misses, query latency and web-worker usage before increasing it. Access counts cannot tell how many records fill the working set.
3. Use form submissions, checklist steps and whiteboard actions only in a controlled workflow load test with isolated fixtures, valid CSRF state and an understood cleanup procedure. Do not replay production POST bodies or turn redirects into retries. Keep normal auditing and authorization enabled.
4. Use the request frequencies as initial relative weights, then measure SQL time and cost for those routes. Weighting by successful GETs is more appropriate for a GET-only warmer; weighting all GET/POST requests is appropriate only when reproducing the corresponding workflow. A realistic browser test should additionally load its normal AJAX/image requests, which are deliberately absent from the top-40 table.
5. Measure a cold and a warm run separately. Warming InnoDB pages, warming PHP/application caches and warming a browser cache are different effects. Record server timings, SQL time, physical reads, error rates and worker saturation; do not infer improvement just because the second page load is faster.

The existing [page benchmarking notes](oe-page-benchmarking.md) and [buffer-pool audit notes](../Database/mariadb-buffer-pool-audit.md) describe measurement techniques. Verify their examples against the deployed release before using them.

## Background activity and integrations

The full top-20 application list explains the work surrounding foreground pages. Its denominator is all 903,932 application requests; it includes all methods and statuses, and does not apply the foreground exclusions above.

| URL template | Requests | Share of application | Role |
| --- | --- | --- | --- |
| `/User/getSessionExpireTimestamp` | 89,781 | 9.93% | Check session expiry |
| `/Site/getOverlayPrepopulationData` | 89,583 | 9.91% | Fetch login-overlay defaults |
| `/eventImage/getImageIds` | 80,617 | 8.92% | Resolve or generate event images |
| `/eventImage/viewById` | 77,334 | 8.56% | Fetch event image |
| `/api/v2/attachmentData/get` | 55,875 | 6.18% | Retrieve attachment content |
| `/api/v2/attachmentData/store` | 43,240 | 4.78% | Store attachment data |
| `/site/login` | 35,733 | 3.95% | Sign-in screen; also used by automated rendering |
| `/eventImage/generateImage/:id` | 27,630 | 3.06% | Generate event image |
| `/OphCiExamination/Default/checkPrescriptionAutoSignEnabled` | 22,644 | 2.51% | Check prescription automatic-signing setting |
| `/worklist/getPathStep` | 21,536 | 2.38% | Load worklist pathway-step content |
| `/PASAPI/V3/Patient/:id` | 18,001 | 1.99% | Patient administration data update |
| `/patient/summary/:id` | 15,923 | 1.76% | Review patient summary and timeline |
| `/worklist/view` | 13,682 | 1.51% | View the clinic worklist and patient pathways |
| `/worklist/retrieveFilters` | 12,929 | 1.43% | Fetch worklist filters |
| `/PASAPI/V3/PatientAppointment/:id` | 12,623 | 1.40% | Appointment data update |
| `/worklist/renderPopup` | 10,807 | 1.20% | Load patient worklist popup |
| `/site/esignDevicePopup` | 10,757 | 1.19% | Load electronic-signature device popup |
| `/OphCoCorrespondence/default/printForRecipient/:id` | 10,049 | 1.11% | Render or print Correspondence |
| `/FileStorage/FileUploadRequest/delete` | 9,975 | 1.10% | Clear temporary upload requests; not deletion of clinical events |
| `/OphCiExamination/default/view/:id` | 8,640 | 0.96% | Review Examination |

Session-expiry and login-overlay defaults account for **179,364 requests, or 19.84% of application traffic**. The three main event-image endpoints account for **185,581, or 20.53%**. Patient administration accounts for 18,001 patient-resource requests and 12,623 appointment-resource requests. These categories should not be interpreted as staff clicks.

`FileStorage/FileUploadRequest/delete` clears temporary upload requests. Its route name does not mean clinical events were deleted. Likewise, fetching an event image or an attachment does not imply that a new clinical event was created.

Explicit `HeadlessChrome` user-agent markers identify **1,238,131 requests, or 42.22% of all requests**. All 10,049 `printForRecipient` requests carried that marker, and rendering routes were also present. This supports server-side document rendering as a substantial source of load; it does not prove that every headless request was a document job or count the number of jobs.

No staff browser market-share table is retained. User agents are advertised strings, automation can use ordinary browser strings, and request counts overweight clients that fetch many resources. A naive `Safari/` match misclassifies Chrome and Edge on iOS: `CriOS/`, `EdgiOS/` and `FxiOS/` must take precedence. The original analysis classifier was corrected accordingly. Browser labels cannot reliably count people, sessions or staff logins. Login requests also include unidentified automation.

## Typical busy and quiet hours

Hours are local clock hours from the access timestamps. Use the deployment's timezone, including daylight-saving transitions, when applying this profile. The tables show requests per hour per backend, averaged across complete days. They are neither instantaneous rates nor a concurrency recommendation.

Weekday activity rises around 07:00, is high from 08:00 to 17:00, peaks around **09:00-11:00**, and has a second busy period around **14:00-16:00**, with a lunch dip. The quietest stretch is approximately **03:00-06:00**. Weekend clinics still generate substantial daytime traffic, so a weekend is not equivalent to an idle application.

| Local hour | Weekday mean | Weekday median | Weekend mean | Weekend median |
| --- | --- | --- | --- | --- |
| 00:00-01:00 | 35.6 | 17.0 | 13.0 | 5.0 |
| 01:00-02:00 | 23.6 | 13.0 | 9.1 | 8.0 |
| 02:00-03:00 | 10.3 | 9.0 | 4.2 | 3.5 |
| 03:00-04:00 | 8.5 | 7.0 | 3.6 | 1.5 |
| 04:00-05:00 | 5.5 | 3.0 | 2.2 | 2.0 |
| 05:00-06:00 | 6.8 | 2.0 | 1.5 | 1.0 |
| 06:00-07:00 | 58.4 | 10.0 | 8.0 | 4.5 |
| 07:00-08:00 | 633.7 | 468.0 | 186.6 | 128.5 |
| 08:00-09:00 | 4,306.8 | 4,524.0 | 1,455.9 | 1,317.0 |
| 09:00-10:00 | 5,076.0 | 5,228.0 | 2,582.5 | 2,506.0 |
| 10:00-11:00 | 4,588.6 | 4,866.0 | 2,791.5 | 2,997.0 |
| 11:00-12:00 | 4,151.9 | 4,271.0 | 2,390.6 | 2,319.0 |
| 12:00-13:00 | 2,582.2 | 2,594.0 | 1,612.2 | 1,511.5 |
| 13:00-14:00 | 3,798.5 | 4,053.0 | 2,422.2 | 2,283.0 |
| 14:00-15:00 | 4,498.6 | 4,672.0 | 2,819.5 | 2,572.5 |
| 15:00-16:00 | 3,946.1 | 3,750.0 | 2,534.2 | 2,736.5 |
| 16:00-17:00 | 2,671.7 | 2,740.0 | 1,327.2 | 1,381.5 |
| 17:00-18:00 | 1,201.6 | 1,228.0 | 186.9 | 126.0 |
| 18:00-19:00 | 174.0 | 150.0 | 177.1 | 6.5 |
| 19:00-20:00 | 167.7 | 88.0 | 13.5 | 3.5 |
| 20:00-21:00 | 167.6 | 53.0 | 103.0 | 22.0 |
| 21:00-22:00 | 261.1 | 84.0 | 27.9 | 10.5 |
| 22:00-23:00 | 343.8 | 128.0 | 32.4 | 1.5 |
| 23:00-24:00 | 132.2 | 19.0 | 2.5 | 1.5 |

The busiest weekday mean is about 5,076 application requests in the 09:00 hour, compared with about 5.5 in the 04:00 hour. The busiest individual observed hour contained 6,435 application requests. Averaging 5,076 requests over an hour gives about 1.41 requests/second; this conceals bursts, long polls, background SQL loops and internal rendering concurrency and must not be used to choose a worker limit.

| Day | Mean application requests/day | Median application requests/day |
| --- | --- | --- |
| Monday | 33,870.5 | 41,629.5 |
| Tuesday | 41,356.2 | 41,706.5 |
| Wednesday | 39,918.7 | 39,504.0 |
| Thursday | 39,183.8 | 40,493.5 |
| Friday | 40,193.2 | 39,681.5 |
| Saturday | 26,539.0 | 26,955.5 |
| Sunday | 14,876.2 | 15,327.5 |

The quiet hours are candidates for scheduling controlled tests, not a proven maintenance window. Integration batches, database jobs, backups and activity on other backends are outside this evidence. The busiest observed server-error hour contained 275 HTTP 500 responses; error counts need their own time series rather than assuming that the highest clinical volume caused them.

## HTTP outcomes and failure concentrations

| HTTP status | Requests | Share of all |
| --- | --- | --- |
| 200 | 2,840,647 | 96.8633% |
| 201 | 3,075 | 0.1049% |
| 204 | 441 | 0.0150% |
| 302 | 70,962 | 2.4197% |
| 304 | 1,496 | 0.0510% |
| 400 | 87 | 0.0030% |
| 403 | 20 | 0.0007% |
| 404 | 8,936 | 0.3047% |
| 409 | 2 | 0.0001% |
| 422 | 488 | 0.0166% |
| 500 | 6,481 | 0.2210% |

There were **6,481 HTTP 500 responses**, 0.221% of all requests and about 0.717% of application requests. The device poll and appointment update routes account for **6,089 of them, or 93.95%**. There were **zero logged 502, 503 or 504 responses** at this backend.

A proxy can return a 504 to the browser while the backend continues and logs a different status. Therefore zero backend 504s does not rule out user-visible gateway timeouts. These access logs have no verified duration field, so no latency percentiles or timeout durations can be recovered. Correlate proxy, backend and application logs to diagnose that behavior. [HTTP 504 semantics](https://www.rfc-editor.org/rfc/rfc9110.html#section-15.6.5).

| HTTP status | URL template | Responses |
| --- | --- | --- |
| 404 | `/api/v2/attachmentData/get` | 8,488 |
| 500 | `/site/pollRequestForDevice` | 3,137 |
| 500 | `/PASAPI/V3/PatientAppointment/:id` | 2,952 |
| 422 | `/api/v2/attachmentData/store` | 480 |
| 500 | `/api/v1/patient/search` | 142 |
| 404 | `/assets/:asset_hash/js/Assessment.js` | 132 |
| 404 | `/worklist/changeStepStatus` | 95 |
| 404 | `/Api/Eyedraw/get/:value/:value` | 92 |
| 500 | `/OphInBiometry/default/createImage/:id` | 69 |
| 400 | `/PASAPI/V3/DidNotAttend` | 41 |
| 404 | `/worklist/checkIn` | 39 |
| 500 | `/OphCoDocument/default/createImage/:id` | 35 |
| 400 | `/worklist/renderPopup` | 23 |
| 500 | `/eventImage/:id` | 20 |
| 500 | `/OphCoCorrespondence/default/createImage/:id` | 19 |
| 404 | `/assets/:asset_hash/dist/svg/v6/all/ui/type-linebreak.svg` | 17 |
| 403 | `/eventImage/getImageIds` | 17 |
| 500 | `/patient/updatePlansProblems` | 14 |
| 500 | `/OphCiExamination/default/step/:id` | 14 |
| 500 | `/OphDrPrescription/default/finalizeWithSignatures` | 12 |
| 404 | `/css/fonts/:asset_hash.woff2` | 12 |
| 500 | `/worklist/deleteStep` | 9 |
| 404 | `/OphCoDocument/default/createImage/:id` | 8 |
| 500 | `/OphTrOperationnote/Default/create` | 7 |
| 404 | `/OphCiExamination/default/step/:id` | 7 |

Attachment retrieval explicitly returns 404 when no attachment exists. Its 8,488 occurrences are about 95% of all 404s, but do not by themselves prove broken pages. Attachment storage's 422 responses indicate validation failures. Inspect the consumer and response body before treating these categories as infrastructure faults. An HTTP 200 can also contain an application-level error, which status counting will miss.

### `/site/pollRequestForDevice`: caller, behavior and likely failure modes

The callers are the linked-device waiting screens, `protected/views/site/device_ready.php` and `device_ready_handheld.php`, reached through `/site/deviceready`. They wait for an electronic-signature or file-upload request from the signed-in user's workflow. Every observed request to this poll route had that waiting-page referrer.

`protected/controllers/SiteController.php::actionPollRequestForDevice()` loops indefinitely, calling `getLatestRequest()` and sleeping two seconds until work appears. Each idle iteration queries the latest unfinished `SignatureRequest` and `FileUploadRequest` for the current user. This is approximately one application query per second per idle waiting device, before session/bootstrap overhead, even though the HTTP access log records only the completed request. One prefork Apache worker remains occupied for that request.

Of 3,328 requests, 3,137 returned 500, 179 returned 200 and 12 redirected: a **94.26% 500 rate**. The browser retries 502 immediately and other non-200 responses after two seconds. This can sustain repeated failures.

Follow-up application-log sampling confirmed a concrete failure in this path: **`Attempt to read property "eventType" on null` at `SiteController.php:595`**. All 20 sampled matching production-web log events contained this error, with repeated failures approximately two seconds apart. The trace passes through `getSignatureRequestForDevice()`, `getLatestRequest()` and `actionPollRequestForDevice()`. This confirms a real cause in the route, not an attribution of all 3,137 failures to that one exception or to the same backend.

The pending `SignatureRequest` exists, but its `event` relation resolves to null. `protected/models/Event.php::defaultScope()` normally excludes soft-deleted events, so an event marked deleted can produce this behavior even when its database row still exists. A missing row is another possibility; the precise data condition needs a database check. The poll selects unfinished requests without validating that related event before dereferencing it. The client then retries, encounters the same invalid pending request, and can repeat the error. The signature lookup happens before file-upload lookup, so this exception can also prevent the device from receiving an otherwise valid upload request.

The saved PR in `~/pullrequests/oe-pr-signature-request-deleted-event/` already addresses selection of requests belonging to deleted events, including the case where a newer invalid request hides an older valid one. Refer to that proposal for the fix; no separate implementation note is needed here. Its presence in the archive does not establish deployment status. The waiting/retry behavior below is a separate concern.

Recommended application change: bound the wait to a measured interval shorter than upstream idle timeouts, return a defined empty result when no work arrives, and update the client to reconnect normally for that result. A 20-25 second deadline is a possible test value, not a known deployment setting. Add bounded backoff and jitter on failures, cancel polling when the screen closes, validate referenced event data and record a request correlation ID with exceptions. Do not return a 500 merely because no signature/upload arrived.

Simply lowering PHP's `max_execution_time` is insufficient: on Unix, database/system waits and sleeps are not generally counted in the same way as script execution time. Use an explicit wall-clock deadline. [PHP execution time behavior](https://www.php.net/manual/en/function.set-time-limit.php).

### `/PASAPI/V3/PatientAppointment/:id`: caller, behavior and likely failure modes

This is the external patient-administration integration endpoint for appointments, not a browser screen. A PAS integration engine submits appointment XML with its external resource identifier. The logs do not identify the integration product; they do not justify naming a particular engine as the confirmed caller.

| Method | HTTP status | Requests |
| --- | --- | --- |
| DELETE | 204 | 441 |
| DELETE | 404 | 6 |
| PUT | 200 | 7,243 |
| PUT | 201 | 1,974 |
| PUT | 400 | 7 |
| PUT | 500 | 2,952 |

There were 12,623 requests overall and 2,952 HTTP 500s: **23.39% overall**, or **24.24% of the 12,176 PUTs**. All of these 500s were PUT failures. DELETE is a separate cancellation/removal path.

`protected/modules/PASAPI/controllers/V3Controller.php::actionUpdate()` parses the resource, establishes institution/identifier context and saves within a transaction. Its exception handler rolls back and returns status 500 with exception messages and a stack trace in the XML failure response. The integration engine's saved HTTP response can therefore be more immediately useful than the Apache error log.

`protected/modules/PASAPI/resources/PatientAppointment.php` maps the patient, appointment time, assigned worklist and attributes. `protected/components/worklist/WorklistManager.php` requires a valid mapping and a unique matching automatic worklist. Relevant failure cases include no matching worklist, multiple matching worklists, missing/invalid mapping attributes, inconsistent stored worklist attributes, and failure to add or update the worklist patient entry. These application exceptions can produce 500 without a database outage.

There is also a locking concern to investigate: `protected/modules/PASAPI/models/PasApiAssignment.php::lock()` retries `GET_LOCK(..., 1)` in an unbounded loop. Concurrent messages for the same external assignment can occupy workers while waiting. Neither contention nor a specific mapping error is proved by the access logs.

For a definitive diagnosis, correlate one failed PUT's timestamp and external identifier with its integration response and timestamped application/PHP exception. Group failure messages before changing mappings or retry behavior. Check whether retries repeatedly submit the same invalid message. Successful 200/201 responses and 400/404 failures should remain separate from the exception category. A bounded application-log search did not establish the appointment 500 cause. The catch handler returns the exception to the caller without an explicit application-log call, so a missing CloudWatch trace does not rule out a handled exception. Add sanitized exception logging with correlation, rather than logging entire patient payloads.

## Reducing session-expiry and login-overlay requests

These calls are **custom OpenEyes code built on Yii**, not unavoidable periodic requests imposed by the framework.

`protected/assets/js/script.js` initializes the login overlay and queues its expiry timer on pages other than `/site/login`. In `protected/assets/js/script-utils.js`, `createLoginOverlay()` synchronously fetches `/Site/getOverlayPrepopulationData`; `queueLoginOverlay()` fetches `/User/getSessionExpireTimestamp` and schedules the overlay for five seconds after the returned expiry. It also runs again around reauthentication. The pair's near-equal totals are consistent with page initialization, not two continuously running fixed-interval polls.

The expiry controller reads the `user_session` expiry. The overlay controller reads user/session context and institution/site models. `protected/components/OESession.php` extends Yii's database session implementation. `extend_session=false` prevents extending expiry, but its custom write path still reads/checks the session and writes session data. It is not a no-SQL switch, and the overlay prepopulation call does not send that flag.

| Change to assess | Benefit and conditions |
|---|---|
| Include minimal overlay defaults in the page's existing authenticated bootstrap data | Removes the separate synchronous prepopulation request and reuses context already loaded to render the page. Keep only the context the overlay actually needs. |
| Provide authoritative session expiry and server time through the existing page/response path | Can remove the separate expiry request while preserving an accurate local timer. Account for when the session write actually extends expiry, subsequent activity and server/client clock differences. |
| Build/show the overlay lazily and eliminate synchronous AJAX | Avoids blocking every page load. Preserve the minimal context needed after expiry; fetching protected context only after the session has expired may fail. |
| Maintain one expiry timer per page and coordinate tabs | Clear obsolete timers after reauthentication and activity. Cross-tab messages should share deadline/logout state, never authentication secrets. The server remains the authority. |
| Use an explicit trusted rendering layout for automated document jobs | Avoid loading interactive login-overlay code in a layout that does not use it. Do not make a user-agent string an authentication bypass. |
| If bootstrapping is not feasible, combine the two reads | Cuts HTTP round trips, but it may simply move the same SQL into one endpoint; measure the database effect separately. |

The observed 179,364 requests are an upper bound on requests affected by this work, not a guaranteed 19.84% CPU or SQL saving. Retain server-side session expiry, the patient-screen privacy overlay, logout handling and safe reauthentication of unsaved work. Increasing session lifetime or disabling expiry is not a performance fix. Verification should cover active/inactive tabs, clock skew, expiry during editing, failed reauthentication, logout in another tab and ordinary rendering jobs.

See [Login overlay: behavior, performance cost and proposed changes](oe-login-overlay-performance.md) for the implementation considerations, request-saving scenarios and verification criteria.

## Ghostscript and document-conversion errors

The error file contained two timestamped Apache startup notices and 1,650 nonempty undated diagnostic lines, mainly from PDF handling. It did not contain timestamped PHP traces explaining the two major HTTP 500 hotspots. The diagnostic counts below are occurrences of messages, **not distinct failed documents or conversion jobs**, and cannot be assigned to an access-log time window.

| Diagnostic | Messages |
| --- | --- |
| **** Error:  An error occurred while reading an XREF table. | 211 |
| **** Error reading a content stream. The page may be incomplete. | 207 |
| **** Error: Unrecoverable error in xref! | 23 |
| **** Error: Transparency Group, Form XObject execution corrupted the stack. | 23 |
| **** Error: Form stream has unbalanced q/Q operators (too many q's) | 23 |
| **** Error: File has insufficient data for an image. | 5 |
| **** Error: stream operator isn't terminated by valid EOL. | 4 |
| **** This file requires a password for access. | 2 |
| Error: /invalidfileaccess in pdf_process_Encrypt | 2 |
| GPL Ghostscript #.#.#: Unrecoverable error, exit code # | 2 |
| **** Error: Cannot find a <value> anywhere in the file. | 1 |
| **** Error:  Trailer dictionary not found. | 1 |
| No pages will be processed (FirstPage > LastPage). | 1 |
| warning: ignoring zlib error: incorrect data check | 1 |
| .<path>:#: s_aes_process(): invalid aes padding byte (0x33) | 1 |

An XREF error concerns the PDF's cross-reference structure, which locates its objects. An incomplete content stream indicates that page drawing/content could not be fully read. These are consistent with malformed, truncated or otherwise damaged PDF input; the additional password/encryption messages describe a different class of input problem. Recovery may still produce output with missing content. PDF version greater than 1.4 alone does not establish corruption.

There are concrete Ghostscript entry points in v10.0.30:

| Source | What invokes PDF processing |
|---|---|
| `protected/modules/OphCoDocument/controllers/DefaultController.php::addPDFToOutput()` and `convertPDF()` | Before importing pages into an assembled document, PDFs above version 1.4 are passed directly to `gs` with the `pdfwrite` device and PDF 1.4 compatibility. |
| `protected/modules/OphCoDocument/components/OphCoDocument_API.php::convertPDF()` | Similar conversion when fetching document attachments for other document/correspondence workflows. |
| `protected/controllers/BaseEventTypeController.php::createPdfPreviewImages()` | Uses Imagick to read PDFs at 300 DPI and generate event preview images. A configured ImageMagick PDF delegate can invoke Ghostscript. |
| `protected/models/ProtectedFile.php::generatePdfThumbnail()` | Reads the first PDF page through Imagick for a thumbnail, with the same delegate possibility. |

The direct `exec('gs ...')` calls do not capture stderr or check an exit status before returning the temporary output path. Inherited stderr provides a plausible route for raw, undated Ghostscript messages to reach Apache's error file. This source evidence locates the conversion paths; it does not identify which input PDF or call site generated each of the 211 XREF and 207 incomplete-content messages. The logs lack that correlation.

Saved PDF-conversion PRs already cover argument quoting, exit-code checks and temporary-file cleanup. The remaining work is documented in [Ghostscript improvements beyond the saved PRs](oe-ghostscript-conversion-improvements.md): bounded diagnostics, validation after a zero exit code, subprocess deadlines and repeated direct conversion work. Check the target branch against those saved patches before implementation. [Ghostscript usage and PDF processing](https://ghostscript.readthedocs.io/en/latest/Use.html).

These diagnostics do not establish a SQL failure or an HTTP 504. Conversion work can consume time and memory, but demonstrating a timeout requires request/job correlation and measured durations.

## Transfer volume and rendering cost

The access records account for **53,251,561,300 logged bytes**, about 53.25 decimal GB. The inspected image's format uses `%O`, which includes headers. These are logged response bytes, not database I/O, storage size or a complete network bill.

| URL template | Logged bytes | Requests |
| --- | --- | --- |
| `/api/v2/attachmentData/get` | 11,658,162,577 | 55,875 |
| `/eventImage/viewById` | 7,764,648,026 | 77,334 |
| `/file/view/:id/:value` | 2,850,909,107 | 3,722 |
| `/worklist/view` | 1,512,865,464 | 13,682 |
| `/ProtectedFile/View/:id` | 1,330,674,726 | 1,305 |
| `/OphCoCorrespondence/default/PDFprint/:id` | 1,260,821,838 | 5,190 |
| `/OphCoCorrespondence/default/printForRecipient/:id` | 813,425,768 | 10,049 |
| `/patient/summary/:id` | 571,420,141 | 15,923 |
| `/OphCiExamination/default/step/:id` | 488,841,459 | 7,034 |
| `/OphCiExamination/default/view/:id` | 398,865,022 | 8,640 |

Attachments, event images and PDF/file delivery dominate large application transfers. This supports measuring preview generation, conversion, caching and rendering separately from page SQL. Repeated asset loads by fresh headless browsers can also inflate total HTTP request counts. The logs do not establish whether caching is ineffective, whether output was regenerated on each fetch, or how much CPU any route consumed.

## Coverage, duplicates and repeatability

Two canonical `access.log` family files accounted for every selected request, with zero rejected canonical lines. Status, method, route and hourly totals reconciled, and both containerized GoAccess dashboards agreed with those totals. Every complete record in the alternative access streams matched the canonical records while preserving multiplicity. Some exported files were exact root/nested copies; one alternative stream ended with an incomplete record.

For this image pattern, assume repeated exports and overlapping access-log families are possible, then verify hashes, timestamp coverage and record multiplicity for each collection. Do not concatenate every file or apply global `sort -u`: distinct requests can have identical logged fields. Circular suffixes do not establish chronological order.

For future analysis, mount original logs read-only into a disposable analysis container, inventory and choose the canonical stream, filter timestamps with explicit offsets using an inclusive start and exclusive end, and retain unmodified evidence outside source repositories. Normalize route IDs/query values before publishing results. Report undated conversion diagnostics separately; they cannot inherit an access-log date filter. IP/user-agent visitor metrics are transport signatures, not authenticated users. Raw records, hostnames, addresses, patient IDs and integration payloads do not belong in this knowledge article.
