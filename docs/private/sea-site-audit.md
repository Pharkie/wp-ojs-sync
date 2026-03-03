# SEA Live Site Audit

Point-in-time snapshot of SEA's WordPress configuration, captured 2026-02-19 via Playwright. Used for planning the initial deployment — not part of the generic plugin documentation.

## Membership roles

**Membership roles** (all grant journal access):

| Role slug | Display name | Members |
|---|---|---|
| `um_custom_role_4` | SEA student member (with listing) | 39 |
| `um_custom_role_3` | SEA student member (no listing) | 202 |
| `um_custom_role_6` | SEA international member (with listing) | 32 |
| `um_custom_role_5` | SEA international member (no listing) | 58 |
| `um_custom_role_2` | SEA UK member (with listing) | 129 |
| `um_custom_role_1` | SEA UK member (no listing) | 234 |

**Manual/admin roles** (Exco/life members — set by admin, not via WCS checkout):

| Role slug | Display name | Members |
|---|---|---|
| `um_custom_role_9` | Manually set student listing | 0 |
| `um_custom_role_8` | Manually set international listing | 0 |
| `um_custom_role_7` | Manually set UK listing | 1 |

**Total active members by role: 695.** Active WCS subscriptions: 698. The small discrepancy is expected (some subscriptions may be in transition or belong to users with non-standard role states).

**Standard WP/WooCommerce/other plugin roles** (not relevant to sync):
- `subscriber` (181), `customer` (629), `editor`, `contributor`, `shop_manager`
- `wpseo_manager`, `wpseo_editor`
- `give_worker`, `give_manager`, `give_donor`, `give_accountant`

The "with listing" / "no listing" distinction is a member directory feature (UM), not relevant to journal access. All nine membership roles (six standard + three manual) grant OJS access.

## WooCommerce subscription products

| WC Product ID | Product name | Price |
|---|---|---|
| 1892 | UK Membership (no directory listing) | £50/yr |
| 1924 | International Membership (no directory listing) | £60/yr |
| 1927 | Student Membership (no directory listing) | £35/yr |
| 23040 | Student Membership (with directory listing) | £35/yr |
| 23041 | International Membership (with directory listing) | £60/yr |
| 23042 | UK Membership (with directory listing) | £50/yr |

698 active subscriptions at time of capture.

All six products grant identical journal access, so they can all map to a single OJS subscription type — or to separate types to track tier breakdowns in OJS admin.
