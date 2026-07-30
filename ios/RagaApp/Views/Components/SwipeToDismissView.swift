import SwiftUI

/// Wraps a row with a left-swipe-to-clear gesture, and — when
/// `canDeleteForAll` is true — a right-swipe-to-delete gesture in the
/// opposite direction. `.swipeActions` only works inside a `List`, but this
/// feed is a plain `ForEach` in a `ScrollView`, so this reimplements the
/// gesture by hand.
///
/// Clearing (left swipe) is a personal, client-side dismiss (not a backend
/// delete) — it just hides the item from this device's feed going forward,
/// so anyone can declutter notifications they're done with regardless of
/// delete permission. Deleting (right swipe) is a real, destructive backend
/// mutation available only to board members, so it's gated by
/// `canDeleteForAll` and confirmed before `onDeleteAll` fires.
///
/// Uses `.simultaneousGesture` plus a dominant-axis check so the horizontal
/// drag doesn't fight the enclosing ScrollView's vertical scroll gesture.
struct SwipeToDismissView<Content: View>: View {
    let onDismiss: () -> Void
    var canDeleteForAll: Bool = false
    var onDeleteAll: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var rowWidth: CGFloat = 320
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            if offset > 0 && canDeleteForAll {
                deleteBackground
            } else {
                clearBackground
            }

            content()
                .offset(x: offset)
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear { rowWidth = geo.size.width }
                    }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            let translation = value.translation
                            guard abs(translation.width) > abs(translation.height) else { return }
                            let maxOffset: CGFloat = canDeleteForAll ? rowWidth : 0
                            offset = min(maxOffset, max(translation.width, -rowWidth))
                        }
                        .onEnded { value in
                            let translation = value.translation
                            guard abs(translation.width) > abs(translation.height) else {
                                snapClosed()
                                return
                            }
                            if -offset > rowWidth * 0.35 {
                                withAnimation(.easeOut(duration: 0.22)) { offset = -rowWidth * 1.2 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDismiss() }
                            } else if canDeleteForAll, offset > rowWidth * 0.35 {
                                showDeleteConfirm = true
                                snapClosed()
                            } else {
                                snapClosed()
                            }
                        }
                )
        }
        .confirmationDialog("Delete notification for all?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete for All", role: .destructive) { onDeleteAll?() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func snapClosed() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = 0 }
    }

    private var clearBackground: some View {
        HStack {
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                Text("Clear")
                    .font(.caption2.bold())
            }
            .foregroundStyle(.white)
            .padding(.trailing, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.green)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var deleteBackground: some View {
        HStack {
            VStack(spacing: 2) {
                Image(systemName: "trash.fill")
                    .font(.title3)
                Text("Delete")
                    .font(.caption2.bold())
            }
            .foregroundStyle(.white)
            .padding(.leading, 26)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.red)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
