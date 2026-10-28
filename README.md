**English** | [Русский](README.ru.md)

# Prompter (Суфлёр) for macOS

A prompter for conversations in a foreign language. Prompter listens to both you and the other person. When you get stuck mid-sentence, it shows a cloud of fitting words and 2–3 ready-made ways to finish the sentence in a floating window, taking your project into account.

## What the MVP can do

- **Real-time transcription** of two channels: "me" (microphone) and "the other person" (system audio from Zoom/Meet/Teams/a browser). Recognition runs on-device via SpeechAnalyzer, free and offline.
- **"Stuck" detector** fires on a pause after an unfinished sentence or on a filler word ("um", "эээ"). You can also bring up a hint manually: **⌥⌘Space** from any app.
- **Word cloud and phrases.** Word size reflects relevance. Clicking a word or phrase copies it. If you said a word in Russian, its translation comes first.
- **Two models in parallel.** Local Apple Intelligence answers quickly and for free. Claude, if an API key is set, answers more accurately with the full project context and replaces the local answer when it arrives.
- **Knowledge base (RAG).** A project description, a glossary ("выкатка = rollout") and documents (txt/md/pdf/docx/code). Documents are split into chunks and embedded locally (NaturalLanguage); search is hybrid: vectors plus keywords.
- **Translated subtitles** of the other person's speech into your native language via the built-in macOS translator.
- **History.** After a call you can see where you stumbled and which words to review; export to Markdown is available.
- The hint window doesn't steal focus and tries to hide itself from screen sharing.

## Getting started

Requires macOS 26+ and Xcode 26+.

```bash
brew install xcodegen        # if not installed yet
git clone https://github.com/aleksabramov77/prompter-macos.git && cd prompter-macos
xcodegen generate
open Prompter.xcodeproj      # then ⌘R in Xcode
```

Or without the Xcode UI:

```bash
xcodebuild -project Prompter.xcodeproj -scheme Prompter -derivedDataPath build build
open build/Build/Products/Debug/Prompter.app
```

Tests: `xcodebuild test -project Prompter.xcodeproj -scheme Prompter -destination 'platform=macOS' -derivedDataPath build`.

### First launch

1. **Settings** tab: choose your speech language and native language. For hints from Claude, paste an API key from console.anthropic.com. Without a key, only Apple Intelligence works (it must be turned on in System Settings).
2. **Knowledge** tab: a couple of paragraphs about your project, a glossary and, optionally, a folder with documents.
3. **Start session**. macOS will ask for microphone access and, if "Listen to the other person" is on, for screen and system audio recording access. After granting screen recording access, the app needs to be restarted.
4. Put on headphones. Without them, the other person's voice from the speakers will reach the microphone as if it were yours.

> Without a Team ID in `project.yml`, the app is signed ad-hoc, and macOS may ask for permissions again after every rebuild. To avoid this, set `DEVELOPMENT_TEAM`.

## Privacy

- Audio is not stored. Speech recognition, embeddings and the local model run on your Mac.
- Claude (only if a key is set) receives the project description, relevant glossary terms, up to 4 matching document chunks and the last ~2000 characters of the conversation.
- The key is stored in the Keychain. App data lives in `~/Library/Application Support/Prompter`.
- Recording the other person without consent is illegal in some countries, so let them know.

## Architecture

```
Prompter/
  App/        AppModel (coordinator), AppSettings, entry point and menu
  Core/       pure logic with tests: stuck detector, transcript, chunker, vector index,
              prompts, model response parsing, session history
  Audio/      microphone (AVAudioEngine) and system audio (ScreenCaptureKit)
  Speech/     streaming recognition (SpeechAnalyzer/SpeechTranscriber)
  AI/         Claude Messages API, Apple Foundation Models, subtitle translation
  Knowledge/  knowledge base: file reading, embeddings, search
  UI/         hint window, main window tabs
PrompterTests/  Swift Testing, 38 tests for Core
```

## What's next

- Spaced repetition of words from the history (linked to a future trainer app).
- Streaming Claude responses (phrases appear as they are generated).
- Customizable hotkey and microphone selection.
- Echo cancellation without headphones (voice separation).
