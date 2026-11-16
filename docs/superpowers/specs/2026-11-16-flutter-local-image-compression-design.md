# Flutter Local Image Compression Design

## 1. Ringkasan

Anchor Flutter akan mengompresi gambar di perangkat sebelum attachment dikirim ke server. Alur yang dipilih menyerupai WhatsApp: pengguna memilih gambar, preview lokal langsung tampil, proses kompresi berjalan di background, dan upload baru dimulai setelah hasil kompresi berstatus `ready`.

Implementasi dibatasi pada `mobile/` Flutter. Server dan web tidak diubah pada iterasi ini.

## 2. Tujuan

- Mengurangi ukuran attachment gambar sebelum upload.
- Menjaga UI tetap responsif selama kompresi.
- Menampilkan gambar lokal sebelum proses selesai.
- Memakai JPEG sebagai format output default dengan kualitas 80–85.
- Menyediakan fallback dan retry saat kompresi gagal.
- Memisahkan logika kompresi dari UI melalui interface dan worker Dart.

## 3. Non-Tujuan

- Tidak mengubah API atau validasi server.
- Tidak mengubah web.
- Tidak menambahkan kompresi audio.
- Tidak menjamin penghematan ukuran tertentu untuk semua jenis gambar.
- Tidak memakai AVIF sebagai output karena dukungan encode tidak cukup luas.
- Tidak mengklaim bahwa WebP selalu lebih kecil dari JPEG.

## 4. Keputusan Format

### 4.1 Format Default

Gunakan JPEG lossy dengan kualitas 80–85 untuk foto.

Alasan:

- Server sudah menerima `image/jpeg`.
- JPEG didukung luas oleh platform mobile.
- Foto umumnya tidak membutuhkan alpha channel.
- Kompatibilitas lebih penting daripada penghematan ekstra dari WebP.

### 4.2 WebP

WebP boleh dipertimbangkan hanya jika package image processing Flutter yang dipilih memiliki dukungan encode WebP yang stabil. WebP bukan default iterasi pertama.

Trade-off:

- Potensi ukuran lebih kecil pada kualitas setara.
- Dukungan dan biaya encode perlu diverifikasi pada Android dan iOS.
- Tidak ada jaminan hasil lebih kecil untuk semua gambar.

### 4.3 Gambar dengan Alpha

Gambar dengan alpha harus diperlakukan sebagai kasus khusus. Jika encoder tidak dapat mempertahankan alpha, gunakan PNG atau pertahankan file asli. Jangan mengonversi gambar transparan ke JPEG tanpa keputusan eksplisit.

## 5. Alur Pengguna

1. Pengguna memilih satu atau beberapa gambar.
2. Attachment lokal dibuat dengan status `queued`.
3. Preview lokal langsung ditampilkan.
4. Worker mengambil item `queued`.
5. Status berubah menjadi `compressing`.
6. Worker membaca gambar di isolate terpisah.
7. Worker melakukan resize sesuai batas dimensi maksimum dan encode JPEG kualitas 80–85.
8. Hasil kompresi menggantikan path file yang akan dipakai untuk upload.
9. Status berubah menjadi `ready`.
10. Setelah note dibuat, attachment `ready` dapat diupload.
11. Jika kompresi gagal, status berubah menjadi `failed`, file asli dipertahankan, dan UI menampilkan retry.

Catatan: kompresi dimulai sebelum note dibuat, tetapi hasilnya hanya dipakai setelah attachment note siap. Ini adalah keputusan desain dari owner.

## 6. State Attachment Lokal

State minimum:

- `queued`: menunggu worker.
- `compressing`: worker sedang memproses.
- `ready`: hasil siap dipakai untuk upload.
- `failed`: kompresi gagal; original masih tersedia.

Setiap item harus menyimpan:

- ID lokal attachment.
- Path file original.
- Path file hasil kompresi.
- MIME type.
- Ukuran file.
- Lebar dan tinggi hasil bila tersedia.
- Status kompresi.
- Pesan error yang aman ditampilkan.

Retry harus idempoten. Item `failed` yang diproses ulang tidak boleh membuat duplikat attachment atau menghapus original sebelum hasil baru berhasil dibuat.

## 7. Arsitektur Flutter

### 7.1 Interface Kompresi

Buat satu interface Dart, misalnya:

```dart
abstract interface class ImageCompressor {
  Future<CompressedImage> compress(SourceImage image);
}
```

Implementasi konkret berada di data/platform layer. UI hanya melihat status dan hasil, bukan memanggil package image processing secara langsung.

### 7.2 Worker

Kompresi berat harus berjalan di background isolate menggunakan `compute()` atau mekanisme isolate Dart yang kompatibel dengan versi Flutter project.

Worker bertugas:

- decode file sumber;
- cek dimensi dan alpha;
- resize bila melewati batas;
- encode ke JPEG kualitas 80–85;
- menulis file hasil sementara;
- mengembalikan metadata hasil.

Worker tidak boleh melakukan akses UI atau memanggil widget.

### 7.3 Queue

Gunakan queue worker lokal agar beberapa gambar tidak dikompresi sekaligus. Queue harus:

- memproses satu item atau jumlah item terbatas;
- mendukung retry;
- tidak memulai duplikasi job untuk attachment yang sama;
- dapat dibatalkan jika attachment dibatalkan sebelum upload;
- bertahan selama proses compose aktif.

Iterasi pertama tidak memerlukan background process yang bertahan setelah aplikasi dimatikan. Scope saat ini adalah kompresi sebelum note dibuat.

## 8. Penyimpanan File Lokal

Original dan hasil kompresi disimpan di direktori aplikasi. Jangan menyimpan gambar besar di database atau preference.

File original harus tetap ada sampai:

- hasil kompresi berhasil;
- attachment diupload; atau
- pengguna membatalkan attachment.

Setelah hasil kompresi siap, path yang dipakai oleh attachment adalah path hasil kompresi. Original hanya dipakai untuk preview awal, retry, atau fallback.

Pembersihan file harus terjadi saat:

- attachment dibatalkan;
- attachment dihapus;
- note dibatalkan sebelum upload;
- retry gagal dan pengguna memilih memakai original.

## 9. Integrasi dengan Attachment Flutter

Rencana integrasi mengikuti repository attachment yang sudah ada. File yang kemungkinan menjadi target implementasi:

- `mobile/lib/features/notes/presentation/widgets/add_sheet.dart`: memulai pemilihan gambar dan preview.
- `mobile/lib/features/notes/data/photo_files.dart`: memakai hasil validasi format gambar.
- `mobile/lib/features/notes/data/repository/note_attachments_repository.dart`: menerima file hasil kompresi sebagai source attachment.
- file data/local attachment dan drift schema: menyimpan status/metadata kompresi lokal bila diperlukan.
- file service/worker baru: menjalankan decode, resize, dan encode di isolate.

Detail nama dan signature final harus ditentukan oleh implementation plan setelah pembacaan struktur Flutter yang lebih lengkap.

## 10. Error Handling

Tentukan perilaku berikut:

- decode gagal: item `failed`, original dipertahankan.
- encode gagal: item `failed`, original dipertahankan.
- disk penuh: item `failed`, tampilkan error yang dapat dipahami.
- proses dibatalkan: hapus file hasil sementara, jangan ubah original.
- hasil kosong: perlakukan sebagai kegagalan.
- ukuran hasil tidak lebih kecil: gunakan hasil yang valid sesuai kebijakan yang ditetapkan plan; jangan mengklaim kompresi berhasil tanpa validasi.

Jangan menampilkan stack trace ke pengguna.

## 11. Testing

### Unit Test

- status berubah dari `queued` ke `compressing` ke `ready`.
- worker menghasilkan JPEG dengan dimensi dan ukuran yang diharapkan.
- gambar yang lebih kecil dari batas tetap diproses sesuai kebijakan.
- original tidak dihapus saat kompresi gagal.
- retry memakai attachment yang sama dan tidak membuat duplikat.
- hasil kompresi menggantikan path yang dipakai untuk upload.
- format dan MIME hasil sesuai.

### Widget Test

- preview lokal tampil sebelum kompresi selesai.
- status `compressing` terlihat.
- status `failed` menampilkan retry.
- attachment `ready` menggunakan file hasil kompresi.

### Verifikasi Akhir

Jalankan:

```bash
cd mobile && flutter analyze && flutter test
```

Jika ada perubahan schema drift, jalankan migrasi dan test terkait sesuai project.

## 12. Batasan Implementasi

- Tidak menyentuh `server/`.
- Tidak menyentuh `web/`.
- Tidak mengubah kontrak upload server.
- Tidak menambahkan dependency tanpa memeriksa versi dan kompatibilitas `mobile/pubspec.yaml`.
- Tidak mengubah schema server.
- Perubahan schema lokal hanya jika status/metadata kompresi benar-benar diperlukan setelah implementasi repository.

## 13. Risiko

- Package `image` dapat memakai memori lebih besar saat decode gambar besar.
- Encode WebP dapat lebih lambat atau tidak tersedia di semua target.
- iOS tidak memiliki jalur HEIC native yang sudah ada di project.
- Status lokal yang tidak konsisten dapat membuat original terhapus atau upload memakai file yang salah.
- Proses background yang hanya berjalan selama compose tidak akan selesai jika aplikasi dimatikan.

## 14. Keputusan Akhir

Gunakan kompresi lokal sebelum note dibuat, dengan preview lokal langsung tampil. Mulai dengan JPEG kualitas 80–85 dan queue background berbasis isolate. Tambahkan status `queued`, `compressing`, `ready`, dan `failed`. Jangan mengubah server atau web pada iterasi ini.