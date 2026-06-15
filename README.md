# Commit+ (macgit)

**Commit+** là một Git client macOS native, được xây dựng bằng Swift và SwiftUI. Ứng dụng cung cấp giao diện trực quan cho các thao tác Git thường dùng, nhắm đến người dùng macOS muốn một trải nghiệm native, nhẹ nhàng thay thế cho command line hoặc các Git client dựa trên Electron.

![Tech Stack](https://img.shields.io/badge/Swift-5.0-orange)
![Platform](https://img.shields.io/badge/macOS-26.2%2B-blue)
![Dependencies](https://img.shields.io/badge/dependencies-0-green)

---

## Tính năng chính

- **Repository Management**: Mở, clone, và quản lý nhiều repository trong các cửa sổ riêng biệt
- **File Status & Staging**: Giao diện split-pane với danh sách file và diff viewer, stage/unstage file, discard changes, xử lý conflict
- **Commit Interface**: Commit bar mở rộng, hỗ trợ amend, bypass hooks, sign-off, push ngay sau commit
- **History & Commit Graph**: Trực quan hóa commit graph với branch lanes, pagination (120 commits/lần), infinite scroll
- **Sidebar Navigation**: Cây branches, tags, remotes, stashes với sync badges (ahead/behind)
- **Git Operations**: Commit, Pull, Push, Fetch, Branch, Merge, Stash - tất cả đều có phím tắt
- **Quick Search**: Spotlight-style search modal để tìm commits, files, branches, tags
- **External Integration**: Mở trong Finder, Terminal, hoặc trực tiếp remote URL (GitHub/GitLab/Bitbucket)

---

## Yêu cầu hệ thống

- **macOS**: 26.2+
- **Xcode**: 26.2+ (nếu build từ source)
- **Git**: Cài đặt trên hệ thống (Homebrew hoặc Xcode Command Line Tools)

---

## Cách chạy từ Command Line (không cần mở Xcode)

### 1. Build và chạy bằng `xcodebuild`

```bash
# Build app từ command line
xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' build

# Chạy app vừa build (lấy build mới nhất để tránh mở nhiều instance)
open $(ls -dt ~/Library/Developer/Xcode/DerivedData/macgit-*/Build/Products/Debug/Commit+.app | head -n 1)
```

### 2. Chạy app đã build trước đó

Nếu bạn đã từng build trong Xcode, app thường nằm ở:

```bash
# Tìm app đã build
find ~/Library/Developer/Xcode/DerivedData -name "Commit+.app" -type d

# Chạy trực tiếp (thay xxxxxxxx bằng đúng hash của bạn)
open ~/Library/Developer/Xcode/DerivedData/macgit-xxxxxxxx/Build/Products/Debug/Commit+.app
```

### 3. Tạo alias tiện lợi

Thêm vào `~/.zshrc` hoặc `~/.bashrc`:

```bash
# Build và chạy Commit+ nhanh
alias runcommitplus='xcodebuild -project ~/Project/macgit/macgit.xcodeproj -scheme macgit build && open $(ls -dt ~/Library/Developer/Xcode/DerivedData/macgit-*/Build/Products/Debug/Commit+.app | head -n 1)'

# Chỉ chạy app đã build (mới nhất)
alias opencommitplus='open $(ls -dt ~/Library/Developer/Xcode/DerivedData/macgit-*/Build/Products/Debug/Commit+.app | head -n 1)'
```

### 4. Tạo script build

Tạo file `build.sh` trong thư mục project:

```bash
#!/bin/bash
set -e

echo "🔨 Building Commit+..."
xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' build

echo "🚀 Launching Commit+..."
# Lấy build mới nhất để tránh mở nhiều instance từ các build cũ
APP_PATH=$(ls -dt ~/Library/Developer/Xcode/DerivedData/macgit-*/Build/Products/Debug/Commit+.app | head -n 1)
if [ -n "$APP_PATH" ]; then
    open "$APP_PATH"
    echo "✅ Done! App launched from: $APP_PATH"
else
    echo "❌ Error: Could not find built app"
    exit 1
fi
```

Sau đó:
```bash
chmod +x build.sh
./build.sh
```

### 5. Build Release version

```bash
xcodebuild -project macgit.xcodeproj -scheme macgit -configuration Release -destination 'platform=macOS' build

# App release sẽ nằm ở (lấy build mới nhất)
open $(ls -dt ~/Library/Developer/Xcode/DerivedData/macgit-*/Build/Products/Release/Commit+.app | head -n 1)
```

---

## Cách chạy từ Xcode

```bash
# Mở project trong Xcode
open macgit.xcodeproj

# Sau đó nhấn Cmd+R để build và chạy
```

---

## Kiến trúc dự án

```
macgit/
├── App/                 # App entry point & global state
│   ├── macgitApp.swift
│   ├── AppState.swift
│   └── ToolbarAction.swift
├── Views/               # SwiftUI views
│   ├── MainWindow/
│   ├── FileStatus/
│   ├── History/
│   ├── Search/
│   ├── Stashes/
│   └── Common/
├── Services/            # Git operations & business logic
│   ├── GitStatusService.swift
│   ├── GitStatus.swift
│   └── ...
├── Models/              # Data models
├── ViewModels/          # View models
└── Resources/           # Assets
```

---

## Tech Stack

| Công nghệ | Chi tiết |
|-----------|----------|
| **Ngôn ngữ** | Swift 5.0 |
| **UI Framework** | SwiftUI |
| **Nền tảng** | macOS 26.2+ |
| **Concurrency** | Swift async/await, actor |
| **Git Engine** | System Git via `Process()` subprocess |
| **Dependencies** | **Không có** — 0 external dependencies |
| **Persistence** | UserDefaults |

---

## Testing

```bash
# Chạy tất cả tests từ command line
xcodebuild -project macgit.xcodeproj -scheme macgit -destination 'platform=macOS' test
```

Test suite bao gồm:
- SidebarTreeBuilderTests
- HistoryPaginationTests
- BranchSyncStatusTests
- StashServiceTests
- SearchViewTests
- CommitGraphLayoutEngineTests
- Và nhiều test khác...

---

## Phím tắt

| Phím tắt | Chức năng |
|----------|-----------|
| `Cmd+Shift+C` | Commit |
| `Cmd+Shift+P` | Pull |
| `Cmd+Option+P` | Push |
| `Cmd+Option+F` | Fetch |
| `Cmd+Shift+B` | Branch |
| `Cmd+Shift+M` | Merge |
| `Cmd+Shift+S` | Stash |
| `Cmd+Shift+F` | Search |

---

## Ghi chú

- **Bundle ID**: `com.thanhtran.macgit`
- **Product Name**: `Commit+.app`
- **App Sandbox**: Đã tắt (bắt buộc để thực thi lệnh git và mở Terminal)
- **Hardened Runtime**: Đã bật

---

## Troubleshooting

### Mở app bằng `open` chạy nhiều instance (3+ cửa sổ)

**Nguyên nhân**: Wildcard `macgit-*` trong command có thể match nhiều thư mục DerivedData cũ (Xcode tạo thư mục mới mỗi lần clean build). Shell expand thành nhiều path, `open` mở cả nhiều app bundle.

**Kiểm tra**:
```bash
# Xem có bao nhiêu thư mục DerivedData
ls ~/Library/Developer/Xcode/DerivedData/ | grep macgit

# Xem shell expand thành bao nhiêu path
echo ~/Library/Developer/Xcode/DerivedData/macgit-*/Build/Products/Debug/Commit+.app
```

**Fix**: Dùng `ls -dt` để lấy build mới nhất thay vì wildcard:
```bash
# Lấy app mới nhất
open $(ls -dt ~/Library/Developer/Xcode/DerivedData/macgit-*/Build/Products/Debug/Commit+.app | head -n 1)

# Hoặc dọn dẹp DerivedData cũ
rm -rf ~/Library/Developer/Xcode/DerivedData/macgit-*
```

---

## License

[Chưa xác định]

---

*Được phát triển với ❤️ cho cộng đồng macOS developer.*
