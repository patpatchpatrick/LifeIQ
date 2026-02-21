# Custom Dropdown Overlay Menu Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace SwiftUI's native `Menu` (which causes janky animations) with a custom popover-style dropdown rendered in the overlay window, so dismissal and content transitions are fully sequenced.

**Architecture:** A new `SQDropDownMenuState` follows the exact same pattern as `SQAlertState`/`SQModalState`. When the dropdown button is tapped, it captures its own screen frame via `GeometryReader`+`PreferenceKey`, presents a floating card through the overlay window, and fires the selection handler only *after* the dismiss animation completes — eliminating the simultaneous-animation problem.

**Tech Stack:** Swift, SwiftUI, UIKit overlay window (`SQOverlayWindow`/`SQPassthroughWindow`), `@Observable`, `PreferenceKey`, `GeometryReader`

---

### Task 1: Create `SQDropDownMenuState`

**Files:**
- Create: `BeastFitness/Managers/SQDropDownMenuState.swift`

**Step 1: Create the file with this exact content**

```swift
//
//  SQDropDownMenuState.swift
//  BeastFitness
//

import Foundation
import Observation
import CoreGraphics

@MainActor
@Observable
final class SQDropDownMenuState {

    struct MenuPresentation {
        /// The button's frame in global (screen) coordinates — used to position the card.
        let anchorFrame: CGRect
        /// All selectable items.
        let items: [SQDropDownButtonViewModel]
        /// Title of the currently selected item (shown with a checkmark).
        let selectedTitle: String
        /// Called with the selected title after the dismiss animation finishes.
        let onSelect: (String) -> Void
    }

    private(set) var currentMenu: MenuPresentation? {
        didSet { onVisibilityChanged?(isPresented) }
    }

    var onVisibilityChanged: ((Bool) -> Void)?
    var isPresented: Bool { currentMenu != nil }

    func present(_ menu: MenuPresentation) {
        currentMenu = menu
    }

    func dismiss() {
        currentMenu = nil
    }
}
```

**Step 2: Commit**

```bash
git add BeastFitness/Managers/SQDropDownMenuState.swift
git commit -m "feat: add SQDropDownMenuState for overlay dropdown"
```

---

### Task 2: Wire `SQDropDownMenuState` into the overlay infrastructure

**Files:**
- Modify: `BeastFitness/StateManagement/SQAppState.swift`
- Modify: `BeastFitness/Views/Toasts/SQToastOverlayWindow.swift`
- Modify: `BeastFitness/Views/OverlayWindow/SQOverlayRootView.swift`
- Modify: `BeastFitness/BeastFitnessApp.swift`

**Step 1: Add `dropDownMenuState` to `SQAppState`**

In `SQAppState.swift`, add the property after `toastState`:
```swift
let dropDownMenuState: SQDropDownMenuState
```

In `init()`, add after `self.toastState = .init(hub: hub)`:
```swift
self.dropDownMenuState = .init()
```

Note: `SQDropDownMenuState` does not need `hub` — it is presented directly, not via event bus.

**Step 2: Add `dropdownMenu:` parameter to `SQOverlayWindow.attachIfNeeded`**

In `SQToastOverlayWindow.swift`:

Change the `attachIfNeeded` signature from:
```swift
func attachIfNeeded(alerts: SQAlertState, toasts: SQToastState, modals: SQModalState) {
```
To:
```swift
func attachIfNeeded(alerts: SQAlertState, toasts: SQToastState, modals: SQModalState, dropdownMenu: SQDropDownMenuState) {
```

Change the `rootView` construction from:
```swift
let rootView = SQOverlayRootView(alerts: alerts, toasts: toasts, modals: modals)
```
To:
```swift
let rootView = SQOverlayRootView(alerts: alerts, toasts: toasts, modals: modals, dropdownMenu: dropdownMenu)
```

Change `updatePassthrough` call and definition to include dropdown:
```swift
updatePassthrough(alerts: alerts, toasts: toasts, modals: modals, dropdownMenu: dropdownMenu)
```

Add a visibility callback for the dropdown (after the existing `modals.onVisibilityChanged` block):
```swift
dropdownMenu.onVisibilityChanged = { [weak self] _ in
    guard let self else { return }
    self.updatePassthrough(alerts: alerts, toasts: toasts, modals: modals, dropdownMenu: dropdownMenu)
}
```

Update `updatePassthrough` signature and body:
```swift
private func updatePassthrough(alerts: SQAlertState, toasts: SQToastState, modals: SQModalState, dropdownMenu: SQDropDownMenuState) {
    window?.isPassthroughEnabled = !(alerts.isPresented || toasts.isPresented || modals.isPresented || dropdownMenu.isPresented)
}
```

**Step 3: Add `dropdownMenu` to `SQOverlayRootView`**

In `SQOverlayRootView.swift`, add the property:
```swift
@Bindable var dropdownMenu: SQDropDownMenuState
```

Update the `init` (implicit memberwise) and add the host at `zIndex(4)` — above modals:
```swift
// Dropdown menu layer (above everything — anchored to button position)
SQDropDownMenuHost(menuState: dropdownMenu)
    .zIndex(4)
```

The full `body` becomes:
```swift
var body: some View {
    ZStack {
        SQToastHostView(toasts: toasts)
            .zIndex(1)
        SQAlertHost(alerts: alerts)
            .zIndex(2)
        SQModalHost(modalState: modals)
            .zIndex(3)
        SQDropDownMenuHost(menuState: dropdownMenu)
            .zIndex(4)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.clear)
}
```

**Step 4: Update `BeastFitnessApp.swift` to pass `dropDownMenuState`**

Change:
```swift
SQOverlayWindow.shared.attachIfNeeded(
    alerts: SQAppState.shared.alertState,
    toasts: SQAppState.shared.toastState,
    modals: SQAppState.shared.modalState
)
```
To:
```swift
SQOverlayWindow.shared.attachIfNeeded(
    alerts: SQAppState.shared.alertState,
    toasts: SQAppState.shared.toastState,
    modals: SQAppState.shared.modalState,
    dropdownMenu: SQAppState.shared.dropDownMenuState
)
```

**Step 5: Commit**

```bash
git add BeastFitness/StateManagement/SQAppState.swift \
        BeastFitness/Views/Toasts/SQToastOverlayWindow.swift \
        BeastFitness/Views/OverlayWindow/SQOverlayRootView.swift \
        BeastFitness/BeastFitnessApp.swift
git commit -m "feat: wire SQDropDownMenuState into overlay window infrastructure"
```

---

### Task 3: Create `SQDropDownMenuOverlayCard`

This is the floating card view rendered in the overlay.

**Files:**
- Create: `BeastFitness/Views/DropDownMenu/SQDropDownMenuOverlayCard.swift`

**Step 1: Create the file**

```swift
//
//  SQDropDownMenuOverlayCard.swift
//  BeastFitness
//

import SwiftUI

struct SQDropDownMenuOverlayCard: View {
    let menu: SQDropDownMenuState.MenuPresentation
    let menuState: SQDropDownMenuState

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(menu.items.enumerated()), id: \.offset) { index, item in
                Button {
                    // Dismiss the overlay first, then fire selection after the animation settles
                    withAnimation(.easeInOut(duration: 0.15)) {
                        menuState.dismiss()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        menu.onSelect(item.title)
                    }
                } label: {
                    HStack {
                        Text(item.title)
                            .sqFont(.body)
                            .sqForegroundColor(.textPrimary)
                        Spacer()
                        if item.title == menu.selectedTitle {
                            SQImageView(
                                image: .init(
                                    symbol: .checkmark,
                                    symbolStyle: .colorWithFont(.textPrimary, font: .body)
                                )
                            )
                            .frame(width: 14, height: 14)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if index < menu.items.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .frame(minWidth: 160)
        .fixedSize(horizontal: false, vertical: true)
        .sqBackgroundColor(.backgroundSecondary)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
    }
}
```

> **Note on `SQImageSymbol.checkmark`:** Verify this symbol exists in `BeastFitness/UI/SQImage.swift`. If not, add `case checkmark = "checkmark"` to the `SQImageSymbol` enum before using it here.

**Step 2: Commit**

```bash
git add BeastFitness/Views/DropDownMenu/SQDropDownMenuOverlayCard.swift
git commit -m "feat: add SQDropDownMenuOverlayCard floating card view"
```

---

### Task 4: Create `SQDropDownMenuHost`

The host renders in the overlay window and positions the card relative to the anchor frame.

**Files:**
- Create: `BeastFitness/Views/DropDownMenu/SQDropDownMenuHost.swift`

**Step 1: Create the file**

```swift
//
//  SQDropDownMenuHost.swift
//  BeastFitness
//

import SwiftUI

struct SQDropDownMenuHost: View {
    @Bindable var menuState: SQDropDownMenuState

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let menu = menuState.currentMenu {
                // Invisible scrim — catches taps outside the card to dismiss
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            menuState.dismiss()
                        }
                    }

                // Floating card — positioned just below and aligned to the button's left edge
                SQDropDownMenuOverlayCard(menu: menu, menuState: menuState)
                    .padding(.top, menu.anchorFrame.maxY + 4)
                    .padding(.leading, menu.anchorFrame.minX)
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.92, anchor: .topLeading))
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.15), value: menuState.isPresented)
    }
}
```

**Step 2: Commit**

```bash
git add BeastFitness/Views/DropDownMenu/SQDropDownMenuHost.swift
git commit -m "feat: add SQDropDownMenuHost for overlay-positioned dropdown"
```

---

### Task 5: Replace `SQDropDownMenu` with overlay-based implementation

This is the final piece — the view that was previously using SwiftUI `Menu`.

**Files:**
- Modify: `BeastFitness/Views/Shared/SQDropDownMenu.swift`

**Step 1: Add a `PreferenceKey` for the button frame**

Add this above `SQDropDownMenu`:

```swift
private struct SQDropDownAnchorKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
```

**Step 2: Replace the full `SQDropDownMenu` struct**

Replace the entire `SQDropDownMenu` struct with:

```swift
struct SQDropDownMenu: View {
    @ObservedObject var menuViewModel: SQDropDownMenuViewModel
    let isDisabled: Bool

    @State private var buttonFrame: CGRect = .zero

    var body: some View {
        SQDropDownButton(viewModel: menuViewModel.mainButton)
            .disabled(isDisabled)
            .frame(height: 30)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: SQDropDownAnchorKey.self,
                            value: geo.frame(in: .global)
                        )
                }
            )
            .onPreferenceChange(SQDropDownAnchorKey.self) { frame in
                buttonFrame = frame
            }
            .onTapGesture {
                guard !isDisabled else { return }
                let presentation = SQDropDownMenuState.MenuPresentation(
                    anchorFrame: buttonFrame,
                    items: menuViewModel.dropDownButtons,
                    selectedTitle: menuViewModel.mainButton.title,
                    onSelect: { title in
                        menuViewModel.dropDownButtons
                            .first(where: { $0.title == title })?
                            .selected()
                    }
                )
                withAnimation(.easeInOut(duration: 0.15)) {
                    SQAppState.shared.dropDownMenuState.present(presentation)
                }
            }
    }
}
```

> **Why remove `NavMenuStyle()`:** The old `Menu` used `.menuStyle(NavMenuStyle())`. This is no longer needed — the custom overlay replaces it entirely. Check that `NavMenuStyle` isn't used anywhere else before removing it; if it is, leave it in place and just stop using it here.

**Step 3: Commit**

```bash
git add BeastFitness/Views/Shared/SQDropDownMenu.swift
git commit -m "feat: replace SwiftUI Menu with overlay-based custom dropdown"
```

---

### Task 6: Verify `SQImageSymbol.checkmark` exists

**Files:**
- Modify (if needed): `BeastFitness/UI/SQImage.swift`

**Step 1: Search for checkmark in SQImageSymbol**

Run:
```bash
grep -n "checkmark" BeastFitness/UI/SQImage.swift
```

**Step 2: Add if missing**

If `checkmark` is not in the `SQImageSymbol` enum, add:
```swift
case checkmark = "checkmark"
```

Add it in a logical place (alphabetical or near other UI symbols).

**Step 3: Commit only if a change was needed**

```bash
git add BeastFitness/UI/SQImage.swift
git commit -m "feat: add checkmark to SQImageSymbol"
```
