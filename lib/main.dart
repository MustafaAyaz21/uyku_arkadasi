import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:usage_stats/usage_stats.dart' hide AppInfo;
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

const String guncellemeJsonUrl =
    'https://raw.githubusercontent.com/MustafaAyaz21/uyku_arkadasi/main/version.json';

Future yeniSurumKontrolEt() async {
  try {
    final bilgi = await PackageInfo.fromPlatform();
    final mevcutSurum = bilgi.version.trim();

    final yanit = await http.get(Uri.parse(guncellemeJsonUrl));
    if (yanit.statusCode != 200) return null;

    final veri = jsonDecode(yanit.body) as Map;
    final sonSurum = (veri['latest_version'] ?? '').toString().trim();

    if (sonSurum.isNotEmpty && sonSurum != mevcutSurum) {
      await telefonaBildirimGonder(
        id: 99901,
        baslik: 'Uyku Arkadaşı Güncellemesi',
        icerik: 'Yeni sürüm ($sonSurum) hazır! İndirmek için uygulamayı aç.',
      );
      return veri;
    }
  } catch (_) {}
  return null;
}
Future<String?> guncellemeApkIndirVeKur(String apkUrl) async {
  try {
    if (apkUrl.trim().isEmpty) {
      return 'APK bağlantısı (apk_url) boş.';
    }
    final yanit = await http.get(Uri.parse(apkUrl));
    if (yanit.statusCode != 200) {
      return 'APK indirilemedi (Kod: ${yanit.statusCode}).';
    }

    final klasor = await getTemporaryDirectory();
    final dosya = File('${klasor.path}/uyku_arkadasi_update.apk');
    await dosya.writeAsBytes(yanit.bodyBytes);

    final sonuc = await OpenFilex.open(dosya.path);
    if (sonuc.type != ResultType.done) {
      return 'Kurulum açılamadı: ${sonuc.message}';
    }
    return null;
  } catch (e) {
    return 'Hata: $e';
  }
}
// ============================================================================
// YEREL BİLDİRİM YÖNETİCİSİ (PLANLI MESAJLAR İÇİN - GÜNCEL SÜRÜM UYUMLU)
// ============================================================================
final FlutterLocalNotificationsPlugin bildirimServisi =
    FlutterLocalNotificationsPlugin();

Future<void> bildirimSisteminiBaslat() async {
  const androidAyar = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ayarlar = InitializationSettings(android: androidAyar);
  await bildirimServisi.initialize(settings: ayarlar);

  const kanal = AndroidNotificationChannel(
    'uyku_planli_mesajlar',
    'Planlı Uyku Mesajları',
    description: 'Partnerinden gelen zamanlanmış uyku ve uyandırma mesajları',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  await bildirimServisi
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(kanal);
}

Future<void> telefonaBildirimGonder({
  required int id,
  required String baslik,
  required String icerik,
}) async {
  const androidDetay = AndroidNotificationDetails(
    'uyku_planli_mesajlar',
    'Planlı Uyku Mesajları',
    channelDescription:
        'Partnerinden gelen zamanlanmış uyku ve uyandırma mesajları',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );
  const detaylar = NotificationDetails(android: androidDetay);
  await bildirimServisi.show(
    id: id,
    title: baslik,
    body: icerik,
    notificationDetails: detaylar,
  );
}

// ============================================================================
// BUZ DEVRİ KARAKTER AVATAR LİSTESİ (ASSETS)
// ============================================================================
const List<Map<String, dynamic>> stokAvatarlar = [
  {
    'id': 'manny',
    'dosya': 'assets/manny.png',
    'ad': 'Manny',
    'renk': 0xFFF6D365
  },
  {
    'id': 'diego',
    'dosya': 'assets/diego.png',
    'ad': 'Diego',
    'renk': 0xFFFF8C42
  },
  {'id': 'sid', 'dosya': 'assets/sid.png', 'ad': 'Sid', 'renk': 0xFF4ECDC4},
  {
    'id': 'scrat',
    'dosya': 'assets/scrat.png',
    'ad': 'Scrat',
    'renk': 0xFF58A6FF
  },
];

Widget profilAvatarOlustur({
  required String avatarTipi,
  required String avatarVeri,
  double boyut = 48,
}) {
  if (avatarTipi == 'galeri' && avatarVeri.isNotEmpty) {
    try {
      final bytes = base64Decode(avatarVeri);
      return ClipOval(
        child: Image.memory(
          bytes,
          width: boyut,
          height: boyut,
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {}
  }

  final secilen = stokAvatarlar.firstWhere(
    (item) => item['id'] == avatarVeri,
    orElse: () => stokAvatarlar[0],
  );
  final renk = Color(secilen['renk'] as int);

  return Container(
    width: boyut,
    height: boyut,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: renk.withValues(alpha: 0.75), width: 2),
      boxShadow: [
        BoxShadow(
          color: renk.withValues(alpha: 0.18),
          blurRadius: 8,
        ),
      ],
    ),
    child: ClipOval(
      child: Image.asset(
        secilen['dosya'] as String,
        width: boyut,
        height: boyut,
        fit: BoxFit.cover,
      ),
    ),
  );
}

// ============================================================================
// ARKA PLAN SERVİSİ (UYGULAMA TAKİBİ + PLANLI MESAJ BİLDİRİM TETİKLEYİCİ)
// ============================================================================
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp();
  await bildirimSisteminiBaslat();

  String? sonGonderilenOlay;

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final odaKodu = prefs.getString('odaKodu');
    final kullaniciId = prefs.getString('kullaniciId');
    final kullaniciAdi = prefs.getString('kullaniciAdi');

    if (odaKodu == null || kullaniciId == null || kullaniciAdi == null) return;

    // 1. GÖREV: ZAMANLANMIŞ MESAJLARI KONTROL ET VE SAATİ GELİNCE BİLDİRİM AT
    try {
      final simdiMs = DateTime.now().millisecondsSinceEpoch;
      final planliSnap = await FirebaseFirestore.instance
          .collection('odalar')
          .doc(odaKodu)
          .collection('planli_mesajlar')
          .where('gonderildi', isEqualTo: false)
          .get();

      for (final doc in planliSnap.docs) {
        final veri = doc.data();
        final hedefMs = veri['hedefZamanMs'] as int? ?? 0;
        final gonderenId = veri['gonderenId'] ?? '';
        final gonderenAd = veri['gonderenAd'] ?? 'Partnerin';
        final mesaj = veri['mesaj'] ?? '';

        if (hedefMs > 0 && simdiMs >= hedefMs) {
          if (gonderenId != kullaniciId) {
            await telefonaBildirimGonder(
              id: doc.id.hashCode,
              baslik: '🌙 $gonderenAd sana bir not bıraktı',
              icerik: mesaj,
            );
            await doc.reference.update({
              'gonderildi': true,
              'gonderilmeZamaniMs': simdiMs,
            });
          }
        }
      }
    } catch (_) {}

    // 2. GÖREV: İYİ GECELER MODU AKTİFSE UYGULAMA KULLANIMINI İZLE
    final iyiGecelerModu = prefs.getBool('iyiGecelerModu') ?? true;
    if (!iyiGecelerModu) return;

    final basSaat = prefs.getInt('baslangicSaat') ?? 0;
    final basDakika = prefs.getInt('baslangicDakika') ?? 0;
    final bitSaat = prefs.getInt('bitisSaat') ?? 7;
    final bitDakika = prefs.getInt('bitisDakika') ?? 0;

    final simdi = TimeOfDay.now();
    final suAnDk = simdi.hour * 60 + simdi.minute;
    final basDk = basSaat * 60 + basDakika;
    final bitDk = bitSaat * 60 + bitDakika;

    bool saatIcinde = basDk <= bitDk
        ? (suAnDk >= basDk && suAnDk <= bitDk)
        : (suAnDk >= basDk || suAnDk <= bitDk);

    if (!saatIcinde) return;

    bool? izinVar = await UsageStats.checkUsagePermission();
    if (izinVar != true) return;

    final paketlerJson = prefs.getString('izlenenPaketler');
    Map<String, dynamic> izlenenPaketler = paketlerJson != null
        ? jsonDecode(paketlerJson)
        : {
            'com.instagram.android': 'Instagram',
            'com.google.android.youtube': 'YouTube',
            'com.zhiliaoapp.musically': 'TikTok',
          };

    DateTime bitis = DateTime.now();
    DateTime baslangic = bitis.subtract(const Duration(seconds: 15));
    List<EventUsageInfo> olaylar =
        await UsageStats.queryEvents(baslangic, bitis);

    for (var olay in olaylar.reversed) {
      if (olay.eventType == '1' && olay.packageName != null) {
        final paket = olay.packageName!;
        if (izlenenPaketler.containsKey(paket)) {
          final uygulamaAdi = izlenenPaketler[paket].toString();
          String olayAnahtari = '$paket-${olay.timeStamp}';

          if (sonGonderilenOlay != olayAnahtari) {
            sonGonderilenOlay = olayAnahtari;
            await FirebaseFirestore.instance
                .collection('odalar')
                .doc(odaKodu)
                .collection('hareketler')
                .doc(kullaniciId)
                .set({
              'kullaniciId': kullaniciId,
              'kullanici': kullaniciAdi,
              'uygulama': uygulamaAdi,
              'paketAdi': paket,
              'zamanMilisaniye': DateTime.now().millisecondsSinceEpoch,
            });
          }
          break;
        }
      }
    }
  });
}

Future<void> arkaPlanServisiniHazirla() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      initialNotificationTitle: 'Uyku Arkadaşı',
      initialNotificationContent: 'Gece takibi ve planlı mesajlar aktif',
    ),
    iosConfiguration: IosConfiguration(),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await bildirimSisteminiBaslat();
  await arkaPlanServisiniHazirla();

  await bildirimServisi
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  final prefs = await SharedPreferences.getInstance();
  final kayitliId = prefs.getString('kullaniciId');
  final kayitliAd = prefs.getString('kullaniciAdi');
  final kayitliOda = prefs.getString('odaKodu');

  runApp(UykuArkadasiApp(
    kayitliId: kayitliId,
    kayitliAd: kayitliAd,
    kayitliOda: kayitliOda,
  ));
}

class UykuArkadasiApp extends StatelessWidget {
  final String? kayitliId;
  final String? kayitliAd;
  final String? kayitliOda;

  const UykuArkadasiApp({
    super.key,
    this.kayitliId,
    this.kayitliAd,
    this.kayitliOda,
  });

  @override
  Widget build(BuildContext context) {
    Widget baslangicEkrani;
    if (kayitliId == null || kayitliAd == null) {
      baslangicEkrani = const HesapOlusturEkrani();
    } else if (kayitliOda == null) {
      baslangicEkrani = const OdaSecimEkrani();
    } else {
      baslangicEkrani = GecePanosuEkrani(
        odaKodu: kayitliOda!,
        kullaniciId: kayitliId!,
        kullaniciAdi: kayitliAd!,
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Uyku Arkadaşı',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0E14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF6D365),
          secondary: Color(0xFF58A6FF),
        ),
      ),
      home: baslangicEkrani,
    );
  }
}

// ============================================================================
// 1. EKRAN: HESAP OLUŞTURMA / PROFİL DÜZENLEME EKRANI
// ============================================================================
class HesapOlusturEkrani extends StatefulWidget {
  final bool duzenlemeModu;

  const HesapOlusturEkrani({super.key, this.duzenlemeModu = false});

  @override
  State<HesapOlusturEkrani> createState() => _HesapOlusturEkraniState();
}

class _HesapOlusturEkraniState extends State<HesapOlusturEkrani> {
  final TextEditingController _isimController = TextEditingController();
  String _avatarTipi = 'stok';
  String _avatarVeri = 'manny';
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    if (widget.duzenlemeModu) {
      _mevcutProfiliYukle();
    }
  }

  Future<void> _mevcutProfiliYukle() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isimController.text = prefs.getString('kullaniciAdi') ?? '';
      _avatarTipi = prefs.getString('avatarTipi') ?? 'stok';
      _avatarVeri = prefs.getString('avatarVeri') ?? 'manny';
    });
  }

  Future<void> _galeridenFotoSec() async {
    try {
      final picker = ImagePicker();
      final XFile? secilen = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 220,
        maxHeight: 220,
        imageQuality: 65,
      );
      if (secilen != null) {
        final bytes = await secilen.readAsBytes();
        setState(() {
          _avatarTipi = 'galeri';
          _avatarVeri = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf seçilirken bir sorun oluştu.')),
      );
    }
  }

  Future<void> _hesabiKaydet() async {
    final ad = _isimController.text.trim();
    if (ad.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen ismini gir.')),
      );
      return;
    }

    setState(() => _kaydediliyor = true);

    final prefs = await SharedPreferences.getInstance();
    String? kullaniciId = prefs.getString('kullaniciId');
    if (kullaniciId == null) {
      kullaniciId =
          'usr_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      await prefs.setString('kullaniciId', kullaniciId);
    }

    await prefs.setString('kullaniciAdi', ad);
    await prefs.setString('avatarTipi', _avatarTipi);
    await prefs.setString('avatarVeri', _avatarVeri);

    final aktifOda = prefs.getString('odaKodu');
    if (aktifOda != null) {
      await FirebaseFirestore.instance
          .collection('odalar')
          .doc(aktifOda)
          .collection('uyeler')
          .doc(kullaniciId)
          .set({
        'kullaniciId': kullaniciId,
        'kullaniciAdi': ad,
        'avatarTipi': _avatarTipi,
        'avatarVeri': _avatarVeri,
      }, SetOptions(merge: true));
    }

    if (!mounted) return;
    setState(() => _kaydediliyor = false);

    if (widget.duzenlemeModu) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OdaSecimEkrani()),
      );
    }
  }

  @override
  void dispose() {
    _isimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.duzenlemeModu
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Profili Düzenle'),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                if (!widget.duzenlemeModu) ...[
                  const Text(
                    'Hesap Oluştur',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Profil fotoğrafını seç, ismini yaz ve gece nöbetine hazırlan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                ],
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    profilAvatarOlustur(
                      avatarTipi: _avatarTipi,
                      avatarVeri: _avatarVeri,
                      boyut: 112,
                    ),
                    GestureDetector(
                      onTap: _galeridenFotoSec,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF6D365),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _galeridenFotoSec,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Galeriden Fotoğraf Seç'),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Veya Buz Devri uyku karakterlerinden birini seç:',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: stokAvatarlar.map((item) {
                    final seciliMi =
                        _avatarTipi == 'stok' && _avatarVeri == item['id'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _avatarTipi = 'stok';
                          _avatarVeri = item['id'] as String;
                        });
                      },
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: seciliMi
                                    ? const Color(0xFFF6D365)
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: profilAvatarOlustur(
                              avatarTipi: 'stok',
                              avatarVeri: item['id'] as String,
                              boyut: 54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item['ad'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: seciliMi
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: seciliMi
                                  ? const Color(0xFFF6D365)
                                  : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _isimController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Adın (Örn: Mustafa)',
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: const Color(0xFF151A23),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _kaydediliyor ? null : _hesabiKaydet,
                    icon: const Icon(Icons.check_circle_outline),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF6D365),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    label: Text(
                      _kaydediliyor
                          ? 'Kaydediliyor...'
                          : (widget.duzenlemeModu
                              ? 'Değişiklikleri Kaydet'
                              : 'Hesabı Onayla ve Devam Et'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. EKRAN: ODA OLUŞTUR VEYA ODAYA KATIL EKRANI (2 KİŞİ LİMİTLİ)
// ============================================================================
class OdaSecimEkrani extends StatefulWidget {
  const OdaSecimEkrani({super.key});

  @override
  State<OdaSecimEkrani> createState() => _OdaSecimEkraniState();
}

class _OdaSecimEkraniState extends State<OdaSecimEkrani> {
  final TextEditingController _odaController = TextEditingController();
  bool _katilKutusuAcik = false;
  bool _islemSuruyor = false;

  String _kullaniciId = '';
  String _kullaniciAdi = '';
  String _avatarTipi = 'stok';
  String _avatarVeri = 'manny';

  @override
  void initState() {
    super.initState();
    _profilYukle();
  }

  Future<void> _profilYukle() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _kullaniciId = prefs.getString('kullaniciId') ?? '';
      _kullaniciAdi = prefs.getString('kullaniciAdi') ?? 'Kullanıcı';
      _avatarTipi = prefs.getString('avatarTipi') ?? 'stok';
      _avatarVeri = prefs.getString('avatarVeri') ?? 'manny';
    });
  }

  Future<void> _odaOlustur() async {
    setState(() => _islemSuruyor = true);
    final rastgeleKod = (100000 + Random().nextInt(900000)).toString();
    final odaRef =
        FirebaseFirestore.instance.collection('odalar').doc(rastgeleKod);

    await odaRef.set({
      'olusturanId': _kullaniciId,
      'olusturmaZamani': DateTime.now().millisecondsSinceEpoch,
    });

    await odaRef.collection('uyeler').doc(_kullaniciId).set({
      'kullaniciId': _kullaniciId,
      'kullaniciAdi': _kullaniciAdi,
      'avatarTipi': _avatarTipi,
      'avatarVeri': _avatarVeri,
      'rol': 'Kurucu',
      'katilmaZamani': DateTime.now().millisecondsSinceEpoch,
    });

    await _odayaGirisYap(rastgeleKod);
  }

  Future<void> _odayaKatil() async {
    final odaKodu = _odaController.text.trim();
    if (odaKodu.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Lütfen partnerinin paylaştığı 6 haneli oda kodunu gir.'),
        ),
      );
      return;
    }

    setState(() => _islemSuruyor = true);

    try {
      final odaRef =
          FirebaseFirestore.instance.collection('odalar').doc(odaKodu);
      final uyelerSnap = await odaRef.collection('uyeler').get();

      final zatenUyeMi = uyelerSnap.docs.any((d) => d.id == _kullaniciId);

      if (!zatenUyeMi && uyelerSnap.docs.length >= 2) {
        if (!mounted) return;
        setState(() => _islemSuruyor = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Bu oda dolu (2/2)! Odalar en fazla 2 kişiliktir.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
        return;
      }

      await odaRef.set(
        {'sonGuncelleme': DateTime.now().millisecondsSinceEpoch},
        SetOptions(merge: true),
      );

      await odaRef.collection('uyeler').doc(_kullaniciId).set({
        'kullaniciId': _kullaniciId,
        'kullaniciAdi': _kullaniciAdi,
        'avatarTipi': _avatarTipi,
        'avatarVeri': _avatarVeri,
        'rol': uyelerSnap.docs.isEmpty ? 'Kurucu' : 'Üye',
        'katilmaZamani': DateTime.now().millisecondsSinceEpoch,
      });

      await _odayaGirisYap(odaKodu);
    } catch (e) {
      if (!mounted) return;
      setState(() => _islemSuruyor = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaya bağlanırken bir hata oluştu.')),
      );
    }
  }

  Future<void> _odayaGirisYap(String odaKodu) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('odaKodu', odaKodu);
    await prefs.setBool('iyiGecelerModu', true);

    final service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      await service.startService();
    }

    if (!mounted) return;
    setState(() => _islemSuruyor = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GecePanosuEkrani(
          odaKodu: odaKodu,
          kullaniciId: _kullaniciId,
          kullaniciAdi: _kullaniciAdi,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _odaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () async {
              final guncellendi = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HesapOlusturEkrani(duzenlemeModu: true),
                ),
              );
              if (guncellendi == true) _profilYukle();
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Profili Düzenle'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                profilAvatarOlustur(
                  avatarTipi: _avatarTipi,
                  avatarVeri: _avatarVeri,
                  boyut: 92,
                ),
                const SizedBox(height: 16),
                Text(
                  'Hoş geldin, $_kullaniciAdi',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Özel 2 kişilik odanı oluştur veya partnerinin paylaştığı koda katıl.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _islemSuruyor ? null : _odaOlustur,
                    icon: const Icon(Icons.add_circle_outline),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF6D365),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    label: const Text(
                      'Oda Oluştur',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: _islemSuruyor
                        ? null
                        : () =>
                            setState(() => _katilKutusuAcik = !_katilKutusuAcik),
                    icon: Icon(
                      _katilKutusuAcik
                          ? Icons.expand_less
                          : Icons.login_rounded,
                      color: const Color(0xFFF6D365),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFFF6D365),
                        width: 1.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    label: const Text(
                      'Odaya Gir',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF6D365),
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _katilKutusuAcik
                      ? Container(
                          margin: const EdgeInsets.only(top: 18),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF151A23),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _odaController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  letterSpacing: 6,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  hintText: '000000',
                                  labelText: 'Partnerinin Oda Kodu',
                                  filled: true,
                                  fillColor: const Color(0xFF0B0E14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _islemSuruyor ? null : _odayaKatil,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF58A6FF),
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    _islemSuruyor
                                        ? 'Kontrol ediliyor...'
                                        : 'Bağlan',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 3. EKRAN: ANA GECE PANOSU + ORTAK UYKU NOTLARI + ZAMANLI MESAJ PLANLAMA
// ============================================================================
class GecePanosuEkrani extends StatefulWidget {
  final String odaKodu;
  final String kullaniciId;
  final String kullaniciAdi;

  const GecePanosuEkrani({
    super.key,
    required this.odaKodu,
    required this.kullaniciId,
    required this.kullaniciAdi,
  });

  @override
  State<GecePanosuEkrani> createState() => _GecePanosuEkraniState();
}

class _GecePanosuEkraniState extends State<GecePanosuEkrani> {
  Map _mevcutGuncelleme = {};
bool _guncellemeIndiriliyor = false;
  bool _iyiGecelerModu = true;
  TimeOfDay _baslangicSaati = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _bitisSaati = const TimeOfDay(hour: 7, minute: 0);

  final TextEditingController _notController = TextEditingController();
  final TextEditingController _planliMesajController = TextEditingController();
  TimeOfDay _planlananSaat = const TimeOfDay(hour: 10, minute: 30);

  Map<String, String> _izlenenPaketler = {
    'com.instagram.android': 'Instagram',
    'com.google.android.youtube': 'YouTube',
    'com.zhiliaoapp.musically': 'TikTok',
  };

  final Map<String, Uint8List?> _uygulamaIkonlari = {};
  bool _izinVarMi = false;
  Timer? _ekranYenilemeSayaci;

  @override
  void initState() {
    super.initState();
    _guncellemeKontrolEt();
    _ayarlariYukle();
    _izniKontrolEt();
    _uyelikKaydiniGarantile();

    _ekranYenilemeSayaci = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }
Future<void> _guncellemeKontrolEt() async {
    final guncelleme = await yeniSurumKontrolEt();
    if (mounted && guncelleme != null) {
      setState(() => _mevcutGuncelleme = guncelleme);
    }
  }
  @override
  void dispose() {
    _ekranYenilemeSayaci?.cancel();
    _notController.dispose();
    _planliMesajController.dispose();
    super.dispose();
  }

  Future<void> _uyelikKaydiniGarantile() async {
    final prefs = await SharedPreferences.getInstance();
    final ad = prefs.getString('kullaniciAdi') ?? widget.kullaniciAdi;
    final tip = prefs.getString('avatarTipi') ?? 'stok';
    final veri = prefs.getString('avatarVeri') ?? 'manny';

    await FirebaseFirestore.instance
        .collection('odalar')
        .doc(widget.odaKodu)
        .collection('uyeler')
        .doc(widget.kullaniciId)
        .set({
      'kullaniciId': widget.kullaniciId,
      'kullaniciAdi': ad,
      'avatarTipi': tip,
      'avatarVeri': veri,
    }, SetOptions(merge: true));
  }

  Future<void> _ayarlariYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final mod = prefs.getBool('iyiGecelerModu') ?? true;
    final basSaat = prefs.getInt('baslangicSaat') ?? 0;
    final basDk = prefs.getInt('baslangicDakika') ?? 0;
    final bitSaat = prefs.getInt('bitisSaat') ?? 7;
    final bitDk = prefs.getInt('bitisDakika') ?? 0;
    final paketlerJson = prefs.getString('izlenenPaketler');

    Map<String, String> yuklenenPaketler = _izlenenPaketler;
    if (paketlerJson != null) {
      final Map<String, dynamic> cozulmus = jsonDecode(paketlerJson);
      yuklenenPaketler = cozulmus.map((k, v) => MapEntry(k, v.toString()));
    } else {
      await prefs.setString('izlenenPaketler', jsonEncode(_izlenenPaketler));
    }

    if (mounted) {
      setState(() {
        _iyiGecelerModu = mod;
        _baslangicSaati = TimeOfDay(hour: basSaat, minute: basDk);
        _bitisSaati = TimeOfDay(hour: bitSaat, minute: bitDk);
        _izlenenPaketler = yuklenenPaketler;
      });
    }
    _seciliUygulamaIkonlariniYukle();
  }

  Future<void> _ayarlariKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('iyiGecelerModu', _iyiGecelerModu);
    await prefs.setInt('baslangicSaat', _baslangicSaati.hour);
    await prefs.setInt('baslangicDakika', _baslangicSaati.minute);
    await prefs.setInt('bitisSaat', _bitisSaati.hour);
    await prefs.setInt('bitisDakika', _bitisSaati.minute);
    await prefs.setString('izlenenPaketler', jsonEncode(_izlenenPaketler));

    final service = FlutterBackgroundService();
    if (_iyiGecelerModu) {
      if (!(await service.isRunning())) {
        await service.startService();
      }
    } else {
      service.invoke('stopService');
    }
  }

  Future<void> _seciliUygulamaIkonlariniYukle() async {
    for (final paket in _izlenenPaketler.keys) {
      if (!_uygulamaIkonlari.containsKey(paket)) {
        try {
          final bilgi = await Future.value(InstalledApps.getAppInfo(paket));
          if (mounted && bilgi != null && bilgi.icon != null) {
            setState(() {
              _uygulamaIkonlari[paket] = bilgi.icon;
            });
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _izniKontrolEt() async {
    bool? durum = await UsageStats.checkUsagePermission();
    if (mounted) setState(() => _izinVarMi = durum ?? false);
  }

  Future<void> _izinAyarlariniAc() async {
    await UsageStats.grantUsagePermission();
    await Future.delayed(const Duration(seconds: 2));
    _izniKontrolEt();
  }

  Future<void> _uygulamaSecimEkraniniAc() async {
    final guncelListe = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UygulamaSecimEkrani(seciliPaketler: Map.from(_izlenenPaketler)),
      ),
    );

    if (guncelListe != null && guncelListe is Map<String, String>) {
      setState(() {
        _izlenenPaketler = guncelListe;
      });
      await _ayarlariKaydet();
      _seciliUygulamaIkonlariniYukle();
    }
  }

  Future<void> _saatSec(bool baslangicMi) async {
    final secilen = await showTimePicker(
      context: context,
      initialTime: baslangicMi ? _baslangicSaati : _bitisSaati,
    );
    if (secilen != null) {
      setState(() {
        if (baslangicMi) {
          _baslangicSaati = secilen;
        } else {
          _bitisSaati = secilen;
        }
      });
      await _ayarlariKaydet();
    }
  }

  Future<void> _planlananSaatiSec() async {
    final secilen = await showTimePicker(
      context: context,
      initialTime: _planlananSaat,
    );
    if (secilen != null) {
      setState(() => _planlananSaat = secilen);
    }
  }

  Future<void> _ortakNotEkle() async {
    final metin = _notController.text.trim();
    if (metin.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final ad = prefs.getString('kullaniciAdi') ?? widget.kullaniciAdi;

    await FirebaseFirestore.instance
        .collection('odalar')
        .doc(widget.odaKodu)
        .collection('notlar')
        .add({
      'yazanId': widget.kullaniciId,
      'yazanAd': ad,
      'metin': metin,
      'zamanMs': DateTime.now().millisecondsSinceEpoch,
    });

    _notController.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _mesajPlanla() async {
    final metin = _planliMesajController.text.trim();
    if (metin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen planlanacak mesajı yaz.')),
      );
      return;
    }

    final simdi = DateTime.now();
    DateTime hedefZaman = DateTime(
      simdi.year,
      simdi.month,
      simdi.day,
      _planlananSaat.hour,
      _planlananSaat.minute,
    );

    if (hedefZaman.isBefore(simdi)) {
      hedefZaman = hedefZaman.add(const Duration(days: 1));
    }

    final prefs = await SharedPreferences.getInstance();
    final ad = prefs.getString('kullaniciAdi') ?? widget.kullaniciAdi;

    await FirebaseFirestore.instance
        .collection('odalar')
        .doc(widget.odaKodu)
        .collection('planli_mesajlar')
        .add({
      'gonderenId': widget.kullaniciId,
      'gonderenAd': ad,
      'mesaj': metin,
      'hedefSaatMetni': _saatFormatla(_planlananSaat),
      'hedefZamanMs': hedefZaman.millisecondsSinceEpoch,
      'gonderildi': false,
      'olusturmaMs': simdi.millisecondsSinceEpoch,
    });

    _planliMesajController.clear();
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.teal,
        content: Text(
          'Mesaj ${_saatFormatla(_planlananSaat)} için planlandı! Saati gelince partnerine bildirim düşecek.',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  String _saatFormatla(TimeOfDay saat) {
    return '${saat.hour.toString().padLeft(2, '0')}:${saat.minute.toString().padLeft(2, '0')}';
  }

  String _msSaatFormatla(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _odadanCik() async {
    try {
      await FirebaseFirestore.instance
          .collection('odalar')
          .doc(widget.odaKodu)
          .collection('uyeler')
          .doc(widget.kullaniciId)
          .delete();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('odaKodu');
    FlutterBackgroundService().invoke('stopService');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OdaSecimEkrani()),
    );
  }

  void _odadakiKisileriGoster(List<QueryDocumentSnapshot> uyeDokumanlari) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151A23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Odadaki Kişiler',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6D365).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${uyeDokumanlari.length} / 2 Kişi',
                      style: const TextStyle(
                        color: Color(0xFFF6D365),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...uyeDokumanlari.map((doc) {
                final uye = doc.data() as Map<String, dynamic>;
                final ad = uye['kullaniciAdi'] ?? 'Kullanıcı';
                final tip = uye['avatarTipi'] ?? 'stok';
                final veri = uye['avatarVeri'] ?? 'manny';
                final benMiyim = doc.id == widget.kullaniciId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0E14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: benMiyim
                          ? const Color(0xFFF6D365).withValues(alpha: 0.4)
                          : Colors.white10,
                    ),
                  ),
                  child: Row(
                    children: [
                      profilAvatarOlustur(
                        avatarTipi: tip,
                        avatarVeri: veri,
                        boyut: 46,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              benMiyim ? '$ad (Sen)' : ad,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              uye['rol'] ?? 'Üye',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (benMiyim)
                        IconButton(
                          tooltip: 'Profili Düzenle',
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFFF6D365),
                            size: 20,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HesapOlusturEkrani(
                                  duzenlemeModu: true,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic> _akilliDurumAnalizi(int zamanMilisaniye) {
    final fark = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(zamanMilisaniye));
    final dakika = fark.inMinutes;

    String gecenSureMetni;
    if (dakika < 1) {
      gecenSureMetni = 'Az önce girdi';
    } else if (dakika < 60) {
      gecenSureMetni = '$dakika dakika önce girdi';
    } else {
      final saat = fark.inHours;
      final kalanDk = dakika % 60;
      gecenSureMetni = kalanDk > 0
          ? '$saat saat $kalanDk dk önce girdi'
          : '$saat saat önce girdi';
    }

    if (dakika <= 15) {
      return {
        'sure': gecenSureMetni,
        'tahmin': 'Yüksek ihtimal uyanık',
        'renk': Colors.orangeAccent
      };
    } else if (dakika <= 45) {
      return {
        'sure': gecenSureMetni,
        'tahmin': 'Uykuya dalıyor olabilir',
        'renk': const Color(0xFF58A6FF)
      };
    } else {
      return {
        'sure': gecenSureMetni,
        'tahmin': 'Uyuyor olabilir',
        'renk': Colors.tealAccent
      };
    }
  }

  Widget _uygulamaLogosuOlustur(String paketAdi, String uygulamaAdi) {
    final ikonByte = _uygulamaIkonlari[paketAdi];
    if (ikonByte != null && ikonByte.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(ikonByte, width: 42, height: 42, fit: BoxFit.cover),
      );
    }

    IconData yedekIkon = Icons.apps_rounded;
    Color yedekRenk = const Color(0xFFF6D365);
    if (uygulamaAdi == 'Instagram') {
      yedekIkon = Icons.camera_alt_rounded;
      yedekRenk = const Color(0xFFE1306C);
    } else if (uygulamaAdi == 'YouTube') {
      yedekIkon = Icons.play_circle_fill_rounded;
      yedekRenk = const Color(0xFFFF0000);
    } else if (uygulamaAdi == 'TikTok') {
      yedekIkon = Icons.music_note_rounded;
      yedekRenk = const Color(0xFF00F2FE);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: yedekRenk.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(yedekIkon, color: yedekRenk, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('odalar')
          .doc(widget.odaKodu)
          .collection('uyeler')
          .snapshots(),
      builder: (context, uyeSnapshot) {
        final uyeDokumanlari = uyeSnapshot.data?.docs ?? [];
        final odaDoluMu = uyeDokumanlari.length >= 2;

        final Map<String, Map<String, dynamic>> uyeHaritasi = {};
        for (final doc in uyeDokumanlari) {
          uyeHaritasi[doc.id] = doc.data() as Map<String, dynamic>;
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: odaDoluMu
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          color: Colors.tealAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Uyku Arkadaşı',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                : InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: widget.odaKodu));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Oda kodu (${widget.odaKodu}) kopyalandı!')),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.nightlight_round,
                            color: Color(0xFFF6D365), size: 22),
                        const SizedBox(width: 8),
                        Text('Oda: ${widget.odaKodu}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy_rounded,
                            size: 16, color: Colors.white54),
                      ],
                    ),
                  ),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF58A6FF).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  tooltip: 'Odadaki Kişiler (${uyeDokumanlari.length}/2)',
                  icon: const Icon(Icons.people_alt_rounded,
                      color: Color(0xFF58A6FF), size: 22),
                  onPressed: () => _odadakiKisileriGoster(uyeDokumanlari),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6D365).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  tooltip:
                      'İzlenecek Uygulamaları Seç (${_izlenenPaketler.length})',
                  icon: const Icon(Icons.add_rounded,
                      color: Color(0xFFF6D365), size: 26),
                  onPressed: _uygulamaSecimEkraniniAc,
                ),
              ),
              IconButton(
                tooltip: 'Odadan Çık',
                icon: const Icon(Icons.logout_rounded, color: Colors.white54),
                onPressed: _odadanCik,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
               if (_mevcutGuncelleme.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF58A6FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF58A6FF)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.system_update_rounded, color: Color(0xFF58A6FF)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Yeni bir güncelleme mevcut (${_mevcutGuncelleme['latest_version']})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ElevatedButton(
onPressed: _guncellemeIndiriliyor
    ? null
    : () async {
        setState(() => _guncellemeIndiriliyor = true);
        final hata = await guncellemeApkIndirVeKur(
          (_mevcutGuncelleme['apk_url'] ?? '').toString(),
        );
        if (mounted) {
          setState(() => _guncellemeIndiriliyor = false);
          if (hata != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(hata)),
            );
          }
        }
      },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF58A6FF),
                            foregroundColor: Colors.black,
                          ),
                          child: Text(_guncellemeIndiriliyor ? 'İndiriliyor...' : 'İndir'),
                        ),
                      ],
                    ),
                  ),
                if (!odaDoluMu)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6D365).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              const Color(0xFFF6D365).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.share_outlined,
                            color: Color(0xFFF6D365), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Odan hazır! Partnerine ${widget.odaKodu} kodunu gönder.',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: widget.odaKodu));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Oda kodu kopyalandı!')),
                            );
                          },
                          child: const Text('Kopyala'),
                        ),
                      ],
                    ),
                  ),

                if (!_izinVarMi)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.amber),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Arka plan takibi için Kullanım Erişimi izni gerekli.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ),
                        TextButton(
                            onPressed: _izinAyarlariniAc,
                            child: const Text('İzin Ver')),
                      ],
                    ),
                  ),

                // 1. BÖLÜM: İYİ GECELER MODU
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151A23),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _iyiGecelerModu
                          ? const Color(0xFFF6D365).withValues(alpha: 0.5)
                          : Colors.white10,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('İyi Geceler Modu',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                _iyiGecelerModu
                                    ? 'Arka Plan Aktif • ${_izlenenPaketler.length} uygulama'
                                    : 'Arka plan takibi kapalı',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white54),
                              ),
                            ],
                          ),
                          Switch(
                            value: _iyiGecelerModu,
                            activeThumbColor: const Color(0xFFF6D365),
                            onChanged: (deger) async {
                              setState(() => _iyiGecelerModu = deger);
                              await _ayarlariKaydet();
                            },
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          InkWell(
                            onTap: () => _saatSec(true),
                            child: Row(
                              children: [
                                const Icon(Icons.bedtime_outlined,
                                    size: 18, color: Color(0xFFF6D365)),
                                const SizedBox(width: 6),
                                Text(
                                    'Başlangıç: ${_saatFormatla(_baslangicSaati)}'),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => _saatSec(false),
                            child: Row(
                              children: [
                                const Icon(Icons.wb_sunny_outlined,
                                    size: 18, color: Color(0xFFF6D365)),
                                const SizedBox(width: 6),
                                Text('Bitiş: ${_saatFormatla(_bitisSaati)}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // 2. BÖLÜM: CANLI DURUM PANOSU
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'CANLI DURUM PANOSU',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white54),
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('odalar')
                      .doc(widget.odaKodu)
                      .collection('hareketler')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _bosDurumKarti();
                    }

                    final kayitlar = snapshot.data!.docs;
                    return Column(
                      children: kayitlar.map((doc) {
                        final veri = doc.data() as Map<String, dynamic>;
                        final kisiId = veri['kullaniciId'] ?? doc.id;
                        final uyeBilgisi = uyeHaritasi[kisiId];
                        final kisi = uyeBilgisi?['kullaniciAdi'] ??
                            veri['kullanici'] ??
                            'Bilinmiyor';
                        final avatarTipi = uyeBilgisi?['avatarTipi'] ?? 'stok';
                        final avatarVeri =
                            uyeBilgisi?['avatarVeri'] ?? 'manny';

                        final uygulama = veri['uygulama'] ?? '';
                        final paketAdi = veri['paketAdi'] ?? '';
                        final zamanMs = veri['zamanMilisaniye'] as int? ?? 0;

                        final analiz = _akilliDurumAnalizi(zamanMs);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF151A23),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: (analiz['renk'] as Color)
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  profilAvatarOlustur(
                                    avatarTipi: avatarTipi,
                                    avatarVeri: avatarVeri,
                                    boyut: 28,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    kisiId == widget.kullaniciId
                                        ? '$kisi (Sen)'
                                        : kisi,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              IntrinsicHeight(
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 84,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _uygulamaLogosuOlustur(
                                              paketAdi, uygulama),
                                          const SizedBox(height: 6),
                                          Text(
                                            uygulama,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 1.5,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 4),
                                      color: Colors.white12,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            analiz['sure'],
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (analiz['renk'] as Color)
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              analiz['tahmin'],
                                              style: TextStyle(
                                                color: analiz['renk'],
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 22),

                // 3. BÖLÜM: ORTAK UYKU NOTLARI
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'ORTAK UYKU NOTLARI',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white54),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151A23),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _notController,
                              maxLines: 2,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText:
                                    'Not bırak (Örn: 04:00\'te uyudum, erken uyandırma)...',
                                hintStyle: const TextStyle(
                                    fontSize: 13, color: Colors.white38),
                                filled: true,
                                fillColor: const Color(0xFF0B0E14),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filled(
                            onPressed: _ortakNotEkle,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF6D365),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('odalar')
                            .doc(widget.odaKodu)
                            .collection('notlar')
                            .orderBy('zamanMs', descending: true)
                            .limit(5)
                            .snapshots(),
                        builder: (context, notSnap) {
                          if (!notSnap.hasData || notSnap.data!.docs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Henüz bırakılmış bir not yok.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white38),
                              ),
                            );
                          }

                          return Column(
                            children: notSnap.data!.docs.map((doc) {
                              final n = doc.data() as Map<String, dynamic>;
                              final yazanId = n['yazanId'] ?? '';
                              final yazanAd = n['yazanAd'] ?? 'Kullanıcı';
                              final metin = n['metin'] ?? '';
                              final zamanMs = n['zamanMs'] as int? ?? 0;

                              return Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0B0E14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                yazanId == widget.kullaniciId
                                                    ? '$yazanAd (Sen)'
                                                    : yazanAd,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFF6D365),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _msSaatFormatla(zamanMs),
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white38),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            metin,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (yazanId == widget.kullaniciId)
                                      InkWell(
                                        onTap: () => doc.reference.delete(),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.close_rounded,
                                              size: 16, color: Colors.white38),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // 4. BÖLÜM: ZAMANLI MESAJ PLANLAMA (BİLDİRİM TETİKLEYİCİ)
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'ZAMANLI MESAJ PLANLA (BİLDİRİM)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white54),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151A23),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF58A6FF).withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Partnerin uyurken mesajını yaz, seçtiğin saatte telefonuna bildirim düşsün.',
                        style: TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _planliMesajController,
                        maxLines: 2,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText:
                              'Örn: Beni 10:30\'da uyandır ya da erken uyandırma...',
                          hintStyle: const TextStyle(
                              fontSize: 13, color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF0B0E14),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _planlananSaatiSec,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 46,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0B0E14),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFF58A6FF)
                                          .withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.alarm_rounded,
                                        color: Color(0xFF58A6FF), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Saat: ${_saatFormatla(_planlananSaat)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: _mesajPlanla,
                              icon: const Icon(Icons.schedule_send_rounded,
                                  size: 18),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF58A6FF),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              label: const Text(
                                'Planla',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('odalar')
                            .doc(widget.odaKodu)
                            .collection('planli_mesajlar')
                            .orderBy('olusturmaMs', descending: true)
                            .limit(5)
                            .snapshots(),
                        builder: (context, planSnap) {
                          if (!planSnap.hasData ||
                              planSnap.data!.docs.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              children: planSnap.data!.docs.map((doc) {
                                final p = doc.data() as Map<String, dynamic>;
                                final gonderildi =
                                    p['gonderildi'] as bool? ?? false;
                                final hedefSaat = p['hedefSaatMetni'] ?? '';
                                final mesaj = p['mesaj'] ?? '';
                                final gonderenId = p['gonderenId'] ?? '';
                                final gonderenAd = p['gonderenAd'] ?? '';

                                if (!gonderildi &&
                                    gonderenId != widget.kullaniciId) {
                                  return const SizedBox.shrink();
                                }

                                return Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0B0E14),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: gonderildi
                                          ? Colors.tealAccent
                                              .withValues(alpha: 0.3)
                                          : const Color(0xFF58A6FF)
                                              .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        gonderildi
                                            ? Icons.notifications_active_rounded
                                            : Icons.hourglass_bottom_rounded,
                                        color: gonderildi
                                            ? Colors.tealAccent
                                            : const Color(0xFF58A6FF),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              gonderildi
                                                  ? '$gonderenAd • $hedefSaat bildirim gönderildi'
                                                  : 'Saat $hedefSaat için planlandı (Bekliyor)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: gonderildi
                                                    ? Colors.tealAccent
                                                    : const Color(0xFF58A6FF),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              mesaj,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (gonderenId == widget.kullaniciId)
                                        InkWell(
                                          onTap: () => doc.reference.delete(),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(Icons.delete_outline,
                                                size: 18,
                                                color: Colors.white38),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bosDurumKarti() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151A23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.nights_stay, color: Colors.tealAccent, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Şu an sessiz ve sakin',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(
                  'Seçilen gece saatlerinde henüz hiçbir uygulamaya giriş yapılmadı.',
                  style: TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. EKRAN: TELEFONDAKİ YÜKLÜ UYGULAMALARI SEÇME EKRANI ("+" BUTONUYLA AÇILIR)
// ============================================================================
class UygulamaSecimEkrani extends StatefulWidget {
  final Map<String, String> seciliPaketler;

  const UygulamaSecimEkrani({super.key, required this.seciliPaketler});

  @override
  State<UygulamaSecimEkrani> createState() => _UygulamaSecimEkraniState();
}

class _UygulamaSecimEkraniState extends State<UygulamaSecimEkrani> {
  List<AppInfo> _tumUygulamalar = [];
  List<AppInfo> _filtrelenmisUygulamalar = [];
  bool _yukleniyor = true;
  late Map<String, String> _geciciSecimler;

  @override
  void initState() {
    super.initState();
    _geciciSecimler = Map.from(widget.seciliPaketler);
    _uygulamalariGetir();
  }

  Future<void> _uygulamalariGetir() async {
    final liste = await InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      withIcon: true,
    );
    liste.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (mounted) {
      setState(() {
        _tumUygulamalar = liste;
        _filtrelenmisUygulamalar = liste;
        _yukleniyor = false;
      });
    }
  }

  void _aramaYap(String sorgu) {
    setState(() {
      _filtrelenmisUygulamalar = _tumUygulamalar
          .where((app) => app.name.toLowerCase().contains(sorgu.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('İzlenecek Uygulamalar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, _geciciSecimler),
            icon: const Icon(Icons.check_rounded, color: Color(0xFFF6D365)),
            label: const Text(
              'Kaydet',
              style: TextStyle(
                  color: Color(0xFFF6D365),
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              onChanged: _aramaYap,
              decoration: InputDecoration(
                hintText: 'Uygulama ara (Örn: WhatsApp, Instagram, X)...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFF151A23),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _yukleniyor
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFFF6D365)))
                : ListView.builder(
                    itemCount: _filtrelenmisUygulamalar.length,
                    itemBuilder: (context, index) {
                      final app = _filtrelenmisUygulamalar[index];
                      final seciliMi =
                          _geciciSecimler.containsKey(app.packageName);

                      return ListTile(
                        leading: app.icon != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(app.icon!,
                                    width: 38, height: 38, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.apps_rounded, size: 36),
                        title: Text(app.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                        trailing: Switch(
                          value: seciliMi,
                          activeThumbColor: const Color(0xFFF6D365),
                          onChanged: (deger) {
                            setState(() {
                              if (deger) {
                                _geciciSecimler[app.packageName] = app.name;
                              } else {
                                _geciciSecimler.remove(app.packageName);
                              }
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            if (seciliMi) {
                              _geciciSecimler.remove(app.packageName);
                            } else {
                              _geciciSecimler[app.packageName] = app.name;
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
