import 'package:flutter/material.dart';
<<<<<<< HEAD

class VoiceTextToSign extends StatelessWidget {
  const VoiceTextToSign({super.key});
=======
import 'package:signlinggo/screens/sign_recognition/sign_recognition_screen.dart';
import 'package:signlinggo/main.dart';

class TextTranslationScreen extends StatefulWidget {
  const TextTranslationScreen({super.key});

  @override
  State<TextTranslationScreen> createState() => _TextTranslationScreenState();
}

class _TextTranslationScreenState extends State<TextTranslationScreen> {
  final TextEditingController _textController = TextEditingController();
  String _translatedText = '';
  bool isSignToText = false; // false = Text→Sign, true = Sign→Text

  void _translateText() {
    setState(() {
      _translatedText = _textController.text.isEmpty
          ? 'Please enter text first.'
          : '(Sign translation of "${_textController.text}")';
    });
  }
>>>>>>> origin/features/tasha-conversationmode

  @override
  Widget build(BuildContext context) {
    return Scaffold(
<<<<<<< HEAD
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 2,
        backgroundColor: Colors.white,
        shadowColor: Colors.black12,
        title: const Text(
          'Voice/Text to Sign',
          style: TextStyle(
            color: Color(0xFF101727),
            fontSize: 20,
            fontFamily: 'Arimo',
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Input Box
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.text_fields, size: 20, color: Color(0xFF101727)),
                      SizedBox(width: 8),
                      Text(
                        'Enter Text',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Arimo',
                          color: Color(0xFF101727),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                    ),
                    child: const TextField(
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Type or speak what you want to translate...',
                        hintStyle: TextStyle(
                          color: Color(0xFF717182),
                          fontSize: 16,
                          fontFamily: 'Arimo',
                        ),
                        border: InputBorder.none,
=======
      appBar: AppBar(
        title: const Text('Voice/Text to Sign', style: TextStyle(color: Colors.black, fontFamily: 'Arimo',),),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () { Navigator.pop(context); },),),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              //Mode Label + Switch
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFAC46FF), Color(0xFF8B2EFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isSignToText ? 'Sign → Text' : 'Text → Sign',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white,),
                    ),
                    Row(
                      children: [
                        const Text(
                          'Switch Mode',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontFamily: 'Arimo',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: isSignToText,
                          activeThumbColor: Colors.white,
                          inactiveThumbColor: Colors.white,
                          activeTrackColor: Colors.grey[400],
                          inactiveTrackColor: Colors.grey[400],
                          onChanged: (value) async {
                            setState(() => isSignToText = value);

                            if (value) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SignRecognitionScreen(
                                    camera: cameras.first,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- Text Input ---
              TextField(
                controller: _textController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type or speak what you want to translate...',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFE5E7EB),
                      width: 1.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              //Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Voice recording not implemented yet')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: Color(0xFFD0D5DB), width: 1.2),
                      ),
                      icon: const Icon(Icons.mic, color: Colors.black87),
                      label: const Text(
                        'Record Voice',
                        style: TextStyle(
                          color: Color(0xFF0A0A0A),
                          fontSize: 14,
                          fontFamily: 'Arimo',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _translateText,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Translate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Arimo',
                        ),
>>>>>>> origin/features/tasha-conversationmode
                      ),
                    ),
                  ),
                ],
              ),
<<<<<<< HEAD
            ),

            const SizedBox(height: 24),

            // Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFD0D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.mic, color: Color(0xFF0A0A0A)),
                    label: const Text(
                      'Record Voice',
                      style: TextStyle(
                        color: Color(0xFF0A0A0A),
                        fontSize: 14,
                        fontFamily: 'Arimo',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      disabledBackgroundColor: const Color(0xFFD1D5DC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Translate',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Arimo',
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Tips Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                border: Border.all(color: const Color(0xFFBDDAFF), width: 1.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Tips',
                    style: TextStyle(
=======

              const SizedBox(height: 24),

              //Translation Result
              if (_translatedText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    border: Border.all(
                        color: const Color(0xFFBDDAFF), width: 1.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _translatedText,
                    style: const TextStyle(
>>>>>>> origin/features/tasha-conversationmode
                      fontSize: 16,
                      fontFamily: 'Arimo',
                      color: Color(0xFF101727),
                    ),
                  ),
<<<<<<< HEAD
                  SizedBox(height: 16),
                  Text(
                    '• Speak clearly or type your message\n'
                    '• The avatar will demonstrate each sign\n'
                    '• Tap replay to watch again',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Arimo',
                      color: Color(0xFF495565),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
=======
                ),

              const SizedBox(height: 24),

              //Tips Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFBDDAFF), width: 1.2),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Tips',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Arimo',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF101727),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('• Speak clearly or type your message',
                        style: TextStyle(
                            color: Color(0xFF495565), fontSize: 15)),
                    Text('• The avatar will demonstrate each sign',
                        style: TextStyle(
                            color: Color(0xFF495565), fontSize: 15)),
                    Text('• Tap replay to watch again',
                        style: TextStyle(
                            color: Color(0xFF495565), fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
>>>>>>> origin/features/tasha-conversationmode
        ),
      ),
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> origin/features/tasha-conversationmode
