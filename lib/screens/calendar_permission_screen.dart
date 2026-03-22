import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import 'app_shell.dart';

class CalendarPermissionScreen extends StatefulWidget {
  const CalendarPermissionScreen({super.key});

  @override
  State<CalendarPermissionScreen> createState() =>
      _CalendarPermissionScreenState();
}

class _CalendarPermissionScreenState extends State<CalendarPermissionScreen> {
  final _authService = AuthService();
  bool _loading = false;

  Future<void> _requestPermission() async {
    setState(() => _loading = true);

    try {
      final granted = await _authService.requestCalendarPermission();
      if (mounted) {
        if (granted) {
          _navigateToHome();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Calendar permission was not granted.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request permission: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),

              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primaryPurple,
                  size: 26,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Connect your calendar',
                style: Theme.of(context).textTheme.headlineLarge,
              ),

              const SizedBox(height: 12),

              Text(
                'We\'ll sync with your calendar to plan around your meetings, commute, and personal time — so your day flows, not fights.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                    ),
              ),

              const SizedBox(height: 40),

              _permissionItem(
                Icons.event_outlined,
                'Read your events',
                'Plan around your meetings and commitments',
              ),
              const SizedBox(height: 20),
              _permissionItem(
                Icons.edit_calendar_outlined,
                'Create events',
                'Block time for meals, self-care, and workouts',
              ),
              const SizedBox(height: 20),
              _permissionItem(
                Icons.lock_outline,
                'Private & secure',
                'Your data stays between you and Google',
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: _loading ? null : _requestPermission,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('Allow calendar access'),
              ),

              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: _loading ? null : _navigateToHome,
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionItem(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.softPurple, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
