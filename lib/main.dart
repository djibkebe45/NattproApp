import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_config.dart';
import 'auth_screen.dart';
import 'dart:math';

final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);
  await notificationsPlugin.initialize(settings);
}

Future<void> envoyerNotification(String titre, String corps) async {
  const details = NotificationDetails(
    android: AndroidNotificationDetails('nattro_channel', 'NattPro', importance: Importance.high, priority: Priority.high),
  );
  await notificationsPlugin.show(0, titre, corps, details);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(NattProApp());
}

final supabase = Supabase.instance.client;
const kBlue = Color(0xFF1B4FD8);
const kBluLight = Color(0xFFEEF2FF);
const kNoir = Color(0xFF111111);
const kGris = Color(0xFF888888);

class NattProApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NattPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: kBlue), useMaterial3: true),
      home: supabase.auth.currentSession != null ? HomeScreen() : AuthScreen(),
    );
  }
}

class Paiement {
  String? id;
  String membreId;
  int tour;
  bool paye;
  String type; // 'tontine' ou 'amende'
  Paiement({this.id, required this.membreId, required this.tour, required this.paye, this.type = 'tontine'});
}

class Membre {
  String? id;
  String nom;
  String telephone;
  int ordre;
  bool aDejaGagne;
  List<Paiement> paiements;
  Membre({this.id, required this.nom, required this.telephone, required this.ordre, this.aDejaGagne = false, required this.paiements});
  
  factory Membre.fromJson(Map<String, dynamic> json) => Membre(
    id: json['id'], nom: json['nom'], telephone: json['telephone'] ?? '',
    ordre: json['ordre'] ?? 0, aDejaGagne: json['a_deja_gagne'] ?? false, paiements: [],
  );
  bool aPaye(int tour) => paiements.any((p) => p.tour == tour && p.paye && p.type == 'tontine');
}

class GroupeNatt {
  String? id;
  String nom;
  double montant;
  String frequence;
  DateTime dateDebut;
  List<Membre> membres;
  bool tirageEffectue;
  GroupeNatt({this.id, required this.nom, required this.montant, required this.frequence, required this.dateDebut, required this.membres, this.tirageEffectue = false});

  factory GroupeNatt.fromJson(Map<String, dynamic> json) => GroupeNatt(
    id: json['id'], nom: json['nom'], montant: (json['montant'] as num).toDouble(),
    frequence: json['frequence'], dateDebut: DateTime.parse(json['date_debut']),
    tirageEffectue: json['tirage_effectue'] ?? false, membres: [],
  );

  int get tourActuel {
    final maintenant = DateTime.now();
    int tours = (frequence == 'Hebdomadaire') 
      ? maintenant.difference(dateDebut).inDays ~/ 7 
      : (maintenant.year - dateDebut.year) * 12 + maintenant.month - dateDebut.month;
    return tours.clamp(0, membres.isEmpty ? 0 : membres.length - 1);
  }
  
  Membre? get receveurActuel => membres.isNotEmpty && tirageEffectue ? membres.firstWhere((m) => m.ordre == tourActuel + 1, orElse: () => membres[0]) : null;
  double get cagnotte => membres.length * montant;
  int get nbPayesTourActuel => membres.where((m) => m.aPaye(tourActuel)).length;
}

// --- ECRAN ACCUEIL ---
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<GroupeNatt> groupes = [];
  bool chargement = true;
  int _onglet = 0;

  @override
  void initState() { super.initState(); _chargerGroupes(); }

  Future<void> _chargerGroupes() async {
    setState(() => chargement = true);
    final data = await supabase.from('groupes').select('*, membres(*, paiements(*))').eq('user_id', supabase.auth.currentUser!.id).order('created_at');
    final liste = (data as List).map((g) {
      final groupe = GroupeNatt.fromJson(g);
      groupe.membres = (g['membres'] as List).map((m) {
        final membre = Membre.fromJson(m);
        membre.paiements = (m['paiements'] as List).map((p) => Paiement(membreId: m['id'], tour: p['tour'], paye: p['paye'])).toList();
        return membre;
      }).toList()..sort((a, b) => a.ordre.compareTo(b.ordre));
      return groupe;
    }).toList();
    setState(() { groupes = liste; chargement = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _onglet == 0 ? _buildAccueil() : Center(child: Text("Historique bientôt disponible")),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _onglet,
        onTap: (i) => setState(() => _onglet = i),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Activités'),
        ],
      ),
      floatingActionButton: FloatingActionButton(backgroundColor: kBlue, child: Icon(Icons.add, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreerGroupeScreen(onCreer: _chargerGroupes)))),
    );
  }

  Widget _buildAccueil() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(expandedHeight: 120, pinned: true, backgroundColor: kBlue, title: Text('NattPro 🇸🇳', style: TextStyle(color: Colors.white))),
        if (chargement) SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else SliverList(delegate: SliverChildBuilderDelegate((context, i) => _buildCard(groupes[i]), childCount: groupes.length)),
      ],
    );
  }

  Widget _buildCard(GroupeNatt g) {
    return Card(
      margin: EdgeInsets.all(10),
      child: ListTile(
        title: Text(g.nom, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${g.membres.length} membres - ${g.montant} FCFA"),
        trailing: Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailGroupeScreen(groupe: g, onUpdate: _chargerGroupes))),
      ),
    );
  }
}

// --- ECRAN DETAIL (FONCTIONNALITÉS CLÉS ICI) ---
class DetailGroupeScreen extends StatefulWidget {
  final GroupeNatt groupe;
  final VoidCallback onUpdate;
  DetailGroupeScreen({required this.groupe, required this.onUpdate});
  @override
  _DetailGroupeScreenState createState() => _DetailGroupeScreenState();
}

class _DetailGroupeScreenState extends State<DetailGroupeScreen> {
  
  // 1. Logique du Tirage (Exclure ceux qui ont gagné)
  Future<void> _lancerTirage() async {
    final eligibles = widget.groupe.membres.where((m) => !m.aDejaGagne).toList();
    if (eligibles.isEmpty) return;
    
    eligibles.shuffle();
    for (int i = 0; i < eligibles.length; i++) {
      await supabase.from('membres').update({'ordre': i + 1, 'a_deja_gagne': i == 0 ? true : eligibles[i].aDejaGagne}).eq('id', eligibles[i].id!);
    }
    await supabase.from('groupes').update({'tirage_effectue': true}).eq('id', widget.groupe.id!);
    widget.onUpdate();
  }

  // 2. Gestion des Amendes
  void _infligerAmende(Membre m) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text("Amende pour ${m.nom}"),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Montant")),
      actions: [ElevatedButton(onPressed: () async {
        await supabase.from('amendes').insert({'membre_id': m.id, 'groupe_id': widget.groupe.id, 'montant': int.parse(ctrl.text), 'motif': 'Retard'});
        Navigator.pop(context);
      }, child: Text("Valider"))],
    ));
  }

  // 3. Coffre-fort Personnel
  void _depotCoffre(Membre m) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text("Épargne : ${m.nom}"),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Somme")),
      actions: [ElevatedButton(onPressed: () async {
        await supabase.from('coffre_fort').insert({'membre_id': m.id, 'groupe_id': widget.groupe.id, 'montant': int.parse(ctrl.text)});
        Navigator.pop(context);
      }, child: Text("Épargner"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupe.nom), actions: [IconButton(icon: Icon(Icons.shuffle), onPressed: _lancerTirage)]),
      body: ListView.builder(
        itemCount: widget.groupe.membres.length,
        itemBuilder: (context, i) {
          final m = widget.groupe.membres[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text("${m.ordre}")),
              title: Text(m.nom),
              subtitle: Row(
                children: [
                  IconButton(icon: Icon(Icons.gavel, color: Colors.red, size: 20), onPressed: () => _infligerAmende(m)),
                  IconButton(icon: Icon(Icons.savings, color: Colors.orange, size: 20), onPressed: () => _depotCoffre(m)),
                ],
              ),
              trailing: IconButton(
                icon: Icon(m.aPaye(widget.groupe.tourActuel) ? Icons.check_circle : Icons.circle_outlined, color: kBlue),
                onPressed: () async {
                  await supabase.from('paiements').insert({'membre_id': m.id, 'tour': widget.groupe.tourActuel, 'paye': true});
                  widget.onUpdate();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- ECRAN CREATION ---
class CreerGroupeScreen extends StatelessWidget {
  final VoidCallback onCreer;
  final nomCtrl = TextEditingController();
  final montantCtrl = TextEditingController();
  CreerGroupeScreen({required this.onCreer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Nouveau Groupe")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(children: [
          TextField(controller: nomCtrl, decoration: InputDecoration(labelText: "Nom")),
          TextField(controller: montantCtrl, decoration: InputDecoration(labelText: "Montant"), keyboardType: TextInputType.number),
          SizedBox(height: 20),
          ElevatedButton(onPressed: () async {
            await supabase.from('groupes').insert({'nom': nomCtrl.text, 'montant': int.parse(montantCtrl.text), 'user_id': supabase.auth.currentUser!.id, 'frequence': 'Mensuel', 'date_debut': DateTime.now().toIso8601String()});
            onCreer();
            Navigator.pop(context);
          }, child: Text("Créer"))
        ]),
      ),
    );
  }
}

