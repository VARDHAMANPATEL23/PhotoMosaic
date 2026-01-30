# 📸 Local Photomosaic Generator

A privacy-focused, cross-platform Flutter application that creates stunning photomosaics from your personal photo library.

This app runs entirely on your device (Linux Desktop or Web Browser). It analyzes your photos locally, calculates their average colors, and stitches them together to recreate a target portrait—without ever uploading your data to a cloud server.

## ✨ Features

- **🔒 100% Local & Private**: No cloud processing. Your photos never leave your device.
- **🖥️ Cross-Platform**: Optimized for Linux Desktop, Windows Desktop and Web, with architecture ready for Mobile.
- **📦 Smart Storage (Hive)**: Uses a high-performance NoSQL database to store processed image tiles efficiently.
- **⚡ Multi-Threaded**: Heavy image processing runs in background Isolates, keeping the UI smooth.
- **🧠 Advanced Mosaic Algorithm**:
    - **Adaptive Tile Sizing**: Uses local variance analysis to use smaller tiles for details (eyes, text) and larger tiles for flat areas.
    - **Smart Tinting**: Subtly tints tiles to better match the target processing without losing the original image authenticity.
    - **Dynamic Rotation**: Slightly rotates tiles for a more organic, natural look.
- **🌙 Dynamic Theming**: Beautiful UI built with **Shadcn UI**, featuring seamless light/dark mode switching.
- **💾 Save & Export**: Export your final high-resolution mosaic to your local file system.

## 🛠️ Tech Stack

- **Framework**: Flutter (Dart)
- **UI Component Library**: [shadcn_ui](https://pub.dev/packages/shadcn_ui) (Port of shadcn/ui to Flutter)
- **State Management**: provider
- **Database**: hive (Fast, lightweight NoSQL)
- **Image Processing**: image (Pure Dart library for resizing/encoding)
- **File I/O**: file_picker, path_provider, cross_file

## 📂 Project Structure

The project follows a Clean Architecture approach to separate logic from UI.

```text
lib/
├── core/
│   ├── image_processor.dart   # Logic to compress images & calculate avg color
│   ├── mosaic_generator.dart  # The Algorithm (Runs in background Isolate)
│   └── storage/               # Abstracts storage (Hive implementation)
├── models/
│   └── tile_image.dart        # Hive Database Model
├── providers/
│   ├── gallery_provider.dart  # State Management (Uploads, Progress, Logic)
│   └── theme_provider.dart    # Theme State Management (Light/Dark mode)
├── screens/
│   └── home_screen.dart       # Main User Interface
└── main.dart                  # App Entry Point & Configuration
```

## 🚀 Installation & Setup Guide

Follow these steps to set up the project on your local machine.

### 1. Prerequisites

Ensure you have the following installed:

- **Flutter SDK** (Version 3.10+)
- **Dart SDK**

### 2. Linux Build Dependencies (Crucial for Ubuntu/Debian)

If you are running on Linux, you must install the C++ and GTK development headers, plus the LLVM linker (`lld`) to avoid build errors.

Run this command in your terminal:

```bash
sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev lld
```

### 3. Clone & Install Dependencies

Navigate to the project folder and install the Dart packages:

```bash
# Get dependencies
flutter pub get
```

### 4. Code Generation (Required)

This project uses Hive, which requires a generated "Adapter" to store custom objects. You must run this command before the app will work:

```bash
dart run build_runner build --delete-conflicting-outputs
```

> **Note**: If you skip this step, the app will crash with an error like `TileImageAdapter not found`.

## ▶️ How to Run

### 🐧 Run on Linux Desktop (Recommended)

This offers the best performance and access to the local file system.

```bash
flutter run -d linux
```

### 🌐 Run on Web (Chrome)

Useful for quick testing without compiling native code.
_Note: Web version security restrictions may prevent displaying local file paths in the gallery grid (showing colors instead)._

```bash
flutter run -d chrome
```

## 📖 Usage Manual

1.  **Add Tiles (Source Images)**:
    - Click the **"Upload Images"** button.
    - Select 200+ images from your computer.
    - _Tip: The more images you provide, the detailed the result will be._
    - Wait for the Progress Bar to finish processing.

2.  **Generate Mosaic**:
    - Click the **"Generate Mosaic"** button (Wand icon) at the bottom right.
    - Select a **Target Image** (The portrait you want to recreate).
    - Wait for the generation process to complete (this happens in the background).
    - _Note: Ensure you have at least 10 images loaded before generating._

3.  **Save Result**:
    - An interactive window will pop up with the result.
    - Click the **"Save"** button to export the mosaic as a PNG file.

4.  **Manage Library**:
    - Use the **Trash bin** icon in the app bar to clear your library and start fresh.
    - Toggle **Dark/Light Mode** using the Sun/Moon icon in the app bar.

## ⚠️ Troubleshooting

### `failed to find any of [ld.lld, ld]`

> **Solution**: You are missing the linker. Run this command:
>
> ```bash
> sudo apt-get install lld
> ```

### `TileImageAdapter not found`

> **Solution**: You forgot to generate database code. Run this command:
>
> ```bash
> dart run build_runner build
> ```

### `Generation Error: object is unsendable`

> **Solution**: The background thread tried to touch the database. Ensure you are using the latest `mosaic_generator.dart`.

### `CMake Error: gtk+-3.0 not found`

> **Solution**: Missing Linux headers. Run the `sudo apt-get install ...` command listed in **Section 2 (Linux Build Dependencies)**.
