# UIUX - Creator Subscriptions

## Screen 1 - Tier Browser (subscriber discovery)
```
+-----------------------------------------------+
| <-  Subscribe to @santosh                     |
+-----------------------------------------------+
|  [creator hero photo]                         |
|  @santosh - product designer + game dev       |
|  3.2k subscribers - $14k MRR (public)         |
+-----------------------------------------------+
|  TIERS                                        |
| +-------------------------------------------+ |
| | BRONZE                              $4/mo | |
| | * Subscriber-only channel               * | |
| | * Bronze badge                          * | |
| | * Monthly newsletter                    * | |
| |        [Subscribe]                        | |
| +-------------------------------------------+ |
| +-------------------------------------------+ |
| | SILVER                  $9/mo most popular | |
| | * Everything in Bronze                    | |
| | * Source files, Figma exports             | |
| | * Vote on next stream topic               | |
| |        [Subscribe]                        | |
| +-------------------------------------------+ |
| +-------------------------------------------+ |
| | GOLD                              $19/mo  | |
| | * Everything in Silver                    | |
| | * Monthly 1:1 30 min                       | |
| | * DM access                                | |
| |        [Subscribe]                        | |
| +-------------------------------------------+ |
+-----------------------------------------------+
| Yearly toggle: save 17% [ off | ON ]          |
+-----------------------------------------------+
```
Copy: "most popular" auto-set to median tier. Empty creator state: "@creator has no tiers yet."
Motion: tier card scales 1.02 on hover/press, ribbon "Most popular" rotates 6deg static.
A11y: pricing read as "nine dollars per month", toggle has explicit label "Yearly billing".

## Screen 2 - Checkout / Trial Sheet
```
+-----------------------------------------------+
|  Subscribe to Silver - @santosh         [x]   |
+-----------------------------------------------+
|  $9 / month                                   |
|  7-day free trial included                    |
|  Then $9 every month, cancel anytime          |
|                                                |
|  Promo code [_________] [apply]               |
+-----------------------------------------------+
|  Payment                                      |
|   o Apple Pay                                 |
|   o Card **** 4242                            |
|   o Add new card                              |
+-----------------------------------------------+
|     [Start free trial]                        |
|  By tapping you agree to ToS and Refunds      |
+-----------------------------------------------+
```
Copy: trial copy hidden if no trial. Promo error inline "Code expired" or "Already used".
Motion: success sheet slides into a confetti checkmark, 600 ms total.
A11y: focus trap, ESC dismisses, screen reader announces subscription terms.

## Screen 3 - Manage Subscription (subscriber)
```
+-----------------------------------------------+
| <- My subscription to @santosh                |
+-----------------------------------------------+
|  SILVER tier                                  |
|  Renews on Jun 14 - $9 charged to **** 4242   |
|  [Change tier]   [Pause]   [Cancel]           |
+-----------------------------------------------+
|  Trial ends Jun 7 - first charge then         |
+-----------------------------------------------+
|  History                                      |
|  May 14  $9 paid       [receipt]              |
|  Apr 14  $9 paid       [receipt]              |
+-----------------------------------------------+
```
Copy: cancel CTA opens confirmation "You'll keep access until Jun 14." With "Wait, change tier instead" deflection.
Motion: history list staggers in 40ms each.
A11y: receipts open in WebView with retain focus return.

## Screen 4 - Creator Tier Composer
```
+-----------------------------------------------+
| <- New tier                                   |
+-----------------------------------------------+
|  Name           [____________]                |
|  Tagline        [____________]                |
|  Monthly price  [$ 9 ]                        |
|  Yearly price   [auto $90 (17% off)] [edit]   |
|  Free trial     [7 days v]                    |
|                                                |
|  Perks                                        |
|   [+ Add channel access]                      |
|   [+ Add role badge]                          |
|   [+ Add custom perk text]                    |
|                                                |
|  Limit subscribers [ off ]   [unlimited]      |
+-----------------------------------------------+
|        [Save draft]    [Publish]              |
+-----------------------------------------------+
```
Copy: "Publish" disabled until at least one perk + price set. Helper text under price "Stripe + platform fees deducted, you net ~$8.04 per $9".
Motion: perk add slides down with 200ms ease.
A11y: numeric inputs have aria-describedby with fee disclosure.
