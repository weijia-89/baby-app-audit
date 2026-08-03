# Test Results Template

**Test Run ID:** `RUN_ID`  
**Date:** YYYY-MM-DD  
**Harness Version:** 3.1.0  
**Tested by:** NAME  
**Device:** MODEL  
**Android Version:** API_LEVEL  

---

## Executive Summary

| App | Verdict | Confidence | Evidence |
| --- | --- | --- | --- |
| Nurture Lock | TBD | 0% | Pending test execution |
| Nubo | TBD | 0% | Pending test execution |
| Pebbi | TBD | 0% | Pending test execution |
| Baby Buddy | TBD | 0% | Pending test execution |

---

## Detailed Results

### Nurture Lock

**Package:** `com.angry.shark.studio.nurturelock`  
**Type:** Native Android  
**Claim:** "100% offline"

#### Offline Test (Part 2)

* **Outbound requests:** TBD
* **Destinations:** TBD
* **Flow file:** `artifacts/captures/nurturelock-offline-flows.json`

#### Static Scan (Part 3)

* **Trackers found:** TBD
* **Permissions:** TBD
* **Exodus report:** `artifacts/reports/nurturelock-exodus.json`

#### Dynamic Capture (Part 4)

* **Destinations:** TBD
* **Payloads:** TBD
* **Pinning bypass required:** TBD
* **Flow file:** `artifacts/captures/nurturelock-dynamic-flows.json`

#### Verdict

TBD

---

### Nubo

**Package:** TBD  
**Type:** Native Android  
**Claim:** "Local-first"

#### Offline Test (Part 2)

* **Outbound requests:** TBD
* **Destinations:** TBD
* **Flow file:** `artifacts/captures/nubo-offline-flows.json`

#### Static Scan (Part 3)

* **Trackers found:** TBD
* **Permissions:** TBD
* **Exodus report:** `artifacts/reports/nubo-exodus.json`

#### Dynamic Capture (Part 4)

* **Destinations:** TBD
* **Payloads:** TBD
* **Pinning bypass required:** TBD
* **Flow file:** `artifacts/captures/nubo-dynamic-flows.json`

#### Verdict

TBD

---

### Pebbi

**Package:** TBD  
**Type:** Native Android  
**Claim:** Known to share data (positive control)

#### Offline Test (Part 2)

* **Outbound requests:** TBD
* **Destinations:** TBD
* **Flow file:** `artifacts/captures/pebbi-offline-flows.json`

#### Static Scan (Part 3)

* **Trackers found:** TBD
* **Permissions:** TBD
* **Exodus report:** `artifacts/reports/pebbi-exodus.json`

#### Dynamic Capture (Part 4)

* **Destinations:** TBD
* **Payloads:** TBD
* **Pinning bypass required:** TBD
* **Flow file:** `artifacts/captures/pebbi-dynamic-flows.json`

#### Verdict

TBD (Expected: fail — outbound traffic should be detected)

---

### Baby Buddy

**Package:** TBD or web  
**Type:** FOSS / Web  
**Claim:** Open-source, self-hostable

#### Browser Test (Part 5.5 Path A)

* **Browser used:** TBD
* **Outbound requests:** TBD
* **Destinations:** TBD

#### Source Audit (Part 5.5 Path C)

* **Repository:** `https://github.com/babybuddy/babybuddy`
* **Commit hash:** TBD
* **Network endpoints in code:** TBD
* **Tracker libraries:** TBD
* **Sends by default:** TBD

#### Verdict

TBD

---

## Compliance

* [ ] DPIA completed (if required)
* [ ] Consent obtained from data subject
* [ ] Purpose documented
* [ ] Data retention policy: 90 days maximum
* [ ] Artifacts securely stored

---

## Artifacts

| File | Description | Size |
| --- | --- | --- |
| `artifacts/apks/*.apk` | Pulled APK files | TBD |
| `artifacts/captures/*-flows.json` | mitmproxy flow exports | TBD |
| `artifacts/reports/*-exodus.json` | Exodus static scan reports | TBD |
| `artifacts/reports/jadx-out/` | Decompiled source | TBD |
| `artifacts/logs/audit.log` | Audit trail | TBD |
| `artifacts/logs/audit.chain` | Hash chain for tamper detection | TBD |

---

## Methodology

See `TESTING_METHODOLOGY_SIMPLE_ENGLISH.md` for a full explanation of the testing process.
