import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OCR demo',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ValueNotifier<File?> file = ValueNotifier(null);

  final Completer<CameraController> controller = Completer();

  void makeController() async {
    final cameras = await availableCameras();

    final controller =
        CameraController(cameras.first, ResolutionPreset.ultraHigh);

    await controller.initialize();

    this.controller.complete(controller);
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    makeController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OCR test"),
        actions: [
          ValueListenableBuilder(
            valueListenable: file,
            builder: (context, snapshot, old) => IconButton(
              onPressed: () async {
                if (file.value != null) {
                  file.value = null;
                } else {
                  final path =
                      (await (await controller.future).takePicture()).path;
                  file.value = File(path);
                }
              },
              icon: Icon(file.value == null
                  ? Icons.add_a_photo
                  : Icons.change_circle_outlined),
            ),
          ),
        ],
      ),
      body: Builder(
        builder: (context) => ValueListenableBuilder<File?>(
          valueListenable: file,
          builder: (context, snapshot, old) {
            if (snapshot == null) {
              print("🥰 nofile");
              return NoFile(
                controller: controller.future,
              );
            } else {
              print("🤮 yesfile");
              return YesFile(file: snapshot);
            }
          },
        ),
      ),
    );
  }
}

class NoFile extends StatefulWidget {
  const NoFile({Key? key, required this.controller}) : super(key: key);

  final Future<CameraController> controller;

  @override
  State<NoFile> createState() => _NoFileState();
}

class _NoFileState extends State<NoFile> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CameraController>(
      future: widget.controller,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Text("Loading camera");
        else {
          return snapshot.data!.buildPreview();
        }
      },
    );
  }
}

class YesFile extends StatefulWidget {
  const YesFile({Key? key, required this.file}) : super(key: key);

  final File file;

  @override
  State<YesFile> createState() => _YesFileState();
}

class _YesFileState extends State<YesFile> {
  @override
  Widget build(BuildContext context) {
    final recognizer = TextRecognizer();

    return FutureBuilder<RecognizedText>(
      future: recognizer.processImage(InputImage.fromFile(widget.file)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text("Parsing");
        } else {
          final parsed = OcrResult.parse(snapshot.data!);
          return SizedBox(
            height: 1000,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Text("💸 ${parsed.price}"),
                  ),
                  SliverToBoxAdapter(
                    child: Text("⌚ ${parsed.time}"),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        height: 1,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Text(snapshot.data!.text),
                  ),
                  // for (TextBlock block in snapshot.data!.blocks)
                  //   for (TextLine line in block.lines)
                  //     SliverToBoxAdapter(
                  //       child: Text(line.text),
                  //     ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}

class OcrResult {
  OcrResult({this.price, this.time});

  final double? price;
  final DateTime? time;

  factory OcrResult.parse(RecognizedText input) {
    double? price;
    DateTime? time;

    for (final block in input.blocks) {
      for (final _text in block.lines) {
        String text = _text.text;

        if (text.contains(",")) {
          print("");
        }

        final matchedDate =
            RegExp(r'[0-9]+.[0-9]+.[0-9]+').firstMatch(text)?.group(0);

        DateTime? asDateTime;
        if (matchedDate != null) {
          try {
            if (text.contains(".")) {
              asDateTime = DateFormat("d.M.y").parseLoose(matchedDate);
            } else if (text.contains("-")) {
              asDateTime = DateFormat("d-M-y").parseLoose(matchedDate);
            } else if (text.contains(" ")) {
              asDateTime = DateFormat("d M y").parseLoose(matchedDate);
            } else {
              asDateTime = DateTime.parse(matchedDate);
            }

            if (asDateTime.year < 1000) {
              asDateTime = DateTime(
                  asDateTime.year + 2000, asDateTime.month, asDateTime.day);
            }
            // ignore: empty_catches
          } on FormatException catch (e) {
            print(e.message);
          }
        }

        if (asDateTime != null) {
          if (time != null) {
            print("too dates");
          }
          time = asDateTime;
        }

        final withoutComma = text.replaceAll(",", ".");
        final asDouble = double.tryParse(withoutComma);

        print("🥰 $withoutComma $asDouble");
        if (asDouble != null && withoutComma.contains(".")) {
          if (price != null) {
            if (price < asDouble && text.length < 18) {
              price = asDouble;
            }
          } else {
            price = asDouble;
          }
        }
      }
    }

    return OcrResult(
      price: price,
      time: time,
    );
  }
}
