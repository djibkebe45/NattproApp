import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class AmendesScreen extends StatefulWidget {
  final GroupeNatt groupe;
  AmendesScreen({required this.groupe});
  @override
  _AmendesScreenState createState() => _AmendesScreenState();
}

class _AmendesScreenState extends State<AmendesScreen> {
  List<Map<String, dynamic>> amendes = [];
  bool chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerAmendes();
  }

  Future<void> _chargerAmendes() async {
    setState(() => chargement = true);
    try {
      final data = await supabase
          .from('amendes')
          .select('*, membres(nom)')
          .eq('groupe_id', widget.groupe.id!)
          .order('date_amende', ascending: false);
      setState(() { amendes = List<Map<String, dynamic>>.from(data); chargement = false; });
    } catch (e) {
      setState(() => chargement = false);
    }
  }

  double get totalAmendes => amendes.fold(0.0, (sum, a) => sum + (a['montant'] as num).toDouble());
  double get totalNonPayees => amendes.where((a) => !a['payee']).fold(0.0, (sum, a) => sum + (a['montant'] as num).toDouble());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: kBlue,
        title: Text('Amendes — ${widget.groupe.nom}', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(children: [
        Container(
          margin: EdgeInsets.all(16), padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat('💸', '${totalAmendes.toStringAsFixed(0)}', 'Total FCFA'),
            _stat('⚠️', '${amendes.length}', 'Amendes'),
            _stat('❌', '${totalNonPayees.toStringAsFixed(0)}', 'Non payées'),
          ]),
        ),
        Expanded(
          child: chargement
              ? Center(child: CircularProgressIndicator(color: kBlue))
              : amendes.isEmpty
                  ? Center(child: Text('Aucune amende', style: TextStyle(color: kGris)))
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: amendes.length,
                      itemBuilder: (context, index) {
                        final a = amendes[index];
                        final payee = a['payee'] as bool;
                        final date = DateTime.parse(a['date_amende']);
                        return Container(
                          margin: EdgeInsets.only(bottom: 10),
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: payee ? Colors.green.shade100 : Colors.red.shade100),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                              backgroundColor: payee ? Colors.green.shade50 : Colors.red.shade50,
                              child: Icon(payee ? Icons.check_circle : Icons.warning_rounded,
                                color: payee ? Colors.green : Colors.red, size: 22),
                            ),
                            SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(a['membres']['nom'], style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(a['motif'], style: TextStyle(color: kGris, fontSize: 12)),
                              Text('${date.day}/${date.month}/${date.year}', style: TextStyle(color: kGris, fontSize: 11)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('${(a['montant'] as num).toStringAsFixed(0)} FCFA',
                                style: TextStyle(color: payee ? Colors.green : Colors.red, fontWeight: FontWeight.w600)),
                              SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => _togglePaiement(a['id'], payee),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: payee ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: payee ? Colors.green.shade200 : Colors.red.shade200),
                                  ),
                                  child: Text(payee ? 'Payée ✓' : 'Non payée',
                                    style: TextStyle(fontSize: 10, color: payee ? Colors.green.shade700 : Colors.red.shade700)),
                                ),
                              ),
                            ]),
                          ]),
                        );
                      },
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kBlue,
        onPressed: _ajouterAmende,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('Ajouter amende', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _stat(String emoji, String val, String label) {
    return Column(children: [
      Text(emoji, style: TextStyle(fontSize: 20)),
      Text(val, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
      Text(label, style: TextStyle(color: Colors.white70, fontSize: 10)),
    ]);
  }

  Future<void> _togglePaiement(String amendeId, bool payee) async {
    await supabase.from('amendes').update({'payee': !payee}).eq('id', amendeId);
    _chargerAmendes();
  }

  void _ajouterAmende() {
    Membre? membreSelectionne;
    final montantCtrl = TextEditingController();
    String motif = 'Retard';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Ajouter une amende'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<Membre>(
              decoration: InputDecoration(labelText: 'Membre', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              items: widget.groupe.membres.map((m) => DropdownMenuItem(value: m, child: Text(m.nom))).toList(),
              onChanged: (val) => setStateDialog(() => membreSelectionne = val),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: motif,
              decoration: InputDecoration(labelText: 'Motif', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              items: ['Retard', 'Absence', 'Autre'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (val) => setStateDialog(() => motif = val!),
            ),
            SizedBox(height: 12),
            TextField(
              controller: montantCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Montant (FCFA)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kBlue),
              onPressed: () async {
                if (membreSelectionne == null || montantCtrl.text.isEmpty) return;
                await supabase.from('amendes').insert({
                  'membre_id': membreSelectionne!.id,
                  'groupe_id': widget.groupe.id,
                  'motif': motif,
                  'montant': double.tryParse(montantCtrl.text) ?? 0,
                  'payee': false,
                });
                Navigator.pop(context);
                _chargerAmendes();
              },
              child: Text('Ajouter', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
