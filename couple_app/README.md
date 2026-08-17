# Private Couple App — Minimal Versiyon

## Ne var?
- Firebase Auth (kayıt / giriş)
- 6 haneli kod ile eşleşme sistemi
- Eşleşme ekranı + Home ekranı
- Ayarlar (eşleşmeyi bitir / çıkış)

## Ne yok? (sonraya bırakıldı)
- Google Maps
- Konum takibi
- SOS butonu
- Push bildirim (FCM)

---

## Kurulum (3 adım)

### 1. Firebase bağla
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
Bu komut `lib/firebase_options.dart` dosyasını otomatik oluşturur.
Zaten dosyan varsa (senin zip'inde vardı) — dokunma.

### 2. Paketleri yükle
```bash
flutter pub get
```

### 3. Çalıştır
```bash
flutter run
```

---

## Firestore kurallarını yükle
```bash
firebase deploy --only firestore:rules
```

## Test akışı
1. **Telefon A** → Kayıt ol → 6 haneli kodunu gör
2. **Telefon B** → Kayıt ol → A'nın kodunu gir → Eşleştir
3. Her iki telefon da otomatik Home ekranına geçer ✓

