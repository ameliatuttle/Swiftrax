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
    @Published var lastDetectedBarcode: String = ""
    
    // FIXED: Thread-safe scanning state
    private var canScan = true
    private let scanningQueue = DispatchQueue(label: "com.swiftrax.barcode.scanning", qos: .userInitiated)
    private var isProcessingBarcode = false
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        print("📱 Setting up camera capture session...")
        
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else {
            DispatchQueue.main.async {
                self.delegate?.didFailWithError(ScannerError.noCameraAvailable)
            }
            return
        }
        
        captureSession.sessionPreset = .high
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            DispatchQueue.main.async {
                self.delegate?.didFailWithError(ScannerError.noCameraAvailable)
            }
            return
        }
        
        self.videoCaptureDevice = videoCaptureDevice
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            DispatchQueue.main.async {
                self.delegate?.didFailWithError(error)
            }
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            print("📱 Video input added successfully")
        } else {
            DispatchQueue.main.async {
                self.delegate?.didFailWithError(ScannerError.invalidInput)
            }
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            // FIXED: Set delegate on main queue to avoid thread issues
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean8, .ean13, .pdf417, .qr, .aztec, .code128, .code93, .code39, .upce
            ]
            
            print("📱 Metadata output configured")
        } else {
            DispatchQueue.main.async {
                self.delegate?.didFailWithError(ScannerError.invalidOutput)
            }
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
    
    // FIXED: Thread-safe scanning control
    func startScanning() {
        guard let captureSession = captureSession else { return }
        
        scanningQueue.async {
            // RESET: Clear previous barcode and enable scanning
            self.canScan = true
            self.isProcessingBarcode = false
            
            DispatchQueue.main.async {
                self.lastDetectedBarcode = ""
            }
            
            if !captureSession.isRunning {
                captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isScanning = true
                    print("📱 Camera scanning started")
                }
            }
        }
    }
    
    // FIXED: Thread-safe scanning control
    func stopScanning() {
        guard let captureSession = captureSession else { return }
        
        scanningQueue.async {
            // DISABLE: Stop scanning
            self.canScan = false
            self.isProcessingBarcode = false
            
            if captureSession.isRunning {
                captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isScanning = false
                    print("📱 Camera scanning stopped")
                }
            }
        }
    }
    
    func toggleTorch() {
        guard let device = videoCaptureDevice, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            DispatchQueue.main.async {
                if self.torchEnabled {
                    device.torchMode = .off
                    self.torchEnabled = false
                    print("📱 Torch turned OFF")
                } else {
                    try? device.setTorchModeOn(level: 1.0)
                    self.torchEnabled = true
                    print("📱 Torch turned ON")
                }
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

// FIXED: Thread-safe barcode detection with proper main thread handling
extension BarcodeScannerUtility: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        // Check if we can still scan (already on main thread)
        guard canScan && !isProcessingBarcode else {
            print("📱 Scanning disabled, ignoring detection (canScan: \(canScan), isProcessing: \(isProcessingBarcode))")
            return
        }
        
        guard let metadataObject = metadataObjects.first else { return }
        guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
        guard let stringValue = readableObject.stringValue else { return }
        
        // FIXED: Immediate processing flag to prevent race conditions
        isProcessingBarcode = true
        canScan = false
        
        print("📱 Barcode detected: \(stringValue)")
        
        // Haptic feedback (already on main thread)
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        // FIXED: Update published property on main thread (we're already on main thread)
        print("📱 📡 PUBLISHING barcode to @Published property: \(stringValue)")
        self.lastDetectedBarcode = stringValue
        
        // FIXED: Call delegate on main thread (we're already on main thread)
        print("📱 📞 CALLING delegate with barcode: \(stringValue)")
        self.delegate?.didScanBarcode(stringValue)
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
