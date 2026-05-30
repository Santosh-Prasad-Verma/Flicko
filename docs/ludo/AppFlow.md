# Ludo - App Flow

**Last updated:** 2026-05-29

## 1. Top-level navigation

```
                   /gaming (hub)
                       |
                  tap Ludo card
                       v
                    /ludo  (LudoHomeScreen)
        +--------+----+----+----------+
        v        v         v          v
     PLAY     VS CPU   PASS&PLAY   INVITE
     ONLINE                        FRIENDS
        |        |         |          |
        v        v         v          v
     bottom-   seat      seat       generate
     sheet:    picker    picker     /ludo/play
     1v1/2v2/  (1-3      (2-4       ?gameId=X,
     4P FFA    bots)     humans)    copy link
        |        |         |          |
        v        v         v          v
     /ludo/   /ludo/    /ludo/     waiting
     match-   play      play       room
     making              <-- (route to board)
        |
     8s elapse OR
     match found
        |
        v
     /ludo/play?mode=onlineRandom
        |
        v
     LudoBoardScreen
```

## 2. Detailed flows

### 2.1 Cold start to game

1. App boots, MainShell shows /home.
2. User taps Gaming tab > tap Ludo card on `/gaming`.
3. Router pushes `/ludo` -> `LudoHomeScreen`. `home.mp3` starts looping.
4. User picks a mode card. Each card opens a bottom sheet (online/CPU/local) or directly pushes (friends).
5. Sheet -> `_start(mode, seats)` builds a `List<SeatConfig>` and pushes `/ludo/play` with `extra: seats`.
6. `LudoBoardScreen.initState`:
   - resets `LudoNotifier` with the seats and mode
   - registers `onBotTurn = brain.takeTurn`
   - plays `game_start.mp3`
   - shows blinking START image for 2.5 s

### 2.2 Turn cycle

```
chancePlayer: P
   |
   v
seat[P-1].kind == bot ?
   yes -> brain.takeTurn(P)         (ai branch)
   no  -> wait for tap on dice      (ui branch)

ui branch:
   tap dice -> notifier.rollDice()
              -> dice_roll.mp3
              -> 800ms anim
              -> updateDiceNumber
              -> classify:
                 (a) all in pocket && rolled 6 -> enablePileSelection
                 (b) all in pocket && other     -> auto-pass
                 (c) rolled 6                   -> enable both pile + cell
                 (d) any moveable               -> enableCellSelection
                 (e) no moveable                -> auto-pass

selection -> tap pocket: releaseFromPocket -> piece on starting cell
          -> tap cell:    handleForward    -> per-cell loop:
                                              pile_move.mp3, 200ms,
                                              advance, possibly turn into
                                              home stretch, possibly wrap.

after move:
   if landed on safe/star -> safe_spot.mp3
   if collided with enemy -> capture sequence (collide.mp3)
   if travelCount == 57   -> home_win.mp3
                             if all four pieces home -> announceWinner(P)
                                                    -> cheer.mp3
                             else -> fireworks=true, same player, unfreeze
   if rolled 6            -> chancePlayer stays P
   else                    -> chancePlayer = next seat
```

### 2.3 Win flow

1. `announceWinner` flips `state.winner` from null to P.
2. `LudoBoardScreen.ref.listen` catches the transition -> calls `_onWinAnnounced` -> `submitLudoScore(...)` (best-effort).
3. Same listener pushes `WinnerModal`:
   - shows trophy Lottie, fireworks Lottie, congrats text
   - **NEW GAME** -> `notifier.resetGame()` -> board re-uses same screen.
   - **EXIT** -> pop modal then pop board.

### 2.4 Online matchmaking (current stub)

1. User taps PLAY ONLINE > one of the sub-options.
2. Push `/ludo/matchmaking?players=N&team=bool`.
3. Screen starts a 1 Hz timer; at 8 s simulates "match found".
4. Builds seats: seat 0 = human (you), rest = bots placeholder.
5. `pushReplacement` to `/ludo/play?mode=onlineRandom` with seats.
6. **Future:** swap the timer for `POST /api/v1/gaming/matchmaking/queue` + Centrifugo subscription on `matchmaking/{user}`.

### 2.5 Friends invite (planned)

1. User taps INVITE FRIENDS.
2. Generate `gameId` = random 8-char id.
3. Build link `flicko://ludo/play?gameId=<id>` and pass to `share_plus`.
4. Push board with mode=onlineFriends, seat 0 = human, others = remote (placeholder names "Friend 1..3").
5. Incoming invitee opens link -> deep-link handler routes to `/ludo/play?gameId=<id>` -> connects, fills next remote seat with their identity.
6. Once 2+ players seated, host taps START to begin play; remaining seats auto-fill with bots after a 30 s grace period.

### 2.6 Leaderboard

1. From `/ludo`, tap leaderboard icon (top-right).
2. Push `/ludo/leaderboard` -> `ludoLeaderboardProvider` calls `GET /api/v1/gaming/ludo/leaderboard`.
3. On error: show retry, fall back to a 5-row mock list so the screen never goes blank.

## 3. Background behaviours

- **App backgrounded mid-game:** state lives in the Notifier. When app returns to foreground, the screen rebuilds from state. (Online sync recovery is L-1 in TRD - not yet implemented.)
- **Music:** `home.mp3` plays only on `LudoHomeScreen`. `LudoSoundService.stopBgm()` runs in dispose so it doesn't bleed onto the board.
- **Mute:** `setMuted(true)` halts bgm and silences all SFX. (UI toggle TBD.)

## 4. Error states

| Where | What happens | UX |
|---|---|---|
| Leaderboard fetch fails | Provider returns mock list | Banner-free fallback |
| Score POST fails | Ignored | Silent (game already won locally) |
| Asset missing | `errorBuilder` shows fallback widget | Coloured circle/text instead of PNG/Lottie |
| Audio init fails (no platform binding in tests) | Lazy ctor + try/catch in `play` | Logs only |
