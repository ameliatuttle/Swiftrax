import AVFoundation
import UIKit

// SIMPLIFIED: Keep protocol for compatibility but add @Published approach
protocol BarcodeScannerDelegate: AnyObject {
    func didScanBarcode(_ barcode: String)
    func didFailWithError(_ error: Error)
}

class BarcodeScannerUtility: NSObject, ObservableObject {
    weak var delegate: BarcodeScannerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoCaptureDevice: AVCaptureDevice?
    
    @Published var isScanning = false
    @Published var torchEnabled = false
    @Published var lastDetectedBarcode: String = "" // NEW: Published property for boolean approach
    
    private var canScan = true
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        print("📱 Setting up camera capture session...")
        
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else {
            delegate?.didFailWithError(ScannerError.noCameraAvailable)
            return
        }
        
        captureSession.sessionPreset = .high
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            delegate?.didFailWithError(ScannerError.noCameraAvailable)
            return
        }
        
        self.videoCaptureDevice = videoCaptureDevice
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didFailWithError(error)
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            print("📱 Video input added successfully")
        } else {
            delegate?.didFailWithError(ScannerError.invalidInput)
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean8, .ean13, .pdf417, .qr, .aztec, .code128, .code93, .code39, .upce
            ]
            
            print("📱 Metadata output configured")
        } else {
            delegate?.didFailWithError(ScannerError.invalidOutput)
            return
        }
        
        configureCameraSettings()
        print("📱 Camera capture session setup complete")
    }
    
    private func configureCameraSettings() {
        guard let device = videoCaptureDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            device.unlockForConfiguration()
            print("📱 Camera settings configured")
        } catch {
            print("📱 Failed to configure camera settings: \(error)")
        }
    }
    
    func startScanning() {
        guard let captureSession = captureSession else { return }
        
        // RESET: Clear previous barcode and enable scanning
        canScan = true
        lastDetectedBarcode = ""
        
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                captureSession.startRunning()
                DispatchQueue.main.async {
                    self?.isScanning = true
                    print("📱 Camera scanning started")
                }
            }
        }
    }
    
    func stopScanning() {
        guard let captureSession = captureSession else { return }
        
        // DISABLE: Stop scanning
        canScan = false
        
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                captureSession.stopRunning()
                DispatchQueue.main.async {
                    self?.isScanning = false
                    print("📱 Camera scanning stopped")
                }
            }
        }
    }
    
    func toggleTorch() {
        guard let device = videoCaptureDevice, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if torchEnabled {
                device.torchMode = .off
                torchEnabled = false
                print("📱 Torch turned OFF")
            } else {
                try device.setTorchModeOn(level: 1.0)
                torchEnabled = true
                print("📱 Torch turned ON")
            }
            
            device.unlockForConfiguration()
        } catch {
            print("📱 Torch error: \(error)")
        }
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let captureSession = captureSession else { return nil }
        
        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
            print("📱 Preview layer created")
        }
        
        return previewLayer
    }
}

// FIXED: Ensure delegate is called AND published property is updated
extension BarcodeScannerUtility: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        // Check if we can still scan
        guard canScan else {
            print("📱 Scanning disabled, ignoring detection")
            return
        }
        
        guard let metadataObject = metadataObjects.first else { return }
        guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
        guard let stringValue = readableObject.stringValue else { return }
        
        // DISABLE further scanning immediately
        canScan = false
        
        print("📱 Barcode detected: \(stringValue)")
        
        // Haptic feedback
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        // BOTH approaches: Update published property AND call delegate
        DispatchQueue.main.async {
            print("📱 📡 PUBLISHING barcode to @Published property: \(stringValue)")
            self.lastDetectedBarcode = stringValue
            
            print("📱 📞 CALLING delegate with barcode: \(stringValue)")
            self.delegate?.didScanBarcode(stringValue)
        }
    }
}

enum ScannerError: LocalizedError {
    case noCameraAvailable
    case invalidInput
    case invalidOutput
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noCameraAvailable:
            return "No camera available"
        case .invalidInput:
            return "Invalid camera input"
        case .invalidOutput:
            return "Invalid camera output"
        case .permissionDenied:
            return "Camera permission denied"
        }
    }
}
