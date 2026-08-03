import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../../../../shared/widgets/screen_accent_backdrop.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/visits_providers.dart';

String _visitSaveErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    final status = error.response?.statusCode;
    if (status != null) {
      return 'Request failed (HTTP $status). Please try again.';
    }
    return 'Network error. Check your connection and try again.';
  }
  return error.toString();
}

const _indianStates = <String>[
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
  'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
  'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
  'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
  'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
  'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Puducherry',
];

const _ratingLabels = <String>[
  '', 'Not intrested', 'Less quantity, Rate OK', 'Medium Qty, Rate NG',
  'High Qty, Rate NG', 'Neutral', 'Qty OK, Rate OK, Vendor not changing',
  'Order more then 45 Days', 'Order more then 15 Days', 'Order Within 15 Days',
  'Instant Order',
];

String _ratingLabelFor(int r) => (r >= 1 && r <= 10) ? _ratingLabels[r] : '';

Color _ratingColor(int r) {
  if (r <= 3) return const Color(0xFFEF4444);
  if (r <= 5) return const Color(0xFFF59E0B);
  if (r <= 7) return const Color(0xFF3B82F6);
  return const Color(0xFF10B981);
}

class AddVisitScreen extends ConsumerStatefulWidget {
  const AddVisitScreen({super.key});

  @override
  ConsumerState<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends ConsumerState<AddVisitScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  int _currentStep = 0;

  final _partyNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _partyNameFocus = FocusNode();
  final _cityFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _contactNameFocus = FocusNode();
  final _contactPhoneFocus = FocusNode();
  final _contactEmailFocus = FocusNode();
  final _purposeFocus = FocusNode();
  final _notesFocus = FocusNode();

  String? _selectedState;
  bool _isClient = true;
  bool _isNewVisit = true;
  int _rating = 5;
  DateTime? _followUpDate;
  DateTime _visitWhen = DateTime.now();
  File? _selectedImage;
  bool _saving = false;

  double? _latitude;
  double? _longitude;
  bool _locationBusy = false;
  String? _placeHeadline;
  String _locationStatus = 'Fetching GPS location...';

  Timer? _locationServicePoll;

  late final stt.SpeechToText _speech;
  bool _speechListening = false;
  TextEditingController? _speechTarget;
  String _speechBaseline = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _currentStep = _tabController.index);
    });

    _speech = stt.SpeechToText();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefillContactFromAuth();
      _captureLocationAndPlace();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationServicePoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    try { _speech.stop(); } catch (_) {}
    try { _speech.cancel(); } catch (_) {}

    _partyNameFocus.dispose();
    _cityFocus.dispose();
    _addressFocus.dispose();
    _contactNameFocus.dispose();
    _contactPhoneFocus.dispose();
    _contactEmailFocus.dispose();
    _purposeFocus.dispose();
    _notesFocus.dispose();

    _partyNameCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _contactEmailCtrl.dispose();
    _purposeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeResumeLocationAfterSettings();
    }
  }

  Future<void> _maybeResumeLocationAfterSettings() async {
    final on = await Geolocator.isLocationServiceEnabled();
    if (on) {
      _locationServicePoll?.cancel();
      _locationServicePoll = null;
      await _captureLocationAndPlace();
    }
  }

  void _prefillContactFromAuth() {
    final raw = ref.read(authProvider).rawUser;
    if (raw == null) return;
    final email = raw['email']?.toString().trim();
    final phone = raw['mobile']?.toString().trim().isNotEmpty == true
        ? raw['mobile']?.toString().trim()
        : raw['phone']?.toString().trim();
    if (email != null && email.isNotEmpty) {
      _contactEmailCtrl.text = email;
    }
    if (phone != null && phone.isNotEmpty) {
      _contactPhoneCtrl.text = phone.replaceAll(RegExp(r'\s'), '');
    }
  }

  String? _matchIndianState(String? adminArea) {
    if (adminArea == null || adminArea.trim().isEmpty) return null;
    final a = adminArea.trim();
    for (final s in _indianStates) {
      if (s.toLowerCase() == a.toLowerCase()) return s;
    }
    for (final s in _indianStates) {
      if (a.toLowerCase().contains(s.toLowerCase()) ||
          s.toLowerCase().contains(a.toLowerCase())) {
        return s;
      }
    }
    return null;
  }

  void _applyPlacemark(Placemark place) {
    final street = place.street ?? '';
    final subLocality = place.subLocality ?? '';
    final locality = place.locality ?? '';
    final adminArea = place.administrativeArea ?? '';
    final line = [
      if (place.name != null &&
          place.name!.isNotEmpty &&
          place.name != street)
        place.name!,
      street,
      subLocality,
    ].where((e) => e.isNotEmpty).toSet().join(', ');

    final headlineParts = <String>[];
    for (final e in [locality, subLocality, adminArea]) {
      final t = e.trim();
      if (t.isNotEmpty && !headlineParts.contains(t)) {
        headlineParts.add(t);
      }
    }
    final headline = headlineParts.take(4).join(' · ');

    setState(() {
      _placeHeadline = headline.isNotEmpty ? headline : null;
      if (locality.isNotEmpty) _cityCtrl.text = locality;
      final st = _matchIndianState(adminArea);
      if (st != null) _selectedState = st;
      if (line.isNotEmpty) _addressCtrl.text = line;
    });
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (!mounted || marks.isEmpty) return;
      _applyPlacemark(marks.first);
    } catch (_) {}
  }

  void _startLocationServicePolling() {
    _locationServicePoll?.cancel();
    var attempts = 0;
    _locationServicePoll = Timer.periodic(const Duration(seconds: 1), (t) async {
      attempts++;
      final on = await Geolocator.isLocationServiceEnabled();
      if (on) {
        t.cancel();
        _locationServicePoll = null;
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) await _captureLocationAndPlace();
      } else if (attempts > 30) {
        t.cancel();
        _locationServicePoll = null;
        if (mounted) {
          setState(() {
            _locationBusy = false;
            _locationStatus = 'Location services off. Turn on & retry.';
          });
        }
      }
    });
  }

  Future<void> _captureLocationAndPlace() async {
    if (!mounted) return;
    setState(() {
      _locationBusy = true;
      _locationStatus = 'Checking GPS...';
    });

    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      _startLocationServicePolling();
      if (mounted) {
        setState(() {
          _locationBusy = false;
          _locationStatus = 'Enable GPS to auto-fill place details.';
        });
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _locationBusy = false;
          _locationStatus = 'Location permission blocked in settings.';
        });
      }
      return;
    }
    if (permission == LocationPermission.denied) {
      if (mounted) {
        setState(() {
          _locationBusy = false;
          _locationStatus = 'Location permission denied.';
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _locationStatus = 'Fetching accurate position...');

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locationBusy = false;
        _locationStatus =
            'GPS Locked (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
      });
      await _reverseGeocode(pos.latitude, pos.longitude);
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationBusy = false;
          _locationStatus = 'Location unavailable. Enter address manually.';
        });
      }
    }
  }

  Future<void> _refreshLocation() async {
    await _captureLocationAndPlace();
  }

  Future<File?> _compressPhoto(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final target = p.join(
        dir.path,
        'visit_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        target,
        quality: 86,
        minWidth: 1280,
        minHeight: 1280,
      );
      return result != null ? File(result.path) : file;
    } catch (_) {
      return file;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: source == ImageSource.camera ? 85 : 92,
    );
    if (file == null) return;
    setState(() => _selectedImage = File(file.path));
  }

  Future<void> _showImageSourceSheet() async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Visit Proof Photo',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Take a photo of site or party meeting',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildModalOption(
                      ctx,
                      icon: Icons.camera_alt_rounded,
                      label: 'Take Photo',
                      color: scheme.primary,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildModalOption(
                      ctx,
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: scheme.secondary,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalOption(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickVisitWhen() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _visitWhen,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_visitWhen),
    );
    if (t == null || !mounted) return;
    setState(() {
      _visitWhen = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  String _formatApiDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }

  InputDecoration _fieldDec(
    String label, {
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 20, color: scheme.primary.withOpacity(0.8)),
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error.withOpacity(0.8)),
      ),
    );
  }

  String _formatSpeechText(TextEditingController c, String text) {
    if (text.isEmpty) return text;
    if (c == _contactEmailCtrl) return text.toLowerCase().replaceAll(' ', '');
    if (c == _contactPhoneCtrl) return text.replaceAll(' ', '');
    if (c == _partyNameCtrl ||
        c == _cityCtrl ||
        c == _contactNameCtrl ||
        c == _purposeCtrl) {
      return text.split(' ').map((word) {
        if (word.isEmpty) return word;
        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      }).join(' ');
    }
    if (c == _addressCtrl || c == _notesCtrl) {
      return '${text[0].toUpperCase()}${text.substring(1)}';
    }
    return text;
  }

  Widget _micButton(TextEditingController controller, FocusNode focus) {
    final active = _speechListening && identical(_speechTarget, controller);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: IconButton(
        key: ValueKey(active),
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.only(right: 8),
        tooltip: active ? 'Listening...' : 'Voice typing',
        onPressed: () {
          FocusScope.of(context).requestFocus(focus);
          _toggleSpeech(controller);
        },
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: active ? Colors.red.shade50 : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            active ? Icons.mic_rounded : Icons.mic_none_rounded,
            size: 20,
            color: active ? Colors.redAccent : Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSpeech(TextEditingController controller) async {
    var mic = await Permission.microphone.status;
    if (!mic.isGranted) {
      mic = await Permission.microphone.request();
    }
    if (mic.isPermanentlyDenied) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Microphone Permission'),
          content: const Text('Please enable microphone access in settings for voice typing.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return;
    }
    if (!mic.isGranted) return;

    if (_speechListening) {
      await _speech.stop();
      final was = _speechTarget;
      if (!mounted) return;
      setState(() {
        _speechListening = false;
        _speechTarget = null;
      });
      if (was == controller) return;
    }

    final ok = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (!mounted) return;
          setState(() {
            _speechListening = false;
            _speechTarget = null;
          });
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _speechListening = false;
          _speechTarget = null;
        });
      },
    );
    if (!ok) return;
    if (!mounted) return;
    setState(() {
      _speechListening = true;
      _speechTarget = controller;
      _speechBaseline = controller.text;
    });
    await _speech.listen(
      onResult: (val) {
        if (!mounted) return;
        setState(() {
          final raw = val.recognizedWords;
          final formatted = _formatSpeechText(controller, raw);
          if (_speechBaseline.isNotEmpty) {
            final prefix = _speechBaseline.endsWith(' ') ? _speechBaseline : '$_speechBaseline ';
            controller.text = '$prefix$formatted';
          } else {
            controller.text = formatted;
          }
          controller.selection = TextSelection.collapsed(offset: controller.text.length);
        });
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: const Text('Please upload a proof photo before saving.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final image = await _compressPhoto(_selectedImage!);
      final fields = <String, dynamic>{
        'is_new_visit': _isNewVisit,
        'client_name': _isClient ? _partyNameCtrl.text.trim() : null,
        'contractor_name': !_isClient ? _partyNameCtrl.text.trim() : null,
        'state': _selectedState ?? '',
        'city': _cityCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'contact_name': _contactNameCtrl.text.trim(),
        'contact_phone': _contactPhoneCtrl.text.trim(),
        'contact_email': _contactEmailCtrl.text.trim(),
        'purpose': _purposeCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'rating': _rating,
        'visit_date': _formatApiDateTime(_visitWhen),
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
        if (_followUpDate != null)
          'follow_up_date': _formatApiDateTime(
            DateTime(_followUpDate!.year, _followUpDate!.month, _followUpDate!.day, 10, 0, 0),
          ),
      };
      await ref.read(visitsProvider.notifier).createVisit(
            fields: fields,
            imageFile: image ?? _selectedImage!,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text('Failed to save visit: ${_visitSaveErrorMessage(e)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildCard({required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18.0),
      child: child,
    );
  }

  Widget _buildSegmentedPill<T>({
    required T selected,
    required List<ButtonSegment<T>> segments,
    required ValueChanged<Set<T>> onSelectionChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return SegmentedButton<T>(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
        backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.3),
        foregroundColor: scheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      segments: segments,
      selected: {selected},
      onSelectionChanged: onSelectionChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      drawer: const AppSideDrawer(),
      appBar: const SalesGlassAppBar(
        title: 'AddVisit ',
        showDrawer: true,
      ),
      body: ScreenAccentBackdrop(
        spot: DrawerRouteAccents.addVisit,
        spot2: DrawerRouteAccents.addVisitWarm,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- STEPPER PROGRESS TAB BAR ---
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant.withOpacity(0.2)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: scheme.onPrimary,
                  unselectedLabelColor: scheme.onSurfaceVariant,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  tabs: const [
                    Tab(text: '1. Location'),
                    Tab(text: '2. Contact'),
                    Tab(text: '3. Outcome'),
                  ],
                ),
              ),

              // --- TAB VIEWS ---
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: LOCATION & PARTY
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        // GPS Status Banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                scheme.primary.withOpacity(0.06),
                                scheme.secondary.withOpacity(0.03),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: scheme.primary.withOpacity(0.12)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.my_location_rounded, size: 18, color: scheme.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _placeHeadline ?? 'Location Status',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _locationStatus,
                                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _locationBusy ? null : _refreshLocation,
                                style: IconButton.styleFrom(backgroundColor: scheme.surface),
                                icon: _locationBusy
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                                      )
                                    : Icon(Icons.refresh_rounded, size: 18, color: scheme.primary),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PARTY DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: scheme.primary, letterSpacing: 0.5)),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSegmentedPill<bool>(
                                      selected: _isClient,
                                      segments: const [
                                        ButtonSegment(value: true, label: Text('Client', style: TextStyle(fontSize: 15))),
                                        ButtonSegment(value: false, label: Text('Contractor', style: TextStyle(fontSize: 15))),
                                      ],
                                      onSelectionChanged: (s) => setState(() => _isClient = s.first),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildSegmentedPill<bool>(
                                      selected: _isNewVisit,
                                      segments: const [
                                        ButtonSegment(value: true, label: Text('New Visit', style: TextStyle(fontSize: 15))),
                                        ButtonSegment(value: false, label: Text('Followup', style: TextStyle(fontSize: 15))),
                                      ],
                                      onSelectionChanged: (s) {
                                        final next = s.first;
                                        setState(() {
                                          _isNewVisit = next;
                                          if (next) {
                                            _prefillContactFromAuth();
                                          } else {
                                            _contactPhoneCtrl.clear();
                                            _contactEmailCtrl.clear();
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _partyNameCtrl,
                                focusNode: _partyNameFocus,
                                decoration: _fieldDec(
                                  _isClient ? 'Client / Company Name' : 'Contractor Name',
                                  icon: Icons.business_rounded,
                                  suffixIcon: _micButton(_partyNameCtrl, _partyNameFocus),
                                ),
                                textCapitalization: TextCapitalization.words,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (v.trim().length < 3) return 'Min 3 chars';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _pickVisitWhen,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 18, color: scheme.primary),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Visit Time', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                          Text(
                                            DateFormat('EEE, dd MMM yyyy · hh:mm a').format(_visitWhen),
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Icon(Icons.edit_calendar_rounded, size: 18, color: scheme.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ADDRESS DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: scheme.primary, letterSpacing: 0.5)),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedState,
                                      isExpanded: true,
                                      decoration: _fieldDec('State'),
                                      hint: const Text('State', style: TextStyle(fontSize: 14)),
                                      items: _indianStates
                                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                                          .toList(),
                                      onChanged: (v) => setState(() => _selectedState = v),
                                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cityCtrl,
                                      focusNode: _cityFocus,
                                      decoration: _fieldDec(
                                        'City',
                                        suffixIcon: _micButton(_cityCtrl, _cityFocus),
                                      ),
                                      textCapitalization: TextCapitalization.words,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _addressCtrl,
                                focusNode: _addressFocus,
                                decoration: _fieldDec(
                                  'Full Address Line',
                                  icon: Icons.map_rounded,
                                  suffixIcon: _micButton(_addressCtrl, _addressFocus),
                                ),
                                maxLines: 2,
                                textCapitalization: TextCapitalization.sentences,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // TAB 2: CONTACT INFORMATION
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PRIMARY CONTACT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: scheme.primary, letterSpacing: 0.5)),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _contactNameCtrl,
                                focusNode: _contactNameFocus,
                                decoration: _fieldDec(
                                  'Contact Person Name',
                                  icon: Icons.person_rounded,
                                  suffixIcon: _micButton(_contactNameCtrl, _contactNameFocus),
                                ),
                                textCapitalization: TextCapitalization.words,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _contactPhoneCtrl,
                                focusNode: _contactPhoneFocus,
                                keyboardType: TextInputType.phone,
                                decoration: _fieldDec(
                                  'Phone Number',
                                  icon: Icons.phone_rounded,
                                  suffixIcon: _micButton(_contactPhoneCtrl, _contactPhoneFocus),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                                  if (digits.length != 10) return '10 digits';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _contactEmailCtrl,
                                focusNode: _contactEmailFocus,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _fieldDec(
                                  'Email Address',
                                  icon: Icons.alternate_email_rounded,
                                  suffixIcon: _micButton(_contactEmailCtrl, _contactEmailFocus),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
                                  if (!ok) return 'Invalid';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // TAB 3: OUTCOME & PROOF
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('VISIT PURPOSE & FEEDBACK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: scheme.primary, letterSpacing: 0.5)),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _purposeCtrl,
                                focusNode: _purposeFocus,
                                decoration: _fieldDec(
                                  'Purpose of Visit',
                                  icon: Icons.track_changes_rounded,
                                  suffixIcon: _micButton(_purposeCtrl, _purposeFocus),
                                ),
                                textCapitalization: TextCapitalization.sentences,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),

                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.star_rounded, color: _ratingColor(_rating), size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _rating,
                                          isExpanded: true,
                                          items: List.generate(10, (i) {
                                            final n = i + 1;
                                            final label = _ratingLabelFor(n);
                                            return DropdownMenuItem(
                                              value: n,
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: _ratingColor(n).withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      '$n',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: _ratingColor(n),
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      label,
                                                      style: TextStyle(color: scheme.onSurface, fontSize: 12),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                          onChanged: (v) {
                                            if (v != null) setState(() => _rating = v);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _notesCtrl,
                                focusNode: _notesFocus,
                                maxLines: 2,
                                decoration: _fieldDec(
                                  'Discussion Notes (Optional)',
                                  icon: Icons.notes_rounded,
                                  suffixIcon: _micButton(_notesCtrl, _notesFocus),
                                ),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _followUpDate ?? now,
                                    firstDate: now,
                                    lastDate: DateTime(now.year + 2),
                                  );
                                  if (picked != null) setState(() => _followUpDate = picked);
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _followUpDate == null
                                        ? scheme.surfaceContainerHighest.withOpacity(0.2)
                                        : scheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _followUpDate == null
                                          ? scheme.outlineVariant.withOpacity(0.3)
                                          : scheme.primary.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.event_repeat_rounded,
                                        size: 18,
                                        color: _followUpDate == null ? scheme.onSurfaceVariant : scheme.primary,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _followUpDate == null
                                            ? 'Set Follow-up Date'
                                            : 'Follow-up: ${DateFormat('dd MMM yyyy').format(_followUpDate!)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: _followUpDate == null ? FontWeight.normal : FontWeight.bold,
                                          color: _followUpDate == null ? scheme.onSurfaceVariant : scheme.primary,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (_followUpDate != null)
                                        GestureDetector(
                                          onTap: () => setState(() => _followUpDate = null),
                                          child: Icon(Icons.cancel_rounded, size: 18, color: scheme.primary),
                                        )
                                      else
                                        Icon(Icons.add_rounded, size: 18, color: scheme.onSurfaceVariant),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PHOTO PROOF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: scheme.primary, letterSpacing: 0.5)),
                              const SizedBox(height: 14),
                              Container(
                                height: 130,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _selectedImage == null
                                        ? scheme.outlineVariant.withOpacity(0.3)
                                        : scheme.primary.withOpacity(0.5),
                                  ),
                                ),
                                child: InkWell(
                                  onTap: _showImageSourceSheet,
                                  borderRadius: BorderRadius.circular(16),
                                  child: _selectedImage == null
                                      ? Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_a_photo_rounded, size: 24, color: scheme.primary),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Upload proof photo',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                                            ),
                                          ],
                                        )
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.file(_selectedImage!, fit: BoxFit.cover),
                                              Container(color: Colors.black38),
                                              Center(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.7),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: const Text('Change Photo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // --- BOTTOM NAVIGATION BUTTONS ---
              Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -4)),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      if (_currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _tabController.animateTo(_currentStep - 1),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Back'),
                          ),
                        ),
                      if (_currentStep > 0) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () {
                            if (_currentStep < 2) {
                              _tabController.animateTo(_currentStep + 1);
                            } else {
                              if (!_saving) _save();
                            }
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  _currentStep == 2 ? 'Save Visit' : 'Next Step',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}