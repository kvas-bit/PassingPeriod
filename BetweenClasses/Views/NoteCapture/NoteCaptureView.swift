import SwiftUI
import AVFoundation
import UIKit

struct NoteCaptureView: View {
    @State private var capturedImage: Data?
    @State private var extractedText: String = ""
    @State private var ocrDraft: OCRDraft?
    @State private var isProcessing = false
    @State private var showConfirm = false
    @State private var showImagePicker = false
    @State private var captureRequested = false
    @State private var captureSequence = 0
    @State private var cameraSessionFailed = false
    @State private var cameraRelaunchToken = 0
    @State private var lastCaptureOCRFailed = false
    @State private var captureUserMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                CameraPreviewView(
                    captureRequested: $captureRequested,
                    cameraSessionFailed: $cameraSessionFailed,
                    onCapture: handleCapture,
                    onSessionIssue: {
                        captureUserMessage = "Camera unavailable. Allow access in Settings, or pick a photo from your library."
                    },
                    onCaptureFailure: {
                        captureUserMessage = "Couldn’t capture this shot — try again or choose from your library."
                    }
                )
                .id(cameraRelaunchToken)
                .ignoresSafeArea()
                DocumentCaptureGuideOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Controls float above tab bar — 83pt clears the custom tab bar on all iPhones
            captureControls

            if cameraSessionFailed || captureUserMessage != nil {
                captureRecoveryBanner
                    .padding(.horizontal, BCSpacing.gutter)
                    .padding(.bottom, 108)
            }

            // Processing overlay
            if isProcessing {
                processingOverlay
            }
        }
        .sheet(isPresented: $showConfirm) {
            if let data = capturedImage {
                OCRConfirmView(
                    imageData: data,
                    extractedText: extractedText,
                    ocrSourceSummary: ocrDraft?.sourceLabel,
                    ocrConfidenceSummary: ocrDraft?.confidenceSummary,
                    suggestedTopicName: ocrDraft?.suggestedTopic,
                    unreadableRegions: ocrDraft?.unreadableRegions ?? [],
                    ocrFailed: lastCaptureOCRFailed,
                    onSave: { _ in
                        capturedImage = nil
                        extractedText = ""
                        ocrDraft = nil
                        lastCaptureOCRFailed = false
                    },
                    onCaptureAnother: {
                        // Dismiss sheet (showConfirm goes false) then camera is live again
                        capturedImage = nil
                        extractedText = ""
                        ocrDraft = nil
                        lastCaptureOCRFailed = false
                        showConfirm = false
                    }
                )
            }
        }
        .photosPicker(isPresented: $showImagePicker, onPick: handlePickedPhoto)
    }

    private var captureControls: some View {
        HStack(spacing: 36) {
            Button {
                showImagePicker = true
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.textPrimary.opacity(0.85))
                    .frame(width: 52, height: 52)
                    .glassCard(cornerRadius: BCRadius.control)
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            .accessibilityLabel("Choose from library")

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                captureRequested = true
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.42), lineWidth: 3)
                        .frame(width: 94, height: 94)
                    Circle()
                        .strokeBorder(LinearGradient(
                            colors: [Color.white.opacity(0.65), Color.white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: 1.5)
                        .frame(width: 84, height: 84)
                    Circle()
                        .fill(Color.accentPrimary)
                        .frame(width: 68, height: 68)
                        .shadow(color: Color.black.opacity(0.42), radius: 16, y: 8)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.28), Color.clear],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 48
                            )
                        )
                        .frame(width: 68, height: 68)
                        .allowsHitTesting(false)
                }
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            .accessibilityLabel("Capture note")

            Spacer()

            Color.clear.frame(width: 52, height: 52)
        }
        .padding(.horizontal, BCSpacing.xxl)
        .padding(.bottom, BCSpacing.xl)
    }

    private var processingOverlay: some View {
        ZStack {
            Color.bgPrimary.opacity(0.85)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)

                Text("Reading your notes…")
                    .bcBody()
                    .foregroundStyle(Color.textSecond)
                Text("If this takes too long, you can cancel from the review screen and retake.")
                    .bcCaption()
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    private var captureRecoveryBanner: some View {
        let title = cameraSessionFailed ? "Camera unavailable" : "Capture issue"
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: cameraSessionFailed ? "camera.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary.opacity(0.9))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(captureUserMessage ?? "")
                        .bcCaption()
                        .foregroundStyle(Color.textSecond)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 12) {
                if cameraSessionFailed {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Open Settings")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    captureUserMessage = nil
                    cameraSessionFailed = false
                    cameraRelaunchToken += 1
                } label: {
                    Text(cameraSessionFailed ? "Try camera again" : "Dismiss")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.accentPrimary.opacity(0.35), in: RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSurface.opacity(0.92), in: RoundedRectangle(cornerRadius: BCRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BCRadius.panel, style: .continuous)
                .strokeBorder(Color.glassStroke, lineWidth: 1)
        )
    }

    private func handleCapture(_ imageData: Data) {
        captureSequence += 1
        let currentCaptureID = captureSequence
        capturedImage = imageData
        lastCaptureOCRFailed = false
        isProcessing = true

        Task {
            do {
                let draft = try await VisionOCRService.extractDraft(from: imageData)
                await MainActor.run {
                    guard currentCaptureID == captureSequence else { return }
                    extractedText = draft.text
                    ocrDraft = draft
                    let textEmpty = draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    lastCaptureOCRFailed = textEmpty
                    isProcessing = false
                    showConfirm = true
                }
            } catch {
                await MainActor.run {
                    guard currentCaptureID == captureSequence else { return }
                    extractedText = ""
                    ocrDraft = nil
                    lastCaptureOCRFailed = true
                    isProcessing = false
                    showConfirm = true
                }
            }
        }
    }

    private func handlePickedPhoto(_ data: Data?) {
        guard let data else { return }
        handleCapture(data)
    }
}

// MARK: - On-camera framing guide

private struct DocumentCaptureGuideOverlay: View {
    private let bracketLength: CGFloat = 28
    private let lineWidth: CGFloat = 2.5

    var body: some View {
        GeometryReader { geo in
            let sideInset = geo.size.width * 0.1
            let frameWidth = max(geo.size.width - sideInset * 2, 120)
            let frameHeight = min(frameWidth * 4.0 / 3.0, geo.size.height * 0.5)
            let origin = CGPoint(
                x: (geo.size.width - frameWidth) / 2,
                y: geo.size.height * 0.34 - frameHeight / 2
            )
            let frameRect = CGRect(origin: origin, size: CGSize(width: frameWidth, height: frameHeight))

            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [Color.black.opacity(0.52), Color.black.opacity(0.12), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 108)
                .allowsHitTesting(false)

                VStack {
                    Text("Fill the frame with your note")
                        .bcCaption()
                        .foregroundStyle(Color.textPrimary.opacity(0.9))
                        .padding(.top, geo.safeAreaInsets.top + 10)
                    Spacer()
                }
                .allowsHitTesting(false)

                BracketCornersPath(rect: frameRect, cornerLength: bracketLength)
                    .stroke(Color.white.opacity(0.58), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    .shadow(color: Color.black.opacity(0.35), radius: 4, y: 2)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
        }
    }
}

private struct BracketCornersPath: Shape {
    let rect: CGRect
    var cornerLength: CGFloat

    func path(in _: CGRect) -> Path {
        var p = Path()
        let r = rect
        let L = cornerLength
        let c = min(L, r.width / 2.2, r.height / 2.2)

        p.move(to: CGPoint(x: r.minX, y: r.minY + c))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.minY))

        p.move(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))

        p.move(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))

        p.move(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - c))

        return p
    }
}

// MARK: - Photos picker shim

extension View {
    func photosPicker(isPresented: Binding<Bool>, onPick: @escaping (Data?) -> Void) -> some View {
        self.sheet(isPresented: isPresented) {
            ImagePickerShim(onPick: onPick)
        }
    }
}

struct ImagePickerShim: UIViewControllerRepresentable {
    let onPick: (Data?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerShim
        init(_ p: ImagePickerShim) { parent = p }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let img = info[.originalImage] as? UIImage
            parent.onPick(img?.jpegData(compressionQuality: 0.9))
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onPick(nil)
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    @Binding var captureRequested: Bool
    @Binding var cameraSessionFailed: Bool
    let onCapture: (Data) -> Void
    let onSessionIssue: () -> Void
    let onCaptureFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCapture: onCapture,
            sessionFailed: $cameraSessionFailed,
            onSessionIssue: onSessionIssue,
            onCaptureFailure: onCaptureFailure
        )
    }

    func makeUIView(context: Context) -> CameraView {
        let view = CameraView()
        view.coordinator = context.coordinator
        view.onSessionFailed = { [weak coordinator = context.coordinator] in
            coordinator?.reportSessionFailed()
        }
        view.onCaptureHardwareFailure = { [weak coordinator = context.coordinator] in
            coordinator?.reportCaptureFailure()
        }
        view.startSession()
        return view
    }

    func updateUIView(_ uiView: CameraView, context: Context) {
        context.coordinator.sessionFailed = $cameraSessionFailed
        if captureRequested {
            uiView.capturePhoto()
            DispatchQueue.main.async { captureRequested = false }
        }
    }

    final class Coordinator {
        let onCapture: (Data) -> Void
        let onSessionIssue: () -> Void
        let onCaptureFailure: () -> Void
        var sessionFailed: Binding<Bool>

        init(
            onCapture: @escaping (Data) -> Void,
            sessionFailed: Binding<Bool>,
            onSessionIssue: @escaping () -> Void,
            onCaptureFailure: @escaping () -> Void
        ) {
            self.onCapture = onCapture
            self.sessionFailed = sessionFailed
            self.onSessionIssue = onSessionIssue
            self.onCaptureFailure = onCaptureFailure
        }

        func reportSessionFailed() {
            sessionFailed.wrappedValue = true
            onSessionIssue()
        }

        func reportCaptureFailure() {
            onCaptureFailure()
        }
    }
}

final class CameraView: UIView {
    var coordinator: CameraPreviewView.Coordinator?
    var onSessionFailed: (() -> Void)?
    var onCaptureHardwareFailure: (() -> Void)?
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput = AVCapturePhotoOutput()

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    func startSession() {
        let s = AVCaptureSession()
        s.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              s.canAddInput(input) else {
            DispatchQueue.main.async { self.onSessionFailed?() }
            return
        }

        s.addInput(input)
        if s.canAddOutput(photoOutput) { s.addOutput(photoOutput) }

        let layer = AVCaptureVideoPreviewLayer(session: s)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { s.startRunning() }
        session = s
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraView: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            DispatchQueue.main.async { self.onCaptureHardwareFailure?() }
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async { self.onCaptureHardwareFailure?() }
            return
        }
        coordinator?.onCapture(data)
    }
}
