# RobloxGuiBootstrap

Framework / Bootstrap GUI Roblox berbahasa Lua/Luau yang modular, ringan, responsif untuk perangkat **HP (Low-End)** hingga **PC (High-End)**, siap dijalankan di **Executor** maupun **Roblox Studio**.

---

## Arsitektur Utama

- **1 Bar Shortcut (Top Window Bar)**:
  - Draggable menggunakan Mouse (PC) maupun Touch (HP).
  - **`[-]` Minimize**: Menyembunyikan menu utama ke **Floating Shortcut Icon** yang dapat digeser, serta membuka kembali kontrol GameCanvas. Ketuk ikon shortcut untuk membuka menu kembali.
  - **`[[]]` Maximize / Restore**: Memperbesar menu hingga memenuhi viewport layar atau kembali ke ukuran standar.
  - **`[X]` Close**: Menutup menu sepenuhnya, memulihkan `CoreGui`, melepas lock input, dan membersihkan seluruh instance/koneksi via `Janitor`.
  - **`[PREFS]` Toggle**: Membuka/menutup `Right Tab` secara cepat di layar HP berukuran kecil.

- **3 Tab Layout**:
  1. **Left Tab (`LeftTab`)**: Sidebar navigasi + `Logo / LogoTitle` + badge status Performa & FPS real-time.
  2. **Center Tab (`CenterTab`)**: Area konten utama fitur/menu yang otomatis mengikuti **Grid**, **Pattern**, dan **Visual Graphics** aktif tanpa mereset state komponen.
  3. **Right Tab (`RightTab`)**: Panel *Further Preferences & Quick Shortcuts* untuk mengganti Tema, Custom Color + Add to Preset, Grid, Pattern, Visual Graphics, Mode Performa, Topbar/GameCanvas Blocker, dan custom shortcut developer.

- **Proteksi Input, GameCanvas & Topbar Roblox**:
  - `ScreenGui` menggunakan `IgnoreGuiInset = true`, `ResetOnSpawn = false`, `DisplayOrder = 999999`.
  - **GameCanvas Blocker**: `ModalBlocker` layar penuh (`Modal = true`, `Active = true`) + `ContextActionService` input sink mencegah klik/sentuhan di luar menu menekan tombol game 3D atau UI di belakangnya.
  - **Topbar Shield**: Menutup area inset Topbar Roblox dan menyembunyikan `CoreGui` sementara saat GUI aktif (otomatis dipulihkan saat Minimize atau Close).

- **Responsive Mobile Auto-Scale & Performance Engine**:
  - Menghitung skala `UIScale` otomatis setiap kali `ViewportSize` atau orientasi layar HP berubah.
  - **Performance Mode (`Auto`, `Low`, `Medium`, `High`)**: Memantau rata-rata FPS secara ringan (throttled), menonaktifkan shadow/gradient & mempercepat tween ke `0` pada perangkat Low-End HP, serta membatasi FPS loop `Rendering`.

---

## Cara Menggunakan

Repository: `https://github.com/Mytzcodes/GUIX`
Raw Basepath: `https://raw.githubusercontent.com/Mytzcodes/GUIX/main/`

### 1. Menjalankan Demo Langsung di Executor (GitHub Raw)
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Mytzcodes/GUIX/main/RobloxGuiBootstrap.lua"))()
```
Atau jalankan template contoh:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Mytzcodes/GUIX/main/ExampleUsage.lua"))()
```

### 2. Menggunakan sebagai Framework Reusable
Lihat contoh lengkap di [ExampleUsage.lua](file:///c:/Users/Defin/Documents/GUI/ExampleUsage.lua):

```lua
_G.ROBLOX_GUI_BOOTSTRAP_LIBRARY_ONLY = true
local RAW_BASE = "https://raw.githubusercontent.com/Mytzcodes/GUIX/main/"
local Bootstrap = loadstring(game:HttpGet(RAW_BASE .. "RobloxGuiBootstrap.lua"))()

local Window = Bootstrap.CreateWindow({
    Title = "MY CUSTOM SUITE",
    Subtitle = "3-Tab Framework",
    Palette = "ObsidianDark",
    Grid = "Bento Grid",
    Pattern = "Multi Column",
    Visual = "Minimalist",
    PerformanceMode = "Auto",
    BlockGameCanvas = true,
    BlockTopbar = true,
})

local Home = Window:AddTab({ Name = "Home", Icon = "H" })
Home:AddTitle({ Title = "Welcome", Subtitle = "Modular & Reusable" })
Home:AddButton({ Title = "Run Task", Callback = function() print("Clicked!") end })
```

---

## Referensi 14 Komponen

Semua method dipanggil pada objek `Tab` (atau sub-container dari `AddLayout`) dan tidak hardcoded:

| # | Komponen | Method | Keterangan |
|---|----------|--------|------------|
| 1 | Title | `Tab:AddTitle(cfg)` | Judul section + subtitle + garis aksen |
| 2 | Label | `Tab:AddLabel(cfg)` | Teks informatif dinamis (`:SetText(...)`) |
| 3 | Logo / LogoTitle | `Tab:AddLogo(cfg)` / `Window:SetLogo(cfg)` | Monogram / `rbxassetid://` + judul & subjudul |
| 4 | Button | `Tab:AddButton(cfg)` | Variant `Primary`, `Secondary`, `Danger`, `Ghost` |
| 5 | Toggle | `Tab:AddToggle(cfg)` | Switch animasi boolean (`:Set()`, `:Get()`) |
| 6 | Radio | `Tab:AddRadio(cfg)` | Pilihan tunggal dari daftar `Options` |
| 7 | Card | `Tab:AddCard(cfg)` | Mendukung `WithImage = true` atau `false`, badge, dan tombol aksi |
| 8 | Grid Shape | `Tab:AddGridShape(cfg)` | Bentuk `Square`, `Rounded`, `Circle`, `Pill`, `Diamond` |
| 9 | Layout | `Tab:AddLayout(cfg)` | Sub-container bersarang dengan Grid independen |
| 10 | Rendering | `Tab:AddRendering(cfg)` | `Mode = "3D"` (`ViewportFrame`) atau `Mode = "2D"` (waveform canvas) |
| 11 | Notifications | `Window:Notify(cfg)` | Toast notifikasi bertumpuk dengan countdown bar |
| 12 | Loading | `Window:ShowLoading(cfg)` / `Tab:AddLoading(cfg)` | Indikator loading spinner + progress bar (`:SetProgress()`, `:Finish()`) |
| 13 | Bar | `Tab:AddBar(cfg)` | `Mode = "Progress" \| "Update" \| "Slider" \| "Stat"` |
| 14 | Picker | `Tab:AddPicker(cfg)` | `Mode = "Color"` (RGB slider) atau `Mode = "Dropdown"` |

---

## Preset Bawaan

### Default Colour Palettes (`Bootstrap.Palettes`)
`ObsidianDark`, `CyberNeon`, `SwissMono`, `EmeraldMatrix`, `OceanicDeep`, `SunsetEditorial`, `NewspaperInk`, `BrutalistYellow` — ditambah fitur **Custom Colors + Add to Preset** (`Window:SaveColorPreset(name, tbl)`) yang otomatis tersimpan ke JSON (`RobloxGuiBootstrap_Presets.json`) jika executor mendukung `writefile`.

### Default Grid (7)
1. `Grid Modular`
2. `Bento Grid`
3. `Masonry`
4. `Swiss`
5. `Golden Ratio Layout`
6. `12 Column Grid`
7. `Baseline Grid`

### Default Pattern (7)
1. `F-Pattern`
2. `Z-Pattern`
3. `Single Column`
4. `Multi Column`
5. `Split Screen`
6. `Full-Blend Hero`
7. `Sticky Sidebar`

### Visual Graphics (10)
1. `Minimalist`
2. `Maximalism`
3. `Editorial`
4. `Newspaper`
5. `Brutalist Layout`
6. `Deconstructed`
7. `Collage`
8. `Isometric`
9. `Card Base`
10. `Dashboard Layout`
