//
//  PromptInputView+ImagePaste.swift
//  ExcalidrawZ
//
//  Image-paste support for `PromptInputView`. Modeled on the ChatGPT
//  macOS client: pasted images do *not* go inside the text — they
//  appear as a row of thumbnails above the input field, each with its
//  own delete affordance, and ride along to the user message as
//  attachments on send.
//
//  Why no inline tokens (the previous design): inline tokens looked
//  cute but conflate two concerns — composing a prompt and selecting
//  attachments. Users pastes a screenshot to *show* the model
//  something; they don't want the placeholder living inside their
//  prose. Out-of-band thumbnails match every modern chat UI and let
//  the prompt text stay clean.
//
//  Data flow:
//
//  1. TextArea's `.onPaste(_:)` handler captures image-bearing items,
//     appends a `PendingPastedImage` to side-state, and returns
//     `.action {}` so TextArea inserts nothing into the text.
//  2. The strip view (`AttachmentThumbnailStrip`) renders the
//     side-state as little chips above the input.
//  3. On send, every entry in the side-state is encoded as an
//     AI-optimized data URI and attached to the user message via
//     `ChatMessageContent.files`.
//  4. From there the existing pipeline takes over: LLMKit's automatic
//     upload provider may rewrite base64 → URL, the persistence
//     layer's `AIChatAttachmentRepository` writes either form to
//     iCloud-Drive-synced storage and roundtrips it on restore.
//
//  iOS note: TextArea's paste pipeline is backed by the UIKit bridge
//  in ChocofordKit, so the same attachment path handles paste, file
//  import, PhotosPicker, and camera captures.
//

import SwiftUI
import ChocofordUI
import LLMCore
import SFSafeSymbols
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if os(iOS)
import PhotosUI
#endif

// MARK: - Side-state record

/// One pasted image, paired with a stable id so SwiftUI's `ForEach`
/// can identify it across removals and the user's "remove" tap can
/// resolve back to the right entry.
struct PendingPastedImage: Identifiable, Equatable {
    let id: UUID
    let image: PlatformImage

    static func == (lhs: PendingPastedImage, rhs: PendingPastedImage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Encoding helpers

enum PastedImageHelpers {
    /// `PlatformImage` → AI-optimized data URI. Camera photos are resized and
    /// encoded as JPEG so a pasted / captured image does not balloon into a
    /// huge PNG payload before LLMKit's upload pipeline sees it.
    static func encodeAsDataURI(_ image: PlatformImage) -> String? {
        guard let payload = AIImagePayloadOptimizer.optimize(image) else { return nil }
        return AIImagePayloadOptimizer.dataURL(from: payload)
    }

    /// Build the `[File]` payload for a user message from the current
    /// pastedImages. Encoding failures drop that one entry silently —
    /// the message itself shouldn't be blocked by one corrupted
    /// attachment.
    static func buildFiles(
        from pastedImages: [PendingPastedImage]
    ) -> [ChatMessageContent.File] {
        pastedImages.compactMap { entry in
            guard let dataURI = encodeAsDataURI(entry.image) else { return nil }
            return .base64EncodedImage(dataURI)
        }
    }

    /// Rehydrate persisted message attachments back into input thumbnails
    /// when editing an older user message.
    static func pendingImages(
        from files: [ChatMessageContent.File]
    ) -> [PendingPastedImage] {
        files.compactMap { file in
            guard let image = platformImage(from: file) else { return nil }
            return PendingPastedImage(id: UUID(), image: image)
        }
    }

    private static func platformImage(from file: ChatMessageContent.File) -> PlatformImage? {
        switch file {
            case .base64EncodedImage(let value):
                let payload = value.split(separator: ",", maxSplits: 1).last.map(String.init) ?? value
                guard let data = Data(base64Encoded: payload) else { return nil }
#if canImport(AppKit)
                return NSImage(data: data)
#elseif canImport(UIKit)
                return UIImage(data: data)
#else
                return nil
#endif
            case .image(let url):
                guard let data = try? Data(contentsOf: url) else { return nil }
#if canImport(AppKit)
                return NSImage(data: data)
#elseif canImport(UIKit)
                return UIImage(data: data)
#else
                return nil
#endif
        }
    }
}

#if os(iOS)
enum AIChatAttachmentImageImporter {
    static func pendingImage(from url: URL) -> PendingPastedImage? {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return pendingImage(from: data)
    }

    static func pendingImage(from data: Data) -> PendingPastedImage? {
        guard let image = UIImage(data: data) else { return nil }
        return PendingPastedImage(id: UUID(), image: image)
    }

    static func pendingImage(from image: UIImage) -> PendingPastedImage {
        PendingPastedImage(id: UUID(), image: image)
    }

    static func pendingImages(from items: [PhotosPickerItem]) async -> [PendingPastedImage] {
        var images: [PendingPastedImage] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = pendingImage(from: data)
            else { continue }
            images.append(image)
        }
        return images
    }
}

struct AIChatCameraImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let onImagePicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: AIChatCameraImagePicker

        init(parent: AIChatCameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            parent.onImagePicked(image)
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImagePicked(nil)
            parent.dismiss()
        }
    }
}
#endif

extension ChatMessageContent.File {
    var isImageInput: Bool {
        switch self {
            case .base64EncodedImage, .image:
                return true
        }
    }
}

extension Array where Element == ChatMessageContent.File {
    var containsImageInput: Bool {
        contains { $0.isImageInput }
    }
}

struct AIChatImageAttachmentReference: Codable, Hashable, Sendable {
    let id: String
    let mimeType: String
    let dataURL: String

    static func makeReferences(
        from files: [ChatMessageContent.File]
    ) -> [AIChatImageAttachmentReference] {
        files.enumerated().compactMap { index, file in
            guard let payload = imagePayload(from: file) else { return nil }
            return AIChatImageAttachmentReference(
                id: "input_image_\(index + 1)",
                mimeType: payload.mimeType,
                dataURL: payload.dataURL
            )
        }
    }

    static func parseDataURL(_ value: String) -> (mimeType: String, data: Data)? {
        guard let commaIndex = value.firstIndex(of: ",") else { return nil }
        let header = String(value[..<commaIndex])
        guard header.lowercased().hasPrefix("data:") else { return nil }
        let metadata = String(header.dropFirst("data:".count))
        let parts = metadata.split(separator: ";").map(String.init)
        let mimeType = parts.first(where: { !$0.isEmpty && !$0.caseInsensitiveCompare("base64").isSame }) ?? "image/png"
        guard parts.contains(where: { $0.caseInsensitiveCompare("base64").isSame }) else { return nil }
        let payload = String(value[value.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters) else { return nil }
        return (mimeType, data)
    }

    static func makeDataURL(data: Data, mimeType: String) -> String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    private static func imagePayload(
        from file: ChatMessageContent.File
    ) -> (mimeType: String, dataURL: String)? {
        switch file {
            case .base64EncodedImage(let dataURL):
                guard let parsed = parseDataURL(dataURL) else { return nil }
                return (parsed.mimeType, dataURL)

            case .image(let url):
                guard url.isFileURL else { return nil }
                let didStart = url.startAccessingSecurityScopedResource()
                defer {
                    if didStart { url.stopAccessingSecurityScopedResource() }
                }
                guard let data = try? Data(contentsOf: url) else { return nil }
                let mimeType = mimeType(for: url)
                return (mimeType, makeDataURL(data: data, mimeType: mimeType))
        }
    }

    private static func mimeType(for url: URL) -> String {
        guard !url.pathExtension.isEmpty,
              let type = UTType(filenameExtension: url.pathExtension),
              let mimeType = type.preferredMIMEType,
              mimeType.lowercased().hasPrefix("image/")
        else {
            return "image/png"
        }
        return mimeType
    }
}

private extension ComparisonResult {
    var isSame: Bool { self == .orderedSame }
}

// MARK: - Thumbnail strip

/// Horizontal row of pasted-image thumbnails, each with a hover-
/// revealed ✕ delete button. Sits above the TextArea inside the
/// input chrome (the ChatGPT layout) so it visually reads as
/// "what's about to be sent" rather than as standalone media.
///
/// Self-collapsing: when there are no images, returns an `EmptyView`
/// so the host doesn't have to gate it conditionally — drop in once,
/// it's invisible until something gets pasted.
struct AttachmentThumbnailStrip: View {
    @Binding var pastedImages: [PendingPastedImage]

    var body: some View {
        if !pastedImages.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(pastedImages) { entry in
                        // Each tile is its own view so per-tile hover
                        // state can live next to the tile — sharing
                        // a single `@State` at strip level would mean
                        // hovering any tile reveals every ✕.
                        AttachmentThumbnailTile(
                            entry: entry,
                            onRemove: { remove(entry.id) }
                        )
                    }
                    .padding(.horizontal, 12)
                }
                .scrollIndicators(.hidden)
                .padding(.top, 10)
                // Bottom padding intentionally small — the TextArea
                // sits right below; we want a single visual block.
                .padding(.bottom, 6)
            }
        }
    }

    private func remove(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.15)) {
            pastedImages.removeAll { $0.id == id }
        }
    }
}

/// Single thumbnail with its own remove affordance. macOS keeps the
/// button hover-revealed; iOS shows it persistently because there is no
/// hover state and attachments need an obvious touch target.
private struct AttachmentThumbnailTile: View {
    let entry: PendingPastedImage
    let onRemove: () -> Void

    /// Side length of each thumbnail tile, in points. ChatGPT-ish
    /// proportions; small enough to fit several in the input chrome
    /// without dominating the prompt area.
    private let tileSize: CGFloat = 56

    @State private var isHovering: Bool = false

    var body: some View {
        ZStack(alignment: removeButtonAlignment) {
            // The image itself — rounded card, fixed square aspect.
            // Using `.scaledToFill` + clip so portrait/landscape both
            // present as a clean tile rather than letterboxing.
#if canImport(AppKit)
            Image(nsImage: entry.image)
                .resizable()
                .scaledToFill()
                .frame(width: tileSize, height: tileSize)
                .clipShape(RoundedRectangle(cornerRadius: 8))
#elseif canImport(UIKit)
            Image(uiImage: entry.image)
                .resizable()
                .scaledToFill()
                .frame(width: tileSize, height: tileSize)
                .clipShape(RoundedRectangle(cornerRadius: 8))
#endif

            // On macOS this stays hover-revealed. On iOS it is always
            // visible and anchored to the top-left corner.
            Button(action: onRemove) {
                Label(
                    .localizable(.aiChatButtonRemoveAttachment),
                    systemSymbol: .xmarkCircleFill
                )
                .font(.system(size: 16))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.55))
                .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .frame(width: removeButtonHitLength, height: removeButtonHitLength)
            .offset(removeButtonOffset)
            .opacity(removeButtonIsVisible ? 1 : 0)
            .allowsHitTesting(removeButtonIsVisible)
            .animation(.easeInOut(duration: 0.12), value: isHovering)
            .help(.localizable(.aiChatButtonRemoveAttachment))
        }
        .padding(.top, 6)
        .padding(removeButtonHorizontalPaddingEdge, 6)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var removeButtonIsVisible: Bool {
#if canImport(UIKit)
        true
#else
        isHovering
#endif
    }

    private var removeButtonAlignment: Alignment {
#if canImport(UIKit)
        .topLeading
#else
        .topTrailing
#endif
    }

    private var removeButtonOffset: CGSize {
#if canImport(UIKit)
        CGSize(width: -6, height: -6)
#else
        CGSize(width: 6, height: -6)
#endif
    }

    private var removeButtonHitLength: CGFloat {
#if canImport(UIKit)
        28
#else
        18
#endif
    }

    private var removeButtonHorizontalPaddingEdge: Edge.Set {
#if canImport(UIKit)
        .leading
#else
        .trailing
#endif
    }
}
