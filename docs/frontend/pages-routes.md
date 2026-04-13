# Pages & Routes
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Routing: Expo Router (file-based)

### Tab Navigation (`app/(tabs)/`)
| File | Route | Screen |
|------|-------|--------|
| `index.tsx` | `/` | Server list (home) |
| `friends.tsx` | `/friends` | Friends list |
| `dms.tsx` | `/dms` | Direct messages |
| `notifications.tsx` | `/notifications` | Notification center |
| `profile.tsx` | `/profile` | User profile |

### Auth Screens (`app/(auth)/`)
| File | Route | Screen |
|------|-------|--------|
| `login.tsx` | `/login` | Login screen (15 KB) |
| `register.tsx` | `/register` | Registration screen (22 KB) |

### Feature Screens
| File | Route | Screen |
|------|-------|--------|
| `app/server/` | `/server/*` | Server detail, channels |
| `app/channel/` | `/channel/*` | Channel view, messages |
| `app/dm/` | `/dm/*` | DM conversation |
| `app/settings/` | `/settings/*` | Settings screens |
| `app/voice/` | `/voice/*` | Voice channel |
| `app/profile/` | `/profile/*` | User profiles |
| `app/search.tsx` | `/search` | Search (21 KB) |
| `app/advanced-search.tsx` | `/advanced-search` | Advanced search |
| `app/notifications.tsx` | `/notifications` | Notifications (12 KB) |
| `app/flicko-plus.tsx` | `/flicko-plus` | Subscription page (26 KB) |
| `app/nitro.tsx` | `/nitro` | Redirect to Flicko Plus |
| `app/+not-found.tsx` | `/*` | 404 page |

### Screen Animations
- Auth screens: `fade`
- Tab screens: `fade`
- Settings/Server/DM: `slide_from_right`
- Profile: `slide_from_bottom`
- Search: `fade_from_bottom`
