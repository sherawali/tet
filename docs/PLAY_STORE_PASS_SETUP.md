# Pro Pass - Play Console setup (one time)

The app reads the price from the Play Store, so the prices live in the Play
Console, not in the code.  Change a price there and the app shows the new one
after the next sync - no new app release needed.

## The products to create

| Product id | Name | Price | Type | Base plan |
|---|---|---|---|---|
| `tet_all_access_1y` | Full Access Pro Pass (UTET + CTET) | ₹2,499 | Subscription | 12 months, ₹2,499/yr |
| `tet_utet_pass_1y` | UTET Pro Pass (Paper-1 + Paper-2) | ₹1,499 | Subscription | 12 months, ₹1,499/yr |
| `tet_ctet_pass_1y` | CTET Pro Pass (Paper-1 + Paper-2) | ₹1,499 | Subscription | 12 months, ₹1,499/yr |
| `tet_single_paper_399` | Ek Pariksha - one paper (₹999) | ₹999 | Subscription | 12 months, ₹999/yr |

**The paywall shows two packs.** Full Access is the first card. The second
card ("Ek Pariksha Pro Pass") uses the exam selector and the paper chips:
Paper-1 or Paper-2 buys `tet_single_paper_399` (₹999/yr, one direction of
the chosen exam - the id keeps its old name because Play Console ids cannot
be renamed), the "Dono" chip buys `tet_utet_pass_1y` or `tet_ctet_pass_1y`
(₹1,499/yr, both papers). Every choice runs for 365 days.

**No lifetime product.** A 365 day pass can be re-priced every season, a
lifetime pass locks the price forever.

The app also keeps the old ids working, so nothing breaks while the new
products are being created:
`tet_master_all_access_599`, `tet_single_paper_299`, `tet_2026_all_access_pass_99`.

## Why subscriptions and not one time purchases

- Google keeps **15 %** of a subscription and 15 % of the first ₹1 crore of
  one time purchases - and 30 % after that. A subscription is always 15 %.
- A subscription renews by itself, so the second year needs no new customer.
- At ₹2,499 the net per buyer is **₹2,124**; at ₹1,499 it is **₹1,274**.
  The full access pass is the one that clears ₹1,500 per user, so it is the
  pack the paywall pushes (featured, in the middle, with "₹208 a month" and
  the struck through ₹4,999 anchor).

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
