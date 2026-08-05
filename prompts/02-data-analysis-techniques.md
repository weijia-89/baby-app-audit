# Prompt 02  -  Data Analysis Techniques and Scoring Rubric

> **Roadmap task:** Team Alpha Sprint 3  -  Live Data Collection Pipeline
> **Output:** `results/research/02-rubric.json`
> **Feeds into:** `APK_PRIVACY_TEST_HARNESS.md` Part 8.5 and `results/schema.json`

---

## Objective

Build a scoring rubric for per-product privacy risk. The rubric covers retention schedule scoring, security posture scoring, and regulatory regime scoring.

## Constraints

* Each score must map to a specific evidence type.
* Do not invent scoring methods without citing a source.
* Distinguish between "policy claims" (what the privacy policy says) and "observed behavior" (what network capture shows).
* Where policy and capture disagree, trust capture and note the discrepancy.
* Do not claim "this is the first scoring rubric for baby apps."

## Output format

Return JSON only. No markdown, no prose outside the JSON block.

```json
{
  "$schema": "prompt-output/1.0",
  "prompt_id": "02-rubric",
  "date": "YYYY-MM-DD",
  "scoring_dimensions": [
    {
      "name": "retention_schedule",
      "description": "How long the app or service keeps data.",
      "score_range": [0, 100],
      "tiers": [
        {"score": 90, "label": "user_controlled", "criteria": "User can delete data at any time. No minimum retention."},
        {"score": 70, "label": "short_term", "criteria": "Retention <= 30 days with clear deletion policy."},
        {"score": 40, "label": "indefinite", "criteria": "No deletion policy or retention claimed as indefinite."},
        {"score": 0, "label": "unknown", "criteria": "Retention policy not stated or not found."}
      ],
      "evidence_type": "policy_text|network_capture|manual_audit",
      "source": "https://...",
      "confidence": 85
    }
  ]
}
```

## Required dimensions

1. **retention_schedule**  -  How long data is kept.
2. **security_posture**  -  EOL date, CVE count, patch frequency.
3. **regulatory_compliance**  -  MDR, RED, COPPA, GDPR alignment.
4. **data_minimization**  -  What data is collected vs what is needed.
5. **transparency**  -  How clear the privacy policy is.

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

Before proposing a scoring dimension, check:
1. Does the S4.2 canon already define a similar dimension?
2. Has a prior study (e.g., Ren 2024, Yu 2023) used a similar rubric?
3. If yes, cite it and adapt rather than invent.

## Cross-prompt dedup

Check Prompt 03 output (`results/research/03-gaps.json`) for scoring dimensions already proposed in gap analysis. Do not duplicate.

## Source of truth

S4.2 canon: Confirmed data transmission is the standard of proof. All counts from network capture are lower bounds.

## How results feed back

I add the scoring dimensions to `APK_PRIVACY_TEST_HARNESS.md` Part 8.5. I update `results/schema.json` to include score fields. Each tested app gets a score card in its result file.
