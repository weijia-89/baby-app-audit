# Prompt 01  -  Find Additional Tracking Apps

> **Roadmap task:** Team Gamma Sprint 1  -  New Apps & Expansion
> **Output:** `results/research/01-apps.json`
> **Feeds into:** `localonly/candidates.md`

---

## Objective

Find baby tracking, pregnancy, fertility, and parenting apps that share sensitive data with third parties. Build on the 16+ apps already identified in `localonly/candidates.md`.

## Baseline

The current candidate list includes:

* Tier 1: BabyTrack, Amila, Wachanga
* Tier 2: NighP, Milli, Baby Connect, SNUGL
* Tier 3: Sprout Baby, Glow Baby, Huckleberry, Tinyhood, Kinedu, Pregnancy+, What to Expect, BabyCenter
* Wearable/IoT: Owlet Sock, Owlet Cam, Nanit, Miku, Snuza
* Out of scope: riafy

## Constraints

* Focus on apps with >10,000 downloads or high privacy risk.
* Exclude apps removed from official app stores.
* Distinguish baby-milestone trackers from pregnancy trackers  -  they collect different data types.
* Distinguish wearable/IoT companion apps from pure mobile apps  -  they have different test paths.
* Do not claim "first to find this app" or "no prior research exists."

## Output format

Return JSON only. No markdown, no prose outside the JSON block.

```json
{
  "$schema": "prompt-output/1.0",
  "prompt_id": "01-apps",
  "date": "YYYY-MM-DD",
  "apps": [
    {
      "name": "App Name",
      "platform": "Android|iOS|both",
      "package_name": "com.example.app",
      "category": "baby_tracker|pregnancy|fertility|parenting|wearable_iot",
      "source": "Play Store|App Store|operator_suggestion|news_article",
      "source_url": "https://...",
      "download_estimate": "10000-50000",
      "privacy_posture": "claims_offline|claims_local_first|admits_cloud|unknown",
      "why_interesting": "One sentence.",
      "confidence": 85,
      "confidence_reason": "Primary source: Play Store listing verified on 2026-08-04."
    }
  ]
}
```

## Confidence rubric

| Source type | Max confidence | Example |
| --- | --- | --- |
| Primary source (direct observation, official listing) | 95 | Play Store page, app website |
| Secondary source (news article, blog post) | 70 | TechCrunch, parent blog |
| Single study or report | 70 | Academic paper, NGO report |
| Aggregator or database | 60 | App Annie, Sensor Tower |
| Rumor or unverified claim | 30 | Forum post, social media |

Use "unverified" if you cannot verify the claim. Do not hedge with "might" or "could."

## Prior art check

Before adding an app, check:
1. Is it already in `localonly/candidates.md`?
2. Has it been mentioned in the S4.2 canon or prior research?
3. If yes, cite the prior source and do not duplicate it.

## Cross-prompt dedup

Check Prompt 03 output (`results/research/03-gaps.json`) for apps already identified in gap analysis. Do not duplicate.

## Source of truth

S4.2 canon: Confirmed data transmission is the standard of proof. Tracker library presence is capability only, not proof.

## How results feed back

I append new apps to `localonly/candidates.md`. Each app gets a tier assignment based on user-base size and privacy risk. Apps with high confidence scores go to Tier 1 or 2. Apps with low confidence or unverified claims go to Tier 3 or out of scope.
