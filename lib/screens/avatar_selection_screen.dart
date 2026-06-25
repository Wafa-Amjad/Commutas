import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme.dart';

class AvatarSelectionScreen extends StatefulWidget {
  final String? currentAvatarPath;

  const AvatarSelectionScreen({super.key, this.currentAvatarPath});

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _pickedImage;
  String? _selectedAvatar;

  final List<Map<String, String>> _femaleAvatars = [
    {'path': 'assets/avatars/f_hijab.png', 'label': 'Academic (Hijab)'},
    {'path': 'assets/avatars/f_glasses.png', 'label': 'Student (Glasses)'},
    {'path': 'assets/avatars/f_pro.png', 'label': 'Professional'},
    {'path': 'assets/avatars/f_casual.png', 'label': 'Casual'},
  ];

  final List<Map<String, String>> _maleAvatars = [
    {'path': 'assets/avatars/m_pro.png', 'label': 'Professional'},
    {'path': 'assets/avatars/m_formal.png', 'label': 'Formal'},
    {'path': 'assets/avatars/m_casual.png', 'label': 'Casual'},
    {'path': 'assets/avatars/m_academic.png', 'label': 'Academic'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedAvatar = widget.currentAvatarPath;
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
        _selectedAvatar = null;
      });
      _handleCompletion();
    }
  }

  void _handleCompletion() {
    Navigator.pop(context, {
      'type': _pickedImage != null ? 'file' : 'asset',
      'path': _pickedImage?.path ?? _selectedAvatar,
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: CommutasColors.backgroundGray,
        appBar: AppBar(
          title: const Text('Choose Avatar'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: _handleCompletion,
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold, color: CommutasColors.emeraldGreen)),
            ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: CommutasColors.lineBorder.withOpacity(0.3),
                  borderRadius: BorderRadius.zero,
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: CommutasColors.primaryNavy,
                    borderRadius: BorderRadius.zero,
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: CommutasColors.primaryNavy,
                  labelStyle: CommutasTextStyles.labelBold.copyWith(fontSize: 13),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Female'),
                    Tab(text: 'Male'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAvatarGrid(_femaleAvatars, Icons.woman),
                  _buildAvatarGrid(_maleAvatars, Icons.man),
                ],
              ),
            ),
            _buildGalleryOption(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarGrid(List<Map<String, String>> avatars, IconData placeholderIcon) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final avatar = avatars[index];
        final path = avatar['path']!;
        final label = avatar['label']!;
        final isSelected = _selectedAvatar == path;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedAvatar = path;
              _pickedImage = null;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: isSelected ? CommutasColors.emeraldGreen : CommutasColors.lineBorder,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: Container(
                      width: double.infinity,
                      color: CommutasColors.backgroundGray,
                      child: Image.asset(
                        path,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          placeholderIcon,
                          color: CommutasColors.primaryNavy.withOpacity(0.2),
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text(
                    label,
                    style: CommutasTextStyles.bodySmall.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? CommutasColors.emeraldGreen : CommutasColors.primaryNavy,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGalleryOption() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CommutasColors.lineBorder)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('UPLOAD FROM DEVICE'),
            style: OutlinedButton.styleFrom(
              foregroundColor: CommutasColors.primaryNavy,
              side: const BorderSide(color: CommutasColors.lineBorder),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
          ),
        ),
      ),
    );
  }
}
