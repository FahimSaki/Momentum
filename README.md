# Momentum

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/images/momentum_app_logo_dark.png">
    <source media="(prefers-color-scheme: light)" srcset="assets/images/momentum_app_logo_light.png">
    <img src="assets/images/momentum_app_logo_dark.png" width="100" alt="Momentum Logo"/>
  </picture>
</p>

A modern habit tracking application built with Flutter that helps users build and maintain positive habits. Momentum features a hybrid database approach, combining local storage with cloud synchronization, and a clean, intuitive interface.

## 🌟 Features

- **Habit Management**
  - Create, edit, and delete habits
  - Mark habits as complete/incomplete
  - Animated transitions when completing habits
  - Organized view of completed and pending habits

- **Visual Progress Tracking**
  - Heat map visualization of habit completion patterns
  - Daily streak tracking
  - Historical data viewing

- **User Experience**
  - Clean, modern UI
  - Dark/Light theme support
  - Smooth animations
  - Responsive design
  - Offline capability

- **Data Management**
  - Cloud synchronization with Supabase
  - Secure data handling with Row Level Security (RLS)

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- [Flutter](https://flutter.dev/docs/get-started/install) (2.0 or higher)
- [Dart](https://dart.dev/get-dart) (2.12 or higher)
- [Git](https://git-scm.com/downloads)
- A code editor (preferably [VS Code](https://code.visualstudio.com/))

### Installation

1. Clone the repository:

```sh
git clone https://github.com/FahimSaki/Momentum.git
cd momentum
```

2. Install dependencies:

```sh
flutter pub get
```

3. Create a `.env` file in the root directory:

```sh
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

4. Run the app:

```sh
flutter run
```

## 📱 Usage

### Creating a Habit

1. Tap the + button in the bottom right corner
2. Enter the habit name
3. Tap "Save" to create the habit

### Completing a Habit

- Tap the checkbox next to a habit to mark it as complete
- Watch the smooth animation as it moves to the completed section

### Managing Habits

- Long press on a habit to edit its name
- Swipe left on a habit to delete it
- Use the dropdown to view completed habits

## 🏗️ Architecture

The project follows a clean architecture pattern:

```
lib/
├── components/          # Reusable UI components
├── database/            # Database related code
├── models/              # Data models
├── pages/               # App screens
├── theme/               # Theme configuration
└── util/                # Utility functions
```

## 🛠️ Built With

- [Flutter](https://flutter.dev/) - UI framework
- [Supabase](https://supabase.io/) - Backend as a Service
- [Provider](https://pub.dev/packages/provider) - State management
- [Flutter Heatmap Calendar](https://pub.dev/packages/flutter_heatmap_calendar) - Heat map visualization

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the **Apache License 2.0**.

You may:

- ✅ Use this software freely in personal and commercial projects  
- 🛠️ Modify and distribute it under the terms of the license  
- 🌍 Incorporate it into your applications  

Under the condition that you:

- 🔐 Include a copy of the Apache License 2.0 in any distribution  
- ✨ Provide proper attribution to the original author (Fahimuzzaman Saki)  
- 🚫 Do not use the trademarks, logos, or project name without permission  

> See the [LICENSE](LICENSE) file or visit [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) for more details.

---

## 🙏 Acknowledgments

- CS50 team for the incredible learning experience  
- Flutter team for the amazing framework  
- Supabase team for the powerful backend service  
- Isar Database team for the efficient local storage solution

## 📞 Contact

Fahimuzzaman Saki - [@FahimSaki](https://github.com/FahimSaki)

Project Link: [https://github.com/FahimSaki/Momentum](https://github.com/FahimSaki/Momentum)
