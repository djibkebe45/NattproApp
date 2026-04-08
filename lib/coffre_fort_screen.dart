import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class CoffreFortScreen extends StatefulWidget {
  final GroupeNatt groupe;
  CoffreFortScreen({required this.groupe});
  @override
  _CoffreFortScreenState createState() => _CoffreFortScreenState();
}

class _CoffreFortScreenState extends State<CoffreFortScreen> {
  Map<String, List<Map<String, dynamic>>> depotParMembre = {};
  bool chargement = true;
  Membre? membreSelectionne;

  @override
  void initState() {
    super.initState();
    _chargerDepots();
  }

  Future<void> _chargerDepots() async {
    setState(() => chargement = true);
    try {
      final data = await supabase
          .from('coffre_fort')
          .select('*, membres(nom, id)')
          .eq('groupe_id', widget.groupe.id!)
          .order('date_depot', ascending: false);

      Map<String, List<Map<String, dynamic>>> result = {};
      for (final depot in data as List) {
        final membreId = depot['membre_id'] as String;
        if (!result.containsKey(membreId)) result[membreId] = [];
        result[membreId]!.add(Map<String, dynamic>.from(depot));
      }
      setState(() { depotParMembre = result; chargement = false; });
    } catch (e) {
      setState(() => chargement = false);
    }
  }

  double totalMembre(String membreId) =>
      (depotParMembre[membreId] ?? []).fold(0.0, (sum, d) => sum + (d['montant'] as num).toDouble());

  double get totalGlobal => widget.groupe.membres.fold(0.0, (sum, m) => sum + totalMembre(m.id ?? ''));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: kBlue,
        title: Text('Coffre-Fort — ${widget.groupe.nom}', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: Colors.white), onPressed: _chargerDepots),
        ],
      ),
      body: chargement
          ? Center(child: CircularProgressIndicator(color: kBlue))
          : Column(children: [
              Container(
                margin: EdgeInsets.all(16), padding: EdgeInsets.all(16),
                decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(16)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _stat('🏦', '${totalGlobal.toStringAsFixed(0)}', 'Total FCFA'),
                  _stat('👥', '${widget.groupe.membres.length}', 'Membres'),
                  _stat('📥', '${depotParMembre.values.fold(0, (sum, list) => sum + list.length)}', 'Dépôts'),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.groupe.membres.length,
                  itemBuilder: (context, index) {
                    final membre = widget.groupe.membres[index];
                    final depots = depotParMembre[membre.id] ?? [];
                    final total = totalMembre(membre.id ?? '');
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: kBluLight,
                            child: Text(membre.nom[0], style: TextStyle(color: kBlue, fontWeight: FontWeight.w600)),
                          ),
                          title: Text(membre.nom, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('${depots.length} dépôts', style: TextStyle(color: kGris, fontSize: 12)),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('${total.toStringAsFixed(0)}', style: TextStyle(color: kBlue, fontWeight: FontWeight.w700, fontSize: 15)),
                            Text('FCFA', style: TextStyle(color: kGris, fontSize: 10)),
                          ]),
                          children: [
                            if (depots.isEmpty)
                              Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Aucun dépôt', style: TextStyle(color: kGris, fontSize: 13)),
                              )
                            else
                              ...depots.map((d) {
                                final date = DateTime.parse(d['date_depot']);
                                return ListTile(
                                  dense: true,
                                  leading: Icon(Icons.savings_rounded, color: Colors.green, size: 20),
                                  title: Text('${(d['montant'] as num).toStringAsFixed(0)} FCFA',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  subtitle: Text(d['description'] ?? 'Dépôt', style: TextStyle(fontSize: 11)),
                                  trailing: Text('${date.day}/${date.month}/${date.year}',
                                    style: TextStyle(color: kGris, fontSize: 11)),
                                );
                              }).toList(),
                            Padding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Row(children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: kBlue, side: BorderSide(color: kBlue)),
                                    icon: Icon(Icons.add, size: 16),
                                    label: Text('Ajouter dépôt'),
                                    onPressed: () => _ajouterDepot(membre),
                                  ),
                                ),
                                if (total > 0) ...[
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: BorderSide(color: Colors.green)),
                                      icon: Icon(Icons.account_balance_wallet, size: 16),
                                      label: Text('Clôturer'),
                                      onPressed: () => _cloturerCoffre(membre, total),
                                    ),
                                  ),
                                ],
                              ]),
                            ),
                          ],
                        ),
                      ),
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
      Text(val, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
      Text(label, style: TextStyle(color: Colors.white70, fontSize: 10)),
    ]);
  }

  void _ajouterDepot(Membre membre) {
    final montantCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Dépôt — ${membre.nom}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: montantCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Montant (FCFA)', prefixIcon: Icon(Icons.savings, color: kBlue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            decoration: InputDecoration(labelText: 'Description (optionnel)', prefixIcon: Icon(Icons.note, color: kBlue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBlue),
            onPressed: () async {
              if (montantCtrl.text.isEmpty) return;
              await supabase.from('coffre_fort').insert({
                'membre_id': membre.id,
                'groupe_id': widget.groupe.id,
                'montant': double.tryParse(montantCtrl.text) ?? 0,
                'description': descCtrl.text.isNotEmpty ? descCtrl.text : 'Dépôt',
              });
              Navigator.pop(context);
              _chargerDepots();
            },
            child: Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _cloturerCoffre(Membre membre, double total) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('🏦 Clôturer le coffre-fort'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Remettre le coffre-fort de'),
          SizedBox(height: 8),
          Text(membre.nom, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: kBlue)),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: kBluLight, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.savings_rounded, color: kBlue),
              SizedBox(width: 8),
              Text('${total.toStringAsFixed(0)} FCFA', style: TextStyle(color: kBlue, fontWeight: FontWeight.w700, fontSize: 20)),
            ]),
          ),
          SizedBox(height: 8),
          Text('Cette action supprimera tous les dépôts de ce membre.', style: TextStyle(color: kGris, fontSize: 12), textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              await supabase.from('coffre_fort').delete().eq('membre_id', membre.id!).eq('groupe_id', widget.groupe.id!);
              Navigator.pop(context);
              _chargerDepots();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✅ ${membre.nom} a reçu ${total.toStringAsFixed(0)} FCFA'), backgroundColor: Colors.green),
              );
            },
            child: Text('Confirmer la remise', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
