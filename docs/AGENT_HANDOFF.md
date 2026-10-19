# Суфлёр (Prompter): задание для агента — словарь к созвону

Прочитай этот файл целиком, затем `README.md` и `CLAUDE.md` в корне репозитория. С пользователем общайся по-русски.

## Что это
Нативное macOS-приложение (Swift/SwiftUI, macOS 26+). Слушает микрофон и звук созвона, распознаёт речь на устройстве (SpeechAnalyzer). Когда пользователь запинается посреди фразы на английском, показывает облако слов и готовые продолжения фразы от LLM (OpenRouter `anthropic/claude-haiku-5.5` или Claude). Контекст для подсказок: описание проекта, глоссарий и документы (локальный RAG).

- Репозиторий: https://github.com/aleksabramov77/prompter-macos (личный аккаунт, см. правила git ниже)
- Локальная копия: `~/Projects/My/Prompter`
- **Работать от ветки `feature/openrouter`** (PR #1, может быть ещё не слит в `main`). Установленное приложение собрано из неё.

## Сборка и запуск
```bash
cd ~/Projects/My/Prompter
git fetch origin && git switch feature/openrouter && git pull
xcodegen generate                       # .xcodeproj генерируется, руками не правим
xcodebuild test -project Prompter.xcodeproj -scheme Prompter -destination 'platform=macOS' -derivedDataPath build
xcodebuild build -project Prompter.xcodeproj -scheme Prompter -destination 'platform=macOS' -derivedDataPath build
# установить и запустить:
pkill -f "/Applications/Prompter.app/Contents/MacOS/Prompter"; rm -rf /Applications/Prompter.app
cp -R build/Build/Products/Debug/Prompter.app /Applications/ && open /Applications/Prompter.app
```
Сейчас проходят 42 теста. Сборка подписана ad-hoc, поэтому после переустановки macOS может заново спросить доступ к микрофону и записи экрана. Нажимает пользователь.

## Задача 1: словарь к созвону (без изменений кода)
Узнай у пользователя тему созвона, собеседников и проект. Подготовь:

1. **Глоссарий**: по одной паре на строку, `русский термин = english term` (разделители `=`, ` — `, ` - `, Tab; строки с `#` — комментарии). Сюда идут слова, на которых пользователь может запнуться: термины проекта, глаголы для статуса задач, связки («to be honest», «the thing is», «let me rephrase»). Разумный объём — 50–150 строк.
2. **Описание проекта**: 1–3 абзаца на английском. Что за проект, роль пользователя, текущие задачи и проблемы, о чём будет созвон.
3. Документы (по желанию): `.md`/`.txt`/`.pdf`/`.docx`. Положи в папку, пользователь добавит её во вкладке «Знания» кнопкой «Добавить файлы или папку…». CLI-импорта нет.

Записать глоссарий и описание в приложение. Они хранятся в UserDefaults домена `com.aleksandrabramov.Prompter`, ключи `glossaryText` и `projectBrief`:
```bash
pkill -f "/Applications/Prompter.app/Contents/MacOS/Prompter"      # сначала закрыть приложение
defaults write com.aleksandrabramov.Prompter glossaryText "$(cat glossary.txt)"
defaults write com.aleksandrabramov.Prompter projectBrief "$(cat brief.txt)"
open /Applications/Prompter.app
```
Проверка: вкладка «Знания» показывает тексты. Ключи API лежат в Связке ключей, их не трогать.

Сейчас глоссарий используется только в промпте LLM: модель подсказывает слова из него. Распознаватель речи его не видит.

## Задача 2 (код): передать слова распознавателю речи
Цель: SpeechAnalyzer должен лучше узнавать термины из глоссария (имена, названия сервисов, жаргон), иначе он их коверкает и подсказки строятся на мусоре.

- API: `AnalysisContext` из Speech framework. `context.contextualStrings[.general] = [String]`, затем `try await analyzer.setContext(context)` (или параметр `analysisContext:` в инициализаторе `SpeechAnalyzer`). Сверяй сигнатуры по SDK: `xcrun --sdk macosx --show-sdk-path` → `System/Library/Frameworks/Speech.framework/Versions/A/Modules/Speech.swiftmodule/arm64e-apple-macos.swiftinterface`.
- Где: `Prompter/Speech/LiveTranscriber.swift`, метод `start(locale:onUpdate:)`. Передать в него список строк из `AppModel.start()` (там есть `settings.glossaryText`).
- Какие строки: из `Glossary.parse(settings.glossaryText)` взять стороны на языке речи (латиница для английского), без дублей, с разумным лимитом (например, 100). Чистую логику выбора положи в `Prompter/Core` и покрой тестами в `PrompterTests` (Swift Testing), как остальной Core.
- Применяется к обоим каналам (я и собеседник). Глоссарий меняется между сессиями, поэтому список берётся при каждом «Начать сессию».
- Done: тесты зелёные, сборка без предупреждений, приложение переустановлено. Пользователь проверил вслух: произносит термин из глоссария, и он появляется в расшифровке во вкладке «Сессия» правильно.

## Правила git (обязательно)
- Только личный GitHub `aleksabramov77`: remote `git@github-personal:aleksabramov77/prompter-macos.git`, автор `aleksabramov77@gmail.com`. Организацию cupid-media не трогать.
- `gh` вызывать только как `GH_CONFIG_DIR="$HOME/.config/gh-personal" gh …`.
- Новая ветка от `feature/openrouter` (например, `feature/speech-vocabulary`), PR в `feature/openrouter` или в `main` после слияния PR #1. В `main` не пушить и самому не сливать.
