# Swiftrax 🍎

A clean, focused nutrition tracking app for iOS built with SwiftUI. No fitness features, no ads, no sponsored content—just simple, effective food logging.

## 📱 Features

### Core Functionality
- **🔍 Barcode Scanning**: Scan food barcodes using your camera to instantly log nutrition data
- **🔎 Smart Food Search**: Search for foods with automatic API fallback to OpenFoodFacts and local Database
- **✏️ Manual Food Entry**: Create custom foods with complete nutritional customization
- **🍳 Recipe Management**: Build recipes from ingredients with automatic nutrition calculation
- **📱 Offline-First**: Full functionality without internet connection using local SQLite database

### User Experience
- **⏰ Recent Foods**: Quick access to recently logged items
- **🍽️ Meal Organization**: Log foods to breakfast, lunch, dinner, or snacks
- **📏 Smart Units**: Flexible serving size units with automatic conversion
- **🌙 Dark/Light Themes**: System-aware theming with manual override

### Tracking & Analytics
- **⚙️ Customizable Tracking**: Choose which nutrients to monitor (calories, protein, carbs, fat, fiber, etc.)
- **📊 Daily Dashboard**: Visual nutrition summary with goal tracking
- **📈 History Charts**: View progress over daily, weekly, and monthly periods
- **🎯 Nutrition Goals**: Set and track personal nutrition targets

## 🛠 Tech Stack

- **Framework**: SwiftUI + iOS 15+
- **Database**: SQLite3 with thread-safe operations
- **Camera**: AVFoundation for barcode scanning
- **APIs**: OpenFoodFacts API

## 📁 Project Structure

```
Swiftrax/
├── Models/            # Core data models (Food, FoodEntry, Recipe, etc.)
├── Networking/        # All things API
├── Persistance/       # All things database
├── Utilities/         # Swift extensions and other helpers
├── Views/             # SwiftUI views organized by feature
├── ContentView/       # Main SwiftUI view features
├── SwiftraxApp.swift  # Entrypoint into the app
```

## 🔧 Key Components

- **DatabaseManager**: Thread-safe SQLite operations with duplicate prevention
- **APIManager**: Handles OpenFoodFacts and USDA API integration
- **BarcodeScannerUtility**: Camera-based barcode detection
- **UnitConverter**: Flexible measurement unit conversion system
- **BasicFoodsSeeder**: Populates database with common foods

## ✅ Requirements Met

- [x] Barcode scanning with camera integration
- [x] Food search with API fallback
- [x] Manual food entry with full customization
- [x] Local SQLite storage with offline functionality
- [x] Recipe creation and management
- [x] Nutrition tracking with customizable metrics
- [x] Data visualization and goal tracking
- [x] Dark/light theme support

## 🚀 Getting Started

1. Clone the repository
   ```bash
   git clone https://github.com/ameliatuttle/Swiftrax
   ```
2. Open `Swiftrax.xcodeproj` in Xcode 15+
3. Build and run on iOS device or simulator
4. Grant camera permissions for barcode scanning

## 🗄️ Database Schema

The app uses SQLite with the following main tables:

| Table | Description |
|-------|-------------|
| **Foods** | Stores food items with nutrition data |
| **FoodEntries** | Daily food logs with quantities and meal types |
| **Recipes** | User-created recipes with serving information |
| **RecipeIngredients** | Recipe components and quantities |
| **UserSettings** | App preferences and nutrition goals |

## 🌐 API Integration

- **OpenFoodFacts**: Primary source for barcode-based food data
- Graceful fallback handling with offline-first architecture

## 📸 Screenshots

| Dashboard | Food Search | Recipe Creation | Manual Entry | History | Settings | App Logo |
|-----------|-------------|-----------------|--------------|---------|----------|----------|
| ![Dashboard](screenshots/Dashboard.png) | ![Search](screenshots/SearchLog.png) | ![Recipe](screenshots/Recipes.png) | ![Manual](screenshots/Manual.png) | ![History](screenshots/History.png) | ![Settings](screenshots/Settings.png) | ![AppLogo](screenshots/AppLogo.png) |

(App logo curtesy of Brittney Hanson)

## 🙏 Acknowledgments

- [OpenFoodFacts](https://world.openfoodfacts.org/) for their comprehensive food database
- [USDA FoodData Central](https://fdc.nal.usda.gov/) for nutrition data
- Apple's SwiftUI team for the excellent framework

---

*Built as a capstone project focusing on clean architecture, user experience, and practical nutrition tracking without the bloat of typical fitness apps.*

**Author**: Amelia Tuttle  
**Date**: Jully 2025
