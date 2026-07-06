# Ralli Padel

Ralli, iPhone ve Apple Watch için özgün bir padel skor takip uygulamasıdır. İlk MVP; klasik/altın puan skoru, tie-break, servis rotasyonu, geri alma, maç geçmişi ve cihazlar arası canlı senkronizasyon içerir.

## Projeyi açma

Bu depo, Xcode proje dosyasını tekrarlanabilir biçimde üretmek için XcodeGen kullanır.

1. macOS üzerinde Xcode 16 veya üzerini kurun.
2. `brew install xcodegen` komutuyla XcodeGen'i kurun.
3. Proje klasöründe `xcodegen generate` çalıştırın.
4. Oluşan `RalliPadel.xcodeproj` dosyasını Xcode ile açın.
5. iPhone hedefi ve Watch hedefi için kendi Apple Developer takımınızı seçin.
6. `RalliPadel` şemasını bir iPhone + eşlenmiş Apple Watch simülatöründe çalıştırın.

## Mimari

- `Shared/Engine`: Saf ve test edilebilir padel skor motoru
- `Shared/Models`: Codable maç durumu ve skor modelleri
- `Shared/Services`: Yerel JSON kayıt ve WatchConnectivity köprüsü
- `iOS`: SwiftUI telefon uygulaması
- `Watch`: SwiftUI saat uygulaması
- `Tests`: Skor, tie-break, altın puan ve geri alma testleri

## Sonraki ürün adımları

- SwiftData + CloudKit ile iCloud geçmiş senkronizasyonu
- Oyuncu profilleri ve detaylı istatistikler
- Americano turnuva modu
- StoreKit 2 Pro paketi
- Paylaşılabilir sonuç görseli
- App Store ikonları, ekran görüntüleri ve gizlilik metni

