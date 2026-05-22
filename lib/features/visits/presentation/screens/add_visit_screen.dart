import 'dart:async';
import 'dart:io';

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

const _indianStates = <String>[
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Delhi',
  'Jammu and Kashmir',
  'Ladakh',
  'Puducherry',
];

/// Same wording as legacy Sales App rating dropdown.
const _ratingLabels = <String>[
  '',
  'Not intrested',
  'Less quantity, Rate OK',
  'Medium Qty, Rate NG',
  'High Qty, Rate NG',
  'Neutral',
  'Qty OK, Rate OK, Vendor not changing',
  'Order more then 45 Days',
  'Order more then 15 Days',
  'Order Within 15 Days',
  'Instant Order',
];

String _ratingLabelFor(int r) =>
    (r >= 1 && r <= 10) ? _ratingLabels[r] : '';

Color _ratingColor(int r) {
  if (r <= 3) return Colors.red.shade600;
  if (r <= 5) return Colors.orange.shade700;
  if (r <= 7) return Colors.blue.shade700;
  return Colors.green.shade700;
}

class AddVisitScreen extends ConsumerStatefulWidget {
  const AddVisitScreen({super.key});

  @override
  ConsumerState<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends ConsumerState<AddVisitScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
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
  String _locationStatus =
      'We will request location to fill the map pin and suggest address fields.';

  Timer? _locationServicePoll;

  late final stt.SpeechToText _speech;
  bool _speechListening = false;
  TextEditingController? _speechTarget;
  String _speechBaseline = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speech = stt.SpeechToText();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefillContactFromAuth();
      _captureLocationAndPlace();
    });
  }

  @override
  void dispose() {
    _locationServicePoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    try {
      _speech.stop();
    } catch (_) {}
    try {
      _speech.cancel();
    } catch (_) {}

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
    } catch (_) {
      /* optional */
    }
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
            _locationStatus =
                'Location services are off. Turn them on and tap refresh, or enter the address manually.';
          });
        }
      }
    });
  }

  Future<void> _captureLocationAndPlace() async {
    if (!mounted) return;
    setState(() {
      _locationBusy = true;
      _locationStatus = 'Checking location services…';
    });

    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      _startLocationServicePolling();
      if (mounted) {
        setState(() {
          _locationBusy = false;
          _locationStatus =
              'Enable device location, then return to the app. We will retry automatically.';
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
          _locationStatus =
              'Location permission blocked. Open Settings to allow, or enter the site manually.';
        });
      }
      return;
    }
    if (permission == LocationPermission.denied) {
      if (mounted) {
        setState(() {
          _locationBusy = false;
          _locationStatus =
              'Location denied. You can still submit; tap refresh after allowing permission.';
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _locationStatus = 'Fetching GPS & place…');

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
            'GPS locked · ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      });
      await _reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        if (!mounted) return;
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _locationBusy = false;
          _locationStatus =
              'GPS locked · ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        });
        await _reverseGeocode(pos.latitude, pos.longitude);
      } catch (_) {
        if (mounted) {
          setState(() {
            _locationBusy = false;
            _locationStatus =
                'Could not read GPS. You can still save; coordinates stay blank.';
          });
        }
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
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Visit photo',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'A clear site photo is required to submit (same as classic Sales App).',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Use camera'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Pick from gallery'),
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
      _visitWhen = DateTime(
        d.year,
        d.month,
        d.day,
        t.hour,
        t.minute,
      );
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
      prefixIcon: icon == null ? null : Icon(icon, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: .75)),
      ),
    );
  }

  String _formatSpeechText(TextEditingController c, String text) {
    if (text.isEmpty) return text;
    if (c == _contactEmailCtrl) {
      return text.toLowerCase().replaceAll(' ', '');
    }
    if (c == _contactPhoneCtrl) {
      return text.replaceAll(' ', '');
    }
    // Party / city / contact / purpose: light title-case for voice chunks
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
    final active =
        _speechListening && identical(_speechTarget, controller);
    return IconButton(
      tooltip: active ? 'Stop voice input' : 'Voice input',
      onPressed: () {
        FocusScope.of(context).requestFocus(focus);
        _toggleSpeech(controller);
      },
      icon: Icon(
        active ? Icons.mic_rounded : Icons.mic_none_rounded,
        color: active ? Colors.redAccent : null,
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
          title: const Text('Microphone'),
          content: const Text(
            'Voice input needs microphone access. You can enable it in system settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      return;
    }
    if (!mic.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required for voice input.')),
      );
      return;
    }

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
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition is not available on this device.'),
          ),
        );
      }
      return;
    }
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
            final prefix = _speechBaseline.endsWith(' ')
                ? _speechBaseline
                : '$_speechBaseline ';
            controller.text = '$prefix$formatted';
          } else {
            controller.text = formatted;
          }
          controller.selection = TextSelection.collapsed(
            offset: controller.text.length,
          );
        });
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a visit photo.')),
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
            DateTime(
              _followUpDate!.year,
              _followUpDate!.month,
              _followUpDate!.day,
              10,
              0,
              0,
            ),
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
        SnackBar(content: Text('Failed to save visit: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      drawer: const AppSideDrawer(),
      appBar: const SalesGlassAppBar(
        title: 'Add visit',
        showDrawer: true,
      ),
      body: ScreenAccentBackdrop(
        spot: DrawerRouteAccents.addVisit,
        spot2: DrawerRouteAccents.addVisitWarm,
        child: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  PremiumFeatureHeader(
                    icon: Icons.add_location_alt_rounded,
                    title: 'Capture the visit',
                    subtitle:
                        'GPS and reverse geocoding suggest city, state, and street like the classic app. Edit anything before saving.',
                    trailing: IconButton(
                      tooltip: 'Refresh GPS & place',
                      onPressed: _locationBusy ? null : _refreshLocation,
                      icon: _locationBusy
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.primary,
                              ),
                            )
                          : Icon(Icons.my_location_rounded, color: scheme.primary),
                    ),
                  ),
                  PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PremiumSectionTitle(
                          title: 'Party',
                          subtitle: 'Who did you meet on site?',
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              label: Text('Client'),
                              icon: Icon(Icons.business_rounded, size: 18),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text('Contractor'),
                              icon: Icon(Icons.engineering_rounded, size: 18),
                            ),
                          ],
                          selected: {_isClient},
                          onSelectionChanged: (s) =>
                              setState(() => _isClient = s.first),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _partyNameCtrl,
                          focusNode: _partyNameFocus,
                          decoration: _fieldDec(
                            _isClient ? 'Client name' : 'Contractor name',
                            icon: Icons.badge_outlined,
                            suffixIcon: _micButton(_partyNameCtrl, _partyNameFocus),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            if (v.trim().length < 3) {
                              return 'At least 3 characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PremiumSectionTitle(
                          title: 'Visit type & timing',
                          subtitle: 'Matches legacy app: new vs follow-up.',
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              label: Text('New'),
                              icon: Icon(Icons.fiber_new_rounded, size: 18),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text('Follow-up'),
                              icon: Icon(Icons.reply_rounded, size: 18),
                            ),
                          ],
                          selected: {_isNewVisit},
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
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.event_rounded, color: scheme.primary),
                          title: const Text('Visit date & time'),
                          subtitle: Text(
                            DateFormat('EEE, d MMM yyyy · h:mm a')
                                .format(_visitWhen),
                          ),
                          trailing: const Icon(Icons.edit_calendar_outlined),
                          onTap: _pickVisitWhen,
                        ),
                        const Divider(height: 24),
                        Material(
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: _locationBusy ? null : _refreshLocation,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: _locationBusy
                                        ? Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: scheme.primary,
                                            ),
                                          )
                                        : Icon(
                                            Icons.place_rounded,
                                            color: scheme.primary,
                                            size: 28,
                                          ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Location & place',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _locationStatus,
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                            height: 1.35,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (_placeHeadline != null &&
                                            _placeHeadline!.trim().isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                            _placeHeadline!,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.refresh_rounded, color: scheme.primary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PremiumSectionTitle(
                          title: 'Place',
                          subtitle:
                              'Reverse geocode fills these when GPS works; pick state from the list.',
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use — controlled updates from GPS / user
                          value: _selectedState,
                          decoration: _fieldDec('State', icon: Icons.map_outlined),
                          hint: Text(
                            'Select state',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          items: _indianStates
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _selectedState = v),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Pick a state' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _cityCtrl,
                          focusNode: _cityFocus,
                          decoration: _fieldDec(
                            'City',
                            icon: Icons.location_city_outlined,
                            suffixIcon: _micButton(_cityCtrl, _cityFocus),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _addressCtrl,
                          focusNode: _addressFocus,
                          decoration: _fieldDec(
                            'Address',
                            icon: Icons.home_work_outlined,
                            suffixIcon: _micButton(_addressCtrl, _addressFocus),
                          ),
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PremiumSectionTitle(
                          title: 'Contact on site',
                          subtitle:
                              'For new visits, your account email and phone start here — replace with the client if needed.',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _contactNameCtrl,
                          focusNode: _contactNameFocus,
                          decoration: _fieldDec(
                            'Name',
                            icon: Icons.person_outline,
                            suffixIcon: _micButton(_contactNameCtrl, _contactNameFocus),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _contactPhoneCtrl,
                          focusNode: _contactPhoneFocus,
                          keyboardType: TextInputType.phone,
                          decoration: _fieldDec(
                            'Phone',
                            icon: Icons.phone_outlined,
                            suffixIcon: _micButton(_contactPhoneCtrl, _contactPhoneFocus),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                            if (digits.length != 10) {
                              return 'Enter 10-digit phone';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _contactEmailCtrl,
                          focusNode: _contactEmailFocus,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _fieldDec(
                            'Email',
                            icon: Icons.email_outlined,
                            suffixIcon: _micButton(_contactEmailCtrl, _contactEmailFocus),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Required';
                            }
                            final ok = RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(v.trim());
                            if (!ok) return 'Invalid email';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PremiumSectionTitle(
                          title: 'Outcome',
                          subtitle: 'Purpose, notes, rating, follow-up.',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _purposeCtrl,
                          focusNode: _purposeFocus,
                          decoration: _fieldDec(
                            'Purpose',
                            icon: Icons.flag_outlined,
                            suffixIcon: _micButton(_purposeCtrl, _purposeFocus),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesCtrl,
                          focusNode: _notesFocus,
                          maxLines: 4,
                          decoration: _fieldDec(
                            'Notes',
                            hint: 'Optional — key takeaways',
                            icon: Icons.notes_rounded,
                            suffixIcon: _micButton(_notesCtrl, _notesFocus),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          // ignore: deprecated_member_use — rating must stay controlled
                          value: _rating,
                          isExpanded: true,
                          decoration: _fieldDec(
                            'Interest level (1–10)',
                            icon: Icons.star_rate_rounded,
                          ),
                          items: List.generate(10, (i) {
                            final n = i + 1;
                            final label = _ratingLabelFor(n);
                            return DropdownMenuItem(
                              value: n,
                              child: Text(
                                '$n — $label',
                                style: TextStyle(color: _ratingColor(n)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                          onChanged: (v) {
                            if (v != null) setState(() => _rating = v);
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _ratingLabelFor(_rating),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading:
                              Icon(Icons.event_available_outlined, color: scheme.primary),
                          title: Text(
                            _followUpDate == null
                                ? 'Follow-up date (optional)'
                                : 'Follow-up · ${DateFormat('d MMM yyyy').format(_followUpDate!)}',
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _followUpDate ?? now,
                                firstDate: now,
                                lastDate: DateTime(now.year + 2),
                              );
                              if (picked != null) {
                                setState(() => _followUpDate = picked);
                              }
                            },
                            child: const Text('Pick'),
                          ),
                        ),
                        if (_followUpDate != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => _followUpDate = null),
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('Remove follow-up date'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PremiumCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PremiumSectionTitle(
                          title: 'Proof photo',
                          subtitle: 'Compressed before upload to save data.',
                        ),
                        const SizedBox(height: 12),
                        AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Material(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              onTap: _showImageSourceSheet,
                              borderRadius: BorderRadius.circular(18),
                              child: _selectedImage == null
                                  ? CustomPaint(
                                      painter: _DashedBorderPainter(
                                        color: scheme.outlineVariant,
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.add_a_photo_rounded,
                                              size: 40,
                                              color: scheme.primary,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Tap to add photo',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.file(
                                            _selectedImage!,
                                            fit: BoxFit.cover,
                                          ),
                                          Positioned(
                                            right: 8,
                                            top: 8,
                                            child: FilledButton.tonal(
                                              onPressed: _showImageSourceSheet,
                                              child: const Icon(Icons.edit_rounded),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Material(
            elevation: 8,
            shadowColor: Colors.black38,
            color: scheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: scheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Saving…',
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Save visit',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
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

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(18),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    const dash = 7.0;
    const gap = 5.0;
    final path = Path()..addRRect(r);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final next = d + dash;
        canvas.drawPath(
          metric.extractPath(d, next.clamp(0, metric.length)),
          paint,
        );
        d = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
