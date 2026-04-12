import SwiftUI
import AVFoundation
import os

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
        Logger.qrScanner.info("Setting up camera for QR scanning")
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            Logger.qrScanner.error("Camera not available or failed to create input")
            onError?("Camera not available")
            return
        }

        guard session.canAddInput(input) else {
            Logger.qrScanner.error("Cannot add camera input to session")
            onError?("Cannot add camera input")
            return
        }
        session.addInput(input)
        Logger.qrScanner.debug("Camera input added")

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            Logger.qrScanner.error("Cannot add metadata output to session")
            onError?("Cannot add metadata output")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        Logger.qrScanner.debug("Metadata output configured for QR codes")

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            Logger.qrScanner.info("Capture session started")
        }
    }

    func stopScanning() {
        Logger.qrScanner.info("Stopping capture session")
        captureSession?.stopRunning()
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned else {
            Logger.qrScanner.debug("Ignoring metadata — already scanned")
            return
        }

        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr else {
            Logger.qrScanner.debug("Metadata received but no QR code object (count: \(metadataObjects.count))")
            return
        }

        guard let payload = object.stringValue else {
            Logger.qrScanner.warning("QR code detected but stringValue is nil")
            return
        }

        Logger.qrScanner.info("QR code scanned, raw payload: \(payload)")

        guard let data = payload.data(using: .utf8) else {
            Logger.qrScanner.warning("Payload is not valid UTF-8")
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Logger.qrScanner.warning("Payload is not valid JSON: \(payload)")
            return
        }

        guard let app = json["app"] as? String, app == "healthwatch" else {
            Logger.qrScanner.info("QR code is not a HealthWatch code (app: \(json["app"] as? String ?? "missing"))")
            return
        }

        guard let version = json["version"] as? Int, version == 1 else {
            Logger.qrScanner.warning("Unsupported QR version: \(String(describing: json["version"]))")
            return
        }

        guard let deviceId = json["deviceId"] as? String else {
            Logger.qrScanner.warning("QR payload missing deviceId")
            return
        }

        Logger.qrScanner.info("Valid HealthWatch QR code — deviceId: \(deviceId)")
        hasScanned = true
        stopScanning()
        onCodeScanned?(payload)
    }
}
