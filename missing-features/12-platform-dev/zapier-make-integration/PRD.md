# PRD: Zapier and Make Integration

## Problem
Flicko sits next to dozens of SaaS tools that admins already use: Notion, Stripe, GitHub, Calendly, Typeform, HubSpot. Today, integrating Flicko with these tools requires custom code against the Go API. Most server admins are not engineers. Every "send a Flicko DM when a Stripe subscription cancels" use case becomes a feature request to the platform team.

## Goal
Publish a Flicko app on Zapier and Make (formerly Integromat) so admins can wire Flicko events to 6,000+ third-party services without writing code, and route third-party events into Flicko bots and channels.

## Non-Goals
- Building our own automation runtime (we already have the bot builder for that).
- Custom webhooks UI in v1; that ships separately as the visual webhook builder.
- IFTTT in v1 (smaller share, revisit if usage justifies).

## Users
- Server admin: connects Flicko to other tools, owns the Zaps/Scenarios.
- Operations lead: monitors automation health from a dashboard.
- Developers on partner platforms: discover Flicko triggers and actions during their automation builds.

## Triggers (Flicko emits)
- New message in channel (filterable by channel id and text match).
- New member joined.
- Member left.
- Reaction added.
- Role assigned.
- Voice channel joined.
- Form submitted (forms feature).
- Bot run completed.
- Boost received.
- Mention of user or role.

## Actions (Flicko receives)
- Send message to channel.
- Send DM to user.
- Add role to member.
- Remove role.
- Create channel.
- Update channel topic.
- Pin message.
- Create event.
- Post announcement.
- Trigger bot run by name.

## Searches
- Find user by email.
- Find channel by name.
- Find role by name.

## User Stories
- Stripe charge failed → Flicko DM to billing-admins role with a Stripe link.
- Typeform submission → New thread in #feedback with the response.
- New Notion page in "Changelog" db → Announcement in #updates.
- New member joined Flicko → row in Google Sheets, Slack message to team.
- GitHub PR merged → Flicko message in #engineering with PR title.

## Success Metrics
- 1,000 active connections in the first 90 days.
- 25 percent of Pro tier servers connect at least one third-party tool.
- p95 webhook delivery under 5 seconds (Flicko → partner).
- App rating above 4.4 on the Zapier marketplace.

## Pricing Tier
Free servers: 1 active Zap, 100 tasks per month. Pro: 25 active Zaps, 10,000 tasks per month. Enterprise: unlimited.

## Risks
- Webhook spam: a misconfigured Zap could fire thousands of triggers per minute. Mitigated by per-server rate limits and a "loop detection" heuristic that pauses Zaps repeating the same payload more than 50 times in a minute.
- Authentication: OAuth tokens for Flicko cover entire servers. We require per-Zap scope and a clear consent screen showing exactly which servers and which permissions a Zap will use.
- Partner outages: Zapier or Make downtime should not back up our queue indefinitely. Mitigated by 24-hour TTL on outbound deliveries with exponential backoff and a dead-letter sink visible to admins.

## Launch Plan
- Week 1 to 3: trigger and action catalog, OAuth provider, migration 244.
- Week 4 to 5: Zapier app definition, internal app testing.
- Week 6: Make app definition.
- Week 7: marketplace submission to both, beta program.
- Week 8 to 10: GA, marketing push, template gallery.
