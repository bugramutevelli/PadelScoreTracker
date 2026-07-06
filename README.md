# Padel Score Tracker

Padel Score Tracker, iPhone ve Apple Watch için özgün bir padel skor takip uygulamasıdır. İlk MVP; klasik/altın puan skoru, tie-break, servis rotasyonu, geri alma, maç geçmişi ve cihazlar arası canlı senkronizasyon içerir.

## Puanlama modları

- **Klasik avantaj:** 40-40 sonrasında bir takım art arda iki puan alana kadar oyun sürer.
- **Star Point (FIP 2026):** İlk iki avantaj döngüsü sonuçlanmazsa üçüncü deuce'de tek karar puanı oynanır.
- **Golden Point:** İlk 40-40 durumunda tek karar puanı oynanır.

## Maç formatları

- **3 set üzerinden:** İki set kazanan maçı alır; standart sette 6-6'da tie-break oynanır.
- **Tek set:** Bir standart set sonucu maçı belirler.
- **Mini setler:** Setler 4 oyuna oynanır; 4-4'te tie-break yapılır.
- **Avantaj final seti:** Üçüncü sette 6-6'dan sonra tie-break oynanmaz; iki oyun fark oluşana kadar sürer.
- **Match tie-break:** Setler 1-1 olursa üçüncü set yerine 7 puanlık, iki farkla biten tie-break oynanır.
- **Super tie-break:** Setler 1-1 olursa üçüncü set yerine 10 puanlık, iki farkla biten tie-break oynanır.

## Windows arayüz önizlemesi

`Preview/index.html` dosyasını çift tıklayarak etkileşimli iPhone ve Apple Watch arayüzünü tarayıcıda açabilirsiniz. Bu önizleme görsel/etkileşim kontrolü içindir; gerçek SwiftUI uygulaması Xcode üzerinde çalışır.

Apple Watch ekranını büyük ve etkileşimli görmek için `Preview/watch.html` dosyasını açın.

## Projeyi açma

Bu depo, Xcode proje dosyasını tekrarlanabilir biçimde üretmek için XcodeGen kullanır.

1. macOS üzerinde Xcode 16 veya üzerini kurun.
2. `brew install xcodegen` komutuyla XcodeGen'i kurun.
3. Proje klasöründe `xcodegen generate` çalıştırın.
4. Oluşan `PadelScoreTracker.xcodeproj` dosyasını Xcode ile açın.
5. iPhone hedefi ve Watch hedefi için kendi Apple Developer takımınızı seçin.
6. `PadelScoreTracker` şemasını bir iPhone + eşlenmiş Apple Watch simülatöründe çalıştırın.

## Mimari

- `Shared/Engine`: Saf ve test edilebilir padel skor motoru
- `Shared/Models`: Codable maç durumu ve skor modelleri
- `Shared/Services`: Yerel JSON kayıt ve WatchConnectivity köprüsü
- `iOS`: SwiftUI telefon uygulaması
- `Watch`: SwiftUI saat uygulaması
- `Tests`: Skor, tie-break, altın puan ve geri alma testleri

## Apple Sağlık

Watch uygulaması maç başladığında HealthKit izni ister ve antrenmanı Tenis türünde kaydeder. Aktif kalori, antrenman süresi, nabız, adım ve yürüme/koşma mesafesi canlı izlenir; maç özeti iPhone geçmişinde saklanır. İlk gerçek cihaz çalıştırmasında Xcode'da Watch hedefinin Signing & Capabilities bölümünde HealthKit yetkisinin seçili olduğunu doğrulayın.

## Sonraki ürün adımları

- SwiftData + CloudKit ile iCloud geçmiş senkronizasyonu
- Oyuncu profilleri ve detaylı istatistikler
- Americano turnuva modu
- StoreKit 2 Pro paketi
- Paylaşılabilir sonuç görseli
- App Store ikonları, ekran görüntüleri ve gizlilik metni
