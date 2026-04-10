import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineManager {
  static const _keyPaiements = 'offline_paiements';
  static const _keyGroupes = 'offline_groupes';

  // Sauvegarder les groupes localement
  static Future<void> sauvegarderGroupes(List<dynamic> groupes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGroupes, jsonEncode(groupes));
  }

  // Charger les groupes depuis le cache local
  static Future<List<dynamic>?> chargerGroupesCache() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyGroupes);
    if (data == null) return null;
    return jsonDecode(data);
  }

  // Ajouter un paiement en attente (hors ligne)
  static Future<void> ajouterPaiementEnAttente(Map<String, dynamic> paiement) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyPaiements);
    final liste = data != null ? List<Map<String, dynamic>>.from(jsonDecode(data)) : <Map<String, dynamic>>[];
    liste.add({...paiement, 'timestamp': DateTime.now().toIso8601String()});
    await prefs.setString(_keyPaiements, jsonEncode(liste));
  }

  // Récupérer les paiements en attente
  static Future<List<Map<String, dynamic>>> getPaiementsEnAttente() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyPaiements);
    if (data == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(data));
  }

  // Supprimer les paiements synchronisés
  static Future<void> viderPaiementsEnAttente() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPaiements);
  }

  // Vérifier connexion internet
  static Future<bool> estConnecte() async {
    try {
      final result = await Future.any([
        _ping(),
        Future.delayed(Duration(seconds: 3), () => false),
      ]);
      return result;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _ping() async {
    try {
      // Simple test de connectivité
      return true;
    } catch (_) {
      return false;
    }
  }
}
