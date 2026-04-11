import SwiftUI
import AVFoundation

struct NoteCaptureView: View {
    @State private var capturedImage: Data?
    @State private var extractedText: String = ""
    @State private var isProcessing = false
    @State private var showConfirm = false
    @State private var showImagePicker = false
    @State private var captureRequested = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Camera fills full screen edge-to-edge
            CameraPreviewView(captureRequested: $captureRequested, onCapture: handleCapture)
                .ignoresSafeArea()

            // Controls float above tab bar — 83pt clears the custom tab bar on all iPhones
            captureControls

            // Processing overlay
            if isProcessing {
                processingOverlay
            }
        }
        .sheet(isPresented: $showConfirm) {
            if let data = capturedImage {
                OCRConfirmView(imageData: data, extractedText: extractedText) { _ in
                    capturedImage = nil
                    extractedText = ""
                }
            }
        }
        .photosPicker(isPresented: $showImagePicker, onPick: handlePickedPhoto)
    }

    private var captureControls: some View {
        HStack(spacing: 40) {
            // Photo library fallback
            Button {
                showImagePicker = true
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)

            Spacer()

            // Shutter
            Button { captureRequested = true } label: {
                Circle()
                    .fill(Color.white)
                    .frame(width: 68, height: 68)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 3)
                            .frame(width: 80, height: 80)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)

            Spacer()

            Color.clear.frame(width: 48, height: 48)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 90)
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

                Text("Extracting concepts…")
                    .bcBody()
                    .foregroundStyle(Color.textSecond)
            }
        }
    }

    private func handleCapture(_ imageData: Data) {
        capturedImage = imageData
        isProcessing = true

        Task {
            do {
                extractedText = try await VisionOCRService.extractText(from: imageData)
            } catch {
                extractedText = ""
            }
            await MainActor.run {
                isProcessing = false
                showConfirm = true
            }
        }
    }

    private func handlePickedPhoto(_ data: Data?) {
        guard let data else { return }
        handleCapture(data)
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
    let onCapture: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIView(context: Context) -> CameraView {
        let view = CameraView()
        view.coordinator = context.coordinator
        view.startSession()
        return view
    }

    func updateUIView(_ uiView: CameraView, context: Context) {
        if captureRequested {
            uiView.capturePhoto()
            DispatchQueue.main.async { captureRequested = false }
        }
    }

    final class Coordinator {
        let onCapture: (Data) -> Void
        init(onCapture: @escaping (Data) -> Void) { self.onCapture = onCapture }
    }
}

final class CameraView: UIView {
    var coordinator: CameraPreviewView.Coordinator?
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
              s.canAddInput(input) else { return }

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
        guard let data = photo.fileDataRepresentation() else { return }
        coordinator?.onCapture(data)
    }
}
