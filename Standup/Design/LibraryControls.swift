import SwiftUI

/// The + button in a page's toolbar, as in Music: adds the special or
/// comedian to the App Library, then shows a checkmark. Tapping the
/// checkmark offers to remove it.
struct LibraryToolbarButton: View {
    let item: LibraryItem

    @Environment(LibraryStore.self) private var library
    @State private var confirmsRemoval = false

    var body: some View {
        let saved = library.contains(item)
        Button {
            if saved {
                confirmsRemoval = true
            } else {
                library.add(item)
            }
        } label: {
            Image(systemName: saved ? "checkmark" : "plus")
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(saved ? "In Library" : "Add to Library")
        .accessibilityHint(saved ? "Offers to remove it from your Standup library" : "")
        .accessibilityIdentifier("library.toggle")
        .confirmationDialog("Remove from Library?", isPresented: $confirmsRemoval, titleVisibility: .hidden) {
            Button("Remove from Library", role: .destructive) {
                library.remove(item)
            }
        }
    }
}

/// Add to Library / Remove from Library in a long-press menu.
struct LibraryContextMenu: ViewModifier {
    let item: LibraryItem
    @Environment(LibraryStore.self) private var library

    func body(content: Content) -> some View {
        content.contextMenu {
            if library.contains(item) {
                Button("Remove from Library", systemImage: "minus.circle", role: .destructive) {
                    library.remove(item)
                }
            } else {
                Button("Add to Library", systemImage: "plus") {
                    library.add(item)
                }
            }
        }
    }
}

/// Add to Library / Remove from Library on a list row's trailing swipe.
struct LibrarySwipeActions: ViewModifier {
    let item: LibraryItem
    @Environment(LibraryStore.self) private var library

    func body(content: Content) -> some View {
        content.swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if library.contains(item) {
                Button(role: .destructive) {
                    library.remove(item)
                } label: {
                    Label("Remove from Library", systemImage: "minus.circle")
                }
            } else {
                Button {
                    library.add(item)
                } label: {
                    Label("Add to Library", systemImage: "plus")
                }
                .tint(Theme.accent)
            }
        }
    }
}

extension View {
    func libraryContextMenu(_ item: LibraryItem) -> some View {
        modifier(LibraryContextMenu(item: item))
    }

    func librarySwipeActions(_ item: LibraryItem) -> some View {
        modifier(LibrarySwipeActions(item: item))
    }
}

/// Music's "Added to Library" HUD: a brief glass square in the middle of
/// the screen, with a haptic and a VoiceOver announcement.
struct LibraryFeedbackHUD: View {
    @Environment(LibraryStore.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.libraryFeedbackDuration) private var duration

    var body: some View {
        ZStack {
            if let feedback = library.feedback {
                VStack(spacing: 12) {
                    Image(systemName: feedback.symbol)
                        .font(.system(size: 44, weight: .semibold))
                    Text(feedback.message)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(minWidth: 168, minHeight: 168)
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
                .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("library.feedback")
                .task(id: feedback.id) {
                    AccessibilityNotification.Announcement(feedback.message).post()
                    // Cancelled means a newer confirmation replaced this one.
                    guard (try? await Task.sleep(for: .seconds(duration))) != nil else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        library.dismissFeedback(feedback.id)
                    }
                }
            }
        }
        .animation(.spring(duration: 0.3), value: library.feedback)
        .sensoryFeedback(.success, trigger: library.feedback?.id) { _, new in new != nil }
        .allowsHitTesting(false)
    }
}

extension EnvironmentValues {
    /// How long the library confirmation stays up, in seconds. UI tests
    /// lengthen it (`-StandupFeedbackSeconds`) so they can see it.
    @Entry var libraryFeedbackDuration: Double = 1.6
}
