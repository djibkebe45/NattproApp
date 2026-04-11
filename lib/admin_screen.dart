import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

// Ton email admin
const String ADMIN_EMAIL = 'djibyk996@gmail.com';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> utilisateurs = [];
  bool chargement = true;
  int totalPremium = 0;
  double revenusTotal = 0;

  @override
  void initState() {
    super.initState();
    _chargerUtilisateurs();
  }

  Future<void> _chargerUtilisateurs() async {
    setState(() => chargement = true);
    try {
      final data = await supabase
          .from('abonnements')
          .select('*, user_id')
          .order('created_at', ascending: false);

      final premium = (data as List).where((u) => u['type'] == 'premium' && u['actif'] == true).toList();
      setState(() {
        utilisateurs = List<Map<String, dynamic>>.from(data);
        totalPremium = premium.length;
        revenusTotal = premium.length * 1000.0;
        chargement = false;
      });
    } catch (e) {
      setState(() => chargement = false);
    }
  }

  Future<void> _activerPremium(String userId) async {
    final dateFin = DateTime.now().add(Duration(days: 30));
    await supabase.from('abonnements').upsert({
      'user_id': userId,
      'type': 'premium',
      'actif': true,
      'date_fin': dateFin.toIso8601String(),
      'montant': 1000,
    });
    _chargerUtilisateurs();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Premium activé !'), backgroundColor: Colors.green),
    );
  }

  Future<void> _desactiverPremium(String userId) async {
    await supabase.from('abonnements')
        .update({'type': 'gratuit', 'actif': true})
        .eq('user_id', userId);
    _chargerUtilisateurs();
  }

  @override
  Widget build(BuildContext context) {
    final emailActuel = supabase.auth.currentUser?.email ?? '';
    if (emailActuel != ADMIN_EMAIL) {
      return Scaffold(
        appBar: AppBar(backgroundColor: kBlue, title: Text('Admin', style: TextStyle(color: Colors.white)), iconTheme: IconThemeData(color: Colors.white)),
        body: Center(child: Text('Accès refusé', style: TextStyle(color: Colors.red, fontSize: 18))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: kBlue,
        title: Text('Dashboard Admin', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [IconButton(icon: Icon(Icons.refresh, color: Colors.white), onPressed: _chargerUtilisateurs)],
      ),
      body: Column(children: [
        Container(
          margin: EdgeInsets.all(16), padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat('👥', '${utilisateurs.length}', 'Total users'),
            _stat('👑', '$totalPremium', 'Premium'),
            _stat('💰', '${revenusTotal.toStringAsFixed(0)}', 'FCFA/mois'),
          ]),
        ),
        Expanded(
          child: chargement
              ? Center(child: CircularProgressIndicator(color: kBlue))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: utilisateurs.length,
                  itemBuilder: (context, index) {
                    final u = utilisateurs[index];
                    final estPremium = u['type'] == 'premium' && u['actif'] == true;
                    final dateFin = u['date_fin'] != null ? DateTime.parse(u['date_fin']) : null;
                    return Container(
                      margin: EdgeInsets.only(bottom: 10),
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: estPremium ? Colors.amber.shade200 : Colors.grey.shade100),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          backgroundColor: estPremium ? Colors.amber.shade100 : kBluLight,
                          child: Text(estPremium ? '👑' : '🔓', style: TextStyle(fontSize: 16)),
                        ),
                        SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u['user_id'].toString().substring(0, 8) + '...', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(estPremium ? 'Premium' : 'Gratuit', style: TextStyle(color: estPremium ? Colors.amber.shade700 : kGris, fontSize: 12)),
                          if (dateFin != null) Text('Expire: ${dateFin.day}/${dateFin.month}/${dateFin.year}', style: TextStyle(color: kGris, fontSize: 11)),
                        ])),
                        estPremium
                            ? TextButton(
                                onPressed: () => _desactiverPremium(u['user_id']),
                                child: Text('Désactiver', style: TextStyle(color: Colors.red, fontSize: 12)),
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                                onPressed: () => _activerPremium(u['user_id']),
                                child: Text('Activer', style: TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _stat(String emoji, String val, String label) {
    return Column(children: [
      Text(emoji, style: TextStyle(fontSize: 20)),
      Text(val, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
      Text(label, style: TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }
}
