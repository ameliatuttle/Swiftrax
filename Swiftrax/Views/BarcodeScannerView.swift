import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    let onBarcodeScanned: (String) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject private var scanner = BarcodeScannerUtility()
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var hasScanned = false
    @State private var isProcessing = false
    @State private var scannedBarcode: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                CameraViewRepresentable(scanner: scanner)
                    .ignoresSafeArea()
                
                // Processing overlay
                if isProcessing {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Barcode detected!")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Passing to search...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Overlay UI
                VStack {
                    Spacer()
                    
                    if !isProcessing {
                        ScanningFrameWithAnimation()
                    }
                    
                    Spacer()
                    
                    if !isProcessing {
                        HStack(spacing: 40) {
                            Button("Cancel") {
                                dismissSafely()
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            
                            Button("Flash") {
                                scanner.toggleTorch()
                            }
                            .foregroundColor(scanner.torchEnabled ? .yellow : .white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                        }
                        .padding(.bottom, 40)
                    } else {
                        Button("Cancel") {
                            dismissSafely()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupScanner()
                requestCameraPermission()
            }
            .onDisappear {
                scanner.stopScanning()
            }
            .onChange(of: scanner.lastDetectedBarcode) { barcode in
                handleBarcodeDetected(barcode)
            }
        }
    }
    
    // Processes detected barcode and prevents duplicate scans
    private func handleBarcodeDetected(_ barcode: String) {
        guard !barcode.isEmpty && !hasScanned && !isProcessing else { return }
        
        hasScanned = true
        isProcessing = true
        scannedBarcode = barcode
        
        scanner.stopScanning()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.async {
            self.onBarcodeScanned(barcode)
            self.dismissSafely()
        }
    }
    
    // Safely dismisses the scanner view
    private func dismissSafely() {
        scanner.stopScanning()
        
        DispatchQueue.main.async {
            self.presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func setupScanner() {
        // Scanner setup is handled by onChange
    }
    
    // Requests camera permission and starts scanning
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    self.scanner.startScanning()
                } else {
                    self.errorMessage = "Camera access required"
                    self.showingError = true
                }
            }
        }
    }
}

struct ScanningFrameWithAnimation: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Corner brackets
            VStack {
                HStack {
                    CornerBracket(position: .topLeft)
                    Spacer()
                    CornerBracket(position: .topRight)
                }
                Spacer()
                HStack {
                    CornerBracket(position: .bottomLeft)
                    Spacer()
                    CornerBracket(position: .bottomRight)
                }
            }
            .frame(width: 250, height: 150)
            
            // Animated scanning line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .green, .green, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 230, height: 2)
                .offset(y: isAnimating ? 65 : -65)
                .animation(
                    Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
            
            VStack {
                Spacer()
                Text("Position barcode within frame")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                Spacer()
                    .frame(height: 20)
            }
        }
    }
}

struct CornerBracket: View {
    enum Position {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    let position: Position
    
    var body: some View {
        ZStack {
            switch position {
            case .topLeft:
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: 20, height: 3)
                        Spacer()
                    }
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: 3, height: 20)
                        Spacer()
                    }
                    Spacer()
                }
            case .topRight:
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .frame(width: 20, height: 3)
                    }
                    HStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .frame(width: 3, height: 20)
                    }
                    Spacer()
                }
            case .bottomLeft:
                VStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: 3, height: 20)
                        Spacer()
                    }
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: 20, height: 3)
                        Spacer()
                    }
                }
            case .bottomRight:
                VStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .frame(width: 3, height: 20)
                    }
                    HStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .frame(width: 20, height: 3)
                    }
                }
            }
        }
        .foregroundColor(.green)
        .frame(width: 23, height: 23)
    }
}

struct CameraViewRepresentable: UIViewRepresentable {
    let scanner: BarcodeScannerUtility
    
    func makeUIView(context: Context) -> CameraDisplayView {
        let view = CameraDisplayView()
        
        if let previewLayer = scanner.getPreviewLayer() {
            view.setupCamera(with: previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: CameraDisplayView, context: Context) {
        uiView.updateCameraFrame()
    }
}

class CameraDisplayView: UIView {
    private var cameraLayer: AVCaptureVideoPreviewLayer?
    
    func setupCamera(with layer: AVCaptureVideoPreviewLayer) {
        cameraLayer?.removeFromSuperlayer()
        
        cameraLayer = layer
        layer.frame = bounds
        layer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(layer)
    }
    
    func updateCameraFrame() {
        guard let cameraLayer = cameraLayer else { return }
        cameraLayer.frame = bounds
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateCameraFrame()
    }
}
