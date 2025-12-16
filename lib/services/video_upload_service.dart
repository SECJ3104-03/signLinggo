import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String?> uploadVideoViaSignedUrl(File videoFile) async {
  try {
    final fileName = 'videos/${DateTime.now().millisecondsSinceEpoch}.mp4';

    // Step 2a: Get signed URL from backend
    final backendResponse = await http.post(
      Uri.parse('https://tdtosjyrvwtnrmkjiwav.supabase.co/getSignedUrl'),
      headers: {'Content-Type': 'application/json'},
      body: '{"filename":"$fileName"}',
    );

    if (backendResponse.statusCode != 200) return null;

    final Map<String, dynamic> data = jsonDecode(backendResponse.body);
    final signedUrl = data['url'] as String?;
    if (signedUrl == null) return null;

    // Step 2b: Upload video via PUT to signed URL
    final bytes = await videoFile.readAsBytes();
    final uploadResponse = await http.put(
      Uri.parse(signedUrl),
      headers: {
        'Content-Type': 'video/mp4',
      },
      body: bytes,
    );

    if (uploadResponse.statusCode != 200 &&
        uploadResponse.statusCode != 201) {
      print('Upload failed: ${uploadResponse.statusCode}');
      return null;
    }

    // Step 2c: Get public URL of the uploaded file
    final publicUrl = 'https://tdtosjyrvwtnrmkjiwav.supabase.co/storage/v1/object/public/videoMessage/$fileName';
    return publicUrl;
  } catch (e) {
    print('Video upload error: $e');
    return null;
  }
}