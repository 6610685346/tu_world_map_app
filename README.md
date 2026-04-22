# 🏛️ TU World Map

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![MapLibre](https://img.shields.io/badge/MapLibre-212121?style=for-the-badge&logo=maplibre&logoColor=white)](https://maplibre.org)
[![SQLite](https://img.shields.io/badge/SQLite-07405E?style=for-the-badge&logo=sqlite&logoColor=white)](https://sqlite.org)

A premium, feature-rich navigation and campus exploration application designed specifically for **Thammasat University**. TU World Map provides students, staff, and visitors with a seamless way to navigate the campus, find buildings, and explore local points of interest.

---

## ✨ Key Features

### 🗺️ Advanced Campus Mapping
- **MapLibre GL Integration**: High-performance vector maps with custom "VersaTiles" styling.
- **Enhanced POIs**: Programmatic labels for bus stops, parking, shops, and campus landmarks at optimal zoom levels.
- **Building Highlights**: Detailed GeoJSON polygons for campus structures with dynamic color coding and stroke highlights.
- **Intelligent Camera Clamping**: Smart boundary constraints that adapt to your zoom level, ensuring the campus stays in focus.

### 🕹️ Racing-Game Style Mock GPS
- **Joystick Control**: Navigate the campus like a pro with a dedicated joystick interface.
- **Physics-Based Movement**: Realistic acceleration, braking, and steering for a unique campus exploration experience.
- **Snap-to-Path**: Smoothly transitions between real GPS data and university walkways.

### 🔍 Smart Discovery
- **Comprehensive Database**: SQLite-backed repository of all campus buildings and facilities.
- **Instant Search**: Find any location by name or category (Library, Canteen, Faculty, etc.).
- **Recent & Favorites**: Quick-access cards for your most-visited spots and bookmarked locations.

### 🎨 Premium UI/UX
- **Warm/Campus Design System**: A unified aesthetic featuring cream, rich browns, and primary reds that reflect the TU spirit.
- **Fluid Transitions**: Smooth animations for map panning, camera movements, and screen transitions.
- **Responsive Design**: Optimized layouts for both mobile and web platforms.

---

## 🚀 Tech Stack

- **Framework**: [Flutter](https://flutter.dev)
- **Mapping**: [MapLibre GL](https://pub.dev/packages/maplibre_gl) & [LatLong2](https://pub.dev/packages/latlong2)
- **Database**: [SQFlite](https://pub.dev/packages/sqflite)
- **Location Services**: [Geolocator](https://pub.dev/packages/geolocator)
- **Persistence**: [Shared Preferences](https://pub.dev/packages/shared_preferences)
- **Theming**: Custom "Warm/Campus" Design System

---

## 🛠️ Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-repo/tu_world_map_app.git
   cd tu_world_map_app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   # Run on mobile
   flutter run

   # Run on web
   flutter run -d chrome
   ```

---

## 📂 Project Structure

- `lib/screens/`: UI components for Map, Home, Search, Favorites, and Settings.
- `lib/services/`: Core logic for mapping, navigation, and data persistence.
- `lib/models/`: Data structures for Buildings, Locations, and Settings.
- `assets/styles/`: Custom map styling (VersaTiles).
- `assets/db/`: Pre-populated SQLite database for campus buildings.

---

## 👥 Development Team

1. **Athichart Penwong** (6610685015)
2. **Thawalporn Jindavaranon** (6610545029)
3. **Krittin Dansai** (6610685031)
4. **Natthasit Thitithammakun** (6610685155)
5. **Supawich Boonpraseart** (6610685346)

---

## 📝 License

This project is developed as part of a university project. All rights reserved by the development team.
