import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../services/auth_service.dart';
import '../widgets/searchable_country_dropdown.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'register_screen.dart';
import 'main_screen.dart';
import 'complete_profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sanitizePseudo(String input) {
    const withAccents    = 'àáâãäåèéêëìíîïòóôõöùúûüçñýÿÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÇÑÝ';
    const withoutAccents = 'aaaaaaeeeeiiiiiooooouuuucnyyAAAAAAEEEEIIIIIOOOOOUUUUCNY';
    String result = input;
    for (int i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }
    result = result.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    result = result.replaceAll(RegExp(r'[_]{2,}'), '_').replaceAll(RegExp(r'[-]{2,}'), '-');
    result = result.replaceAll(RegExp(r'^[_|-]+|[_|-]+$'), '');
    if (result.length > 15) {
      result = result.substring(0, 15);
      result = result.replaceAll(RegExp(r'[_|-]+$'), '');
    }
    return result;
  }

  List<String> _generatePseudoSuggestions(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) return [];

    final List<String> suggestions = [];
    final sanitizedFull = _sanitizePseudo(displayName);

    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .map((p) => _sanitizePseudo(p))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isNotEmpty) {
      if (sanitizedFull.isNotEmpty && sanitizedFull.length >= 3) {
        suggestions.add(sanitizedFull);
      }
      if (parts.first.length >= 3) {
        suggestions.add(parts.first);
      }
      if (parts.length > 1 && parts.last.length >= 3) {
        suggestions.add(parts.last);
      }
      if (parts.length > 1 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
        final combined = _sanitizePseudo('${parts.first}_${parts.last}');
        if (combined.length >= 3) {
          suggestions.add(combined);
        }
      }
      if (parts.first.isNotEmpty) {
        final withYear = _sanitizePseudo('${parts.first}${DateTime.now().year % 100}');
        if (withYear.length >= 3) {
          suggestions.add(withYear);
        }
      }
    }

    return suggestions
        .where((s) => s.length >= 3 && s.length <= 15)
        .toSet()
        .toList();
  }

  Future<Map<String, dynamic>?> _showGoogleRegistrationBottomSheet(String? defaultName, {String? errorMessage}) async {
    final authService = AuthService();
    List<Map<String, dynamic>> countries = [];
    bool isLoadingCountries = true;
    int? selectedCountryId;
    String selectedType = 'particulier';

    final suggestions = _generatePseudoSuggestions(defaultName);

    String defaultPseudo = '';
    if (defaultName != null && defaultName.trim().isNotEmpty) {
      final sanitized = _sanitizePseudo(defaultName);
      if (sanitized.isNotEmpty) {
        defaultPseudo = sanitized;
      } else {
        defaultPseudo = defaultName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      }
    }
    final pseudoController = TextEditingController(text: defaultPseudo);

    try {
      final prefs = await SharedPreferences.getInstance();
      selectedCountryId = prefs.getInt('selected_country_id');
    } catch (_) {}

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final l10n = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            if (isLoadingCountries && countries.isEmpty) {
              authService.getCountries().then((list) {
                setModalState(() {
                  countries = List<Map<String, dynamic>>.from(list);
                  isLoadingCountries = false;
                });
              }).catchError((_) {
                setModalState(() {
                  isLoadingCountries = false;
                });
              });
            }

            final theme = Theme.of(context);
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.finalizeRegistration,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.finalizeRegistrationDesc,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          errorMessage,
                          style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    TextFormField(
                      controller: pseudoController,
                      decoration: InputDecoration(
                        labelText: l10n.username,
                        prefixIcon: const Icon(Icons.alternate_email),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.uniqueIdentifierDesc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Propositions :',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: suggestions.map((suggestion) {
                          final isSelected = pseudoController.text.trim() == suggestion;
                          return ChoiceChip(
                            label: Text('@$suggestion'),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() {
                                  pseudoController.text = suggestion;
                                });
                              }
                            },
                            selectedColor: theme.colorScheme.primaryContainer,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 24),

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
                              setModalState(() => selectedType = 'particulier');
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
                              setModalState(() => selectedType = 'professionnel');
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
                                    'Professionnel',
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
                      'Pays de résidence',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    isLoadingCountries
                        ? const Center(child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(),
                          ))
                        : SearchableCountryDropdown<int>(
                            countries: countries,
                            initialValue: selectedCountryId,
                            labelBuilder: (country) => country['name'] as String? ?? '',
                            valueBuilder: (country) => country['id'] as int,
                            hint: 'Sélectionnez votre pays',
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.flag_outlined),
                            ),
                            onChanged: (v) {
                              setModalState(() => selectedCountryId = v);
                            },
                          ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: selectedCountryId == null
                          ? null
                          : () {
                              final pseudo = pseudoController.text.trim();
                              if (pseudo.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.pleaseEnterUsername)),
                                );
                                return;
                              }
                              if (pseudo.length < 3 || pseudo.length > 15) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.pseudoLength)),
                                );
                                return;
                              }
                              final validPseudoRegex = RegExp(r'^[a-zA-Z0-9_-]+$');
                              if (!validPseudoRegex.hasMatch(pseudo)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(l10n.pseudoFormat)),
                                );
                                return;
                              }
                              Navigator.pop(context, {
                                'type': selectedType,
                                'country_id': selectedCountryId,
                                'pseudo': pseudo,
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      child: const Text(
                        'CONFIRMER ET S\'INSCRIRE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    
    final bool isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final String rawNonce = _generateNonce();
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(
      clientId: isIos ? '60857387958-c37ds66bcu99ejio7gp801lcomg4b38j.apps.googleusercontent.com' : null,
      serverClientId: '60857387958-er15r76tt09pkco2fo5i3q6ti1c6pp9q.apps.googleusercontent.com',
      nonce: rawNonce,
    );

    try {
      final GoogleSignInAccount googleUser;
      try {
        final account = await googleSignIn.attemptLightweightAuthentication();
        if (account != null) {
          googleUser = account;
        } else {
          googleUser = await googleSignIn.authenticate();
        }
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          setState(() => _isLoading = false);
          return;
        }
        
        String errorMessage;
        switch (e.code) {
          case GoogleSignInExceptionCode.interrupted:
            errorMessage = "Connexion interrompue, réessayez.";
            break;
          case GoogleSignInExceptionCode.uiUnavailable:
            errorMessage = "Aucun compte Google trouvé. Ajoutez-en un ou utilisez email/mot de passe.";
            break;
          case GoogleSignInExceptionCode.clientConfigurationError:
            errorMessage = "Configuration indisponible. Veuillez réessayer plus tard.";
            break;
          case GoogleSignInExceptionCode.providerConfigurationError:
            errorMessage = "Mettez à jour Google Play Services.";
            break;
          case GoogleSignInExceptionCode.userMismatch:
            errorMessage = "Changement de compte détecté, réessayez.";
            break;
          default:
            errorMessage = e.description ?? "Erreur Google Sign-In (${e.code})";
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception("Impossible d'obtenir le jeton ID Google.");
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

      if (googleUser.photoUrl != null) {
        profileProvider.updateProfile(profileProvider.profile.copyWith(photoUrl: googleUser.photoUrl));
      }

      try {
        await authProvider.loginWithGoogle(
          context,
          idToken: idToken,
          name: googleUser.displayName,
        );
        if (mounted) {
          final targetScreen = authProvider.isProfileComplete
              ? const MainScreen()
              : const CompleteProfileScreen();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => targetScreen),
          );
        }
      } on GoogleAuthNeedsRegistrationException catch (_) {
        if (mounted) {
          String? currentPseudo = googleUser.displayName;
          String? errorMessage;
          
          while (true) {
            final extraInfo = await _showGoogleRegistrationBottomSheet(currentPseudo, errorMessage: errorMessage);
            if (extraInfo == null) {
              setState(() => _isLoading = false);
              return;
            }
            
            setState(() => _isLoading = true);
            String currentIdToken = idToken;
            
            try {
              await authProvider.loginWithGoogle(
                context,
                idToken: currentIdToken,
                name: googleUser.displayName,
                type: extraInfo['type'] as String,
                countryId: extraInfo['country_id'] as int,
                pseudo: extraInfo['pseudo'] as String,
              );
              if (mounted) {
                final targetScreen = authProvider.isProfileComplete
                    ? const MainScreen()
                    : const CompleteProfileScreen();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => targetScreen),
                );
                return;
              }
            } on PseudoTakenException catch (e) {
               currentPseudo = extraInfo['pseudo'] as String;
               errorMessage = e.message;
               setState(() => _isLoading = false);
               continue;
            } on InvalidGoogleTokenException catch (_) {
               try {
                 final newGoogleUser = await googleSignIn.attemptLightweightAuthentication() ?? await googleSignIn.authenticate();
                 final newAuth = await newGoogleUser.authentication;
                 if (newAuth.idToken != null) {
                   currentIdToken = newAuth.idToken!;
                   await authProvider.loginWithGoogle(
                     context,
                     idToken: currentIdToken,
                     name: newGoogleUser.displayName,
                     type: extraInfo['type'] as String,
                     countryId: extraInfo['country_id'] as int,
                     pseudo: extraInfo['pseudo'] as String,
                   );
                    if (mounted) {
                      final targetScreen = authProvider.isProfileComplete
                          ? const MainScreen()
                          : const CompleteProfileScreen();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => targetScreen),
                      );
                      return;
                    }
                 }
               } catch (e) {
                 rethrow;
               }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseFillAllFields)),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.login(context, email, password);
      if (mounted) {
        final targetScreen = authProvider.isProfileComplete
            ? const MainScreen()
            : const CompleteProfileScreen();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => targetScreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    bool isSubmitting = false;
    final l10n = AppLocalizations.of(context)!;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.forgotPassword),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.forgotPasswordInstruction),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.email,
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: Text(l10n.cancel.toUpperCase()),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.pleaseEnterValidEmail)),
                            );
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          try {
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            await authProvider.forgotPassword(context, email);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Un nouveau mot de passe a été envoyé à votre adresse email. Veuillez vérifier vos spams si le message n\'est pas dans la boîte principale.',
                                  ),
                                  duration: Duration(seconds: 5),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.resetPasswordBtn),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 120,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connectez-vous pour gérer vos finances',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.emailOrUsername,
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _showForgotPasswordDialog,
                      child: Text(
                        'Mot de passe oublié ?',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'SE CONNECTER',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OU',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: Image.asset('assets/images/google_logo.png', height: 24, width: 24),
                    label: Text(l10n.continueWithGoogle),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        text: "Vous n'avez pas de compte ? ",
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        children: [
                          TextSpan(
                            text: "S'inscrire",
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }
}
