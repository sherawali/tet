# Pro Pass - Play Console setup (one time)

The app reads the price from the Play Store, so the prices live in the Play
Console, not in the code.  Change a price there and the app shows the new one
after the next sync - no new app release needed.

## The products to create

| Product id | Name | Price | Type | Base plan |
|---|---|---|---|---|
| `tet_all_access_1y` | All-Open Pass · 1 Year (UTET + CTET) | ₹2,500 | Subscription | 12 months, ₹2,500/yr, prepaid |
| `tet_all_access_6m` | All-Open Pass · 6 Months (UTET + CTET) | ₹1,499 | Subscription | 6 months, ₹1,499, prepaid |

**The paywall shows exactly two packs and both are the same combo** - UTET
AND CTET, every paper of both exams. Only the term differs:

- `tet_all_access_6m` (₹1,499 · 182 days · prepaid) is the *anchor*: ₹250 a
  month.
- `tet_all_access_1y` (₹2,500 · 365 days · prepaid) is the *value pick*,
  default selected. The wall shows the anchor struck through: two 6-month
  passes would cost ₹2,998 - so the yearly pass reads as a ₹498 gift.

Do **not** create `tet_utet_pass_1y`, `tet_ctet_pass_1y` or the old ₹999
one-direction tier (`tet_single_paper_399`) - those products are retired
from sale. An earlier buyer's restored purchase still opens exactly what
was bought. Recommend **prepaid** plans for both products - no silent
auto-charge.

**No lifetime product.** A 365 day pass can be re-priced every season, a
lifetime pass locks the price forever.

The app also keeps the old ids working, so nothing breaks while the new
products are being created:
`tet_master_all_access_599`, `tet_single_paper_299`, `tet_2026_all_access_pass_99`.

## Why subscriptions and not one time purchases

- Google keeps **15 %** of a subscription and 15 % of the first ₹1 crore of
  one time purchases - and 30 % after that. A subscription is always 15 %.
- A subscription renews by itself, so the second year needs no new customer.
- At ₹2,500 the net per yearly buyer is **₹2,125**; at ₹1,499 it is **₹1,274**.
  The yearly pass is the one that clears ₹1,500 per user, so it is the pack
  the paywall pushes (default selected, with "₹208 a month" and the struck
  ₹2,998 two-pass anchor).

## Turning a paper free or paid (no app update)

1. Put the paper id into `bin/remote_access.json`:
   - `free_form_ids` - the paper is free for everyone,
   - `paid_form_ids` - the paper is always paid.
2. Run `python bin/build_github_cdn_vault.py`.
3. Commit and push. The app picks the new manifest and the new bank up on
   the next sync and the paper shows up free or paid as it was set.

The five free flagship papers that every candidate can try without paying:
`utet-p1-fullmock`, `utet-p2-set-b`, `ctet-p1-2026-pyq`,
`ctet-p2-ms-mock-01`, `ctet-p2-sst-mock-01`.
