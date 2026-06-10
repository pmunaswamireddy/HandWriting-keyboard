import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/profile.dart';
import '../../core/providers/profile_provider.dart';
import '../../shared/widgets/profile_avatar.dart';
import 'create_profile_screen.dart';
import '../home/home_screen.dart';
import '../glyph_editor/key_grid_screen.dart';

class ProfileListScreen extends ConsumerWidget {
  final bool isStandalone;
  ProfileListScreen({super.key, this.isStandalone = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);
    final activeId = ref.watch(activeProfileIdProvider);

    return Scaffold(
      backgroundColor: isStandalone ? Theme.of(context).scaffoldBackgroundColor : Colors.transparent,
      appBar: isStandalone
          ? AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              automaticallyImplyLeading: false,
              elevation: 0,
              title: Text(
                'Select Profile',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            )
          : null,
      body: profilesAsync.when(
        data: (profiles) => Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Add new profile button
                        _AddProfileButton(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CreateProfileScreen()),
                          ),
                        ),
                        SizedBox(height: 16),
                        if (profiles.isEmpty)
                          _EmptyState()
                        else
                          ...profiles.map((Profile profile) {
                            final isActive = profile.id == activeId ||
                                (activeId == null && profile == profiles.first);
                            return Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: _ProfileCard(
                                profile: profile,
                                isActive: isActive,
                                onSetActive: () => ref
                                    .read(profileServiceProvider)
                                    .setActiveProfile(profile.id),
                                onDelete: () => _confirmDelete(context, ref, profile.id, profile.name),
                                onEdit: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CreateProfileScreen(profile: profile),
                                  ),
                                ),
                                onRewrite: () {
                                  ref.read(profileServiceProvider).setActiveProfile(profile.id);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => KeyGridScreen()),
                                  );
                                },
                              ),
                            );
                          }),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            if (isStandalone && profiles.isNotEmpty)
              Padding(
                padding: EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.linearGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withOpacity(0.4),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        if (activeId == null && profiles.isNotEmpty) {
                          ref.read(profileServiceProvider).setActiveProfile(profiles.first.id);
                        }
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => HomeScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Continue to Keyboard',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        loading: () => Center(
            child: CircularProgressIndicator(color: AppTheme.primaryPurple)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Delete Profile',
            style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700)),
        content: Text('Delete "$name"? All glyphs will be permanently removed.',
            style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(profileServiceProvider).deleteProfile(id);
    }
  }
}

class _AddProfileButton extends StatelessWidget {
  final VoidCallback onTap;
  _AddProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Theme.of(context).colorScheme.surface, Color(0xFF131325)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.primaryPurple.withOpacity(0.4),
              style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.linearGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.onSurface, size: 28),
            ),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add New Profile',
                    style: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                Text('Create a new handwriting style',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Profile profile;
  final bool isActive;
  final VoidCallback onSetActive;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onRewrite;

  _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.onSetActive,
    required this.onDelete,
    required this.onEdit,
    required this.onRewrite,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSetActive,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryPurple.withOpacity(0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppTheme.primaryPurple.withOpacity(0.5)
                : Color(0xFF2A2A2A),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            ProfileAvatar(
              name: profile.name as String,
              color: Color(profile.avatarColor as int),
              size: 48,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        profile.name as String,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (isActive) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Active',
                              style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface)),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    'Created ${_formatDate(profile.createdAt as DateTime)}',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'rewrite') onRewrite();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.onSurface, size: 16),
                      SizedBox(width: 8),
                      Text('Edit Name', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'rewrite',
                  child: Row(
                    children: [
                      Icon(Icons.draw_rounded, color: Theme.of(context).colorScheme.onSurface, size: 16),
                      SizedBox(width: 8),
                      Text('Rewrite Handwriting', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_rounded, color: Color(0xFFEC4899), size: 16),
                      SizedBox(width: 8),
                      Text('Delete',
                          style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                    ],
                  ),
                ),
              ],
              child: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.draw_rounded, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15)),
            SizedBox(height: 16),
            Text('No profiles yet',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
            SizedBox(height: 8),
            Text('Create a profile to start mapping your handwriting',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }
}
