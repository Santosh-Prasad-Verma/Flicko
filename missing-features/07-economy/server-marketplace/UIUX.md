# UIUX - Server Marketplace

## Screen 1 - Marketplace Home (member view)
```
+-----------------------------------------------+
| <- Acme Server Shop          [search] [cart3] |
+-----------------------------------------------+
| [HERO carousel: featured drops, auto 5s]      |
|  "Limited: VIP Role Pack - 2h 14m left"       |
+-----------------------------------------------+
| Categories  [Roles][Cosmetic][Merch][Services]|
+-----------------------------------------------+
| GRID 2-col                                    |
| +-------------+    +-------------+            |
| | thumb 1:1   |    | thumb 1:1   |            |
| | VIP Pack    |    | Stage Slot  |            |
| | $9.99   *4.8|    | Auction $42 |            |
| +-------------+    +-------------+            |
| ...                                           |
+-----------------------------------------------+
| [+ Sell] (only if can_create_listing)         |
+-----------------------------------------------+
```
Copy: H1 "Acme Shop". Empty state: "No listings yet. Be the first to drop something." CTA "Create listing".
Motion: cards rise 4dp on press with 120ms spring, hero auto-rotates with 280ms cross-fade.
A11y: every price spoken as "nine dollars and ninety-nine cents", category chips have role=tab, focus order top-to-bottom left-to-right.

## Screen 2 - Listing Detail
```
+-----------------------------------------------+
| <-                              [share][...]  |
+-----------------------------------------------+
|  [media gallery, swipeable, dot indicator]    |
+-----------------------------------------------+
|  VIP Role Pack                                |
|  by @santosh  *4.8 (213)                      |
|  $9.99            [Buy now]                   |
+-----------------------------------------------+
|  What you get                                 |
|   - VIP role for 30 days                      |
|   - 2 cosmetic badges                         |
|   - Priority queue in voice channels          |
+-----------------------------------------------+
|  Refund policy: 72h digital                   |
|  Sold by Acme Server, powered by Flicko Pay   |
+-----------------------------------------------+
```
Copy: Buy CTA changes to "Place bid" for auction listings, "Sold out" disabled when stock=0.
Motion: Buy button has subtle 1.5s breathing pulse only when within 1 hour of auction end.
A11y: media has alt-text per asset, gallery announces "image 2 of 4".

## Screen 3 - Checkout Sheet
```
+-----------------------------------------------+
|  Confirm purchase                       [x]   |
+-----------------------------------------------+
|  VIP Role Pack                                |
|  Subtotal           $9.99                     |
|  Tax (auto)         $0.82                     |
|  Total              $10.81                    |
+-----------------------------------------------+
|  Pay with                                     |
|   o Apple Pay       (default if available)    |
|   o **** 4242                                 |
|   o Add new card                              |
+-----------------------------------------------+
|        [Pay $10.81]                           |
|  Secure checkout via Stripe                   |
+-----------------------------------------------+
```
Copy: error states inline e.g. "Card declined - try another method". Loading: button replaced by 3-dot indeterminate.
Motion: sheet slides up 320ms ease-out, on success haptic medium + check animation 500ms.
A11y: focus locked inside sheet, ESC dismisses, dynamic type respected up to 200%.

## Screen 4 - Seller Listing Composer
```
+-----------------------------------------------+
| <- New listing                       [Save]   |
+-----------------------------------------------+
|  Title           [_____________________]      |
|  Description     [_____________________]      |
|                  [_____________________]      |
|  Media           [+ add up to 6]              |
|  Price type      ( ) Fixed  ( ) Auction       |
|  Price           [$ 9.99 ]                    |
|  Stock           [unlimited v]                |
|  Refund window   [72 h v]                     |
|  Category        [Role v]                     |
|  Server cut      18% (set by owner, locked)   |
+-----------------------------------------------+
|  [Save draft]      [Publish]                  |
+-----------------------------------------------+
```
Copy: Publish disabled until KYC complete, helper "Connect payouts to publish" with deeplink.
Motion: validation errors shake field 6dp x2, 80ms each.
A11y: form fields labeled, currency input filters non-numeric, screen reader announces validation.
