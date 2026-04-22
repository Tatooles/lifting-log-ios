# Lifting Log Native iOS App Design

Date: 2026-04-21
Platform: iOS 17+
Framework: SwiftUI
Primary device: iPhone
Design source: Claude HTML export and supplied screenshots

## Goal

Build a native SwiftUI app named `Lifting Log` that recreates the supplied workout logging design with high visual fidelity while using clean, extensible native architecture and mock data.

The app should feel like a native iPhone app rather than a wrapped web design. The HTML export is treated strictly as reference material for layout, styling, states, and content structure.

## Scope

The first version includes:

- A native tab-based app shell
- A main workout logging screen
- A history screen with `Workouts` and `Exercises` modes
- A profile tab placeholder
- A native finish-workout confirmation sheet
- Mock data and local in-memory state
- Explicit loading, empty, and error states where appropriate

The first version does not include:

- Persistent storage
- Networking or backend sync
- Authentication
- Exercise library search
- Charts or analytics
- Apple Health integration

## Primary Screens And States

### 1. Workout Log Screen

This is the main surface and corresponds to the screenshots showing the active workout.

Content:

- Sticky top header with elapsed timer, progress bar, and `Finish` button
- Workout title and current date
- A vertically scrolling list of exercise cards
- Each exercise card contains:
  - Collapse/expand affordance
  - Exercise name
  - Completed sets badge
  - Column headers for `LBS`, `REPS`, and `RPE`
  - Set rows with editable fields
  - Completion toggle per set
  - `Add Set` action
  - Exercise notes field
- `Add Exercise` action
- `Workout Notes` section
- Floating glass-style tab bar

States:

- Expanded exercise card
- Collapsed exercise card
- Completed set
- Incomplete set
- New exercise with empty fields
- Exercise notes empty/populated
- Workout notes empty/populated
- Finish sheet presented

### 2. History Screen

The history tab contains a header and segmented control with two modes.

#### Workouts Mode

Content:

- Large `History` title
- Segmented control
- Scrollable list of workout summary cards
- Each card shows:
  - Accent bar
  - Workout name
  - Date
  - Duration
  - Exercise count
  - Set count
  - Chevron

States:

- Populated list
- Empty list
- Loading state
- Error state with retry

#### Exercises Mode

Content:

- Same header and segmented control
- Scrollable grouped list of exercises
- Each row shows:
  - Exercise icon
  - Exercise name
  - Last performed date
  - Count badge
  - Chevron

States:

- Populated list
- Empty list
- Loading state
- Error state with retry

### 3. Profile Screen

No design was supplied for this tab. The initial implementation will provide a visually aligned placeholder screen that uses the same dark theme and component language.

Content:

- Title
- Profile summary placeholder card
- Mock stat cards
- Placeholder settings rows

State:

- Static placeholder state only

### 4. Finish Workout Sheet

Presented from the workout log screen as a native bottom sheet.

Content:

- Drag handle
- Confirmation title and subtitle
- Summary metric cards:
  - Duration
  - Sets done
  - Volume
- Primary `Save Workout` action
- Secondary `Keep Going` action

## Navigation Structure

- Root `TabView` with three tabs:
  - `History`
  - `Add Workout`
  - `Profile`
- Each tab owns its own `NavigationStack`
- The center tab routes to the active workout log screen instead of a separate creation wizard because the provided design uses the workout editor as the primary creation surface
- History rows may push lightweight detail views derived from mock data so navigation remains native and extensible

## Visual System

### Theme

- Dark-first interface
- Charcoal background
- Slightly lighter card surfaces
- Warm red accent used for progress, primary actions, active states, and emphasis
- Soft glow around primary red controls where shown in the design

### Tokens

Centralized tokens will be created for:

- Colors
- Gradients
- Corner radii
- Spacing scale
- Shadows and glow treatments
- Typography roles
- Stroke and border styles

### Typography

- Native iOS typography using SF-based styles
- Large bold titles for top-level headings
- Medium-to-bold weights for card titles and controls
- Secondary copy with reduced contrast
- Numeric UI uses monospaced digits where helpful, especially timer and counters

### Motion

- Tasteful animations only
- Expand/collapse animation for exercise cards
- Progress bar animation when set completion changes
- Sheet presentation using native motion
- Small state transitions for segmented control and tab emphasis

## App Structure

- `LiftingLogApp`
- `AppShell`
- `Features/Workout`
- `Features/History`
- `Features/Profile`
- `Shared/DesignSystem`
- `Shared/Models`
- `Shared/Components`
- `Shared/Services`
- `Shared/Mocks`

## State Model

- SwiftUI-native state management
- `@Observable` store types for root-owned mock app state on iOS 17+
- Views receive only the data and actions they need
- No unnecessary view-model layer where plain SwiftUI state is sufficient

## Data Flow

- Mock repository/service provides workout and exercise history
- Root store owns active workout state and history collections
- Feature views bind to store slices
- Mutations such as toggling set completion, editing values, adding sets, and adding exercises update in-memory mock state

## Error And Empty States

Because the app uses mock data, explicit UI states will still be modeled so the codebase is ready for production data later.

Examples:

- History loading skeleton or spinner
- History empty state with short explanation
- History error card with retry button
- Optional placeholder content if a workout has no exercises

## Reusable Components

Planned reusable native components:

- Sticky workout header
- Floating glass tab bar wrapper or tab styling helpers
- Segmented control
- Surface card container
- Primary gradient button
- Secondary bordered button
- Metric summary card
- Exercise card
- Set row
- Numeric set input
- Completion circle button
- Empty state view
- Error state view
- Loading state view

## Mock Data

Initial mock content will be adapted from the HTML export:

- Active workout: `Lower Body A`
- Exercises such as `Back Squat`, `Romanian Deadlift`, and `Leg Press`
- Workout history list
- Exercise history list
- Derived summary values such as total sets and volume

## Native Adaptation Decisions

- The HTML `glass` bottom bar will be recreated with native SwiftUI materials and overlays rather than a literal HTML blur treatment
- Native controls and safe-area handling take precedence over exact web behavior
- Bottom sheet uses SwiftUI sheet presentation
- Input behavior will follow iOS form expectations, including numeric keyboard choices where appropriate

## Assumptions

- The supplied screenshots represent the complete required primary screens for V1
- `Profile` is not designed yet and will ship as a polished placeholder
- Missing custom icons and bespoke image assets will be substituted with SF Symbols or simple native vector drawing
- History detail navigation is implied even though detail screens are not shown
- The app targets portrait iPhone layouts only for the initial version

## Missing Assets Or Details

Currently missing or not explicitly provided:

- Profile screen design
- Any brand-specific font files beyond native system typography
- Any exported raster/vector assets beyond what is visible in the HTML and screenshots
- Explicit history detail screen mocks
- Empty/loading/error mock screenshots

## Verification Plan

- Build the Xcode project for an iPhone simulator target
- Verify all screens compile and render
- Validate layout on at least one compact and one larger iPhone simulator size
- Confirm expand/collapse, segmented switching, tab switching, set editing, add-set, add-exercise, and finish-sheet flows work

## Implementation Notes

- The project will be created from scratch in the workspace because no existing iOS project is present
- The workspace is not currently a Git repository, so the requested spec commit cannot be created unless version control is initialized

## Implemented Assumptions

- The profile screen ships as a polished placeholder because no profile comp was supplied
- History detail screens were inferred from the history list rows and implemented as native placeholder drill-down views
- SF Symbols and simple native shapes were used where no custom icon assets were provided
