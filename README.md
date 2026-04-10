# Daemon Protocol

[![Build Status](https://img.shields.io/github/actions/workflow/status/fikriaf/daemon-flutter/build-apk.yml?branch=main&style=flat-square)](https://github.com/fikriaf/daemon-flutter/actions)
[![Release](https://img.shields.io/github/v/release/fikriaf/daemon-flutter?style=flat-square)](https://github.com/fikriaf/daemon-flutter/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg?style=flat-square&logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-green?style=flat-square)](#)
[![License](https://img.shields.io/github/license/fikriaf/daemon-flutter?style=flat-square)](https://github.com/fikriaf/daemon-flutter/blob/main/LICENSE)

Daemon Protocol is a mobile application built with Flutter, serving as a gateway to interact with automated MCP (Model Context Protocol) agents. It provides secure authentication via traditional methods and Web3 wallet integration, allowing users to seamlessly interact with AI agents and blockchain infrastructure.

## Key Features

*   **Hybrid Authentication**: Support for both standard Email/Password authentication and Solana Mobile Wallet Adapter (MWA) signature verification.
*   **Agent Integration**: Direct interface to communicate with and manage MCP-enabled AI agents.
*   **Security Protocol**: Robust session handling, dynamic API key generation, and secure local storage.
*   **Data Visualization**: Integrated markdown rendering and interactive graph visualization modules.
*   **Modern Architecture**: Built using `flutter_riverpod` for state management and `go_router` for structured routing.

## Prerequisites

Before building the project, ensure you have the following installed:
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.10.8 or higher)
*   [Android Studio](https://developer.android.com/studio) (for Android build tools)
*   Java Development Kit (JDK 17 recommended)

## Installation and Setup

1.  **Clone the repository**
    ```bash
    git clone https://github.com/fikriaf/daemon-flutter.git
    cd daemon-flutter/mobile
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Run the Application**
    Connect a physical Android device or start an emulator, then run:
    ```bash
    flutter run
    ```

## Building for Production

This repository is configured with GitHub Actions to automatically build and publish release APKs upon pushes to the `main` branch. 

To build the APK manually in your local environment:

```bash
cd mobile
flutter build apk --release
```
The compiled APK will be available in `mobile/build/app/outputs/flutter-apk/app-release.apk`.

## Project Structure

The Flutter application code is contained within the `mobile/` directory:

*   `lib/config/` - Core configuration and API base setup.
*   `lib/routes/` - Navigation and router definitions using `go_router`.
*   `lib/screens/` - Primary UI views and pages.
*   `lib/services/` - Business logic, API integration, auth state, and wallet services.
*   `lib/widgets/` - Reusable UI components.

## License

This project is open-sourced under the MIT License. See the [LICENSE](LICENSE) file for more details.