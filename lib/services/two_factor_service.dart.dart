import 'package:firebase_auth/firebase_auth.dart';

class TwoFactorService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Variables pour stocker les informations de vérification
  String? _verificationId;
  int? _resendToken;
  User? _authenticatedUser;

  // Première étape : Authentification avec email et mot de passe
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Nous stockons l'utilisateur temporairement, mais nous ne considérons pas
      // l'authentification comme complète tant que l'OTP n'est pas validé
      _authenticatedUser = userCredential.user;
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  // Deuxième étape : Envoyer un code OTP au numéro de téléphone de l'utilisateur
  Future<void> sendOtpToPhone({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(PhoneAuthCredential) onVerificationCompleted,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Auto-vérification sur Android
          onVerificationCompleted(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onVerificationFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Vérifier le code OTP saisi par l'utilisateur
  Future<bool> verifyOtpCode({
    required String smsCode,
  }) async {
    try {
      if (_verificationId == null) {
        throw Exception('ID de vérification non disponible');
      }

      // Créer un objet PhoneAuthCredential avec le code fourni
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      // Pour l'authentification à deux facteurs, nous vérifions simplement si le code est valide
      // sans connecter l'utilisateur car il est déjà connecté avec email/mot de passe
      try {
        // Lier cette credential au compte déjà authentifié
        if (_authenticatedUser != null) {
          await _authenticatedUser!.linkWithCredential(credential);
        }
        return true;
      } catch (e) {
        // Si le téléphone est déjà lié à cet utilisateur, c'est OK
        if (e is FirebaseAuthException && e.code == 'provider-already-linked') {
          return true;
        }
        rethrow;
      }
    } catch (e) {
      rethrow;
    }
  }

  // Déconnexion
  Future<void> logout() async {
    try {
      await _auth.signOut();
      _authenticatedUser = null;
    } catch (e) {
      rethrow;
    }
  }
  
  // Vérifier si l'utilisateur est pleinement authentifié (2FA)
  bool isUserFullyAuthenticated() {
    User? user = _auth.currentUser;
    if (user == null) return false;
    
    // Vérifier si l'utilisateur a un fournisseur de téléphone lié
    // Ce qui confirmerait que l'authentification à deux facteurs est complète
    return user.providerData.any((element) => element.providerId == 'phone');
  }
  
  // Obtenir l'utilisateur actuellement connecté
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}