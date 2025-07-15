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
    @State private var scannedBarcode: String = "" // NEW: Track scanned barcode
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera Preview
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
                        
                        Text("Looking up product...")
                            .font(.headline)
                            .foregroundColor(.white)
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
                                scanner.stopScanning()
                                presentationMode.wrappedValue.dismiss()
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
            // NEW: Watch for barcode detection
            .onChange(of: scanner.lastDetectedBarcode) { barcode in
                guard !barcode.isEmpty && !hasScanned && !isProcessing else { return }
                
                print("📱 🔥 BOOLEAN TRIGGER: Barcode detected: \(barcode)")
                handleBarcodeDetected(barcode)
            }
        }
    }
    
    // NEW: Handle barcode detection with boolean approach
    private func handleBarcodeDetected(_ barcode: String) {
        hasScanned = true
        isProcessing = true
        scannedBarcode = barcode
        
        print("📱 ✅ BOOLEAN CALLBACK: Processing barcode: \(barcode)")
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Stop scanning
        scanner.stopScanning()
        
        // Call the SearchLogView callback
        print("📱 📞 BOOLEAN: Calling SearchLogView callback...")
        onBarcodeScanned(barcode)
        
        // Dismiss after callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("📱 🚪 BOOLEAN: Dismissing scanner...")
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func setupScanner() {
        print("📱 🔧 Setting up scanner with boolean approach...")
        // No delegate needed - we'll use onChange
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    scanner.startScanning()
                    print("📱 Camera permission granted, starting scan")
                } else {
                    errorMessage = "Camera access required"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Scanning Frame with Animation (unchanged)
struct ScanningFrameWithAnimation: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Main scanning frame
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 250, height: 150)
            
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
            
            // The cool green scanning line animation
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
            
            // Instruction text
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

// MARK: - Corner Brackets (unchanged)
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

// MARK: - Camera View (unchanged)
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
        
        print("📱 Camera layer added to view")
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

#Preview {
    BarcodeScannerView { barcode in
        print("Scanned: \(barcode)")
    }
}
