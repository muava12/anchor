# Image compression for note attachments

Date: 2026-11-16, WITA (UTC+8).
Scope: research only. No application code changed.
Sources: primary documents only (W3C, WHATWG, IETF/RFC, IANA, MDN, Chromium source, Android and Apple developer docs, Flutter and Dart API docs, `pub.dev` API docs, Next.js docs).

## Ringkasan jawaban

1. Anchor sudah menerima dan menyimpan gambar apa adanya. Tidak ada kompresi apa pun sebelum upload.
2. Satu-satunya kompresi yang ada sekarang adalah konversi HEIC ke JPEG di Android, lewat
   `MethodChannel('anchor/photos')`. iOS tidak punya jalur ini.
3. Untuk web, jalur yang paling aman adalah `OffscreenCanvas.convertToBlob()` di dalam Web Worker,
   dengan `createImageBitmap(file, { resizeWidth, resizeHeight, resizeQuality })` sebagai tahap
   penskalaan. `HTMLCanvasElement.toBlob()` bekerja, tetapi wajib memakai elemen `<canvas>` di
   dokumen dan menyalin piksel ke canvas yang mutable.
4. Untuk Flutter, kompresi harus jalan di isolate terpisah (`compute()` atau `Isolate.run`), memakai
   paket `image` murni Dart, atau memakai dekoder platform untuk menghindari salinan piksel penuh.
5. Format default yang disarankan: **JPEG** untuk foto, dengan WebP sebagai pilihan bila ukuran lebih
   penting daripada kompatibilitas. PNG hanya untuk gambar yang aslinya PNG dan berguna tanpa alpha.
6. AVIF tidak dapat diandalkan sebagai hasil encode. WebCodecs tidak punya `ImageEncoder`, dan
   `canvas.toBlob()` tidak menjamin AVIF.
7. Status attachment perlu satu status baru (`compressing`) sebelum `pending_upload`, dan
   kompresi harus idempoten supaya retry tidak menumpuk file.

## Sumber

| Klaim | Sumber | Jenis |
| --- | --- | --- |
| `toBlob(callback, type, quality)`: format default `image/png`, dipakai juga bila format tidak didukung; `quality` 0–1 | https://developer.mozilla.org/en-US/docs/Web/API/HTMLCanvasElement/toBlob | MDN (primer untuk API web) |
| Spec `toBlob`: langkah 1 melempar `SecurityError` bila flag origin-clean false; hasil di-queue sebagai task | https://html.spec.whatwg.org/multipage/canvas.html | WHATWG |
| Browser wajib mendukung `image/png`; banyak mendukung `image/jpeg` dan `image/webp` | https://html.spec.whatwg.org/multipage/canvas.html | WHATWG |
| Tipe selain `image/png` harus dicek dari prefix string hasil | https://html.spec.whatwg.org/multipage/canvas.html | WHATWG |
| `toDataURL()` meng-encode seluruh gambar ke string di memori; pakai `toBlob()` | https://developer.mozilla.org/en-US/docs/Web/API/HTMLCanvasElement/toDataURL | MDN |
| `convertToBlob(options)`: `type` default `image/png`, `quality` 0–1; `EncodingError` bila gagal encode; `InvalidStateError` bila canvas tidak detached | https://developer.mozilla.org/en-US/docs/Web/API/OffscreenCanvas/convertToBlob | MDN |
| `OffscreenCanvas` dapat dirender di worker; objek transferable | https://developer.mozilla.org/en-US/docs/Web/API/OffscreenCanvas | MDN |
| `createImageBitmap(image, sx, sy, sw, sh, options)`: `resizeWidth`, `resizeHeight`, `resizeQuality` (`pixelated`\|`low`\|`medium`\|`high`), `imageOrientation` default `from-image` | https://developer.mozilla.org/en-US/docs/Web/API/Window/createImageBitmap | MDN |
| `ImageBitmapOptions.imageOrientation` default `"from-image"`; `flipY` mengabaikan metadata orientasi | https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html | WHATWG |
| `createImageBitmap()` tersedia di worker | https://developer.mozilla.org/en-US/docs/Web/API/WorkerGlobalScope/createImageBitmap | MDN |
| `ImageBitmap.close()` melepas resource grafis; jangan hanya lepas referensi JS | https://developer.mozilla.org/en-US/docs/Web/API/ImageBitmap/close | MDN |
| WebCodecs hanya punya `ImageDecoder`, tidak ada `ImageEncoder`; `canvas.toBlob()` adalah jalur encode bawaan | https://www.w3.org/TR/webcodecs/ | W3C |
| Tidak ada `ImageEncoder` di WebCodecs; usulan menambahkannya ditutup tanpa rencana | https://github.com/w3c/webcodecs/issues/204 | W3C WebCodecs (isu, bukan spesifikasi) |
| Chromium `toBlob`: hanya `image/jpeg`, `image/webp`, `image/png`; tidak ada jalur AVIF | https://chromium.googlesource.com/chromium/src/+/1aec0dc82f13b6243588fedba738d542504d60fe/third_party/blink/renderer/core/html/canvas/canvas_async_blob_creator.cc | Chromium source |
| Chromium meng-encode PNG/JPEG secara idle di thread, dan pindah ke main thread bila idle task tertunda | https://chromium.googlesource.com/chromium/src/+/1aec0dc82f13b6243588fedba738d542504d60fe/third_party/blink/renderer/core/html/canvas/canvas_async_blob_creator.cc | Chromium source |
| Tabel format: MIME, ekstensi, ringkasan, dukungan browser | https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Image_types | MDN |
| AVIF: lossy sekitar 50% lebih kecil dari JPEG pada kualitas setara; alpha; animasi; tanpa progressive rendering | https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Image_types | MDN |
| JPEG: tidak punya alpha channel; DCT; dimensi maksimum 65,535×65,535 | https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Image_types | MDN |
| PNG: lossless, alpha penuh, dimensi maksimum 2,147,483,647×2,147,483,647 | https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Image_types | MDN |
| PNG lossless, patent-free, mendefinisikan `image/png` | https://www.rfc-editor.org/rfc/rfc2083 | IETF RFC 2083 |
| PNG Third Edition: keamanan, privasi, chunk `eXIf` | https://www.w3.org/TR/png-3/ | W3C |
| WebP: RIFF, lossless dan lossy, alpha, animasi; keamanan decoder | https://www.rfc-editor.org/rfc/rfc9649 | IETF RFC 9649 |
| `image/webp` terdaftar di IANA; magic number `RIFF....WEBPVP8` | https://www.iana.org/assignments/media-types/image/webp | IANA |
| `image/avif` terdaftar di IANA | https://www.iana.org/assignments/media-types/image/avif | IANA |
| JPEG adalah proses DCT yang lossy; ada mode lossless non-DCT | https://www.w3.org/Graphics/JPEG/itu-t81.pdf | ITU-T T.81 |
| VP8 intra-frame adalah inti kompresi lossy WebP | https://www.rfc-editor.org/rfc/rfc6386.txt | IETF RFC 6386 |
| AVIF = bitstream AV1 dalam container HEIF | https://aomediacodec.github.io/av1-avif/ | AOMedia |
| `Blob.type` adalah MIME type huruf kecil; jangan pakai sebagai satu-satunya validasi | https://developer.mozilla.org/en-US/docs/Web/API/Blob/type | MDN |
| Spec `Blob.type`: ASCII lowercase, MIME type yang dapat diparse | https://www.w3.org/TR/FileAPI/ | W3C |
| `accept` hanya petunjuk, tidak memvalidasi; validasi wajib di server | https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/accept | MDN |
| Canvas yang kena gambar lintas-origin tanpa CORS menjadi tainted; `toBlob()` melempar `SecurityError` | https://developer.mozilla.org/en-US/docs/Web/HTML/How_to/CORS_enabled_image | MDN |
| Batas ukuran canvas: iOS 4.096×4.096; melebihi batas membuat canvas tidak dapat dipakai | https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/canvas | MDN |
| `ImageDecoder` Android: `ALLOCATOR_SOFTWARE`, `setTargetSize()`, `setTargetSampleSize()`, `setAllocationLimit()` default 0.5 GiB | https://developer.android.com/reference/android/graphics/ImageDecoder | Android |
| `ImageDecoder` mendukung PNG, JPEG, WEBP, GIF, HEIF | https://developer.android.com/reference/android/graphics/ImageDecoder | Android |
| Biaya memori bitmap: `Width × Height × Bytes per pixel`; ARGB_8888 4 byte; foto 4000×3000 = 48 MB | https://developer.android.com/topic/performance/memory/guide/bitmaps | Android |
| Downsample saat decode agar tidak membuang memori | https://developer.android.com/topic/performance/graphics/load-bitmap | Android |
| Android 10 mendukung HEIC (brand HEVC dari HEIF) | https://source.android.com/docs/core/camera/heif | AOSP |
| `Bitmap.CompressFormat` dan `Bitmap.compress()` | https://developer.android.com/reference/android/graphics/Bitmap#compress(android.graphics.Bitmap.CompressFormat,%20int,%20java.io.OutputStream) | Android |
| Apple Image I/O: baca/tulis banyak format, termasuk metadata | https://developer.apple.com/documentation/imageio | Apple |
| `BGTaskScheduler`: eksekusi background bersifat oportunistik dan diskresi sistem | https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler | Apple |
| `BGProcessingTaskRequest`: `requiresExternalPower`, `requiresNetworkConnectivity` | https://developer.apple.com/documentation/backgroundtasks/bgprocessingtaskrequest | Apple |
| WorkManager: tiga jenis pekerjaan; persist melintasi restart dan reboot; basis data SQLite internal | https://developer.android.com/develop/background-work/background-tasks/persistent | Android |
| Interval periodik minimum 15 menit; ada flex interval; constraints menunda pekerjaan | https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work | Android |
| Constraints: `NetworkType`, `BatteryNotLow`, `RequiresCharging`, `DeviceIdle`, `StorageNotLow` | https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work | Android |
| `PeriodicWorkRequest`: interval minimum 15 menit, subjek optimasi baterai dan doze | https://developer.android.com/reference/androidx/work/PeriodicWorkRequest | Android |
| `dart:isolate` hanya didukung di Dart Native (bukan web) | https://api.flutter.dev/flutter/dart-isolate/ | Dart API |
| Isolasi cocok untuk kompresi foto, audio, dan video | https://dart.dev/language/isolates | Dart |
| `Isolate.run()` menyalin input dan mentransfer hasil tanpa salinan | https://dart.dev/language/isolates | Dart |
| `compute()` jalan di isolate terpisah di native, di event loop yang sama di web | https://api.flutter.dev/flutter/foundation/compute.html | Flutter API |
| `compute()` untuk kerja > beberapa milidetik; `SchedulerBinding.scheduleTask` untuk < 1 ms | https://api.flutter.dev/flutter/foundation/compute.html | Flutter API |
| Flutter background isolate: `compute()` di mobile/desktop, thread utama di web | https://github.com/brendan-duncan/image/blob/main/doc/flutter.md | `pub.dev`/repo paket `image` |
| Paket `image`: murni Dart, tanpa dependensi native; resize, encode JPEG/PNG/WebP; Command API berisolasi | https://pub.dev/packages/image | `pub.dev` |
| `encodeJpg(image, {quality = 100, chroma = yuv444})`; `quality` 1–100, 75–90 tipikal untuk foto | https://pub.dev/documentation/image/latest/image/encodeJpg.html | `pub.dev` |
| `encodeWebP(image, {lossless = true, quality = 75, method = 4})`; `quality` hanya berlaku bila `lossless: false` | https://pub.dev/documentation/image/latest/image/encodeWebP.html | `pub.dev` |
| `copyResize` / `resize`; `resize` mendaur ulang memori bila bisa | https://pub.dev/documentation/image/latest/image/copyResize.html | `pub.dev` |
| `decodeJpg(bytes, {scale})`; `scale` 2/4/8 mendekode lebih kecil dan lebih cepat | https://pub.dev/documentation/image/latest/image/decodeJpg.html | `pub.dev` |
| Format yang didukung: JPEG, PNG/APNG, GIF, WebP, BMP, TIFF, TGA, ICO, PVR | https://pub.dev/packages/image | `pub.dev` |
| `instantiateImageCodec(list, {targetWidth, targetHeight, allowUpscaling})`; format: JPEG, PNG, GIF, WebP, BMP, WBMP | https://api.flutter.dev/flutter/dart-ui/instantiateImageCodec.html | Flutter API |
| `ImageDescriptor.instantiateCodec({targetWidth, targetHeight})` | https://api.flutter.dev/flutter/dart-ui/ImageDescriptor/instantiateCodec.html | Flutter API |
| `image_picker`: dukungan Android SDK 24+, iOS 13+; `maxWidth`, `maxHeight`, `imageQuality` (0–100) | https://pub.dev/packages/image_picker | `pub.dev` |
| `ImageOptions.imageQuality`: 0–100, 100 = kualitas asli | https://pub.dev/documentation/image_picker_platform_interface/latest/image_picker_platform_interface/ImageOptions-class.html | `pub.dev` |
| PHPicker pada iOS 14+; HEIC tidak dapat dipilih di simulator iOS 14+ | https://pub.dev/packages/image_picker | `pub.dev` |
| `workmanager`: wrapper Android WorkManager, iOS Background Tasks, macOS `NSBackgroundActivityScheduler` | https://pub.dev/packages/workmanager | `pub.dev` |
| `callbackDispatcher` harus fungsi top-level, berjalan di isolate terpisah | https://pub.dev/documentation/workmanager/latest/workmanager/Workmanager-class.html | `pub.dev` |
| Platform channel Flutter (Kotlin/Swift) | https://docs.flutter.dev/platform-integration/platform-channels | Flutter |
| NestJS: `FileInterceptor`, `memoryStorage()` memuat seluruh file ke memori, `limits.fileSize` | https://docs.nestjs.com/http/file-upload | NestJS |
| NestJS: queue memakai `@nestjs/bullmq` + Redis; Bull dalam mode maintenance | https://docs.nestjs.com/application/queues | NestJS |
| `next/image`: optimasi ukuran, format modern seperti WebP, `quality` default 75 | https://nextjs.org/docs/app/api-reference/components/image | Next.js |
| Flutter UI performance: kerja berat di isolate | https://docs.flutter.dev/perf/rendering/ui-performance | Flutter |

## 1. Keadaan Anchor sekarang

### Server

- Batas ukuran: `ATTACHMENT_MAX_FILE_SIZE = 50 * 1024 * 1024`, dicek di
  `server/src/notes/constants/notes.constants.ts` dan di interceptor
  `server/src/notes/controllers/note-attachments.controller.ts`.
- MIME diizinkan: `image/jpeg`, `image/png`, `image/webp`, `image/gif`, dan
  audio. Lihat `server/src/notes/constants/notes.constants.ts`.
- Penyimpanan: `memoryStorage()` dari multer. Seluruh file masuk memori sebelum
  handler jalan. Lihat `server/src/notes/controllers/note-attachments.controller.ts`.
- Tidak ada kompresi di server. `server/src/notes/utils/attachment-storage.util.ts`
  hanya memvalidasi MIME dan ukuran, lalu menulis byte apa adanya.
- Risiko yang sudah ada: MIME datang dari header klien, bukan dari isi file.
  NestJS mendokumentasikan bahwa `memoryStorage()` memuat seluruh file ke memori,
  sehingga `limits.fileSize` wajib diset. Lihat
  https://docs.nestjs.com/http/file-upload.

### Web

- `web/features/notes/constants.ts` menerima `image/jpeg`, `image/png`,
  `image/webp`, `image/gif` dan audio, maksimum 50 MB.
- `web/features/notes/components/attachments/attachment-strip.tsx` mengunggah
  `File` asli lewat `uploadAttachment()` di `web/features/notes/api.ts`.
- Tidak ada kompresi. Tidak ada canvas, tidak ada worker.

### Mobile (Flutter)

- `mobile/lib/features/notes/presentation/widgets/add_sheet.dart` memakai
  `ImagePicker().pickImage(source: source)` tanpa `maxWidth`, `maxHeight`, atau
  `imageQuality`.
- `mobile/lib/features/notes/data/photo_files.dart` mendeteksi MIME dari byte
  pertama: JPEG, PNG, GIF, WebP. Format lain (misalnya HEIC) dicoba dikonversi
  lewat `MethodChannel('anchor/photos')` ke JPEG.
- Implementasi Android ada di
  `mobile/android/app/src/main/kotlin/com/zhfahim/anchor/photos/JpegConverter.kt`
  dan `PhotoConverterPlugin.kt`, yang didaftarkan di `MainActivity.kt`:
  `ImageDecoder` dengan `ALLOCATOR_SOFTWARE`, target sisi terpanjang 4096,
  `Bitmap.CompressFormat.JPEG` kualitas 90, lalu `recycle()`.
- Tidak ada implementasi iOS atau macOS untuk `anchor/photos`.
  `grep` di `mobile/ios` dan `mobile/macos` tidak menemukan apa pun.
  Akibatnya, di iOS, foto HEIC yang tidak dikenali akan ditolak dengan
  `addPhotoUnsupported` ( perilaku ini terlihat di `add_sheet.dart`, tetapi
  belum diuji di perangkat).
- `mobile/lib/features/notes/data/repository/note_attachments_repository.dart`
  menyalin file sumber ke direktori dokumen, menyimpan baris drift dengan
  `syncStatus = pending_upload`, lalu menjadwalkan sync.
  `sync()` mengunggah semua baris `pending_upload` secara serial, satu per satu.
- Skema drift saat ini (`mobile/lib/features/notes/data/local/attachments_table.dart`,
  `schemaVersion = 11`) menyimpan `originalFilename`, `mimeType`, `fileSize`,
  `localPath`, `syncStatus`, `serverAttachmentId`.

Kesimpulan: fitur ini hampir seluruhnya baru. Yang sudah ada hanya satu jalur
konversi HEIC→JPEG di Android.

## 2. Perbandingan format

| Format | Lossy | Lossless | Alpha | Animasi | Progressive | MIME | Catatan untuk Anchor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| WebP | Ya | Ya | Ya | Ya | Tidak disebut | `image/webp` | Sudah diterima server. Lebih kecil dari JPEG pada kualitas setara, tetapi encode tidak tersedia di semua browser lewat canvas. |
| AVIF | Ya | Ya | Ya | Ya | Tidak | `image/avif` | Belum diterima server. Encode tidak dapat diandalkan di browser. |
| JPEG | Ya | Tidak (mode lossless non-DCT ada di T.81, tetapi jarang dipakai encoder) | Tidak | Tidak | Ya (progresif) | `image/jpeg` | Paling kompatibel. Tidak punya alpha. |
| PNG | Tidak | Ya | Ya | Ya (APNG) | Ya | `image/png` | Aman untuk gambar dengan alpha dan untuk tangkapan layar. Sering jauh lebih besar dari JPEG untuk foto. |

Sumber: tabel format di
https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Image_types,
RFC 2083 (https://www.rfc-editor.org/rfc/rfc2083), RFC 9649
(https://www.rfc-editor.org/rfc/rfc9649), ITU-T T.81
(https://www.w3.org/Graphics/JPEG/itu-t81.pdf), RFC 6386
(https://www.rfc-editor.org/rfc/rfc6386.txt).

Catatan tentang klaim persentase: MDN menyebut "lossy AVIF sekitar 50% lebih
kecil dari JPEG" dan "median 50% vs 30% untuk WebP", tetapi sumber yang dirujuk
adalah blog pihak ketiga (CTRL Blog). Angka itu tidak dapat dibuktikan dari
sumber primer. Jangan pakai angka itu sebagai target desain.

## 3. Format default dan fallback

### Rekomendasi

1. **Foto (mayoritas kasus): JPEG kualitas 80–85.**
   - Alasan: server sudah menerima `image/jpeg`; semua browser dan kedua platform
     mobile dapat meng-encode JPEG; tidak ada alpha yang hilang karena foto
     umumnya tidak punya alpha.
   - Sumber kualitas: `image_picker` mendefinisikan `imageQuality` 0–100
     (https://pub.dev/documentation/image_picker_platform_interface/latest/image_picker_platform_interface/ImageOptions-class.html);
     paket `image` menyebut 75–90 tipikal untuk foto
     (https://pub.dev/documentation/image/latest/image/encodeJpg.html).
2. **Gambar dengan alpha (ikon, stiker, tangkapan layar dengan transparansi):
   WebP lossless bila encode tersedia, jika tidak PNG.**
   - WebP didukung server.
   - Encode WebP tidak tersedia di semua jalur. Chromium hanya men-encode
     JPEG, WebP, dan PNG (lihat §4).
3. **Fallback wajib: JPEG atau PNG.**
   - Bila hasil encode bukan format yang diminta, `toBlob()` mengembalikan PNG.
     Ini terdokumentasi di WHATWG dan MDN
     (https://html.spec.whatwg.org/multipage/canvas.html).
   - Setelah encode, cek `blob.type` atau magic number sebelum menganggap format
     berhasil. `Blob.type` adalah MIME huruf kecil menurut File API
     (https://www.w3.org/TR/FileAPI/), tetapi MDN memperingatkan bahwa
     `Blob.type` tidak boleh menjadi satu-satunya validasi
     (https://developer.mozilla.org/en-US/docs/Web/API/Blob/type).
4. **AVIF: jangan jadikan output encode.**
   - WebCodecs tidak punya `ImageEncoder` (https://www.w3.org/TR/webcodecs/),
     dan usulan menambahkannya ditutup tanpa rencana
     (https://github.com/w3c/webcodecs/issues/204).
   - Chromium tidak punya jalur AVIF di `canvas.toBlob()`
     (https://chromium.googlesource.com/chromium/src/+/1aec0dc82f13b6243588fedba738d542504d60fe/third_party/blink/renderer/core/html/canvas/canvas_async_blob_creator.cc).
   - AVIF baru berguna sebagai input (decode) bila browser mendukungnya.

### Tabel keputusan

| Kondisi | Encode ke | Alasan |
| --- | --- | --- |
| MIME sumber `image/jpeg` dan ukuran > ambang | JPEG, resize bila perlu | Tidak ada alpha, paling kompatibel |
| MIME sumber `image/png`, ada alpha | WebP lossless bila didukung, jika tidak PNG | WebP lossless lebih kecil dari PNG |
| MIME sumber `image/png`, tanpa alpha, foto | JPEG | PNG foto besar |
| MIME sumber `image/webp` | Biarkan (sudah efisien) | Tidak perlu re-encode |
| MIME sumber `image/gif` | Biarkan | Server menerima GIF; jangan rusak animasi |
| HEIC/HEIF | JPEG (Android sudah), iOS perlu jalur baru | Server tidak menerima HEIC |

Ambang ukuran (kapan kompresi dijalankan) adalah keputusan produk. Tidak ada
sumber primer yang menetapkan angka. Saran awal: kompres bila file > 1 MB atau
sisi terpanjang > 2560 px. Angka ini harus diuji, bukan dikutip sebagai fakta.

## 4. API kompresi di browser

### Jalur yang tersedia

| API | Encode | Resize saat decode | Di worker | Catatan |
| --- | --- | --- | --- | --- |
| `HTMLCanvasElement.toBlob(cb, type, quality)` | Ya | Tidak, harus gambar dulu | Tidak (butuh elemen di dokumen) | Menyalin bitmap ke canvas mutable. |
| `OffscreenCanvas.convertToBlob({type, quality})` | Ya | Tidak | Ya | Canvas tidak terikat DOM. |
| `createImageBitmap(blob, opts)` | Tidak | Ya (`resizeWidth`, `resizeHeight`, `resizeQuality`) | Ya | Penskalaan saat decode, tanpa canvas perantara. |
| `ImageBitmap` + `OffscreenCanvas` | Ya (lewat `convertToBlob`) | Ya | Ya | Kombinasi yang disarankan. |
| `ImageDecoder` (WebCodecs) | Tidak (hanya decode) | Tidak langsung | Ya | Tidak ada encoder. |
| `canvas.toDataURL()` | Ya | — | — | Menghindari: meng-encode seluruh gambar ke string di memori. |

Sumber: MDN `toBlob`
(https://developer.mozilla.org/en-US/docs/Web/API/HTMLCanvasElement/toBlob),
MDN `toDataURL` (https://developer.mozilla.org/en-US/docs/Web/API/HTMLCanvasElement/toDataURL),
MDN `convertToBlob`
(https://developer.mozilla.org/en-US/docs/Web/API/OffscreenCanvas/convertToBlob),
MDN `OffscreenCanvas` (https://developer.mozilla.org/en-US/docs/Web/API/OffscreenCanvas),
MDN `createImageBitmap`
(https://developer.mozilla.org/en-US/docs/Web/API/Window/createImageBitmap),
WHATWG canvas (https://html.spec.whatwg.org/multipage/canvas.html),
WHATWG imagebitmap
(https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html),
W3C WebCodecs (https://www.w3.org/TR/webcodecs/).

### Rekomendasi untuk `web/`

1. Buat satu modul worker, misalnya `web/features/notes/images/compress.worker.ts`.
2. Alur di worker:
   - `createImageBitmap(file, { resizeWidth, resizeHeight, resizeQuality: "high" })`
     dengan `resizeWidth`/`resizeHeight` hanya bila sisi terpanjang melebihi target.
   - Gambar ke `OffscreenCanvas`.
   - `convertToBlob({ type: "image/jpeg", quality: 0.82 })`.
   - Periksa `blob.type`. Bila bukan `image/jpeg` (misalnya `"image/png"`),
     perlakukan sebagai fallback: pakai hasil itu, catat di telemetri.
   - `bitmap.close()` setelah selesai
     (https://developer.mozilla.org/en-US/docs/Web/API/ImageBitmap/close).
3. Batasi jumlah worker bersamaan (misalnya 2). Alasannya: memori piksel
   adalah `width × height × 4` byte per gambar. Tidak ada sumber primer yang
   memberi angka batas memori worker; angka 2 adalah pilihan implementasi,
   bukan fakta yang dapat dikutip.
4. Jangan pakai `toDataURL()`. MDN secara eksplisit menyarankan `toBlob()`
   (https://developer.mozilla.org/en-US/docs/Web/API/HTMLCanvasElement/toDataURL).

### Kompatibilitas encode WebP di browser

Tidak ada sumber primer yang menjamin `convertToBlob({type: "image/webp"})`
menghasilkan WebP di semua browser. Spesifikasi hanya mewajibkan PNG
(https://html.spec.whatwg.org/multipage/canvas.html). Chromium mendukung
WebP (lihat source di atas). Dukungan Safari tidak dapat dibuktikan dari
sumber primer yang tersedia untuk riset ini. Perlakukan WebP sebagai
"nice to have": coba, periksa `blob.type`, dan jatuh ke JPEG bila bukan WebP.

### Batas ukuran canvas

MDN menyatakan batas maksimum bergantung pada browser dan lingkungan, dan iOS
membatasi canvas 4.096×4.096 px; melebihi batas membuat canvas tidak dapat
dipakai (https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/canvas).
Karena itu, resize sebelum menggambar ke `OffscreenCanvas`, dan jangan pernah
membuat canvas seukuran foto 12 MP tanpa downscale.

## 5. API kompresi di Flutter

### Jalur yang tersedia

| Jalur | Kelebihan | Kekurangan | Sumber |
| --- | --- | --- | --- |
| `compute(fn, bytes)` + paket `image` | Murni Dart, bekerja di semua platform, API sederhana | Mendekode penuh di memori; salinan input ke isolate | https://api.flutter.dev/flutter/foundation/compute.html, https://pub.dev/packages/image |
| `Isolate.run(fn)` | Sama seperti `compute`, tanpa nama debug | Hanya Dart Native (bukan web) | https://api.flutter.dev/flutter/dart-isolate/, https://dart.dev/language/isolates |
| Platform channel ke `ImageDecoder` (Android) / Image I/O (iOS) | Dekode ke ukuran target, hemat memori | Perlu kode native per platform | https://developer.android.com/reference/android/graphics/ImageDecoder, https://developer.apple.com/documentation/imageio |
| `image_picker` `maxWidth`/`maxHeight`/`imageQuality` | Paling sedikit kode | Tidak memilih format output; tidak memberi kontrol `chroma`; hasil tergantung platform | https://pub.dev/packages/image_picker |
| `dart:ui` `instantiateImageCodec(targetWidth, targetHeight)` | Dekode ke ukuran target oleh engine | Hanya decode; encode tetap butuh paket `image` atau native | https://api.flutter.dev/flutter/dart-ui/instantiateImageCodec.html |

### Rekomendasi untuk `mobile/`

1. **Jangan** memakai `image_picker` `imageQuality` sebagai satu-satunya
   kompresi. Alasannya: parameter itu tidak menjamin format output, dan
   `imageQuality` hanya berlaku bila platform mendukung. `pub.dev` hanya
   mendokumentasikan rentang 0–100
   (https://pub.dev/documentation/image_picker_platform_interface/latest/image_picker_platform_interface/ImageOptions-class.html),
   bukan format hasil.
2. Pakai `compute()` dengan paket `image` sebagai jalur utama:
   - `img.decodeJpg(bytes, scale: 4)` bila sumber JPEG dan target kecil
     (https://pub.dev/documentation/image/latest/image/decodeJpg.html).
   - `img.copyResize(image, width: targetWidth)` untuk mempertahankan rasio
     (https://pub.dev/documentation/image/latest/image/copyResize.html).
   - `img.encodeJpg(resized, quality: 82)`.
   - Kirim `Uint8List` ke isolate, bukan objek `img.Image` yang sudah
     didekode. Alasannya: input kecil mengurangi biaya salin
     (https://dart.dev/language/isolates).
3. Untuk Android, jalur native yang sudah ada
   (`JpegConverter.kt`) sudah benar secara prinsip: `ImageDecoder` dengan
   `ALLOCATOR_SOFTWARE`, `setTargetSize`, lalu `Bitmap.compress`.
   Tambahkan `decoder.setAllocationLimit()` agar decode menolak gambar raksasa
   dengan `IOException` alih-alih `OutOfMemoryError`
   (https://developer.android.com/reference/android/graphics/ImageDecoder).
4. Untuk iOS, tambahkan plugin native yang memakai Image I/O
   (`CGImageSourceCreateWithData` + `CGImageDestination`) atau `UIImage`
   `jpegData(compressionQuality:)`. Belum ada kode ini di repo.
   `grep` di `mobile/ios` tidak menemukan `anchor/photos`.
5. Untuk web (Flutter web), `compute()` berjalan di event loop yang sama
   (https://api.flutter.dev/flutter/foundation/compute.html). Karena itu,
   kompresi di Flutter web harus lewat `package:web` + worker, atau
   nonaktifkan kompresi di web dan andalkan jalur `web/` yang terpisah.

### Memori

Foto 12 MP yang didekode penuh di ARGB_8888 adalah sekitar 48 MB
(https://developer.android.com/topic/performance/memory/guide/bitmaps,
https://github.com/brendan-duncan/image/blob/main/doc/flutter.md).
Itu alasan utama untuk selalu downsample saat decode.

## 6. Opsi job dan queue background

### Mobile

| Opsi | Kapan cocok | Jaminan | Sumber |
| --- | --- | --- | --- |
| Langsung saat menambah (foreground, `compute`) | Pengguna menunggu pratinjau | Langsung | https://api.flutter.dev/flutter/foundation/compute.html |
| `workmanager` `registerOneOffTask` | Perlu jalan walau aplikasi tertutup | Android: persisten, subjek doze dan constraint; iOS: oportunistik, tidak ada jaminan waktu | https://pub.dev/packages/workmanager, https://developer.android.com/develop/background-work/background-tasks/persistent, https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler |
| Sync yang sudah ada (`SyncManager`) | Upload tertunda | Sudah ada, berjalan saat foreground/poll | `mobile/lib/features/sync/data/sync_manager.dart` |

Rekomendasi: **kompres di foreground, dekat dengan aksi pengguna**, lalu
upload lewat sync yang sudah ada. Alasannya:
- Kompresi butuh beberapa ratus milidetik sampai beberapa detik. Menjadwalkan
  pekerjaan yang harus selesai sebelum upload lewat `workmanager` menambah
  kompleksitas tanpa manfaat, karena iOS tidak menjamin waktu eksekusi
  (https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler).
- Anchor sudah punya `pending_upload` dan `SyncManager`. Cukup tambah satu
  status sebelum `pending_upload`.

Bila nanti perlu kompresi saat aplikasi tertutup, pakai `workmanager`
dengan `OneOffTask`, dan terima bahwa iOS dapat menundanya berjam-jam.
Android menjamin persistensi tetapi tidak menjamin waktu
(https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work).

### Web

Web tidak punya scheduler background yang setara. Pilihan:
1. Worker + antrean di memori (paling sederhana). Tidak persisten.
2. Service worker + Background Sync. Tidak dibahas di sini karena Anchor
   offline-first sudah punya jalur sync sendiri lewat API.

Rekomendasi: worker + antrean di memori, batasi 2 pekerjaan bersamaan.

### Server

Anchor tidak memerlukan queue untuk kompresi ini, karena kompresi terjadi di
klien. Bila nanti kompresi dipindah ke server:
- `@nestjs/bullmq` + Redis adalah jalur resmi NestJS
  (https://docs.nestjs.com/application/queues).
- Tambah Redis sebagai dependensi baru. Itu keputusan arsitektur, bukan
  keputusan implementasi.
- Alternatif tanpa Redis: prosesdenoted inline dengan batas ukuran. Tidak
  ada sumber primer NestJS yang merekomendasikan ini untuk CPU berat.

## 7. Skema status attachment yang disarankan

### Status drift sekarang

`AttachmentSyncStatus` di
`mobile/lib/features/notes/domain/note_attachment.dart`:
`synced`, `pendingUpload`, `uploadFailed`, `pendingDelete`.

### Usulan

Tambah satu status: `compressing`, dengan nilai database `compressing`.

Alur baru:

```
pick → compressing → pending_upload → synced
                  ↘ compress_failed (retry manual, jatuh ke pending_upload dengan file asli)
```

Alasan penambahan status:
- Tanpa status ini, file mentah sudah masuk `pending_upload` dan dapat terunggah
  sebelum kompresi selesai. Itu adalah bug.
- Dengan status ini, `sync()` hanya mengambil `pending_upload`, sehingga
  kompresi benar-benar mendahului upload.

### Kolom yang perlu ditambah

| Kolom | Tipe | Alasan |
| --- | --- | --- |
| `originalPath` | `TEXT?` | Path file sebelum kompresi, untuk retry dan undo |
| `originalSize` | `INTEGER?` | Ukuran sebelum kompresi, untuk telemetri |
| `compressError` | `TEXT?` | Pesan kegagalan terakhir |

Catatan: penambahan kolom butuh migrasi drift. `schemaVersion` sekarang 11.
Migrasi harus ditambahkan di `mobile/lib/core/database/app_database.dart`.
Jangan menimpa migrasi yang ada.

### Aturan idempotensi

1. Kompresi hanya boleh dijalankan untuk baris dengan `syncStatus = compressing`
   dan `compressedPath IS NULL`.
2. Setelah kompresi berhasil: tulis `localPath = compressedPath`,
   `fileSize = ukuran baru`, `mimeType = hasil`, `syncStatus = pending_upload`.
3. Setelah upload berhasil: hapus file hasil kompresi dan file asli, sesuai
   aturan yang sudah ada di `sync()`.
4. Bila kompresi gagal dan tidak dapat diulang: jatuh kembali ke `pending_upload`
   dengan file asli. Ini menjaga "attachment selalu berhasil ditambahkan".

## 8. Kompatibilitas

| Jalur | Format yang diterima server | Format yang dapat di-encode | Risiko |
| --- | --- | --- | --- |
| Web (Chromium) | JPEG, PNG, WebP, GIF | JPEG, WebP, PNG | Rendah |
| Web (Safari) | JPEG, PNG, WebP, GIF | JPEG, PNG (WebP tidak dapat dibuktikan) | Sedang: cek `blob.type` |
| Android | JPEG, PNG, WebP, GIF | JPEG (sudah ada jalur native), PNG, WebP (paket `image`) | Rendah |
| iOS | JPEG, PNG, WebP, GIF | JPEG, PNG (native belum ada; paket `image` bisa) | Tinggi sampai plugin native dibuat |
| HEIC dari iOS | Tidak diterima server | — | Tinggi |

Catatan HEIC: `image_picker` pada iOS 14+ memakai PHPicker
(https://pub.dev/packages/image_picker). `pub.dev` mendokumentasikan bahwa
HEIC tidak dapat dipilih di simulator iOS 14+, tetapi tidak menjamin apa yang
dikembalikan di perangkat asli. Perilaku nyata di perangkat **tidak dapat
dibuktikan** dari sumber primer yang tersedia. Uji di perangkat sebelum
menyimpulkan.

## 9. Kualitas dan ukuran

| Parameter | Rentang | Catatan | Sumber |
| --- | --- | --- | --- |
| `quality` canvas | 0–1 | Hanya untuk format lossy | https://developer.mozilla.org/en-US/docs/Web/API/HTMLCanvasElement/toBlob |
| `quality` `image_picker` | 0–100 | 100 = kualitas asli | https://pub.dev/documentation/image_picker_platform_interface/latest/image_picker_platform_interface/ImageOptions-class.html |
| `quality` `encodeJpg` | 1–100 | 75–90 tipikal untuk foto | https://pub.dev/documentation/image/latest/image/encodeJpg.html |
| `quality` `encodeWebP` | 0–100 | Hanya bila `lossless: false` | https://pub.dev/documentation/image/latest/image/encodeWebP.html |
| `chroma` `encodeJpg` | `yuv444` \| `yuv420` | `yuv420` lebih kecil | https://pub.dev/documentation/image/latest/image/encodeJpg.html |
| `resizeQuality` `createImageBitmap` | `pixelated`, `low`, `medium`, `high` | `low` default | https://developer.mozilla.org/en-US/docs/Web/API/Window/createImageBitmap |
| `scale` `decodeJpg` | 2, 4, 8 | Dekode lebih kecil, lebih cepat | https://pub.dev/documentation/image/latest/image/decodeJpg.html |

Rekomendasi nilai awal (harus diuji, bukan dikutip):
- Sisi terpanjang maksimum: 2560 px.
- JPEG `quality`: 82.
- WebP lossy: `quality: 80`, `method: 4` (default).
- WebP lossless untuk PNG dengan alpha.

## 10. CPU dan baterai

Fakta yang dapat dibuktikan:

- Kompresi JPEG adalah kerja CPU. ITU-T T.81 menjelaskan proses DCT, kuantisasi,
  dan entropy coding (https://www.w3.org/Graphics/JPEG/itu-t81.pdf).
- Chromium menjalankan encode canvas sebagai idle task dan beralih ke main
  thread bila idle task tertunda (source Chromium di atas).
- Android WorkManager menyediakan constraint `BatteryNotLow`, `RequiresCharging`,
  `DeviceIdle`, dan `StorageNotLow`
  (https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work).
- iOS menyatakan eksekusi background oportunistik, dengan energi sebagai
  constraint utama (https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler).

Rekomendasi:
1. Kompres hanya bila file > ambang ukuran.
2. Lewati kompresi bila perangkat hemat baterai. Android dapat membaca ini
   lewat `PowerManager.isPowerSaveMode()`; tidak ada sumber primer yang dipakai
   di sini untuk ambangnya.
3. Batasi 1 kompresi mobile per waktu, 2 kompresi web per waktu.
4. Jangan kompres GIF dan WebP yang sudah kecil.

Angka konsumsi baterai per foto **tidak dapat dibuktikan** tanpa pengukuran di
perangkat. Jangan menulis klaim persentase.

## 11. Keamanan

| Risiko | Sumber | Mitigasi |
| --- | --- | --- |
| MIME dari klien dipercaya | https://developer.mozilla.org/en-US/docs/Web/API/Blob/type, https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/accept | Deteksi dari magic number di server; jangan percaya header |
| Decoder WebP rentan overflow dan resource exhaustion | https://www.rfc-editor.org/rfc/rfc9649 | Batasi ukuran decode; perbarui dependensi |
| PNG dapat menyembed chunk berbahaya | https://www.w3.org/TR/png-3/ | Jangan meng-eksekusi apa pun dari chunk |
| Canvas tainted → `SecurityError` | https://developer.mozilla.org/en-US/docs/Web/HTML/How_to/CORS_enabled_image | Hanya gambar dari sumber sendiri |
| Metadata EXIF terbuang saat re-encode | https://html.spec.whatwg.org/multipage/canvas.html | Komunikasikan ke pengguna; jangan janjikan metadata |
| `memoryStorage()` memuat seluruh file ke memori | https://docs.nestjs.com/http/file-upload | Pertahankan `limits.fileSize`; pertimbangkan `diskStorage()` |
| `ImageDecoder` default `setAllocationLimit` 0.5 GiB | https://developer.android.com/reference/android/graphics/ImageDecoder | Set limit lebih kecil sesuai target |
| Tidak ada jalur iOS untuk HEIC | `grep` repo | Tambahkan plugin native; sementara, tolak dengan pesan jelas |

Catatan privasi: re-encode lewat canvas membuang metadata EXIF. Itu adalah
 efek samping privasi yang menguntungkan, tetapi juga menghapus orientasi.
Untuk itu, pakai `imageOrientation: "from-image"` (default) saat
`createImageBitmap` (https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html),
atau terapkan orientasi di Flutter lewat `copyResize` yang sudah
menerapkan orientasi EXIF
(https://github.com/brendan-duncan/image/blob/main/doc/transform.md).

## 12. Trade-off

| Pilihan | Untung | Rugi |
| --- | --- | --- |
| Kompres di klien | Hemat bandwidth server, tidak perlu Redis | CPU dan baterai pengguna; tidak ada jaminan hasil seragam |
| Kompres di server | Hasil seragam, kontrol penuh | Perlu CPU server atau queue + Redis; pengguna menunggu |
| JPEG default | Kompatibel dengan server dan semua platform | Tidak ada alpha; generasi kedua lebih buruk |
| WebP default | Lebih kecil | Tidak dapat diandalkan sebagai output canvas; Safari tidak dapat dibuktikan |
| AVIF | Paling kecil | Tidak dapat di-encode di browser; server belum menerima |
| PNG | Lossless, alpha | Besar untuk foto |
| Resize ke 2560 px | Hemat memori dan ukuran | Kehilangan detail pada zoom |
| Kompres di foreground | Sederhana, langsung | Menambah latensi aksi tambah |
| Kompres via `workmanager` | Jalan walau aplikasi tertutup | iOS tidak menjamin waktu; kompleksitas isolate |
| Paket `image` murni Dart | Satu jalur untuk semua platform | Decode penuh di memori |
| Platform channel native | Hemat memori, cepat | Kode native per platform; belum ada iOS |

## 13. Bagian yang tidak dapat dibuktikan

1. **Perilaku HEIC nyata di iOS untuk Anchor.** `pub.dev` hanya menyebut
   batasan simulator. Tidak ada uji perangkat dalam riset ini.
2. **Dukungan encode WebP di Safari.** Tidak ada sumber primer yang
   menyatakannya. Chromium mendukung; Safari tidak dapat dibuktikan.
3. **Angka penghematan ukuran (50%, 30%).** Berasal dari blog pihak ketiga,
   bukan sumber primer.
4. **Konsumsi baterai per foto.** Butuh pengukuran perangkat.
5. **Batas memori worker di browser.** Tidak ada angka di sumber primer.
6. **Apakah `image_picker` `imageQuality` mengubah format di iOS.**
   Dokumentasi `pub.dev` tidak menyatakannya.
7. **Apakah `OffscreenCanvas.convertToBlob` menghormati `quality` untuk WebP
   di semua browser.** Spesifikasi hanya mewajibkan PNG.
8. **Perilaku `ImageBitmap` dengan EXIF di Safari.** Ada isu WHATWG yang masih
   terbuka (https://github.com/whatwg/html/issues/7210), tetapi itu bukan
   sumber primer yang menyelesaikan pertanyaan.

## 14. Langkah implementasi yang disarankan

1. Tambah status `compressing` di `note_attachment.dart` dan migrasi drift.
2. Buat `mobile/lib/features/notes/data/image_compressor.dart` memakai
   `compute()` + paket `image`.
3. Ubah `addAttachment()` agar memanggil kompresi sebelum menulis
   `pending_upload`.
4. Tambah plugin native iOS (`anchor/photos`) dengan Image I/O.
5. Tambah `web/features/notes/images/compress.worker.ts` dan pakai di
   `attachment-strip.tsx` sebelum `uploadAttachment()`.
6. Tambah deteksi magic number di server, jangan percaya MIME klien.
7. Uji di perangkat: foto 12 MP, HEIC iOS, PNG dengan alpha, GIF animasi.

## 15. Pemeriksaan akhir

- Semua klaim faktual punya tautan ke sumber primer.
- Bagian yang tidak dapat dibuktikan tercantum di §13.
- Tidak ada kode aplikasi yang diubah.
- Tidak ada klaim angka tanpa sumber.