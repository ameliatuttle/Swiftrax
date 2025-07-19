import AVFoundation
import UIKit

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
    
    private var canScan = true
    private let scanningQueue = DispatchQueue(label: "com.swiftrax.barcode.scanning", qos: .userInitiated)
    private var isProcessingBarcode = false
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    // Configures camera capture session for barcode scanning
    private func setupCaptureSession() {
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
        } else {
            DispatchQueue.main.async {
                self.delegate?.didFailWithError(ScannerError.invalidInput)
            }
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean8, .ean13, .pdf417, .qr, .aztec, .code128, .code93, .code39, .upce
            ]
        } else {
            DispatchQueue.main.async {
                self.delegate?.didFailWithError(ScannerError.invalidOutput)
            }
            return
        }
        
        configureCameraSettings()
        print("Camera ready for barcode scanning")
    }
    
    // Optimizes camera focus and exposure settings
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
        } catch {
            print("Failed to configure camera: \(error)")
        }
    }
    
    func startScanning() {
        guard let captureSession = captureSession else { return }
        
        scanningQueue.async {
            self.canScan = true
            self.isProcessingBarcode = false
            
            DispatchQueue.main.async {
                self.lastDetectedBarcode = ""
            }
            
            if !captureSession.isRunning {
                captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isScanning = true
                }
            }
        }
    }
    
    func stopScanning() {
        guard let captureSession = captureSession else { return }
        
        scanningQueue.async {
            self.canScan = false
            self.isProcessingBarcode = false
            
            if captureSession.isRunning {
                captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isScanning = false
                }
            }
        }
    }
    
   func toggleTorch() {
       guard let device = videoCaptureDevice, device.hasTorch else { return }
       
       do {
           try device.lockForConfiguration()
           
           if self.torchEnabled {
               device.torchMode = .off
               self.torchEnabled = false
           } else {
               try device.setTorchModeOn(level: 1.0)
               self.torchEnabled = true
           }

           device.unlockForConfiguration()
       } catch {
           print("Torch error: \(error)")
       }
   }

    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let captureSession = captureSession else { return nil }
        
        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
        }
        
        return previewLayer
    }
}

extension BarcodeScannerUtility: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        guard canScan && !isProcessingBarcode else { return }
        guard let metadataObject = metadataObjects.first else { return }
        guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
        guard let stringValue = readableObject.stringValue else { return }
        
        isProcessingBarcode = true
        canScan = false
        
        print("Barcode detected: \(stringValue)")
        
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        self.lastDetectedBarcode = stringValue
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
