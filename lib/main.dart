import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_config.dart';
import 'auth_screen.dart';
import 'amendes_screen.dart';
import 'coffre_fort_screen.dart';
import 'impayes_screen.dart';
import 'dart:math';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);
  await notificationsPlugin.initialize(settings);
}

Future<void> envoyerNotification(String titre, String corps) async {
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'nattro_channel', 'NattPro',
      channelDescription: 'Rappels de cotisation',
      importance: Importance.high,
      priority: Priority.high,
    ),
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kBlue),
        useMaterial3: true,
      ),
      home: supabase.auth.currentSession != null ? HomeScreen() : AuthScreen(),
    );
  }
}

class Paiement {
  String? id;
  String membreId;
  int tour;
  bool paye;
  DateTime? date;
  Paiement({this.id, required this.membreId, required this.tour, required this.paye, this.date});
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
  bool aPaye(int tour) => paiements.any((p) => p.tour == tour && p.paye);
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
    int tours = 0;
    if (frequence == 'Hebdomadaire') {
      tours = maintenant.difference(dateDebut).inDays ~/ 7;
    } else {
      tours = (maintenant.year - dateDebut.year) * 12 + maintenant.month - dateDebut.month;
    }
    return tours.clamp(0, membres.isEmpty ? 0 : membres.length - 1);
  }
  Membre? get receveurActuel => membres.isNotEmpty && tirageEffectue ? membres[tourActuel % membres.length] : null;
  bool get estTermine => tirageEffectue && membres.isNotEmpty && membres.every((m) => m.aDejaGagne);
  double get cagnotte => membres.length * montant;
  int get nbPayesTourActuel => membres.where((m) => m.aPaye(tourActuel)).length;
  List<Membre> get membresNonPayes => membres.where((m) => !m.aPaye(tourActuel)).toList();
  List<Membre> get membresEligibles => membres.where((m) => !m.aDejaGagne).toList();
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<GroupeNatt> groupes = [];
  bool chargement = true;
  int _onglet = 0;

  @override
  void initState() {
    super.initState();
    _chargerGroupes();
  }

  Future<void> _chargerGroupes() async {
    setState(() => chargement = true);
    try {
      final data = await supabase
          .from('groupes')
          .select('*, membres(*, paiements(*))')
          .eq('user_id', supabase.auth.currentUser!.id)
          .order('created_at');
      final liste = (data as List).map((g) {
        final groupe = GroupeNatt.fromJson(g);
        groupe.membres = (g['membres'] as List).map((m) {
          final membre = Membre.fromJson(m);
          membre.paiements = (m['paiements'] as List).map((p) => Paiement(
            id: p['id'], membreId: p['membre_id'], tour: p['tour'],
            paye: p['paye'], date: p['date_paiement'] != null ? DateTime.parse(p['date_paiement']) : null,
          )).toList();
          return membre;
        }).toList();
        groupe.membres.sort((a, b) => a.ordre.compareTo(b.ordre));
        return groupe;
      }).toList();
      setState(() { groupes = liste; chargement = false; });
    } catch (e) {
      setState(() => chargement = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _deconnecter() async {
    await supabase.auth.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _onglet == 0 ? _buildAccueil() : _buildPaiements(),
      bottomNavigationBar: _buildNavBar(),
      floatingActionButton: _onglet == 0 ? FloatingActionButton(
        backgroundColor: kBlue,
        onPressed: _ajouterGroupe,
        child: Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _navItem(0, Icons.home_rounded, 'Accueil'),
        _navItem(1, Icons.receipt_long_rounded, 'Paiements'),
      ]),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final actif = _onglet == index;
    return GestureDetector(
      onTap: () => setState(() => _onglet = index),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: actif ? kBlue : kGris, size: 24),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: actif ? kBlue : kGris, fontWeight: actif ? FontWeight.w600 : FontWeight.normal)),
          if (actif) Container(margin: EdgeInsets.only(top: 3), width: 4, height: 4, decoration: BoxDecoration(color: kBlue, shape: BoxShape.circle)),
        ]),
      ),
    );
  }

  Widget _buildAccueil() {
    final totalCagnotte = groupes.fold(0.0, (sum, g) => sum + g.cagnotte);
    final email = supabase.auth.currentUser?.email ?? '';
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 170,
          pinned: true,
          backgroundColor: kBlue,
          actions: [
            IconButton(icon: Icon(Icons.notifications_outlined, color: Colors.white), onPressed: _testerNotification),
            IconButton(icon: Icon(Icons.refresh, color: Colors.white), onPressed: _chargerGroupes),
            IconButton(icon: Icon(Icons.logout, color: Colors.white), onPressed: _deconnecter),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: kBlue,
              padding: EdgeInsets.fromLTRB(20, 60, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(height: 10),
                Text('NattPro 🤝', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                Text(email, style: TextStyle(color: Colors.white60, fontSize: 11)),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Cagnotte totale', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text('${totalCagnotte.toStringAsFixed(0)} FCFA', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Groupes actifs', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text('${groupes.length}', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        chargement
            ? SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: kBlue)))
            : groupes.isEmpty
                ? SliverFillRemaining(child: _buildEmpty())
                : SliverPadding(
                    padding: EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildGroupeCard(groupes[index], index),
                        childCount: groupes.length,
                      ),
                    ),
                  ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('🤝', style: TextStyle(fontSize: 60)),
      SizedBox(height: 16),
      Text('Amul Natt bi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: kNoir)),
      SizedBox(height: 8),
      Text('Créez votre premier groupe', style: TextStyle(color: kGris)),
    ]));
  }

  Widget _buildGroupeCard(GroupeNatt groupe, int index) {
    final receveur = groupe.receveurActuel;
    final progression = groupe.membres.isEmpty ? 0.0 : groupe.nbPayesTourActuel / groupe.membres.length;
    final nbImpayes = groupe.membresNonPayes.length;
    return Dismissible(
      key: Key(groupe.id ?? index.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async => await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Supprimer ?'),
          content: Text('Supprimer "${groupe.nom}" ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: Text('Supprimer', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
      onDismissed: (_) async {
        await supabase.from('groupes').delete().eq('id', groupe.id!);
        setState(() => groupes.removeAt(index));
      },
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetailGroupeScreen(groupe: groupe, onUpdate: _chargerGroupes),
        )),
        child: Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(groupe.nom[0].toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18))),
              ),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(groupe.nom, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kNoir)),
                Text('${groupe.membres.length} membres · ${groupe.frequence}', style: TextStyle(color: kGris, fontSize: 12)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${groupe.montant.toStringAsFixed(0)}', style: TextStyle(color: kBlue, fontWeight: FontWeight.w600, fontSize: 15)),
                Text('FCFA', style: TextStyle(color: kGris, fontSize: 11)),
                if (nbImpayes > 0) Container(
                  margin: EdgeInsets.only(top: 2),
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text('$nbImpayes impayé${nbImpayes > 1 ? 's' : ''}', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
            SizedBox(height: 10),
            if (receveur != null) Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: kBluLight, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.emoji_events_rounded, color: kBlue, size: 14),
                SizedBox(width: 6),
                Text('Tour ${groupe.tourActuel + 1} : ${receveur.nom} reçoit', style: TextStyle(color: kBlue, fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
            ),
            if (!groupe.tirageEffectue && groupe.membres.length >= 2) Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 14),
                SizedBox(width: 6),
                Text('Tirage au sort requis', style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
              ]),
            ),
            if (groupe.membres.isNotEmpty) ...[
              SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Cotisations ce tour', style: TextStyle(color: kGris, fontSize: 11)),
                Text('${groupe.nbPayesTourActuel}/${groupe.membres.length}', style: TextStyle(color: kBlue, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
              SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progression,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(kBlue),
                  minHeight: 5,
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildPaiements() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: kBlue,
          title: Text('Historique des paiements', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        groupes.isEmpty
            ? SliverFillRemaining(child: Center(child: Text('Aucun groupe', style: TextStyle(color: kGris))))
            : SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final groupe = groupes[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(groupe.nom, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kNoir)),
                          SizedBox(height: 4),
                          Text('Tour ${groupe.tourActuel + 1} sur ${groupe.membres.length}', style: TextStyle(color: kGris, fontSize: 12)),
                          SizedBox(height: 12),
                          ...groupe.membres.map((m) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 5),
                            child: Row(children: [
                              CircleAvatar(radius: 16, backgroundColor: kBluLight,
                                child: Text(m.nom[0], style: TextStyle(color: kBlue, fontSize: 12, fontWeight: FontWeight.w600))),
                              SizedBox(width: 10),
                              Expanded(child: Text(m.nom, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                              ...List.generate(groupe.membres.length, (tour) {
                                final paye = m.aPaye(tour);
                                final recoit = groupe.tirageEffectue && m.ordre - 1 == tour;
                                return Container(
                                  margin: EdgeInsets.only(left: 3),
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(
                                    color: recoit ? Colors.amber.shade100 : paye ? Color(0xFFE8F5E9) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: recoit ? Colors.amber : paye ? Colors.green.shade300 : Colors.grey.shade200),
                                  ),
                                  child: Center(child: Icon(
                                    recoit ? Icons.star_rounded : paye ? Icons.check_rounded : Icons.remove,
                                    size: 13,
                                    color: recoit ? Colors.amber.shade700 : paye ? Colors.green : Colors.grey.shade400,
                                  )),
                                );
                              }),
                            ]),
                          )).toList(),
                          SizedBox(height: 10),
                          Row(children: [
                            _legendeItem(Colors.amber, 'Reçoit'),
                            SizedBox(width: 12),
                            _legendeItem(Colors.green, 'Payé'),
                            SizedBox(width: 12),
                            _legendeItem(Colors.grey, 'En attente'),
                          ]),
                        ]),
                      );
                    },
                    childCount: groupes.length,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _legendeItem(MaterialColor color, String label) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color.shade100, border: Border.all(color: color.shade300), borderRadius: BorderRadius.circular(3))),
      SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: kGris)),
    ]);
  }

  Future<void> _testerNotification() async {
    await envoyerNotification('NattPro 🤝', 'Rappel : Pensez à cotiser pour votre Natt !');
  }

  void _ajouterGroupe() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreerGroupeScreen(onCreer: _chargerGroupes)));
  }
}

class CreerGroupeScreen extends StatefulWidget {
  final VoidCallback onCreer;
  CreerGroupeScreen({required this.onCreer});
  @override
  _CreerGroupeScreenState createState() => _CreerGroupeScreenState();
}

class _CreerGroupeScreenState extends State<CreerGroupeScreen> {
  final _nomCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  String _frequence = 'Mensuel';
  DateTime _dateDebut = DateTime.now();
  bool _enregistrement = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: kBlue,
        title: Text('Créer un Natt', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              _champ(_nomCtrl, 'Nom du groupe', Icons.group),
              SizedBox(height: 14),
              _champ(_montantCtrl, 'Montant de cotisation (FCFA)', Icons.attach_money, type: TextInputType.number),
              SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _frequence,
                decoration: InputDecoration(labelText: 'Fréquence', prefixIcon: Icon(Icons.repeat, color: kBlue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: ['Hebdomadaire', 'Mensuel'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (val) => setState(() => _frequence = val!),
              ),
              SizedBox(height: 14),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                leading: Icon(Icons.calendar_today, color: kBlue),
                title: Text('Date de début'),
                subtitle: Text('${_dateDebut.day}/${_dateDebut.month}/${_dateDebut.year}'),
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: _dateDebut, firstDate: DateTime(2024), lastDate: DateTime(2030));
                  if (date != null) setState(() => _dateDebut = date);
                },
              ),
            ]),
          ),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: _enregistrement ? null : _valider,
              child: _enregistrement
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Créer le groupe', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _champ(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: type,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: kBlue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
    );
  }

  Future<void> _valider() async {
    if (_nomCtrl.text.isEmpty || _montantCtrl.text.isEmpty) return;
    setState(() => _enregistrement = true);
    try {
      await supabase.from('groupes').insert({
        'nom': _nomCtrl.text, 'montant': double.tryParse(_montantCtrl.text) ?? 0,
        'frequence': _frequence, 'date_debut': _dateDebut.toIso8601String().split('T')[0],
        'tirage_effectue': false, 'user_id': supabase.auth.currentUser!.id,
      });
      widget.onCreer();
      Navigator.pop(context);
    } catch (e) {
      setState(() => _enregistrement = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }
}

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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: kBlue,
        title: Text(groupe.nom, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: Icon(Icons.savings_rounded, color: Colors.white), tooltip: 'Coffre-fort', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CoffreFortScreen(groupe: groupe)))),
          IconButton(icon: Icon(Icons.warning_amber_rounded, color: Colors.white), tooltip: 'Amendes', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AmendesScreen(groupe: groupe)))),
          IconButton(icon: Icon(Icons.money_off_rounded, color: Colors.white), tooltip: 'Impayés', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImpayesScreen(groupe: groupe)))),
          IconButton(icon: Icon(Icons.share, color: Colors.white), onPressed: _partagerWhatsApp),
          if (groupe.membres.length >= 2)
            IconButton(icon: Icon(Icons.shuffle, color: Colors.white), onPressed: _tirage),
        ],
      ),
      body: Column(children: [
        _buildResume(),
        if (!groupe.tirageEffectue && groupe.membres.length >= 2)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
            child: Row(children: [
              Icon(Icons.shuffle, color: Colors.orange),
              SizedBox(width: 10),
              Expanded(child: Text('Lancez le tirage pour définir l\'ordre', style: TextStyle(color: Colors.orange.shade800, fontSize: 13))),
            ]),
          ),
        Expanded(
          child: groupe.membres.isEmpty
              ? Center(child: Text('Ajoutez des membres !', style: TextStyle(color: kGris)))
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: groupe.membres.length,
                  itemBuilder: (context, index) => _buildMembreCard(groupe.membres[index], index),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kBlue,
        onPressed: _afficherOptionsAjout,
        icon: Icon(Icons.person_add, color: Colors.white),
        label: Text('Ajouter', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildResume() {
    final groupe = widget.groupe;
    final nbPaies = groupe.nbPayesTourActuel;
    final progression = groupe.membres.isEmpty ? 0.0 : nbPaies / groupe.membres.length;
    final eligibles = groupe.membresEligibles.length;
    return Container(
      margin: EdgeInsets.all(16), padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _stat('👥', '${groupe.membres.length}', 'Membres'),
          _stat('💰', '${groupe.montant.toStringAsFixed(0)}', 'FCFA'),
          _stat('🏆', '${groupe.cagnotte.toStringAsFixed(0)}', 'Cagnotte'),
          _stat('🎲', '$eligibles', 'Éligibles'),
        ]),
        if (groupe.receveurActuel != null) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Text('${groupe.receveurActuel!.nom} reçoit ce tour', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            ]),
          ),
        ],
        SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Cotisations du tour', style: TextStyle(color: Colors.white70, fontSize: 11)),
          Text('$nbPaies / ${groupe.membres.length} ont payé', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ]),
        SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progression,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
            minHeight: 7,
          ),
        ),
        if (groupe.estTermine) ...[
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Text('🎉 Ce Natt est terminé ! Tout le monde a reçu.', style: TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center),
          ),
        ],
      ]),
    );
  }

  Widget _stat(String emoji, String val, String label) {
    return Column(children: [
      Text(emoji, style: TextStyle(fontSize: 18)),
      Text(val, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
      Text(label, style: TextStyle(color: Colors.white70, fontSize: 10)),
    ]);
  }

  Widget _buildMembreCard(Membre membre, int index) {
    final groupe = widget.groupe;
    final tour = groupe.tourActuel;
    final estReceveur = groupe.tirageEffectue && membre.ordre - 1 == tour;
    final aPaye = membre.aPaye(tour);
    final aDejaRecu = membre.aDejaGagne;
    return Dismissible(
      key: Key(membre.id ?? index.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(14)),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async => await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Supprimer ?'),
          content: Text('Supprimer "${membre.nom}" ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: Text('Supprimer', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
      onDismissed: (_) async {
        await supabase.from('membres').delete().eq('id', membre.id!);
        setState(() {
          widget.groupe.membres.removeAt(index);
          widget.groupe.tirageEffectue = false;
        });
        widget.onUpdate();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: estReceveur ? Color(0xFFFFFDE7) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: estReceveur ? Colors.amber.shade200 : Colors.grey.shade100),
        ),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: estReceveur ? Colors.amber : aDejaRecu ? Colors.green.shade100 : kBluLight,
              child: Text('${membre.ordre}', style: TextStyle(color: estReceveur ? Colors.white : aDejaRecu ? Colors.green.shade700 : kBlue, fontWeight: FontWeight.w600, fontSize: 15)),
            ),
            if (aDejaRecu) Positioned(right: 0, bottom: 0,
              child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                child: Icon(Icons.check, color: Colors.white, size: 10))),
          ]),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(membre.nom, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kNoir)),
              if (estReceveur) ...[
                SizedBox(width: 6),
                Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6)),
                  child: Text('Reçoit', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600))),
              ],
              if (aDejaRecu && !estReceveur) ...[
                SizedBox(width: 6),
                Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text('A reçu ✓', style: TextStyle(fontSize: 10, color: Colors.green.shade700))),
              ],
            ]),
            Text(membre.telephone, style: TextStyle(color: kGris, fontSize: 12)),
            Text(aPaye ? '✅ Cotisation payée' : '⏳ En attente', style: TextStyle(fontSize: 11, color: aPaye ? Colors.green : Colors.orange)),
          ])),
          GestureDetector(
            onTap: () => _togglePaiement(membre, aPaye),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: aPaye ? Colors.green : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: aPaye ? Colors.green : Colors.grey.shade300),
              ),
              child: Icon(aPaye ? Icons.check_rounded : Icons.circle_outlined, color: aPaye ? Colors.white : kGris, size: 20),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _togglePaiement(Membre membre, bool aPaye) async {
    final tour = widget.groupe.tourActuel;
    try {
      final existing = await supabase.from('paiements').select().eq('membre_id', membre.id!).eq('tour', tour);
      if ((existing as List).isEmpty) {
        final result = await supabase.from('paiements').insert({
          'membre_id': membre.id, 'tour': tour, 'paye': true, 'date_paiement': DateTime.now().toIso8601String(),
        }).select();
        setState(() => membre.paiements.add(Paiement(id: result[0]['id'], membreId: membre.id!, tour: tour, paye: true, date: DateTime.now())));
        await envoyerNotification('✅ Cotisation reçue', '${membre.nom} a payé pour ${widget.groupe.nom}');
      } else {
        await supabase.from('paiements').update({'paye': !aPaye}).eq('membre_id', membre.id!).eq('tour', tour);
        setState(() {
          final p = membre.paiements.firstWhere((p) => p.tour == tour);
          p.paye = !aPaye;
        });
      }
      widget.onUpdate();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _partagerWhatsApp() async {
    final groupe = widget.groupe;
    if (!groupe.tirageEffectue) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ Effectuez le tirage d\'abord !')));
      return;
    }
    String message = '🤝 *NattPro - ${groupe.nom}*\n\n';
    message += '💰 Cotisation : ${groupe.montant.toStringAsFixed(0)} FCFA\n';
    message += '📅 Fréquence : ${groupe.frequence}\n';
    message += '👥 ${groupe.membres.length} membres\n\n';
    message += '🎯 *Ordre du tirage :*\n';
    for (final m in groupe.membres) {
      final recoit = m.ordre - 1 == groupe.tourActuel;
      message += '${m.ordre}. ${m.nom}${recoit ? ' 🎯' : m.aDejaGagne ? ' ✅' : ''}\n';
    }
    message += '\n_Partagé via NattPro_ 🇸🇳';

    // Essayer WhatsApp direct puis wa.me
    final urlDirect = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
    final urlWeb = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(urlDirect)) {
        await launchUrl(urlDirect);
      } else if (await canLaunchUrl(urlWeb)) {
        await launchUrl(urlWeb, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir WhatsApp')));
      }
    } catch (e) {
      try {
        await launchUrl(urlWeb, mode: LaunchMode.externalApplication);
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Installez WhatsApp pour partager')));
      }
    }
  }

  Future<void> _tirage() async {
    if (widget.groupe.estTermine) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ce Natt est déjà terminé !')));
      return;
    }
    final eligibles = widget.groupe.membresEligibles;
    if (eligibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tous les membres ont déjà gagné !')));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('🎲 Tirage au sort'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${eligibles.length} membres éligibles au tirage :'),
          SizedBox(height: 8),
          ...eligibles.map((m) => Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Icon(Icons.person, color: kBlue, size: 16),
              SizedBox(width: 6),
              Text(m.nom, style: TextStyle(fontSize: 13)),
            ]),
          )).toList(),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBlue),
            onPressed: () async {
              Navigator.pop(context);
              // Mélanger seulement les éligibles, les gagnants restent en place
              final gagnants = widget.groupe.membres.where((m) => m.aDejaGagne).toList();
              eligibles.shuffle(Random());
              final nouvelOrdre = [...gagnants, ...eligibles];
              for (int i = 0; i < nouvelOrdre.length; i++) {
                nouvelOrdre[i].ordre = i + 1;
                await supabase.from('membres').update({'ordre': i + 1}).eq('id', nouvelOrdre[i].id!);
              }
              widget.groupe.membres.clear();
              widget.groupe.membres.addAll(nouvelOrdre);
              await supabase.from('groupes').update({'tirage_effectue': true}).eq('id', widget.groupe.id!);
              setState(() => widget.groupe.tirageEffectue = true);
              widget.onUpdate();
              _afficherResultat();
              await envoyerNotification('🎲 Tirage effectué !', 'L\'ordre de ${widget.groupe.nom} est défini !');
            },
            child: Text('Lancer le tirage', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _marquerGagnant(Membre gagnant) async {
    await supabase.from('membres').update({'a_deja_gagne': true}).eq('id', gagnant.id!);
    setState(() => gagnant.aDejaGagne = true);
    widget.onUpdate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ ${gagnant.nom} marqué comme ayant reçu'), backgroundColor: Colors.green),
    );
  }

  void _afficherResultat() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('🎉 Ordre du tirage'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: widget.groupe.membres.map((m) => ListTile(
            leading: CircleAvatar(
              backgroundColor: m.aDejaGagne ? Colors.green.shade100 : kBluLight,
              child: Text('${m.ordre}', style: TextStyle(color: m.aDejaGagne ? Colors.green : kBlue, fontWeight: FontWeight.w600)),
            ),
            title: Text(m.nom),
            subtitle: Text(m.aDejaGagne ? 'A déjà reçu ✓' : 'En attente'),
            trailing: m.aDejaGagne ? null : TextButton(
              onPressed: () { Navigator.pop(context); _marquerGagnant(m); },
              child: Text('Marquer reçu', style: TextStyle(fontSize: 11)),
            ),
          )).toList()),
        ),
        actions: [
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: kBlue), onPressed: () => Navigator.pop(context), child: Text('OK', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  void _afficherOptionsAjout() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 16),
          Text('Ajouter un membre', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          SizedBox(height: 16),
          ListTile(
            leading: CircleAvatar(backgroundColor: kBluLight, child: Icon(Icons.contacts, color: kBlue)),
            title: Text('Depuis mes contacts'),
            subtitle: Text('Accéder au répertoire'),
            onTap: () { Navigator.pop(context); _ajouterDepuisContacts(); },
          ),
          Divider(),
          ListTile(
            leading: CircleAvatar(backgroundColor: kBluLight, child: Icon(Icons.person_add, color: kBlue)),
            title: Text('Saisir manuellement'),
            subtitle: Text('Nom et numéro'),
            onTap: () { Navigator.pop(context); _ajouterManuellement(); },
          ),
          SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _ajouterDepuisContacts() async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permission contacts refusée')));
      return;
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Choisir un contact'),
        content: SizedBox(width: double.maxFinite, height: 400,
          child: ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              final tel = contact.phones.isNotEmpty ? contact.phones.first.number : '';
              return ListTile(
                leading: CircleAvatar(backgroundColor: kBluLight,
                  child: Text(contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : '?', style: TextStyle(color: kBlue))),
                title: Text(contact.displayName),
                subtitle: Text(tel),
                onTap: () { Navigator.pop(context); _sauvegarderMembre(contact.displayName, tel); },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Fermer'))],
      ),
    );
  }

  void _ajouterManuellement() {
    final nomCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Nouveau membre'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nomCtrl, decoration: InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person))),
          SizedBox(height: 12),
          TextField(controller: telCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBlue),
            onPressed: () { if (nomCtrl.text.isNotEmpty) { Navigator.pop(context); _sauvegarderMembre(nomCtrl.text, telCtrl.text); } },
            child: Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sauvegarderMembre(String nom, String telephone) async {
    try {
      final ordre = widget.groupe.membres.length + 1;
      final result = await supabase.from('membres').insert({
        'groupe_id': widget.groupe.id, 'nom': nom, 'telephone': telephone, 'ordre': ordre,
      }).select();
      setState(() {
        widget.groupe.membres.add(Membre(id: result[0]['id'], nom: nom, telephone: telephone, ordre: ordre, paiements: []));
        widget.groupe.tirageEffectue = false;
      });
      widget.onUpdate();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }
}
