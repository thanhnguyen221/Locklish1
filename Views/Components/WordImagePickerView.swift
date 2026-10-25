import SwiftUI
import PhotosUI

// MARK: - WordImagePickerView
/// Image display and picker allowing users to tap and pick custom photos
/// from their Photo Library via SwiftUI's PhotosPicker, storing compressed Data directly in SwiftData.
struct WordImagePickerView: View {
    @Binding var imageData: Data?
    var height: CGFloat = 160
    var allowsEditing: Bool = true

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isLoading: Bool = false

    var body: some View {
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            ZStack {
                if let data = imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: height)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    // Placeholder when no custom image is selected
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                            .fill(AppTheme.primary.opacity(0.08))

                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(AppTheme.primary)

                            Text(allowsEditing ? "Chạm để thêm ảnh gợi nhớ" : "Chưa có ảnh gợi nhớ")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(AppTheme.primary.opacity(0.8))
                        }
                    }
                    .frame(height: height)
                }

                // Loading Spinner
                if isLoading {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .tint(.white)
                }

                // Edit badge overlay
                if allowsEditing && imageData != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Label("Đổi ảnh", systemImage: "photo.badge.plus")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .padding(10)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
        .disabled(!allowsEditing)
        .buttonStyle(.plain)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadTransferableImage(from: newItem)
            }
        }
    }

    // MARK: - Photo Loading & Compression
    private func loadTransferableImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            if let rawData = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: rawData) {
                // Resize and compress to preserve memory and disk space
                let resizedImage = image.preparingThumbnail(of: CGSize(width: 800, height: 800)) ?? image
                let compressedData = resizedImage.jpegData(compressionQuality: 0.8)

                await MainActor.run {
                    self.imageData = compressedData
                    HapticFeedback.success()
                }
            }
        } catch {
            print("Failed to load selected photo: \(error.localizedDescription)")
            HapticFeedback.error()
        }
    }
}

#Preview {
    WordImagePickerView(imageData: .constant(nil))
        .padding()
}
