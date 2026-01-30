import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../providers/gallery_provider.dart';
import '../providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => Provider.of<GalleryProvider>(context, listen: false).init());
  }

  // --- Function to Pick Target & Generate ---
  Future<void> _pickTargetAndGenerate() async {
    final gallery = Provider.of<GalleryProvider>(context, listen: false);

    // 1. Pick the Target Image (Portrait)
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null) {
      if (mounted) {
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text('Generating Mosaic...'),
            description: Text('This may take a moment based on complexity.'),
          ),
        );
      }

      // 2. Get bytes
      Uint8List? targetBytes;
      if (kIsWeb) {
        targetBytes = result.files.first.bytes;
      } else if (result.files.first.path != null) {
        targetBytes = await File(result.files.first.path!).readAsBytes();
      }

      if (targetBytes != null) {
        try {
          // 3. Run the Magic!
          await gallery.generateMosaic(targetBytes);

          // 4. Show Result OR Error
          if (mounted) {
            if (gallery.generatedMosaic != null) {
              _showResultDialog(gallery.generatedMosaic!);
            } else {
              _showErrorDialog();
            }
          }
        } catch (e) {
          _showErrorDialog();
        }
      }
    }
  }

  void _showErrorDialog() {
    showShadDialog(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('Generation Failed'),
        description:
            const Text("The mosaic could not be generated. Check logs."),
        actions: [
          ShadButton.outline(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(Uint8List imageBytes) {
    showShadDialog(
      context: context,
      builder: (ctx) => ShadDialog(
        title: const Text("Mosaic Result"),
        // maximize: true,
        child: AspectRatio(
          aspectRatio: 1, // approximate, or allow flexible
          child: InteractiveViewer(
            child: Image.memory(imageBytes, fit: BoxFit.contain),
          ),
        ),
        actions: [
          ShadButton.ghost(
            onPressed: () => Navigator.pop(ctx),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.x, size: 16),
              SizedBox(width: 8),
              Text('Close')
            ]),
          ),
          ShadButton(
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.save, size: 16),
              SizedBox(width: 8),
              Text("Save")
            ]),
            onPressed: () async {
              String? outputFile = await FilePicker.platform.saveFile(
                dialogTitle: 'Save Mosaic',
                fileName: 'mosaic_result.png',
              );

              if (outputFile != null) {
                final file = File(outputFile);
                await file.writeAsBytes(imageBytes);
                if (mounted) {
                  ShadToaster.of(ctx).show(ShadToast(
                    title: const Text('Saved!'),
                    description: Text('Saved to $outputFile'),
                  ));
                }
              }
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gallery = Provider.of<GalleryProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: ShadTheme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text("Mosaic Generator"),
        backgroundColor: ShadTheme.of(context).colorScheme.background,
        elevation: 0,
        actions: [
          ShadButton.ghost(
            child: Icon(
                themeProvider.isDarkMode ? LucideIcons.sun : LucideIcons.moon,
                size: 20),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
          ShadButton.ghost(
            child: const Icon(LucideIcons.trash2, size: 20),
            onPressed: () => gallery.clearGallery(),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: ShadTheme.of(context).colorScheme.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Library",
                        style: ShadTheme.of(context).textTheme.large),
                    Text("${gallery.count} images loaded",
                        style: ShadTheme.of(context).textTheme.muted),
                  ],
                ),
                if (gallery.isProcessing)
                  Expanded(
                      child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Processing ${(gallery.progress * 100).toInt()}%",
                            style: ShadTheme.of(context).textTheme.small),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: gallery.progress),
                      ],
                    ),
                  ))
                else
                  ShadButton(
                    onPressed: () => gallery.pickAndProcessImages(),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.imagePlus, size: 16),
                        SizedBox(width: 8),
                        Text("Upload Images"),
                      ],
                    ),
                  )
              ],
            ),
          ),
          Expanded(
            child: gallery.tiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.images,
                            size: 64,
                            color: ShadTheme.of(context)
                                .colorScheme
                                .mutedForeground),
                        const SizedBox(height: 16),
                        Text("No images in library",
                            style: ShadTheme.of(context).textTheme.h4),
                        Text("Upload 500+ images for best results",
                            style: ShadTheme.of(context).textTheme.muted),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: gallery.tiles.length,
                    itemBuilder: (context, index) {
                      final tile = gallery.tiles[index];
                      // Use ShadCard for nice frames
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? FutureBuilder<Uint8List?>(
                                // Fetch the image bytes from Hive using the ID
                                future: Provider.of<GalleryProvider>(context,
                                        listen: false)
                                    .getImageFromStorage(tile.path),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData &&
                                      snapshot.data != null) {
                                    return Image.memory(snapshot.data!,
                                        fit: BoxFit.cover, cacheWidth: 100);
                                  }
                                  // Fallback to color while loading or if failed
                                  return Container(
                                      color: Color.fromARGB(
                                          255, tile.r, tile.g, tile.b));
                                },
                              )
                            : Image.file(
                                File(tile.path),
                                fit: BoxFit.cover,
                                cacheWidth: 100,
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
      // Bottom Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
              top: BorderSide(color: ShadTheme.of(context).colorScheme.border)),
          color: ShadTheme.of(context).colorScheme.card,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ShadButton(
              size: ShadButtonSize.lg,
              enabled: (!gallery.isProcessing && gallery.count > 10),
              onPressed: _pickTargetAndGenerate,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.wand, size: 18),
                  SizedBox(width: 8),
                  Text("Generate Mosaic"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
