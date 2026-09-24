import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _pseudoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
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
      final countries = await _authService.getCountries();
      if (mounted) {
        setState(() {
          _countries = countries;
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
              context.read<AuthProvider>().logout(context: context);
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
                // Cartes de choix : le fond non sélectionné reste `Colors.transparent`
                // (neutre dans les deux thèmes, il laisse voir la surface réelle).
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => selectedType = 'particulier'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedType == 'particulier'
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
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
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.profileTypePersonal,
                                style: TextStyle(
                                  fontSize: 12,
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => selectedType = 'petit_commerce'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedType == 'petit_commerce'
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                              width: selectedType == 'petit_commerce' ? 2 : 1,
                            ),
                            color: selectedType == 'petit_commerce'
                                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                : Colors.transparent,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                color: selectedType == 'petit_commerce'
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.profileTypeSmallBusinessShort,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selectedType == 'petit_commerce'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: selectedType == 'petit_commerce'
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => selectedType = 'entreprise'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedType == 'entreprise'
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                              width: selectedType == 'entreprise' ? 2 : 1,
                            ),
                            color: selectedType == 'entreprise'
                                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                : Colors.transparent,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.business_outlined,
                                color: selectedType == 'entreprise'
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.profileTypeCompany,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selectedType == 'entreprise'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: selectedType == 'entreprise'
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => selectedType = 'kiosque'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedType == 'kiosque'
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                              width: selectedType == 'kiosque' ? 2 : 1,
                            ),
                            color: selectedType == 'kiosque'
                                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                : Colors.transparent,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.point_of_sale_outlined,
                                color: selectedType == 'kiosque'
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.profileTypeKiosk,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selectedType == 'kiosque'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: selectedType == 'kiosque'
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
                          final id = country is Map ? (country['id'] is int ? country['id'] as int : int.tryParse(country['id']?.toString() ?? '')) : null;
                          final name = country is Map ? country['name']?.toString() ?? '' : country.toString();
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(name),
                          );
                        }).where((item) => item.value != null).toList(),
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
                          if (_formKey.currentState?.validate() == true && selectedCountryId != null) {
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
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
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
