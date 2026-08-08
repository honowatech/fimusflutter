import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../utils/api_config.dart';
import 'package:dio/dio.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _pseudoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String selectedType = 'particulier';
  int? selectedCountryId;
  List<dynamic> _countries = [];
  bool isLoadingCountries = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchCountries();
  }

  Future<void> _fetchCountries() async {
    try {
      final dio = Dio();
      final response = await dio.get(ApiConfig.countries);
      if (mounted) {
        setState(() {
          _countries = response.data;
          isLoadingCountries = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingCountries = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.completeProfileTitle),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.account_circle,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.completeProfileSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.accountType,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => selectedType = 'particulier');
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedType == 'particulier'
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade300,
                              width: selectedType == 'particulier' ? 2 : 1,
                            ),
                            color: selectedType == 'particulier'
                                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                : Colors.transparent,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                color: selectedType == 'particulier'
                                    ? theme.colorScheme.primary
                                    : Colors.grey.shade500,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.individualProfile,
                                style: TextStyle(
                                  fontWeight: selectedType == 'particulier'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: selectedType == 'particulier'
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => selectedType = 'professionnel');
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedType == 'professionnel'
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade300,
                              width: selectedType == 'professionnel' ? 2 : 1,
                            ),
                            color: selectedType == 'professionnel'
                                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                : Colors.transparent,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.business_rounded,
                                color: selectedType == 'professionnel'
                                    ? theme.colorScheme.primary
                                    : Colors.grey.shade500,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.professionalProfile,
                                style: TextStyle(
                                  fontWeight: selectedType == 'professionnel'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: selectedType == 'professionnel'
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.countryOfResidence,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                isLoadingCountries
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ))
                    : DropdownButtonFormField<int>(
                        value: selectedCountryId,
                        hint: Text(l10n.selectCountry),
                        items: _countries.map((country) {
                          return DropdownMenuItem<int>(
                            value: country['id'],
                            child: Text(country['name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedCountryId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return l10n.countryRequired;
                          }
                          return null;
                        },
                      ),
                const SizedBox(height: 24),
                Text(
                  l10n.pseudo,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _pseudoController,
                  decoration: InputDecoration(
                    hintText: l10n.pseudoExample,
                    prefixIcon: const Icon(Icons.alternate_email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.pseudoRequired;
                    }
                    if (value.length < 3 || value.length > 15) {
                      return l10n.pseudoLength;
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value)) {
                      return l10n.pseudoFormat;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() => isSubmitting = true);
                            try {
                              await context.read<AuthProvider>().completeProfile(
                                context,
                                pseudo: _pseudoController.text.trim(),
                                countryId: selectedCountryId!,
                                type: selectedType,
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString()),
                                    backgroundColor: theme.colorScheme.error,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => isSubmitting = false);
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.finish),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
