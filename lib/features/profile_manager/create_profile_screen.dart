import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/models/profile.dart';
import '../../shared/widgets/profile_avatar.dart';

class CreateProfileScreen extends ConsumerStatefulWidget {
  final Profile? profile; // if editing existing

  const CreateProfileScreen({super.key, this.profile});

  @override
  ConsumerState<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  late final TextEditingController _nameController;
  int _selectedColor = 0xFF7C3AED;
  bool _isSaving = false;

  static const List<int> _colorOptions = [
    0xFF7C3AED, // Purple
    0xFFEC4899, // Pink
    0xFF3B82F6, // Blue
    0xFF10B981, // Green
    0xFFF59E0B, // Amber
    0xFFEF4444, // Red
    0xFF06B6D4, // Cyan
    0xFF8B5CF6, // Violet
    0xFFFF6B35, // Orange
    0xFF14B8A6, // Teal
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
        text: widget.profile?.name ?? '');
    _selectedColor = widget.profile?.avatarColor ?? 0xFF7C3AED;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a name',
              style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
          backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final service = ref.read(profileServiceProvider);
      if (widget.profile != null) {
        await service.updateProfile(widget.profile!.copyWith(
          name: _nameController.text.trim(),
          avatarColor: _selectedColor,
        ));
      } else {
        final created = await service.createProfile(
          name: _nameController.text.trim(),
          avatarColor: _selectedColor,
        );
        service.setActiveProfile(created.id);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          widget.profile != null ? 'Edit Profile' : 'New Profile',
          style: GoogleFonts.outfit(
              fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar preview
            Center(
              child: ProfileAvatar(
                name: _nameController.text.isEmpty
                    ? '?'
                    : _nameController.text,
                color: Color(_selectedColor),
                size: 80,
              ),
            ),
            SizedBox(height: 32),

            // Name input
            Text('Profile Name',
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
            SizedBox(height: 8),
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.outfit(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'e.g. My Handwriting, John\'s Style',
                hintStyle: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                prefixIcon: Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              ),
            ),
            SizedBox(height: 28),

            // Color picker
            Text('Avatar Color',
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
            SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colorOptions.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [BoxShadow(
                              color: Color(color).withOpacity(0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            )]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.onSurface, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 40),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppTheme.linearGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Theme.of(context).colorScheme.onSurface),
                        )
                      : Text(
                          widget.profile != null ? 'Save Changes' : 'Create Profile',
                          style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
