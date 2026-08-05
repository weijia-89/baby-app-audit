# Prompt 03  -  Related Studies and Prior Art

> **Roadmap task:** Team Delta Sprint 1  -  Research Prompts
> **Output:** `results/research/03-gaps.json`
> **Feeds into:** `APK_PRIVACY_TEST_HARNESS.md` and `CANON-SUMMARY.md`

---

## Objective

Identify all prior art related to baby app privacy, tracking, and data sharing. Map what has been done, what has not, and what gaps exist.

## Constraints

* Include every study mentioned in the S4.2 canon.
* Do not claim "no prior art exists" for any topic.
* Do not claim "first to do X" for any method or finding.
* Cite the exact paper, report, or dataset for every claim.
* Distinguish between "method invention" and "method application." This project applies existing methods, it does not invent them.

## Output format

Return JSON only. No markdown, no prose outside the JSON block.

```json
{
  "$schema": "prompt-output/1.0",
  "prompt_id": "03-gaps",
  "date": "YYYY-MM-DD",
  "studies": [
    {
      "title": "Study Title",
      "authors": "Author et al.",
      "year": 2024,
      "venue": "Conference or Journal",
      "url": "https://doi.org/...",
      "topic": "baby_app_privacy|pregnancy_app_tracking|iot_security|coppa_compliance",
      "method": "static_analysis|network_capture|policy_analysis|user_study",
      "key_finding": "One sentence summary.",
      "confidence": 85,
      "confidence_reason": "Peer-reviewed publication."
    }
  ],
  "gaps": [
    {
      "description": "What is missing.",
      "severity": "high|medium|low",
      "recommendation": "What to add to the harness.",
      "feeds_into": "APK_PRIVACY_TEST_HARNESS.md Part X"
    }
  ]
}
```

## Confidence rubric

| Source type | Max confidence | Example |
| --- | --- | --- |
| Peer-reviewed publication | 95 | ACM CCS, IEEE S&P, USENIX Security |
| Industry report with data | 80 | FTC complaint, ICO audit |
| Preprint or white paper | 60 | arXiv, company blog |
| News article | 40 | Journalist report |
| Unverified claim | 20 | Social media, forum |

Use "unverified" if you cannot verify the claim. Do not hedge with "might" or "could."

## Prior art check

Before listing a study, check:
1. Is it already in `CANON-SUMMARY.md`?
2. Is it already in `results/research/03-gaps.json` from a prior run?
3. If yes, update the entry rather than duplicate it.

## Cross-prompt dedup

Check Prompt 02 output (`results/research/02-rubric.json`) for scoring dimensions already proposed. Do not duplicate gap recommendations that overlap with rubric dimensions.

## Source of truth

S4.2 canon: The five-lane integration (static analysis, network capture, policy comparison, dark-pattern inspection, compliance mapping) is application, not invention. Confidence 80.

## How results feed back

I update `CANON-SUMMARY.md` with new studies and gap findings. I add recommended harness additions to `APK_PRIVACY_TEST_HARNESS.md`. Each gap gets a priority label (P0-P3) based on severity and effort.
