import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfflineManager {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Dio _dio = Dio();

  /// Checks if the module folder exists on the device
  Future<bool> isModuleDownloaded(String folderName) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final folderPath = Directory('${appDocDir.path}/offline_content/$folderName');
    return await folderPath.exists();
  }

  /// Downloads ZIP from Supabase, Unzips it, then deletes the ZIP
  Future<bool> downloadAndUnzipModule(
      String zipFileName, String folderName,
      {Function(double)? onProgress}) async {
    try {
      // 1. Setup Paths
      final appDocDir = await getApplicationDocumentsDirectory();
      final offlineBaseDir = Directory('${appDocDir.path}/offline_content');

      if (!await offlineBaseDir.exists()) {
        await offlineBaseDir.create(recursive: true);
      }

      final zipFilePath = '${offlineBaseDir.path}/temp_$zipFileName';
      final extractToPath = '${offlineBaseDir.path}/$folderName';

      // 2. Get URL from Supabase
      final String publicUrl = _supabase
          .storage
          .from('offline-materials') 
          .getPublicUrl(zipFileName);

      // 3. Download the ZIP
      await _dio.download(
        publicUrl,
        zipFilePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      // 4. Unzip the file
      final inputStream = InputFileStream(zipFilePath);
      final archive = ZipDecoder().decodeStream(inputStream);

      for (var file in archive.files) {
        if (file.isFile) {
          final outFile = File('$extractToPath/${file.name}');
          await outFile.create(recursive: true);
          
          final outputStream = OutputFileStream(outFile.path);
          file.writeContent(outputStream);
          outputStream.close();
        }
      }

      // 5. Delete temp ZIP file
      final zipFile = File(zipFilePath);
      if (await zipFile.exists()) {
        await zipFile.delete();
      }

      return true;
    } catch (e) {
      print("Error downloading module: $e");
      return false;
    }
  }
  
  /// DELETES the module folder from local storage
  Future<void> deleteModule(String folderName) async {
     final appDocDir = await getApplicationDocumentsDirectory();
     final folderPath = Directory('${appDocDir.path}/offline_content/$folderName');
     if (await folderPath.exists()) {
       await folderPath.delete(recursive: true);
     }
  }
}