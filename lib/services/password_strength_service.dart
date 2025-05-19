// lib/services/password_strength_service.dart
class PasswordStrengthService {
  // Calcule un score de robustesse du mot de passe (0-100)
  static int calculateStrength(String password) {
    if (password.isEmpty) return 0;
    
    int score = 0;
    
    // Longueur (max 30 points)
    score += password.length * 2;
    if (score > 30) score = 30;
    
    // Diversité de caractères (max 40 points)
    Map<String, bool> characterTypes = {
      'lowercase': RegExp(r'[a-z]').hasMatch(password),
      'uppercase': RegExp(r'[A-Z]').hasMatch(password),
      'numbers': RegExp(r'[0-9]').hasMatch(password),
      'symbols': RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password),
      'uncommon': RegExp(r'[^\w!@#$%^&*(),.?":{}|<>]').hasMatch(password),
    };
    
    int typesCount = characterTypes.values.where((type) => type).length;
    score += typesCount * 10;
    
    // Variété (nombre de caractères uniques)
    int uniqueChars = password.split('').toSet().length;
    double varietyRatio = uniqueChars / password.length;
    score += (varietyRatio * 10).round();
    
    // Pénalités
    // 1. Séquences courantes (abc, 123, etc.)
    if (RegExp(r'(abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz|012|123|234|345|456|567|678|789|890)', caseSensitive: false).hasMatch(password)) {
      score -= 10;
    }
    
    // 2. Répétitions
    int repeats = 0;
    for (int i = 0; i < password.length - 1; i++) {
      if (password[i] == password[i + 1]) repeats++;
    }
    score -= repeats * 2;
    
    // 3. Mots de passe courants/faibles
    final List<String> commonPatterns = [
      'password', 'admin', '12345', 'qwerty', 'welcome', 'letmein',
      'monkey', 'login', 'abc123', '111111', 'dragon', 'master', 
      'sunshine', 'ashley', 'bailey', 'passw0rd', 'shadow', '123456',
      'football', 'baseball', 'iloveyou', 'trustno1'
    ];
    
    for (final pattern in commonPatterns) {
      if (password.toLowerCase().contains(pattern)) {
        score -= 15;
        break;
      }
    }
    
    // 4. Modèle prévisible (alternance chiffre/lettre)
    if (RegExp(r'^([a-zA-Z][0-9])+$').hasMatch(password) || 
        RegExp(r'^([0-9][a-zA-Z])+$').hasMatch(password)) {
      score -= 10;
    }
    
    // Garantir un score entre 0 et 100
    return score < 0 ? 0 : (score > 100 ? 100 : score);
  }
  
  // Obtenir une description de la force du mot de passe
  static Map<String, dynamic> getStrengthInfo(int score) {
    if (score < 40) {
      return {
        'label': 'Faible',
        'color': 0xFFE53935, // Rouge
        'feedback': 'Essayez d\'utiliser plus de caractères et de types différents.',
      };
    } else if (score < 60) {
      return {
        'label': 'Moyen',
        'color': 0xFFFFA726, // Orange
        'feedback': 'Ajoutez plus de longueur et des caractères spéciaux pour renforcer le mot de passe.',
      };
    } else if (score < 80) {
      return {
        'label': 'Fort',
        'color': 0xFF43A047, // Vert
        'feedback': 'Bon mot de passe. Assurez-vous qu\'il reste unique pour chaque site.',
      };
    } else {
      return {
        'label': 'Très fort',
        'color': 0xFF1B5E20, // Vert foncé
        'feedback': 'Excellent mot de passe!',
      };
    }
  }
  
  // Suggestions pour améliorer un mot de passe
  static List<String> getSuggestions(String password) {
    List<String> suggestions = [];
    
    if (password.length < 12) {
      suggestions.add("Augmentez la longueur à au moins 12 caractères");
    }
    
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      suggestions.add("Ajoutez des lettres majuscules");
    }
    
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      suggestions.add("Ajoutez des lettres minuscules");
    }
    
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      suggestions.add("Ajoutez des chiffres");
    }
    
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      suggestions.add("Ajoutez des caractères spéciaux");
    }
    
    // Patterns à éviter
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) {
      suggestions.add("Évitez les caractères répétés (ex: 'aaa')");
    }
    
    if (RegExp(r'(abc|123|qwerty|password)', caseSensitive: false).hasMatch(password)) {
      suggestions.add("Évitez les séquences et mots de passe courants");
    }
    
    return suggestions;
  }
}