# Smart Chat Screen - Implementation Guide

## Overview
The `smart_chat_screen.dart` provides a **unified chat interface** that supports three input modes:
- **Text Mode** (⌨️): Traditional text input with keyboard
- **Sign Mode** (📷): Camera-based sign language detection using YOLO
- **Voice Mode** (🎤): Speech-to-text input (requires additional setup)

The chat history remains visible at all times, regardless of the selected input mode.

---

## Key Features

### ✅ Implemented
1. **Persistent Chat History**: Firebase Firestore stream displays messages in real-time
2. **Text Input**: Standard TextField with send button
3. **Sign Language Detection**: 
   - Uses YOLOv8 model for real-time sign detection
   - **Stability Buffer**: Only accepts words detected for 5+ consecutive frames
   - Auto-inserts detected signs into the text field
   - Shows bounding boxes and confidence scores
4. **Dynamic Mode Switching**: Seamlessly switch between input modes
5. **Performance Optimizations**:
   - Frame throttling (10 FPS for YOLO)
   - Automatic camera cleanup when switching modes
6. **Firebase Integration**: Full message sending/receiving with Firestore

### ⚠️ Requires Setup
- **Voice Mode**: Currently shows placeholder UI. Requires `speech_to_text` package (see below)

---

## Dependencies Required

### Already in pubspec.yaml ✅
- `camera: ^0.11.3`
- `flutter_vision: ^1.1.4` (YOLO)
- `cloud_firestore: ^6.1.0`
- `video_player: ^2.8.6`
- `just_audio: ^0.9.36`

### Need to Add ⚠️
Add this to your `pubspec.yaml`:

```yaml
dependencies:
  speech_to_text: ^6.6.0  # For Voice Mode
```

Then run:
```bash
flutter pub get
```

---

## Enabling Voice Mode

### Step 1: Add the dependency
```yaml
# pubspec.yaml
dependencies:
  speech_to_text: ^6.6.0
```

### Step 2: Uncomment the code
In `smart_chat_screen.dart`, uncomment these sections:

**Line 6** - Import:
```dart
import 'package:speech_to_text/speech_to_text.dart' as stt;
```

**Line 50** - Variable declaration:
```dart
stt.SpeechToText? _speech;
```

**Lines 113-117** - Initialization:
```dart
Future<void> _initializeSpeech() async {
  _speech = stt.SpeechToText();
  await _speech!.initialize();
}
```

**Lines 238-255** - Start listening:
```dart
void _startListening() async {
  if (_speech == null || !_speech!.isAvailable) return;
  
  setState(() {
    _isListening = true;
    _voiceText = '';
  });

  await _speech!.listen(
    onResult: (result) {
      setState(() {
        _voiceText = result.recognizedWords;
        _textController.text = _voiceText;
      });
    },
  );
}
```

**Lines 257-263** - Stop listening:
```dart
void _stopListening() async {
  if (_speech != null) {
    await _speech!.stop();
  }
  
  setState(() {
    _isListening = false;
  });
}
```

### Step 3: Add permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice input</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>This app needs speech recognition for voice-to-text</string>
```

---

## How to Use

### Navigation
Navigate to the screen like this:

```dart
import 'package:signlinggo/screens/conversation_mode/smart_chat_screen.dart';

// In your navigation code:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SmartChatScreen(
      chatName: "John Doe",
      avatar: "https://example.com/avatar.jpg", // or initial letter
      conversationId: "user1_user2", // Sorted user IDs joined with underscore
      currentUserID: "user1",
    ),
  ),
);
```

### Using Different Input Modes

#### Text Mode (Default)
1. Tap the **⌨️ Text** button
2. Type your message in the text field
3. Press the send button

#### Sign Mode
1. Tap the **📷 Sign** button
2. Camera will activate automatically
3. Perform signs in front of the camera
4. Words will auto-insert into the text field after 5 stable frames
5. Edit if needed, then press send

#### Voice Mode
1. Tap the **🎤 Voice** button
2. **Hold** the microphone button to speak
3. Release when done
4. Message will auto-send

---

## Sign Detection: Stability Buffer

To prevent spamming the chat with unstable detections, the screen uses a **stability buffer**:

```dart
static const int _stabilityThreshold = 5; // Frames needed
```

**How it works:**
1. YOLO detects a sign (e.g., "Hello")
2. Buffer counts consecutive frames with "Hello"
3. After 5 consecutive frames, "Hello" is inserted into the text field
4. User can continue signing to build a sentence
5. User manually sends when ready

**Adjust threshold:**
- **Lower (3-4)**: Faster insertion, less stable
- **Higher (7-10)**: More stable, slower insertion

---

## Firebase Structure

### Messages Collection
```
conversation/{conversationId}/messages/{messageId}
  - messageId: string
  - senderId: string
  - content: string (text, URL for media)
  - type: 'text' | 'video' | 'voice'
  - isRead: boolean
  - createdAt: Timestamp
  - deletedFor: string[]
```

### Conversation Document
```
conversation/{conversationId}
  - userIDs: string[]
  - lastMessageFor: Map<userId, message>
  - lastMessageAtFor: Map<userId, Timestamp>
```

---

## Performance Tips

### Camera/YOLO Optimization
- **Frame throttling**: 100ms (10 FPS) - adjust in `_processCameraFrame()`
- **Resolution**: `ResolutionPreset.medium` - balance between quality and speed
- **Auto-cleanup**: Camera stops when switching away from Sign mode

### Memory Management
- Video/audio controllers are cached and reused
- Disposed properly when screen closes
- Camera only initializes when Sign mode is activated

---

## Troubleshooting

### Camera not showing
- Ensure camera permissions are granted
- Check `_modelLoaded` status indicator
- Verify YOLO model is in `assets/models/`

### Signs not detecting
- Check lighting conditions
- Ensure model is loaded (green indicator)
- Verify `labels.txt` matches your model
- Adjust `_stabilityThreshold` if too strict

### Voice not working
- Ensure `speech_to_text` package is added
- Uncomment all voice-related code
- Add microphone permissions
- Test on physical device (not emulator)

### Messages not sending
- Check Firebase connection
- Verify `conversationId` format (sorted user IDs)
- Check Firestore security rules

---

## Customization

### Change Colors
```dart
// Primary purple color
const Color(0xFF5B259F)

// Message bubble colors
isUser ? const Color(0xFFF2E7FE) : Colors.grey[100]
```

### Adjust Camera Height (Sign Mode)
```dart
// Line ~700
Container(
  height: 400, // Change this value
  ...
)
```

### Modify Stability Threshold
```dart
// Line ~60
static const int _stabilityThreshold = 5; // Increase for more stability
```

---

## Future Enhancements

Potential improvements:
1. **Multi-word sign sentences**: Buffer multiple signs before sending
2. **Sign history**: Show recently detected signs
3. **Voice visualization**: Real-time waveform display
4. **Offline mode**: Cache messages when no internet
5. **Translation**: Auto-translate between sign language and text
6. **Video recording**: Record sign language videos instead of text

---

## Safety Notes

⚠️ **This is a standalone file** - it does NOT modify your existing chat screen.

✅ **Safe to test** - Navigate to this screen separately to test functionality.

✅ **Reuses existing logic** - Copied from `conversation_mode_screen.dart` and `sign_recognition_screen.dart`.

---

## Example Usage in App

Replace your existing conversation screen navigation with:

```dart
// Before:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ConversationScreen(...),
  ),
);

// After:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => SmartChatScreen(...),
  ),
);
```

Or keep both and add a toggle button to switch between classic and smart chat!

---

## Questions?

If you encounter issues:
1. Check the console for error messages
2. Verify all dependencies are installed
3. Ensure Firebase is properly configured
4. Test camera permissions on physical device
5. Check YOLO model is loaded correctly

Happy chatting! 🎉
