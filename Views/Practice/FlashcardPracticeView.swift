import SwiftUI
import SwiftData

// MARK: - FlashcardPracticeView
/// Advanced 3D Flashcard practice interface featuring:
/// - Smooth interactive swipe physics (DragGesture left = Cần ôn, right = Đã thuộc)
/// - Compact progress header and one-tap undo for accidental swipes
/// - Dynamic deck filtering & SM-2 Spaced Repetition queue integration
struct FlashcardPracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [VocabularyItem]

    var selectedDeck: VocabularyDeck? = nil

    @State private var viewModel = FlashcardViewModel()

    var body: some View {
        GeometryReader { geo in
            if viewModel.deck.isEmpty || viewModel.isSessionCompleted {
                completedOrEmptyView
            } else if let card = viewModel.currentCard {
                // The header is deliberately small, leaving most of the screen for
                // the word, meaning, and example on the card itself.
                let cardH = max(280, geo.size.height - 180)

                VStack(spacing: 0) {
                    compactPracticeHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // Interactive swiping 3D Flip Card
                    ZStack {
                        FlipCardView(
                            item: card,
                            isFlipped: viewModel.isFlipped,
                            rotationAngle: viewModel.cardRotation,
                            onFlip: {
                                // Tap to flip only when not dragging significantly
                                if abs(viewModel.dragOffset.width) < 12 {
                                    viewModel.flipCard()
                                }
                            }
                        )
                        .frame(height: cardH)
                        // Physics offset & tilt angle
                        .offset(x: viewModel.dragOffset.width, y: viewModel.dragOffset.height * 0.12)
                        .rotationEffect(.degrees(Double(viewModel.dragOffset.width / 18.0)))
                        // Dynamic soft shadow glow: green on right, red on left
                        .shadow(
                            color: viewModel.dragOffset.width > 20
                                ? AppTheme.success.opacity(min(0.35, Double(viewModel.dragOffset.width / 180.0)))
                                : (viewModel.dragOffset.width < -20
                                    ? AppTheme.danger.opacity(min(0.35, Double(abs(viewModel.dragOffset.width) / 180.0)))
                                    : Color.black.opacity(0.04)),
                            radius: 16,
                            x: 0,
                            y: 8
                        )
                        // Live Stamp Indicator Overlay
                        .overlay(alignment: .topTrailing) {
                            if viewModel.dragOffset.width < -25 {
                                Label("CẦN ÔN", systemImage: "arrow.counterclockwise")
                                    .font(.system(size: 13, weight: .heavy))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(AppTheme.danger)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .rotationEffect(.degrees(10))
                                    .opacity(min(1.0, Double(abs(viewModel.dragOffset.width) / 80.0)))
                                    .padding(18)
                            }
                        }
                        .overlay(alignment: .topLeading) {
                            if viewModel.dragOffset.width > 25 {
                                Label("ĐÃ THUỘC", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 13, weight: .heavy))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(AppTheme.success)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .rotationEffect(.degrees(-10))
                                    .opacity(min(1.0, Double(viewModel.dragOffset.width / 80.0)))
                                    .padding(18)
                            }
                        }
                        // High-priority Drag Gesture for fluid mouse & finger swiping
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { value in
                                    viewModel.handleDragChanged(translation: value.translation)
                                }
                                .onEnded { value in
                                    viewModel.handleDragEnded(translation: value.translation, in: modelContext)
                                }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer(minLength: 8)

                    // Quick Action Buttons (Cần ôn · Lật thẻ · Đã thuộc)
                    bottomActionBar(in: modelContext)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 12))
                }
            }
        }
        .onDisappear { WidgetDataStore.refreshFromModel() }
        .onAppear {
            viewModel.loadDeck(from: allItems, deckFilter: selectedDeck)
        }
        .onChange(of: selectedDeck) { _, newDeck in
            viewModel.loadDeck(from: allItems, deckFilter: newDeck)
        }
    }

    // MARK: - Compact Header
    private var compactPracticeHeader: some View {
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                Button {
                    viewModel.undoLastSwipe(in: modelContext)
                } label: {
                    Label("Quay lại", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(viewModel.canUndoLastSwipe ? AppTheme.primary : AppTheme.textTertiary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(AppTheme.primary.opacity(viewModel.canUndoLastSwipe ? 0.10 : 0.04))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canUndoLastSwipe)
                .accessibilityLabel("Quay lại thẻ vừa lướt")

                VStack(spacing: 1) {
                    Text(selectedDeck?.name ?? "Thẻ ghi nhớ")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Text("Vuốt trái để ôn · phải để nhớ")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Text(viewModel.progressText)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.primary)
                    .frame(minWidth: 34, alignment: .trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.07))
                    Capsule()
                        .fill(AppTheme.primaryGradient)
                        .frame(width: geo.size.width * viewModel.progressRatio)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.progressRatio)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Bottom Quick Action Bar
    private func bottomActionBar(in modelContext: ModelContext) -> some View {
        HStack(spacing: 36) {
            // Cần ôn (Swipe Left action)
            Button {
                viewModel.swipeLeftNeedsReview(in: modelContext)
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.danger.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.danger)
                    }
                    Text("Cần ôn")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.danger)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Đánh dấu cần ôn tập lại")

            // Lật thẻ (Flip Card action)
            Button {
                viewModel.flipCard()
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.primary)
                    }
                    Text("Lật thẻ")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Lật mặt thẻ")

            // Đã thuộc (Swipe Right action)
            Button {
                viewModel.swipeRightMastered(in: modelContext)
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.success.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: "checkmark")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(AppTheme.success)
                    }
                    Text("Đã thuộc")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.success)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Đánh dấu đã thuộc từ này")
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Completed or Empty Deck View
    private var completedOrEmptyView: some View {
        VStack {
            Spacer()
            if allItems.isEmpty {
                EmptyStatePlaceholderView(
                    iconName: "square.stack.3d.up.slash",
                    title: "Chưa có từ để luyện thẻ",
                    subtitle: "Thêm từ vựng mới hoặc nhập bài đọc qua AI để bắt đầu học flashcard."
                )
            } else if viewModel.deck.isEmpty {
                EmptyStatePlaceholderView(
                    iconName: "folder.badge.questionmark",
                    title: "Tệp này chưa có từ vựng",
                    subtitle: selectedDeck != nil
                        ? "Tệp '\(selectedDeck!.name)' chưa có từ vựng nào. Hãy thêm từ vào tệp này hoặc chọn tệp khác."
                        : "Tất cả các từ đều đã hoàn thành ôn tập cho hôm nay!"
                )
            } else {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.success.opacity(0.12))
                            .frame(width: 88, height: 88)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.success)
                    }

                    VStack(spacing: 8) {
                        Text("Hoàn thành bộ thẻ!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppTheme.textPrimary)

                        if let deck = selectedDeck {
                            Text("Tệp: \(deck.name)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppTheme.primary.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        // Session summary
                        HStack(spacing: 16) {
                            Text("🟢 Đã thuộc: \(viewModel.masteredCount)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.success)
                            Text("🔴 Cần ôn: \(viewModel.reviewNeededCount)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.danger)
                        }
                        .padding(.top, 4)

                        Text("Các từ đã được lập lịch ôn tập tự động theo thuật toán SM-2. Hãy chuyển sang phần nghe chép chính tả để thử thách mở khóa ứng dụng.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(4)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.top, 4)
                    }

                    Button {
                        viewModel.restartSession(with: allItems)
                    } label: {
                        Label("Luyện lại từ đầu", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(AppTheme.primaryGradient)
                            .clipShape(Capsule())
                            .shadow(color: AppTheme.primary.opacity(0.25), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
            Spacer()
        }
    }
}
