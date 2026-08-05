# Prompt 04  -  Device Identity and Regulatory Mapping

> **Roadmap task:** Team Beta Sprint 2  -  Harness Restructure
> **Output:** `results/research/04-identities.json`
> **Feeds into:** `APK_PRIVACY_TEST_HARNESS.md` Part 8.5 and `localonly/candidates.md`

---

## Objective

Map wearable and IoT devices to their regulatory identities. Find Basic UDI-DI numbers, model numbers, and applicable regimes (MDR vs RED) for each device in the candidate list.

## Baseline

Known devices:

| Device | Model | Regime | Basic UDI-DI |
| --- | --- | --- | --- |
| Owlet Sock 3 | Owlet-Sock-3 | MDR | Not found |
| Owlet Cam 2 | Owlet-Cam-2 | RED | Not required |
| Pebbi Cam 2 | Pebbi-Cam-2 | RED | Not required |

## Constraints

* Do not invent UDI-DI numbers. If not found in EUDAMED, record "not found."
* Distinguish MDR (medical device) from RED (radio equipment). A device can be both if it has radio and claims health monitoring.
* Record the evidence source for every regime assignment.
* Do not claim "first to map these devices."

## Output format

Return JSON only. No markdown, no prose outside the JSON block.

```json
{
  "$schema": "prompt-output/1.0",
  "prompt_id": "04-identities",
  "date": "YYYY-MM-DD",
  "devices": [
    {
      "name": "Owlet Sock 3",
      "manufacturer": "Owlet Care",
      "model_number": "Owlet-Sock-3",
      "basic_udi_di": "",
      "udi_di_status": "not_found|found|not_required",
      "regime": "MDR",
      "regime_evidence": "Claims SpO2 monitoring. SpO2 is a medical measurement under MDR.",
      "regime_source": "https://ec.europa.eu/tools/eudamed...",
      "eudamed_query_date": "2026-08-04",
      "confidence": 75,
      "confidence_reason": "Manufacturer website claims SpO2. EUDAMED search returned no result for this model."
    }
  ]
}
```

## Confidence rubric

| Source type | Max confidence | Example |
| --- | --- | --- |
| EUDAMED database entry | 95 | Official EU device registry |
| Manufacturer specification sheet | 90 | PDF from manufacturer website |
| FDA 510(k) clearance | 85 | FDA database entry |
| Product packaging or manual | 80 | Physical label scan |
| Retailer listing | 50 | Amazon, Best Buy product page |
| Unverified claim | 20 | Forum post, social media |

Use "unverified" if you cannot verify the claim. Do not hedge with "might" or "could."

## Prior art check

Before mapping a device, check:
1. Is it already in `localonly/candidates.md` wearable/IoT section?
2. Is it already in `results/research/04-identities.json` from a prior run?
3. If yes, update the entry rather than duplicate it.

## Cross-prompt dedup

Check Prompt 01 output (`results/research/01-apps.json`) for wearable/IoT devices already identified. Do not duplicate.

## Source of truth

S4.2 canon: MDR vs RED regimes require different test paths. A failure in one regime does not block another.

## How results feed back

I update `localonly/candidates.md` with verified device identities. I update `APK_PRIVACY_TEST_HARNESS.md` Part 8.5 with confirmed UDI-DI numbers and regime assignments. Devices with confirmed MDR status get stronger encryption and access control checks.
