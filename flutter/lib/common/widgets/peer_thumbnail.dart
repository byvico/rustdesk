// Remotium: miniaturas (thumbnails) de la pantalla remota para las tarjetas de peers.
// Guarda el primer/ultimo frame de una sesion como PNG por id de peer y lo carga en
// la cuadricula. Si no hay miniatura (o en escritorio con texture-render), la tarjeta
// hace fallback a un gradiente estilizado (ver peer_card.dart).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

String? _thumbDir;

Future<String> _ensureDir() async {
  if (_thumbDir != null) return _thumbDir!;
  final base = await getApplicationDocumentsDirectory();
  final d = Directory('${base.path}/remotium_thumbs');
  if (!await d.exists()) await d.create(recursive: true);
  _thumbDir = d.path;
  return _thumbDir!;
}

/// Inicializa el directorio de miniaturas al arranque para que [thumbnailFileSync]
/// pueda encontrar archivos existentes sin esperar un await.
Future<void> initPeerThumbnails() async {
  try {
    await _ensureDir();
  } catch (_) {}
}

Future<String> thumbnailFilePath(String peerId) async {
  final dir = await _ensureDir();
  return '$dir/${_safe(peerId)}.png';
}

String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

/// Reescala la imagen a ~targetW px de ancho y la guarda como PNG.
Future<void> saveThumbnailFromImage(String peerId, ui.Image image,
    {int targetW = 320}) async {
  try {
    if (image.width <= 0) return;
    final scale = targetW / image.width;
    final w = targetW;
    final h = (image.height * scale).round().clamp(1, 4096);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      paint,
    );
    final scaled = await recorder.endRecording().toImage(w, h);
    final bytes = await scaled.toByteData(format: ui.ImageByteFormat.png);
    scaled.dispose();
    if (bytes == null) return;
    final path = await thumbnailFilePath(peerId);
    await File(path).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  } catch (_) {}
}

/// Devuelve el File de la miniatura si existe (para mostrarla), o null (fallback).
File? thumbnailFileSync(String peerId) {
  if (_thumbDir == null) return null;
  final f = File('$_thumbDir/${_safe(peerId)}.png');
  return f.existsSync() ? f : null;
}
