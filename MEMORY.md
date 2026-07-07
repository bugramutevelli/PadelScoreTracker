# PadelScoreTracker Project Memory

Bu dosya, projede çalışacak insanlar ve Codex oturumları için kalıcı teknik bağlamdır. Kod veya ürün davranışı değiştiğinde bu belge de güncellenmelidir.

## Ürün özeti

PadelScoreTracker, iPhone'dan maç kurup hem iPhone hem Apple Watch üzerinden canlı skor tutulmasını sağlayan SwiftUI uygulamasıdır. Watch uygulaması aynı zamanda HealthKit üzerinden tenis türünde antrenman başlatır; süre, aktif kalori, nabız, adım ve mesafeyi toplar.

Desteklenen puanlama kuralları:

- Klasik avantaj
- FIP 2026 Star Point
- Golden Point

Desteklenen maç formatları:

- Üç set üzerinden
- Tek set
- Dört oyunluk mini setler
- Tie-break olmayan avantaj final seti
- Yedi puanlık match tie-break
- On puanlık super tie-break

## Kaynak yapısı

- `Shared/Models/MatchModels.swift`: Takım, oyuncu, set, snapshot, antrenman metriği ve tüm maç durumu.
- `Shared/Engine/PadelScoringEngine.swift`: Saf skor geçişleri, oyun/set/maç tamamlama, tie-break ve undo.
- `Shared/Services/MatchStore.swift`: UI'nın ana durumu, yerel JSON saklama, arşiv ve cihazlar arası yayın.
- `Shared/Services/WatchSessionCoordinator.swift`: `WCSession` application context ve canlı mesaj köprüsü.
- `Shared/Services/WorkoutManager.swift`: Yalnızca watchOS'ta derlenen HealthKit workout yönetimi.
- `iOS/`: Maç kurulumu, canlı skor ve geçmiş SwiftUI ekranları.
- `Watch/`: Watch skor ve antrenman ekranları.
- `Tests/PadelScoringEngineTests.swift`: Temel skor kuralları ve format regresyon testleri.
- `project.yml`: XcodeGen için tek proje kaynağı. Üretilen `.xcodeproj` elle kalıcı olarak düzenlenmemeli.

## Temel mimari ve veri akışı

Her iki platform kendi `MatchStore` örneğini çalıştırır. Aktif maç tek bir `PadelMatch` değeridir.

1. iPhone `HomeView`, oyuncular ve maç ayarlarıyla `MatchStore.start` çağırır.
2. Store aktif maçı `active-match.json` dosyasına yazar ve WatchConnectivity ile yayınlar.
3. iPhone veya Watch üzerindeki puan dokunuşu `PadelScoringEngine.awardPoint` çağırır.
4. Motor önce `ScoreSnapshot` kaydeder; bu snapshot undo için kullanılır.
5. Güncel maç `updateApplicationContext` ile kalıcı son durum, `sendMessage` ile erişilebiliyorsa anlık mesaj olarak gönderilir.
6. Karşı cihaz maçı decode eder, kendi store'una uygular, diske yazar ve tekrar yayınlar.
7. Maç tamamlanınca veya erken bitirilince sonuç `matches.json` arşivine eklenir.

Senkronizasyon şu anda sürüm, sıra numarası veya conflict resolution içermez. İki cihazda çok hızlı eşzamanlı puan verilmesi last-write-wins davranışı oluşturabilir.

## Skor motoru değişmezleri

- Maç bittikten sonra yeni puan kabul edilmez.
- Her puandan önce snapshot alınır.
- Normal oyundan sonra puanlar sıfırlanır ve servis indeksi bir ilerler.
- Servis sırası `[home.first, away.first, home.second, away.second]` dizisidir.
- Standart tie-break 7 puan ve en az 2 farkla biter.
- Match/super tie-break yalnızca ilk iki set 1-1 olduğunda devreye girer.
- Avantaj final setinin üçüncü setinde 6-6 tie-break başlatılmaz.
- Maç kazananı `completedSets` üzerinden hesaplanan set sayılarına göre belirlenir.
- Undo `endedAt` değerini yalnızca geri dönülen durumun kazananı yoksa temizler.

## Kalıcılık

Dosyalar uygulamanın Application Support altındaki `RalliPadel` klasöründedir:

- `matches.json`: Tamamlanmış maçlar.
- `active-match.json`: Devam eden maç.

Model değişikliklerinde `Codable` geriye uyumluluğu düşünülmelidir. Zorunlu yeni alan eklemek eski kayıtların decode edilmesini bozabilir; yeni alanlar varsayılanlı veya özel decoder ile eklenmelidir.

## HealthKit

HealthKit yalnızca Watch hedefinde derlenir. Antrenman `.tennis` aktivitesi olarak kaydedilir.

Okunan türler:

- Workout
- Aktif enerji
- Adım
- Yürüme/koşma mesafesi
- Nabız

Yazılan türler:

- Workout
- Aktif enerji
- Yürüme/koşma mesafesi

Gerekli yapılandırma:

- `com.apple.developer.healthkit`
- `com.apple.developer.healthkit.background-delivery`
- Watch `WKBackgroundModes`: `workout-processing`
- Sağlık kullanım açıklamaları

Clinical Health Records kullanılmadığından `com.apple.developer.healthkit.access = health-records` eklenmemelidir.

## Build ve test

Gereksinimler:

- Xcode 16 veya üzeri
- XcodeGen
- iOS 17+
- watchOS 10+

Proje üretimi:

```sh
xcodegen generate
```

Simülatör build'i:

```sh
xcodebuild -project PadelScoreTracker.xcodeproj \
  -scheme PadelScoreTracker \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Test:

```sh
xcodebuild -project PadelScoreTracker.xcodeproj \
  -scheme PadelScoreTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Teknik ürün/modül adı `PadelScoreTracker`, kullanıcıya gösterilen ad `Padel Score Tracker` olmalıdır. Test hedefinin `@testable import PadelScoreTracker` satırı buna bağlıdır.

Bundle kimlikleri:

- iPhone: `com.rallipadel.ios`
- Watch: `com.rallipadel.ios.watchkitapp`
- Tests: `com.rallipadel.tests`
- Watch companion değeri: `com.rallipadel.ios`

iPhone ve Watch hedefleri aynı Apple Developer Team ile imzalanmalıdır.

## Fiziksel Watch kurulumu

İmzalı cihaz build'i başarılı olsa bile Apple Watch, Xcode Device Hub'da görünmeden geliştirme sürümü saate kurulamaz. İlk eşleştirmede Watch üzerindeki Geliştirici Modu seçeneği Device Hub eşleştirme süreci başlayana kadar gizli kalabilir.

Kontrol sırası:

1. iPhone'u kabloyla Mac'e bağla ve güveni onayla.
2. iPhone, Watch ve Mac'te Bluetooth/Wi-Fi açık olsun.
3. Watch kilidi açık ve iPhone'a bağlı olsun.
4. Xcode Device Hub'da iPhone'u geliştirici cihazı olarak kur.
5. Watch görünmüyorsa iPhone Geliştirici Modu'nu kapat/aç ve iPhone ile Watch'u yeniden başlat.
6. Watch görününce saatte Geliştirici Modu'nu aç.
7. `PadelScoreTrackerWatch` şemasını fiziksel Watch hedefiyle çalıştır.

Watch uygulamasındaki genel “This application cannot be installed right now” mesajında önce aynı Team, companion bundle ID, HealthKit provisioning ve Xcode'un Watch'ı cihaz olarak görüp görmediği kontrol edilmelidir.

## Bilinen teknik riskler ve sonraki işler

- WatchConnectivity döngüleri aynı durumu iki cihaz arasında tekrar yayınlayabilir; revision/origin alanı eklenmeli.
- Senkronizasyon çatışmalarına karşı monoton revision veya olay günlüğü yok.
- JSON hataları sessizce yutuluyor; kullanıcıya hata ve telemetry katmanı yok.
- Workout adım sorgusu her saniye çalışıyor; enerji tüketimi için daha seyrek sorgu veya observer yaklaşımı değerlendirilmeli.
- `finishEarly` kazanan belirlemeden maçı arşivler; geçmiş UI'si erken biten maçı 0-0 set olarak gösterebilir.
- Workout metrikleri yalnızca yaklaşık her 15 saniyede store'a aktarılıyor; ani kapanmada son ölçümler kaybolabilir.
- HealthKit, WatchConnectivity, disk hataları ve cihazlar arası yarışlar için entegrasyon testleri yok.
- Testler servis rotasyonunu tie-break boyunca, uzun avantaj oyunlarını ve persistence migration senaryolarını daha geniş kapsamalı.
- iCloud/SwiftData, oyuncu profilleri, Americano, StoreKit ve paylaşım görseli README yol haritasındadır.
