import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

void main() {
  runApp(NattProApp());
}

class NattProApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NattPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF006633)),
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}

// ═══════════════════════════════
// MODÈLES
// ═══════════════════════════════

class Membre {
  String nom;
  String telephone;
  int ordre;
  List<bool> paiements;

  Membre({
    required this.nom,
    required this.telephone,
    required this.ordre,
    required this.paiements,
  });
}

class GroupeNatt {
  String nom;
  double montant;
  String frequence;
  DateTime dateDebut;
  List<Membre> membres;
  bool tirageEffectue;

  GroupeNatt({
    required this.nom,
    required this.montant,
    required this.frequence,
    required this.dateDebut,
    required this.membres,
    this.tirageEffectue = false,
  });

  int get tourActuel {
    final maintenant = DateTime.now();
    int tours = 0;
    if (frequence == 'Hebdomadaire') {
      tours = maintenant.difference(dateDebut).inDays ~/ 7;
    } else {
      tours = (maintenant.year - dateDebut.year) * 12 +
          maintenant.month - dateDebut.month;
    }
    return tours.clamp(0, membres.isEmpty ? 0 : membres.length - 1);
  }
}

// ═══════════════════════════════
// ÉCRAN ACCUEIL
// ═══════════════════════════════

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<GroupeNatt> groupes = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Color(0xFF006633),
        title: Text('NattPro 🤝',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: groupes.isEmpty ? _buildEmpty() : _buildListe(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Color(0xFF006633),
        onPressed: _ajouterGroupe,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('Nouveau Natt', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🤝', style: TextStyle(fontSize: 80)),
          SizedBox(height: 16),
          Text('Amul Natt bi',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Créez votre premier groupe de tontine',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildListe() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: groupes.length,
      itemBuilder: (context, index) {
        final groupe = groupes[index];
        final receveur = groupe.membres.isNotEmpty
            ? groupe.membres[groupe.tourActuel]
            : null;
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Color(0xFF006633),
              child: Text(groupe.nom[0].toUpperCase(),
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(groupe.nom,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text('💰 ${groupe.montant.toStringAsFixed(0)} FCFA — ${groupe.frequence}'),
                if (receveur != null)
                  Text('🎯 Tour : ${receveur.nom}',
                      style: TextStyle(
                          color: Color(0xFF006633), fontWeight: FontWeight.w600)),
                Text('👥 ${groupe.membres.length} membres'),
                if (!groupe.tirageEffectue && groupe.membres.isNotEmpty)
                  Text('⚠️ Tirage non effectué',
                      style: TextStyle(color: Colors.orange)),
              ],
            ),
            trailing: Icon(Icons.arrow_forward_ios, color: Color(0xFF006633)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailGroupeScreen(
                    groupe: groupe,
                    onUpdate: () => setState(() {}),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _ajouterGroupe() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreerGroupeScreen(
          onCreer: (groupe) => setState(() => groupes.add(groupe)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════
// CRÉER UN GROUPE
// ═══════════════════════════════

class CreerGroupeScreen extends StatefulWidget {
  final Function(GroupeNatt) onCreer;
  CreerGroupeScreen({required this.onCreer});

  @override
  _CreerGroupeScreenState createState() => _CreerGroupeScreenState();
}

class _CreerGroupeScreenState extends State<CreerGroupeScreen> {
  final _nomCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  String _frequence = 'Mensuel';
  DateTime _dateDebut = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF006633),
        title: Text('Créer un Natt', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _champ(_nomCtrl, 'Nom du groupe', Icons.group),
            SizedBox(height: 16),
            _champ(_montantCtrl, 'Montant (FCFA)', Icons.attach_money,
                type: TextInputType.number),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _frequence,
              decoration: InputDecoration(
                labelText: 'Fréquence',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: ['Hebdomadaire', 'Mensuel']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (val) => setState(() => _frequence = val!),
            ),
            SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey),
              ),
              leading: Icon(Icons.calendar_today),
              title: Text('Date de début'),
              subtitle: Text(
                  '${_dateDebut.day}/${_dateDebut.month}/${_dateDebut.year}'),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dateDebut,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                );
                if (date != null) setState(() => _dateDebut = date);
              },
            ),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF006633),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _valider,
                child: Text('Créer',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _champ(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _valider() {
    if (_nomCtrl.text.isEmpty || _montantCtrl.text.isEmpty) return;
    widget.onCreer(GroupeNatt(
      nom: _nomCtrl.text,
      montant: double.tryParse(_montantCtrl.text) ?? 0,
      frequence: _frequence,
      dateDebut: _dateDebut,
      membres: [],
    ));
    Navigator.pop(context);
  }
}

// ═══════════════════════════════
// DÉTAIL GROUPE
// ═══════════════════════════════

class DetailGroupeScreen extends StatefulWidget {
  final GroupeNatt groupe;
  final VoidCallback onUpdate;
  DetailGroupeScreen({required this.groupe, required this.onUpdate});

  @override
  _DetailGroupeScreenState createState() => _DetailGroupeScreenState();
}

class _DetailGroupeScreenState extends State<DetailGroupeScreen> {
  @override
  Widget build(BuildContext context) {
    final groupe = widget.groupe;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF006633),
        title: Text(groupe.nom, style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (groupe.membres.length >= 2)
            IconButton(
              icon: Icon(Icons.shuffle, color: Colors.white),
              tooltip: 'Tirage au sort',
              onPressed: _tirage,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildResume(),
          if (!groupe.tirageEffectue && groupe.membres.length >= 2)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Effectuez le tirage au sort pour définir l\'ordre des tours',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 8),
          Expanded(
            child: groupe.membres.isEmpty
                ? Center(
                    child: Text('Ajoutez des membres pour commencer !',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: groupe.membres.length,
                    itemBuilder: (context, index) =>
                        _buildMembreCard(groupe.membres[index], index),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Color(0xFF006633),
        onPressed: _afficherOptionsAjout,
        icon: Icon(Icons.person_add, color: Colors.white),
        label: Text('Ajouter', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildResume() {
    final groupe = widget.groupe;
    final cagnotte = groupe.membres.length * groupe.montant;
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF006633),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('👥', '${groupe.membres.length}', 'Membres'),
          _stat('💰', '${groupe.montant.toStringAsFixed(0)}', 'FCFA'),
          _stat('🏆', '${cagnotte.toStringAsFixed(0)}', 'Cagnotte'),
        ],
      ),
    );
  }

  Widget _stat(String emoji, String val, String label) {
    return Column(
      children: [
        Text(emoji, style: TextStyle(fontSize: 22)),
        Text(val,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildMembreCard(Membre membre, int index) {
    final groupe = widget.groupe;
    final estTour =
        groupe.tirageEffectue && index == groupe.tourActuel % groupe.membres.length;
    final aPaye = membre.paiements.isNotEmpty && membre.paiements.last;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: estTour ? Colors.amber[50] : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: estTour ? Colors.amber : Color(0xFF006633),
          child: Text('${membre.ordre}',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text(membre.nom, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(membre.telephone),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (estTour)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('🎯 Tour',
                    style:
                        TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                setState(() {
                  if (membre.paiements.isEmpty) {
                    membre.paiements.add(true);
                  } else {
                    membre.paiements[membre.paiements.length - 1] = !aPaye;
                  }
                });
                widget.onUpdate();
              },
              child: Icon(
                aPaye ? Icons.check_circle : Icons.radio_button_unchecked,
                color: aPaye ? Colors.green : Colors.grey,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TIRAGE AU SORT ──
  void _tirage() {
    final groupe = widget.groupe;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('🎲 Tirage au sort'),
        content: Text(
            'Voulez-vous mélanger aléatoirement l\'ordre des ${groupe.membres.length} membres ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Color(0xFF006633)),
            onPressed: () {
              setState(() {
                groupe.membres.shuffle(Random());
                for (int i = 0; i < groupe.membres.length; i++) {
                  groupe.membres[i].ordre = i + 1;
                }
                groupe.tirageEffectue = true;
              });
              widget.onUpdate();
              Navigator.pop(context);
              _afficherResultatTirage();
            },
            child:
                Text('Tirer !', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _afficherResultatTirage() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('🎉 Résultat du tirage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.groupe.membres
              .map((m) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(0xFF006633),
                      child: Text('${m.ordre}',
                          style: TextStyle(color: Colors.white)),
                    ),
                    title: Text(m.nom),
                    subtitle: Text(m.telephone),
                  ))
              .toList(),
        ),
        actions: [
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Color(0xFF006633)),
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── OPTIONS AJOUT MEMBRE ──
  void _afficherOptionsAjout() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ajouter un membre',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(0xFF006633),
                child: Icon(Icons.contacts, color: Colors.white),
              ),
              title: Text('Depuis mes contacts'),
              subtitle: Text('Accéder au répertoire téléphonique'),
              onTap: () {
                Navigator.pop(context);
                _ajouterDepuisContacts();
              },
            ),
            Divider(),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.person_add, color: Colors.white),
              ),
              title: Text('Nouveau contact'),
              subtitle: Text('Saisir manuellement'),
              onTap: () {
                Navigator.pop(context);
                _ajouterManuellement();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── DEPUIS CONTACTS ──
  Future<void> _ajouterDepuisContacts() async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permission contacts refusée')),
      );
      return;
    }

    final contacts = await FlutterContacts.getContacts(withProperties: true);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Choisir un contact'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: contacts.isEmpty
              ? Center(child: Text('Aucun contact trouvé'))
              : ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final tel = contact.phones.isNotEmpty
                        ? contact.phones.first.number
                        : '';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(0xFF006633),
                        child: Text(
                          contact.displayName.isNotEmpty
                              ? contact.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(contact.displayName),
                      subtitle: Text(tel),
                      onTap: () {
                        setState(() {
                          widget.groupe.membres.add(Membre(
                            nom: contact.displayName,
                            telephone: tel,
                            ordre: widget.groupe.membres.length + 1,
                            paiements: [],
                          ));
                          widget.groupe.tirageEffectue = false;
                        });
                        widget.onUpdate();
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Fermer')),
        ],
      ),
    );
  }

  // ── AJOUT MANUEL ──
  void _ajouterManuellement() {
    final nomCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Nouveau membre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomCtrl,
              decoration: InputDecoration(
                  labelText: 'Nom complet',
                  prefixIcon: Icon(Icons.person)),
            ),
            SizedBox(height: 12),
            TextField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: 'Téléphone', prefixIcon: Icon(Icons.phone)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Color(0xFF006633)),
            onPressed: () {
              if (nomCtrl.text.isNotEmpty) {
                setState(() {
                  widget.groupe.membres.add(Membre(
                    nom: nomCtrl.text,
                    telephone: telCtrl.text,
                    ordre: widget.groupe.membres.length + 1,
                    paiements: [],
                  ));
                  widget.groupe.tirageEffectue = false;
                });
                widget.onUpdate();
                Navigator.pop(context);
              }
            },
            child: Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
