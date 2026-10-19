# Суфлёр (Prompter): что это, как запустить, что сделать

Прочитай этот файл целиком, затем `README.md` и `CLAUDE.md` в корне репозитория. С пользователем общайся по-русски.

## Что это и зачем
Наше внутреннее macOS-приложение, чтобы увереннее говорить по-английски на рабочих созвонах. Суфлёр слушает созвон. Когда пользователь запинается посреди фразы (пауза или «um», «эээ»), он показывает в плавающем окне облако подходящих слов и 2–3 готовых продолжения фразы с учётом нашего проекта. После созвона во вкладке «История» видно, где были запинки и какие слова стоит повторить.

- Проект: **`/Users/aleksandrabramov/Projects/My/Prompter`** — работай только локально, доступ к GitHub не нужен.
- Папка уже переключена на ветку `feature/openrouter` с актуальным кодом. Установленное `/Applications/Prompter.app` собрано из неё.
- Стек: Swift/SwiftUI, macOS 26+, проект генерируется `xcodegen`.

## Что уже работает
- Два канала расшифровки в реальном времени, на устройстве (SpeechAnalyzer): «я» — микрофон, «собеседник» — системный звук Mac (ScreenCaptureKit), то есть вкладка Google Meet в браузере.
- Детектор запинок: пауза после незаконченной фразы или слово-паразит. Подсказку вручную даёт **⌥⌘Space** из любого приложения.
- Подсказки от LLM: OpenRouter (по умолчанию `anthropic/claude-haiku-5.5`, около $0.0005 за подсказку) или Claude напрямую. Apple Intelligence на этом Mac недоступна (регион), поэтому **без ключа OpenRouter подсказок нет**.
- Контекст для подсказок, вкладка «Знания»: описание проекта, **глоссарий (список новых слов)** и документы (локальный RAG).
- **Новые слова учитываются дважды**: LLM подсказывает их в нужный момент, а распознаватель речи получает английские стороны глоссария (`AnalysisContext.contextualStrings`, до 100 слов) и лучше узнаёт их на слух. Код: `Prompter/Core/SpeechVocabulary.swift`, вызов в `LiveTranscriber.start(locale:vocabulary:onUpdate:)`.
- Перевод реплик собеседника на русский (встроенный переводчик macOS, если скачаны языки).
- Окно подсказок не забирает фокус и пытается скрыться от демонстрации экрана (в Meet проверить отдельно).

## Сборка и запуск
```bash
cd /Users/aleksandrabramov/Projects/My/Prompter
git branch --show-current               # должно быть feature/openrouter
xcodegen generate                       # .xcodeproj генерируется, руками не правим
xcodebuild test -project Prompter.xcodeproj -scheme Prompter -destination 'platform=macOS' -derivedDataPath build
xcodebuild build -project Prompter.xcodeproj -scheme Prompter -destination 'platform=macOS' -derivedDataPath build
# установить и запустить:
pkill -f "/Applications/Prompter.app/Contents/MacOS/Prompter"; rm -rf /Applications/Prompter.app
cp -R build/Build/Products/Debug/Prompter.app /Applications/ && open /Applications/Prompter.app
```
Сейчас проходят 45 тестов. Сборка подписана ad-hoc, поэтому после переустановки macOS может заново спросить доступ к микрофону и записи экрана. Нажимает пользователь.

## Подключение к Google Meet
**Рекомендуемый вариант — Суфлёр на том же ноутбуке, где открыт Meet.**
1. Наушники обязательны, иначе голос собеседника из динамиков попадёт в микрофон как «я».
2. Meet открыт в браузере, звук идёт в наушники.
3. В Суфлёре вкладка «Сессия»: включены «Слушать собеседника» и «Подсказывать автоматически» → «Начать сессию».
4. Первый раз macOS просит **Screen & System Audio Recording** для Prompter: включить, нажать **Quit & Reopen**, снова «Начать сессию».
5. Проверка: на вкладке «Сессия» шевелятся оба индикатора уровня («Я» и «Собеседник»), в расшифровке появляются реплики обоих.

**Запасной вариант — второй ноутбук рядом** (если на основном нельзя ставить приложение). Суфлёр слушает комнату своим микрофоном: выключить «Слушать собеседника», Meet на основном ноутбуке — через динамики. Минус: оба голоса смешиваются в один канал «я», поэтому подсказки хуже. Только если первый вариант недоступен.

## Задача: список новых слов к созвону
Узнай у пользователя тему созвона, собеседников и проект. Подготовь:

1. **Глоссарий**: по одной паре на строку, `русский термин = english term` (разделители `=`, ` — `, ` - `, Tab; строки с `#` — комментарии). Сюда идут слова, на которых пользователь может запнуться: термины проекта, имена и названия сервисов (их особенно важно дать распознавателю), глаголы для статуса задач, связки («to be honest», «the thing is», «let me rephrase»). Разумный объём — 50–150 строк; распознаватель берёт первые 100 английских сторон, поэтому самое важное ставь наверх.
2. **Описание проекта**: 1–3 абзаца на английском. Что за проект, роль пользователя, текущие задачи и проблемы, о чём будет созвон.
3. Документы (по желанию): `.md`/`.txt`/`.pdf`/`.docx`. Положи в папку, пользователь добавит её во вкладке «Знания» кнопкой «Добавить файлы или папку…».

Записать в приложение. Глоссарий и описание хранятся в UserDefaults домена `com.aleksandrabramov.Prompter`, ключи `glossaryText` и `projectBrief`:
```bash
pkill -f "/Applications/Prompter.app/Contents/MacOS/Prompter"      # сначала закрыть приложение
defaults write com.aleksandrabramov.Prompter glossaryText "$(cat glossary.txt)"
defaults write com.aleksandrabramov.Prompter projectBrief "$(cat brief.txt)"
open /Applications/Prompter.app
```
Можно и без команд: пользователь вставляет текст в поля вкладки «Знания». Слова применяются при следующем «Начать сессию» (идущую сессию остановить и начать заново). Ключи API лежат в Связке ключей, их не трогать.

Проверка: вкладка «Знания» показывает тексты. Пользователь говорит вслух термин из глоссария, и тот правильно появляется в расшифровке на вкладке «Сессия».

## Правила git: никаких push
- **Ничего не пушь, не создавай PR и не трогай удалённые репозитории пользователя.** Только локальные коммиты в текущую ветку `feature/openrouter`.
- Автор коммитов — `Aleksandr Abramov <aleksabramov77@gmail.com>`. Он уже настроен для `~/Projects/My`, проверь `git config user.email`.
- Ветку `main` не трогай.

## Если ты изменил код: передай на отправку в claude2
Список слов через `defaults write` — это не изменение кода, тогда ничего передавать не нужно. Если ты закоммитил правки в репозиторий, передай их сессии Claude на личной учётке пользователя (`claude2`): она проверит и запушит. `claude2` — это алиас (`CLAUDE_CONFIG_DIR="$HOME/.claude-second" claude`), в shell агента он не работает, поэтому команда полная. Сообщение передаётся через stdin:

```bash
cd /Users/aleksandrabramov/Projects/My/Prompter && cat <<'MSG' | CLAUDE_CONFIG_DIR="$HOME/.claude-second" claude -p --allowedTools "Bash(git:*)" "Bash(xcodegen:*)" "Bash(xcodebuild:*)"
Ты — Claude на личной учётке (claude2). Другой агент внёс локальные правки в Суфлёр (Prompter).
Контекст — чат, где приложение создавалось: сессия 3d3670b9-6795-41be-bb7b-60e465e23eb2,
транскрипт: ~/.claude-second/projects/-Users-aleksandrabramov-Projects-My-Prompter--claude-worktrees-openrouter/3d3670b9-6795-41be-bb7b-60e465e23eb2.jsonl
(при необходимости прочитай его конец). Описание проекта: docs/AGENT_HANDOFF.md, README.md, CLAUDE.md.

Задача:
1. Проект /Users/aleksandrabramov/Projects/My/Prompter, ветка feature/openrouter. Новые коммиты: git log origin/feature/openrouter..HEAD, изменения: git diff origin/feature/openrouter.
2. Проверь сборку и тесты: xcodegen generate, затем xcodebuild test -project Prompter.xcodeproj -scheme Prompter -destination 'platform=macOS' -derivedDataPath build.
3. Проверь по ~/.claude-second/CLAUDE.md: remote — aleksabramov77 через github-personal, автор коммитов — aleksabramov77@gmail.com.
4. Если всё в порядке: git push origin feature/openrouter. В main не пушь и ничего не сливай.
5. Ответь коротко: что запушено (хеши) или почему не запушено.

Что изменил агент: <впиши 1–3 предложения>
MSG
```
Подставь в последнюю строку сообщения, что ты изменил, и покажи пользователю ответ claude2.
