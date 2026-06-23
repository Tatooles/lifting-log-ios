# App Store Submission Materials Design

## Context

GitHub issue 14 covers Phase 7 of `docs/initial-release-roadmap.md`: prepare LiftingLog's App Store submission pack and review requirements before TestFlight release-candidate hardening.

The app now has Release-specific production configuration from issue 36: production bundle identity, production Clerk publishable key and associated domain, and production Convex deployment URL. Issue 13 added the in-app Privacy & Data surface, but its privacy policy and support links intentionally remain release placeholders that issue 14 must replace.

The current repo does not contain a final app icon asset. Icon creation should be split into a separate ticket, while this issue tracks the icon as a required App Store dependency.

## Goals

- Create a repo-tracked App Store submission pack for LiftingLog v1.
- Add a plain static support site in this repo and deploy it separately to `support.liftinglog.app`.
- Publish live privacy and support URLs before App Store submission.
- Wire the live URLs into the app so Release builds no longer show disabled placeholder rows.
- Document App Store metadata, App Privacy answers, review notes, screenshot plan, production verification, and placeholder audit.
- Verify Release configuration points at production services and App Store-critical links are reachable.
- Track final app icon completion as a release dependency handled by a separate ticket.

## Non-Goals

- Do not create the final app icon in this issue.
- Do not perform full TestFlight release-candidate hardening; issue 15 owns that.
- Do not add analytics, advertising, subscriptions, HealthKit, or broader product scope.
- Do not redesign existing app UI beyond replacing release placeholders.
- Do not move the existing `liftinglog.app` application or couple these pages to it.

## Recommended Approach

Add a small static support site under `SupportSite/` in this repo. Deploy it as its own Vercel project with `SupportSite/` as the project root and `support.liftinglog.app` attached as the production domain.

This keeps release-critical privacy and support copy versioned with the iOS app while isolating deployment from the existing application currently hosted at `liftinglog.app`. The support site should use plain HTML and CSS, with no required JavaScript, no analytics, no cookies, and no backend.

The app should use:

- `https://support.liftinglog.app/`
- `https://support.liftinglog.app/privacy`

## Alternatives Considered

### Separate Support-Site Repo

A separate repo creates a clean hosting boundary, but it increases coordination overhead and makes it easier for privacy policy content to drift from the app's actual Clerk, Convex, export, sync, and account deletion behavior.

### Routes Inside Existing `liftinglog.app`

Adding `/privacy` and `/support` to the existing site gives simple URLs, but it couples App Store-critical pages to an unrelated deployed application. That creates avoidable release risk if the root site changes or redeploys independently.

## Support Site

The `SupportSite/` folder should contain at least:

- `index.html`
- `privacy/index.html`
- shared CSS

The root support page should include:

- App name and short product description.
- Contact or support instructions.
- Basic troubleshooting for sign-in, sync, export, and local data.
- Account deletion guidance pointing users to in-app Settings.
- Link to the privacy policy.

The privacy policy page should include:

- Local workout logging behavior.
- Optional account creation.
- Cloud sync behavior.
- Data export behavior.
- Account deletion and local data deletion behavior.
- Clerk as the authentication provider.
- Convex as the backend sync and storage provider.
- Sign in with Apple and Hide My Email behavior in plain language.
- A statement that the app does not use third-party advertising, cross-app tracking, or analytics unless that changes before release.
- Support contact path.
- Effective date.

The site should be readable, responsive, and production-safe. The goal is trust and clarity, not marketing.

## App Store Submission Pack

Add `docs/release/app-store-submission-pack.md` as the operator-facing source of truth for App Store Connect.

The document should include:

- App metadata: app name, subtitle, description, promotional text, keywords, primary category, age-rating notes, copyright, support URL, privacy URL, and review contact.
- App Privacy worksheet: data collected by the app and providers, whether data is linked to the user, whether tracking is used, and why each data type is needed.
- Review notes: signed-out local logging, optional account creation, email/password, Sign in with Apple, production Convex sync, export, and in-app account deletion.
- Demo access decision: provide account-creation instructions and a disposable reviewer account if practical.
- Screenshot plan: start workout and set logging, active workout, history, exercise library, profile/settings with sync/export/privacy.
- Release checklist: production backend reachable, Release build uses production identity and endpoints, support/privacy URLs live, app icon ticket complete, no placeholders remain, export compliance answer ready, and pricing/availability documented.

Known field constraints, such as 30-character app name and subtitle limits, should be reflected in the metadata drafts.

## App Changes

Update `PrivacySupportConfiguration` so Release uses the live support and privacy URLs. Development and tests may keep a way to exercise placeholder states, but Release must not show disabled `Available before release` rows.

Add or update tests proving the configured release URLs are valid and that test/development placeholder behavior remains intentional.

The app-side implementation should stay narrow. This issue should not change account deletion behavior, sync behavior, or Settings structure except as needed to replace release placeholders with live links.

## Production Verification

Issue 14 should not close unless these checks are complete or explicitly blocked:

- Release configuration uses production bundle ID, app display name, Clerk publishable key and associated domain, and Convex deployment URL.
- Support and privacy URLs are reachable.
- Privacy and support links open from Settings.
- A production disposable account can sign up or sign in.
- A completed workout can sync to production Convex.
- Export remains available.
- In-app account deletion path is present.
- Production data remains isolated from development services.

This is a submission-readiness smoke test, not the full TestFlight hardening matrix. Issue 15 still owns real-world TestFlight validation.

## Placeholder Audit

Before closing issue 14, verify Release has no:

- `Lifting Log Dev` display name.
- Development Clerk key or associated domain.
- Development Convex URL.
- Disabled privacy or support rows.
- `Available before release` link detail text.
- Visible development badge.
- Placeholder App Store metadata.
- Missing app icon dependency ticket.

## Error Handling And Blockers

If the support site cannot be deployed or the URLs are not reachable, issue 14 is blocked.

If production Clerk or Convex verification fails, issue 14 should document the blocker and not proceed to App Store submission.

If the app icon ticket is not complete, issue 14 can finish its own implementation but the submission checklist must remain incomplete until the icon dependency is resolved.

## Tests

Unit tests should cover:

- Release privacy and support URLs are present and parse as HTTPS URLs.
- Development or test configurations can still represent unavailable placeholder links where needed.
- App environment configuration continues to select production values for Release.

Manual verification should cover:

- Static support site opens at `https://support.liftinglog.app/`.
- Privacy policy opens at `https://support.liftinglog.app/privacy`.
- Settings opens both links in a Release or TestFlight-style build.
- Disposable production account sign-up or sign-in works.
- Completed workout syncs to production Convex.
- Export still works before destructive deletion.
- Account deletion remains discoverable in Settings.

The written App Store pack should be reviewed before submission to ensure it matches the final shipped app behavior.
