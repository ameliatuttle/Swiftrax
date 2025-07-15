import SwiftUI

// TEMPORARY TEST VIEW - Add this to test your API integration
// You can remove this once you've verified everything works

struct APITestView: View {
    @State private var testResults: [String] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("API Integration Test")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if isLoading {
                    ProgressView("Testing APIs...")
                        .padding()
                }
                
                VStack(spacing: 12) {
                    Button("Test USDA Search API") {
                        testUSDASearch()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Test Barcode API") {
                        testBarcodeSearch()
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Test Database Integration") {
                        testDatabaseIntegration()
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Clear Results") {
                        testResults = []
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(testResults.indices, id: \.self) { index in
                            Text(testResults[index])
                                .font(.caption)
                                .padding(.horizontal)
                        }
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("API Test")
        }
    }
    
    private func addResult(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        testResults.append("[\(timestamp)] \(message)")
    }
    
    private func testUSDASearch() {
        isLoading = true
        addResult("🌐 Testing USDA API with query 'apple'...")
        
        Task {
            do {
                let foods = try await APIManager.shared.searchByText("apple")
                await MainActor.run {
                    addResult("✅ USDA API Success: Found \(foods.count) foods")
                    if let firstFood = foods.first {
                        addResult("   First result: \(firstFood.name) - \(Int(firstFood.nutritionInfo.calories ?? 0)) cal")
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    addResult("❌ USDA API Error: \(error.localizedDescription)")
                    isLoading = false
                }
            }
        }
    }
    
    private func testBarcodeSearch() {
        isLoading = true
        addResult("📱 Testing Barcode API with Coca-Cola barcode...")
        
        Task {
            do {
                if let food = try await APIManager.shared.searchByBarcode("012000161155") {
                    await MainActor.run {
                        addResult("✅ Barcode API Success: Found \(food.name)")
                        addResult("   Calories: \(Int(food.nutritionInfo.calories ?? 0)), Serving: \(food.servingSize) \(food.servingSizeUnit)")
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        addResult("❌ Barcode API: No food found")
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    addResult("❌ Barcode API Error: \(error.localizedDescription)")
                    isLoading = false
                }
            }
        }
    }
    
    private func testDatabaseIntegration() {
        isLoading = true
        addResult("🗄️ Testing database integration...")
        
        // FIXED: Use the correct method name
        DatabaseManager.shared.searchFoodsWithFuzzyMatching(query: "chicken") { foods in
            self.addResult("✅ Database Integration: Found \(foods.count) total results")
            
            let localFoods = foods.filter { $0.source == "manual" }
            let apiFoods = foods.filter { $0.isFromAPI }
            
            self.addResult("   Local foods: \(localFoods.count)")
            self.addResult("   API foods: \(apiFoods.count)")
            
            self.isLoading = false
        }
    }
}

// Add this to your main app to access the test view:
// You can temporarily add a tab or navigation item to access this view

#Preview {
    APITestView()
}
