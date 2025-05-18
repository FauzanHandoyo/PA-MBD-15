<!-- PROJECT LOGO -->
<br />
<div align="center">
<h1 align="center">SOIL HUMIDITY MONITOR</h1>
  
<p align="center">
  <a href="https://docs.google.com/document/d/1hm8Lt8FwRerWbpJ2OE97XsNa6cO3VT7M3mVZjngSqH8/edit"><strong>Explore our docs »</strong></a>
  <span> | </span>
  <a href="#"><strong>Our Presentation »</strong></a>
    <br />
  </p>
</div>

___
**Group 15:**
+ Izzan Nawa Syarif			- 2306266956
+ R. Aisha Syauqi Ramadhani	- 2306250554
+ Fauzan Farras Hakim Budi H.   	- 2306250610
+ Matthew Immanuel Sitorus		- 2306221024
___

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="1. #introduction">Introduction</a></li>
    <li><a href="2. #hardware-design-and-implementation">Hardware Design and Implementation</a></li>
    <li><a href="3. #software-implementation">Software Implementation</a></li>
    <li><a href="4. #testing-and-performance-evaluation">Testing and Performance Evaluation</a></li>
    <li><a href="5. #conclusion-and-future-work">Conclusion and Future Work</a></li>
  </ol>
</details>

# 1. Introduction

### 1.1 Problem Statement
<p align="justify">Kelembaban tanah merupakan salah satu faktor penting dalam keberhasilan pertumbuhan tanaman. Dalam praktiknya, pemantauan dan pengaturan kelembaban tanah masih banyak dilakukan secara manual oleh petani atau pemilik lahan, yang tentu memerlukan waktu, tenaga, dan keterlibatan secara langsung. Ketika terjadi kelalaian dalam penyiraman atau tidak adanya pemantauan secara berkala, kondisi tanah dapat menjadi terlalu kering atau terlalu basah. Hal ini dapat berdampak buruk terhadap pertumbuhan dan kesehatan tanaman, serta menurunkan hasil panen secara keseluruhan.
</p>
<p align="justify">Di sisi lain, kemajuan teknologi sistem embedded dan sensor digital membuka peluang untuk merancang sistem monitoring kelembaban tanah secara otomatis yang dapat bekerja secara real-time dan mandiri. Namun, implementasi sistem seperti ini masih memiliki tantangan, seperti keterbatasan dalam konsumsi daya, respons terhadap perubahan kondisi lingkungan, serta integrasi antara komponen sensor, aktuator, dan mikrokontroler.
</p>

### 1.2 Proposed Solution
<p align="justify">Dalam proyek ini, sistem dirancang untuk mendeteksi tingkat kelembaban tanah secara otomatis dan real-time menggunakan sensor kelembaban digital (DHT11) yang terhubung dengan mikrokontroler slave. Data kelembaban dikirimkan ke mikrokontroler master melalui komunikasi SPI (Serial Peripheral Interface). Berdasarkan nilai kelembaban yang diterima, sistem akan menentukan apakah pompa air perlu diaktifkan.
</p>

Komponen utama dari solusi kami meliputi:
- **Sensor DHT11**: Digunakan untuk mengukur kelembaban secara real-time. Data kelembaban yang diperoleh akan menjadi dasar pengambilan keputusan sistem.
- **Konfigurasi Master-Slave Mikrokontroler**: Slave bertugas membaca data dari sensor DHT11, lalu mengirimkannya ke master melalui komunikasi SPI. Master kemudian mengolah data dan menjalankan logika kontrol.
- **Komunikasi SPI**: Digunakan sebagai jalur komunikasi data digital antara master dan slave.
- **LED Indikator**: LED digunakan sebagai indikator status kelembaban tanah (merah untuk tanah kering, hijau untuk tanah cukup lembap).
- **Mekanisme Interrupt**: Interrupt eksternal digunakan untuk mengatur waktu penyiraman secara manual.
- **Kontrol Timer**: Timer1 digunakan untuk menghitung mundur durasi penyiraman.
- **Kontrol Pompa Air**: Pompa air dikendalikan secara otomatis berdasarkan data kelembaban dan waktu penyiraman.

# 2. Hardware Design and Implementation

### 2.1 System Architecture
<p align="justify">Untuk memenuhi kriteria pada proyek akhir Praktikum Sistem Embedded, pemrograman software dilakukan dalam bahasa Assembly untuk merancang program monitoring kelembaban tanah. Sebelum menuliskan kode dalam bahasa Assembly, dibutuhkan implementasi rangkaian secara virtual menggunakan software Proteus.
</p>
<p align="justify">Sistem kami menggunakan konfigurasi master-slave dengan dua mikrokontroler Arduino Uno. Mikrokontroler slave bertanggung jawab untuk membaca data dari sensor DHT11, sementara mikrokontroler master memproses data ini dan mengendalikan sistem penyiraman berdasarkan ambang batas yang telah ditentukan.
</p>


### 2.2 Circuit Schematic
Sistem dirancang dengan koneksi sebagai berikut:
- Sensor DHT11 terhubung ke pin digital 7 Arduino slave
- Push button untuk kontrol manual terhubung ke pin interrupt eksternal
- LED indikator terhubung ke pin output digital
- Arduino master dan slave terhubung melalui pin SPI (MOSI, MISO, SCK, SS)
- Pompa air disimulasikan (direpresentasikan oleh LED dalam prototipe kami)

# 3. Software Implementation

### Programming Approach
<p align="justify">Untuk memenuhi kriteria pada proyek akhir Praktikum Sistem Embedded, pemrograman software dilakukan dalam bahasa Assembly untuk merancang program monitoring kelembaban tanah. Bahasa Assembly adalah sebuah bahasa pemrograman rendah (low-level) yang digunakan untuk memprogram komputer, khususnya mikroprosesor dan mikrokontroler. Bahasa ini memiliki keterkaitan yang erat dengan machine learning yang merupakan bahasa yang dipahami langsung oleh komputer.
</p>

### 3.1 System Flowchart
Software kami mengikuti alur logika yang ditunjukkan di bawah ini:

### 3.2 Key Functions
Berdasarkan kode, fungsi yang dibuat antara lain:
- **DHT11_sensor**: Berfungsi untuk menginisialisasi dan memulai komunikasi dengan sensor DHT11 guna membaca nilai kelembaban tanah secara digital. 
- **DHT11_reading**: Bertugas membaca data bit-bit kelembaban yang dikirimkan sensor secara berurutan, kemudian mengonversi bit-bit tersebut menjadi nilai kelembaban dalam format byte.
- **SPI_send_data**: Digunakan untuk mengirimkan data kelembaban dari mikrokontroler pengukur ke mikrokontroler pengendali melalui protokol SPI.
- **LED_control**: Bertanggung jawab mengatur status LED indikator berdasarkan nilai kelembaban yang diterima.
- **interrupt_init**: Menginisialisasi dan mengaktifkan interrupt eksternal yang digunakan untuk mengatur durasi penyiraman secara manual melalui tombol.
- **timer1_overflow**: Digunakan sebagai timer untuk menghitung mundur durasi penyiraman secara otomatis.
- **pump_control**: Mengatur kondisi pompa air berdasarkan nilai kelembaban dan timer.


# 4. Testing and Performance Evaluation

### 4.1 Testing Methodology

Setelah melakukan integrasi antara hardware dan software, rangkaian diuji untuk membuktikan apakah sistem bekerja sesuai dengan input kode yang telah diunggah. Pengujian dilakukan dengan memberikan berbagai kondisi kelembaban tanah yang berbeda untuk memastikan sensor DHT11 dapat membaca data secara akurat dan mikrokontroler dapat memproses data tersebut dengan benar.
- Pembacaan nilai kelembaban tanah oleh sensor DHT11
- Transmisi data yang benar antara mikrokontroler slave dan master
- Aktivasi pompa air yang sesuai berdasarkan pembacaan kelembaban
- Fungsionalitas tombol kontrol manual untuk durasi penyiraman
- Indikasi visual melalui LED yang merepresentasikan status kelembaban tanah
- Akurasi timer untuk kontrol durasi penyiraman otomatis

### 4.2 Results

Setelah dilakukan pengujian, didapatkan hasil yang sesuai dengan harapan dan tujuan proyek:
- Sensor DHT11 mampu membaca nilai kelembaban tanah dengan akurat dan mengirimkan data secara tepat ke mikrokontroler.
- Respons sistem terhadap perubahan kelembaban juga berjalan dengan baik, dimana pompa air aktif secara otomatis saat kelembaban turun di bawah batas yang telah ditentukan.
- Pengaturan timer untuk durasi penyiraman juga berjalan efektif, sesuai dengan pilihan waktu yang dipilih melalui tombol input.
- LED indikator berhasil menampilkan status kelembaban secara visual dengan benar, memudahkan pemantauan kondisi tanah secara langsung.

### 4.3 Performance Evaluation
<p align="justify">Evaluasi pada proyek akhir sistem embedded ini dibagi menjadi dua aspek, yaitu evaluasi kinerja selama proses pengerjaan proyek dan evaluasi hasil yang diperoleh setelah implementasi. Dari segi kinerja selama pengerjaan proyek, kelompok kami menunjukkan kerja sama yang baik sehingga proses pengerjaan berjalan terorganisir dan tidak berantakan. Pembagian tugas dilakukan secara seimbang dan tepat waktu, sehingga semua kebutuhan proyek dapat diselesaikan sesuai dengan rencana yang telah ditetapkan. Sedangkan dari segi hasil yang didapatkan, kelompok kami berhasil mencapai tujuan dan harapan awal proyek. Seluruh modul yang dirancang telah berhasil diimplementasikan dalam kode assembly dengan baik, sehingga proyek ini dapat dikatakan memenuhi semua persyaratan dari proyek akhir sistem embedded.
</p>

# 5. Conclusion and Future Work

### 5.1 Conclusion
Sebagai langkah pengembangan berikutnya, kami menyarankan untuk:
- Mengintegrasikan sistem dengan aplikasi mobile atau IoT agar monitoring kelembaban tanah dan pengendalian pompa bisa dilakukan secara jarak jauh.
- Meningkatkan penggunaan sensor dengan akurasi lebih tinggi untuk pembacaan kelembaban yang lebih presisi.
- Mengoptimasi algoritma pengendalian pompa untuk meningkatkan efisiensi penggunaan air serta keandalan sistem secara keseluruhan.
- Menambahkan sensor tambahan seperti sensor suhu, pH, dan nutrisi tanah untuk pemantauan yang lebih komprehensif.
- Mengembangkan sistem yang dapat mendukung beberapa zona penyiraman dengan kontrol independen.
