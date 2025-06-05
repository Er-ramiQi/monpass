// lib/screens/profile/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:monpass/services/user_service.dart' as user_service;
import 'package:monpass/theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;
  
  const EditProfileScreen({
    super.key,
    required this.userProfile,
  });

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> 
    with TickerProviderStateMixin {
  final user_service.UserService _userService = user_service.UserService();
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _selectedBirthDate;
  String? _selectedGender;
  Map<String, dynamic>? _selectedAvatar;
  
  // Page controller for steps
  late PageController _pageController;
  int _currentStep = 0;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  final List<String> _genderOptions = ['Homme', 'Femme', 'Autre', 'Préfère ne pas dire'];
  
  // Avatar options
  final List<Map<String, dynamic>> _avatarOptions = [
    {'icon': Icons.person_rounded, 'color': 0xFF1E88E5, 'name': 'Classique'},
    {'icon': Icons.face_rounded, 'color': 0xFF43A047, 'name': 'Visage'},
    {'icon': Icons.emoji_emotions_rounded, 'color': 0xFFFFA726, 'name': 'Souriant'},
    {'icon': Icons.account_circle_rounded, 'color': 0xFF9C27B0, 'name': 'Compte'},
    {'icon': Icons.sentiment_very_satisfied_rounded, 'color': 0xFFE53935, 'name': 'Heureux'},
    {'icon': Icons.psychology_rounded, 'color': 0xFF00ACC1, 'name': 'Penseur'},
    {'icon': Icons.work_rounded, 'color': 0xFF5E35B1, 'name': 'Professionnel'},
    {'icon': Icons.school_rounded, 'color': 0xFFFF7043, 'name': 'Étudiant'},
    {'icon': Icons.sports_esports_rounded, 'color': 0xFF26A69A, 'name': 'Gamer'},
    {'icon': Icons.music_note_rounded, 'color': 0xFFEC407A, 'name': 'Musical'},
    {'icon': Icons.camera_alt_rounded, 'color': 0xFF42A5F5, 'name': 'Photographe'},
    {'icon': Icons.palette_rounded, 'color': 0xFFAB47BC, 'name': 'Artiste'},
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initAnimations();
    _initializeControllers();
  }
  
  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }
  
  void _initializeControllers() {
    if (widget.userProfile != null) {
      _firstNameController.text = widget.userProfile?['firstName'] ?? '';
      _lastNameController.text = widget.userProfile?['lastName'] ?? '';
      _emailController.text = widget.userProfile?['email'] ?? '';
      _phoneController.text = widget.userProfile?['phoneNumber'] ?? '';
      _selectedGender = widget.userProfile?['gender'];
      _selectedAvatar = widget.userProfile?['avatar'];
      
      // Parse birth date
      if (widget.userProfile?['birthDate'] != null) {
        try {
          if (widget.userProfile!['birthDate'] is String) {
            _selectedBirthDate = DateTime.parse(widget.userProfile!['birthDate']);
          } else if (widget.userProfile!['birthDate'] is int) {
            _selectedBirthDate = DateTime.fromMillisecondsSinceEpoch(widget.userProfile!['birthDate']);
          }
        } catch (e) {
          _selectedBirthDate = null;
        }
      }
    }
  }
  
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      // Navigate to first step with error
      _navigateToStepWithError();
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      Map<String, dynamic> updatedData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'gender': _selectedGender,
        'birthDate': _selectedBirthDate?.millisecondsSinceEpoch,
        'avatar': _selectedAvatar,
        'displayName': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      };
      
      bool success = await _userService.updateUserProfile(updatedData);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Échec de la mise à jour du profil';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _navigateToStepWithError() {
    // Check each step for validation errors
    if (_firstNameController.text.trim().isEmpty || 
        _lastNameController.text.trim().isEmpty) {
      _navigateToStep(0);
    } else if (_emailController.text.trim().isEmpty || 
               _phoneController.text.trim().isEmpty) {
      _navigateToStep(1);
    }
  }
  
  void _navigateToStep(int step) {
    setState(() {
      _currentStep = step;
    });
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
  
  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      
      // Reset animations for next step
      _slideController.reset();
      _slideController.forward();
    }
  }
  
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      
      // Reset animations for previous step
      _slideController.reset();
      _slideController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[900]!.withOpacity(0.9),
              Colors.blue[700]!.withOpacity(0.8),
              Colors.blue[500]!.withOpacity(0.7),
              Colors.white.withOpacity(0.9),
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(isTablet),
              
              // Progress indicator
              _buildProgressIndicator(),
              
              // Content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Form(
                      key: _formKey,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentStep = index;
                          });
                        },
                        children: [
                          _buildPersonalInfoStep(isTablet),
                          _buildContactInfoStep(isTablet),
                          _buildAvatarStep(isTablet),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Navigation buttons
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 20,
        vertical: 20,
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.white, Colors.white.withOpacity(0.8)],
                  ).createShader(bounds),
                  child: Text(
                    'Modifier le profil',
                    style: TextStyle(
                      fontSize: isTablet ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStepTitle(_currentStep),
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          final isCurrent = index == _currentStep;
          
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              height: 8,
              decoration: BoxDecoration(
                gradient: isActive
                    ? LinearGradient(
                        colors: [Colors.white, Colors.white.withOpacity(0.8)],
                      )
                    : null,
                color: isActive ? null : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
  
  Widget _buildPersonalInfoStep(bool isTablet) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 32 : 20),
      child: Column(
        children: [
          _buildStepCard(
            isTablet: isTablet,
            icon: Icons.person_outline_rounded,
            title: 'Informations personnelles',
            color: Colors.purple,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _firstNameController,
                      label: 'Prénom',
                      icon: Icons.badge_rounded,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le prénom est requis';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _lastNameController,
                      label: 'Nom de famille',
                      icon: Icons.badge_outlined,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le nom est requis';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDatePicker(
                label: 'Date de naissance',
                icon: Icons.cake_rounded,
                selectedDate: _selectedBirthDate,
                onDateSelected: (date) {
                  setState(() {
                    _selectedBirthDate = date;
                  });
                },
              ),
              const SizedBox(height: 20),
              _buildDropdown(
                label: 'Genre',
                icon: Icons.wc_rounded,
                value: _selectedGender,
                items: _genderOptions,
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildContactInfoStep(bool isTablet) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 32 : 20),
      child: Column(
        children: [
          _buildStepCard(
            isTablet: isTablet,
            icon: Icons.contact_phone_rounded,
            title: 'Informations de contact',
            color: Colors.green,
            children: [
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'L\'email est requis';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Email invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _phoneController,
                label: 'Téléphone',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le téléphone est requis';
                  }
                  return null;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAvatarStep(bool isTablet) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 32 : 20),
      child: Column(
        children: [
          _buildStepCard(
            isTablet: isTablet,
            icon: Icons.account_circle_rounded,
            title: 'Avatar et photo',
            color: Colors.orange,
            children: [
              // Current avatar preview
              Center(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _selectedAvatar != null
                                ? [
                                    Color(_selectedAvatar!['backgroundColor'] ?? 0xFF1E88E5),
                                    Color(_selectedAvatar!['backgroundColor'] ?? 0xFF1E88E5).withOpacity(0.7),
                                  ]
                                : [AppTheme.primaryColor, AppTheme.secondaryColor],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          _selectedAvatar != null
                              ? IconData(_selectedAvatar!['iconCode'], fontFamily: 'MaterialIcons')
                              : Icons.person_rounded,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Avatar options
              const Text(
                'Choisissez un avatar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const ScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isTablet ? 4 : 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _avatarOptions.length,
                  itemBuilder: (context, index) {
                    final avatar = _avatarOptions[index];
                    final isSelected = _selectedAvatar != null &&
                        _selectedAvatar!['iconCode'] == avatar['icon'].codePoint &&
                        _selectedAvatar!['backgroundColor'] == avatar['color'];
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAvatar = {
                            'type': 'avatar',
                            'iconCode': avatar['icon'].codePoint,
                            'backgroundColor': avatar['color'],
                            'name': avatar['name'],
                          };
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(avatar['color']),
                              Color(avatar['color']).withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Color(avatar['color']).withOpacity(0.3),
                              blurRadius: isSelected ? 15 : 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              avatar['icon'],
                              color: Colors.white,
                              size: isTablet ? 36 : 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              avatar['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Upload photo option
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey[300]!,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_rounded,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ou téléchargez une photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'JPG, PNG jusqu\'à 5MB',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement image upload
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Upload d\'image bientôt disponible'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Choisir une photo'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStepCard({
    required bool isTablet,
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 28 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.95),
            Colors.white.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 40,
            offset: const Offset(0, 25),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(0.1),
                AppTheme.secondaryColor.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }
  
  Widget _buildDatePicker({
    required String label,
    required IconData icon,
    required DateTime? selectedDate,
    required Function(DateTime?) onDateSelected,
  }) {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppTheme.primaryColor,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.1),
                    AppTheme.secondaryColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedDate != null
                        ? '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}'
                        : 'Sélectionner une date',
                    style: TextStyle(
                      fontSize: 16,
                      color: selectedDate != null ? Colors.black87 : Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.calendar_today_rounded,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.secondaryColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                  ),
                ),
                isExpanded: true,
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
                icon: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Précédent'),
              ),
            ),
          
          if (_currentStep > 0) const SizedBox(width: 16),
          
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.white.withOpacity(0.9)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : _currentStep < 2
                        ? _nextStep
                        : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : Icon(_currentStep < 2 ? Icons.arrow_forward_rounded : Icons.save_rounded),
                label: Text(
                  _isLoading
                      ? 'Sauvegarde...'
                      : _currentStep < 2
                          ? 'Suivant'
                          : 'Sauvegarder',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Informations personnelles';
      case 1:
        return 'Informations de contact';
      case 2:
        return 'Avatar et photo';
      default:
        return '';
    }
  }
}