# Prompter (Суфлёр)

macOS-приложение (SwiftUI, macOS 26+), которое подсказывает слова и фразы во время разговора на иностранном языке. Описание, запуск и приватность — в `README.md`.

- Общаться с пользователем по-русски.
- Проект генерируется из `project.yml` командой `xcodegen generate`. `.xcodeproj` руками не правим и не коммитим.
- Стек нативный (Swift), а не TypeScript из глобальных правил: захват системного звука (ScreenCaptureKit), SpeechAnalyzer, Foundation Models и окно поверх созвона доступны только из нативного кода.
- Чистая логика живёт в `Prompter/Core` и покрыта тестами (Swift Testing) в `PrompterTests`. Новую логику кладём туда же и тестируем; платформенный код (аудио, речь, UI) — тонкой обёрткой вокруг Core.
- Claude вызывается через сырой URLSession (`AI/ClaudeClient.swift`), потому что официального Swift SDK нет. Модель по умолчанию — `claude-opus-5-5` с `effort: low` и `fallbacks: "default"`.
- Проверка: `xcodebuild test -project Prompter.xcodeproj -scheme Prompter -destination 'platform=macOS' -derivedDataPath build`.
