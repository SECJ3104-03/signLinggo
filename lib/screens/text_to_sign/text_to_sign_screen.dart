import 'package:flutter/material.dart';

class VoiceTextToSign extends StatelessWidget {
  const VoiceTextToSign({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      ),
                    ),
                  ),
                ],
              ),
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
                      fontSize: 16,
                      fontFamily: 'Arimo',
                      color: Color(0xFF101727),
                    ),
                  ),
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
        ),
      ),
    );
  }
}
