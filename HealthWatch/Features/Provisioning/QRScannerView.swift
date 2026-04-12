import SwiftUI
import AVFoundation

/// SwiftUI wrapper for AVFoundation QR code scanner
struct QRScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCodeScanned = onCodeScanned
        controller.onError = onError
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            onError?("Camera not available")
            return
        }

        guard session.canAddInput(input) else {
            onError?("Cannot add camera input")
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onError?("Cannot add metadata output")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func stopScanning() {
        captureSession?.stopRunning()
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let payload = object.stringValue else {
            return
        }

        // Validate QR payload contains a HealthWatch device code
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let app = json["app"] as? String, app == "healthwatch",
              let version = json["version"] as? Int, version == 1,
              let _ = json["deviceId"] as? String else {
            return // Not a valid HealthWatch QR — ignore silently
        }

        hasScanned = true
        stopScanning()
        onCodeScanned?(payload)
    }
}
