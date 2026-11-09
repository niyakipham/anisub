#!/bin/bash

ANISUB_VERSION="2026.11.10c"

# --- CONFIGURATION & DATA FILES ---
CONFIG_DIR="$HOME/.config/anisub_cli"
CONFIG_FILE="$CONFIG_DIR/config.cfg"
HISTORY_FILE="$CONFIG_DIR/history.log"
FAVORITES_FILE="$CONFIG_DIR/favorites.txt"
MANGA_HISTORY_FILE="$CONFIG_DIR/manga_history.log"
MANGA_FAVORITES_FILE="$CONFIG_DIR/manga_favorites.txt"
CACHE_DIR="$CONFIG_DIR/cache"
SCRIPT_URL="https://raw.githubusercontent.com/NiyakiPham/anisub/main/anisub.sh"

# --- NGUỒN PHIM: KKPHIM (https://kkphim.com) ---------------------------------
# Toàn bộ dữ liệu phim (tìm kiếm, thông tin phim, server phụ đề/thuyết minh,
# danh sách tập, link m3u8...) được lấy từ hệ thống KKPhim:
#   + Trang web : https://kkphim.com   -> trang phim, poster, Referer khi phát
#   + API       : https://phimapi.com  -> RESTful API do chính KKPhim công bố
#                (tài liệu: https://kkphim.com/api-document)
#   + CDN ảnh   : https://phimimg.com  -> dùng khi API trả đường dẫn ảnh tương đối
# KKPhim đôi khi đổi domain frontend (kkphim.com <-> kkphim2.com), vì vậy mọi
# giá trị ở trên đều có thể ghi đè trong config.cfg (xem mục Cài đặt).
SOURCE_NAME="KKPhim"
DEFAULT_KKPHIM_SITE_URL="https://kkphim.com"
DEFAULT_KKPHIM_API_URL="https://phimapi.com"
DEFAULT_KKPHIM_CDN_URL="https://phimimg.com"
DEFAULT_KKPHIM_REFERER="https://kkphim.com/"
DEFAULT_KKPHIM_SEARCH_LIMIT=24      # số kết quả trả về mỗi lần tìm kiếm / 1 trang
DEFAULT_KKPHIM_DETAIL_TTL=600       # giây - cache chi tiết phim (link m3u8 hết hạn rất nhanh)
DEFAULT_KKPHIM_SERVER_PREF="auto"   # auto | vietsub | long-tieng | thuyet-minh | <tên bất kỳ>
KKPHIM_USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
KKPHIM_SITE_URL=""
KKPHIM_API_URL=""
KKPHIM_CDN_URL=""
KKPHIM_REFERER=""
KKPHIM_SEARCH_LIMIT=""
KKPHIM_DETAIL_TTL=""
KKPHIM_SERVER_PREF=""
KKPHIM_FFMPEG_HEADERS=""

# Local Data File
# Đi theo symlink (ai cài bằng "ln -s ~/anisub.sh ~/bin/anisub" vẫn tìm đúng src/)
ANISUB_SELF_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$ANISUB_SELF_PATH")" && pwd)"
# Đường dẫn tuyệt đối của chính script — fzf chạy reload/preview bằng shell riêng,
# CWD có thể đã bị đổi (vd sau tính năng Ghép Video) nên phải dùng đường dẫn đầy đủ.
SELF_SCRIPT="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
# 1 = file này đang được CHẠY trực tiếp (./anisub.sh), 0 = đang bị source
# (test hoặc script khác nhúng vào) -> khi source thì chỉ nạp hàm, không mở menu.
ANISUB_EXECUTED=0
[ "${BASH_SOURCE[0]}" = "$0" ] && ANISUB_EXECUTED=1
LOCAL_DATA_FILE="$SCRIPT_DIR/assets/aniw_export_2026-01-14.csv"

# --- NGUỒN TRUYỆN TRANH ------------------------------------------------------
# nettruyen : https://nettruyen.info - CMS kiểu NetTruyen, danh sách chương nằm
#             sẵn trong HTML (không cần API/CSRF).  URL truyện: /truyen-<slug>
#             URL chương:      /truyen-<slug>/chuong-<n>
#             Ảnh trang:       https://net.imgchapter.store/<slug>/<chap>/page_<i>.jpg
# truyenvn  : https://truyenvn.my  - cần API /webapi/stories/list-chapter,
#             URL truyện /truyen-tranh/<slug>, chương /chapter-<n> (giữ để đổi lại).
# e-hentai  : https://e-hentai.org  - gallery ảnh, 1 gallery = 1 "truyện", các
#             trang ảnh được gom thành từng nhóm (EHENTAI_CHUNK) = 1 "chapter".
#             Danh sách mặc định = tag EHENTAI_TAG (language:vietnamese).
DEFAULT_MANGA_SOURCE="nettruyen"
DEFAULT_MANGA_BASE_URL="https://nettruyen.info"
DEFAULT_MANGA_SEARCH_FEEDS="latest,trending,views"   # danh sách dùng để lọc khi search
DEFAULT_MANGA_SEARCH_PAGES=1                          # số trang tải cho mỗi danh sách
# Giao thức vẽ ảnh trong fzf: auto | kitty | sixel | iterm | symbols
#   auto    : tự đoán theo $TERM/$TERM_PROGRAM (an toàn, terminal lạ -> symbols)
#   symbols : luôn vẽ bằng ký tự (hiện hình ở MỌI terminal, độ nét thấp)
#   kitty/sixel/iterm: ảnh nét, chỉ dùng khi terminal thật sự hỗ trợ
DEFAULT_MANGA_IMAGE_PROTOCOL="auto"
# Khi trang chapter bị chặn/trả bản rút gọn cho máy mình, anisub lấy danh sách ảnh
# qua dịch vụ đọc hộ này (nó tải trang bằng trình duyệt thật rồi trả markdown).
# Đặt "" hoặc "off" để tắt (khi tắt, anisub không gửi URL truyện ra bên thứ ba).
DEFAULT_MANGA_READER_PROXY="https://r.jina.ai"
# e-hentai: tag mặc định (danh sách mở ra đầu tiên), số trang ảnh mỗi "chapter",
# và cookie đăng nhập (chỉ cần cho gallery giới hạn/18+; để trống nếu không dùng).
DEFAULT_EHENTAI_TAG="language:vietnamese"
DEFAULT_EHENTAI_CHUNK=20
DEFAULT_EHENTAI_COOKIE=""
MANGA_SOURCE=""
MANGA_BASE_URL=""
MANGA_SEARCH_FEEDS=""
MANGA_SEARCH_PAGES=""
MANGA_IMAGE_PROTOCOL=""
MANGA_READER_PROXY="$DEFAULT_MANGA_READER_PROXY"
EHENTAI_TAG=""
EHENTAI_CHUNK=""
EHENTAI_COOKIE=""
MANGA_USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
# Trang chapter của TruyenVN trả bản rút gọn (không có ảnh) nếu request "không giống
# trình duyệt". Gửi kèm đủ header điều hướng để nhận đúng HTML có <img>.
MANGA_BROWSER_HEADERS=(
    -H "sec-ch-ua: \"Chromium\";v=\"131\", \"Google Chrome\";v=\"131\", \"Not-A.Brand\";v=\"99\""
    -H "sec-ch-ua-mobile: ?0"
    -H "sec-ch-ua-platform: \"Linux\""
    -H "upgrade-insecure-requests: 1"
)
MANGA_HTTP_STATUS="000"
MANGA_STORY_COVER=""      # ảnh bìa lấy được từ trang truyện gần nhất
# API chặn nếu thiếu phiên: CSRF token chỉ đúng khi gửi kèm cookie của chính trang
# vừa tải (laravel_session), nên mọi request tới web phải dùng chung 1 cookie jar.
MANGA_COOKIE_JAR="${TMPDIR:-/tmp}/anisub-manga-cookies.$$"
# "Chap trước|Chap sau" của chapter đang đọc (fetch_chapter_images ghi ra) - dùng khi
# danh sách chapter bị thiếu để vẫn chuyển chap được.
ANISUB_MANGA_NAV_FILE="${TMPDIR:-/tmp}/anisub-manga-nav.$$"

# --- DEFAULTS ---
DEFAULT_PLAYER="mpv"
DEFAULT_DOWNLOAD_DIR="$HOME/Downloads/anime"
DEFAULT_MANGA_IMAGE_SCALE=130  # Phần trăm kích thước hình ảnh (100 = full terminal, 130 = 30% lớn hơn)
PLAYER=""
DOWNLOAD_DIR=""
MANGA_IMAGE_SCALE=""

# --- UTILITY FUNCTIONS ---
ensure_config_dir() {
    mkdir -p "$CONFIG_DIR"
}
load_config() {
    ensure_config_dir
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "PLAYER=\"$DEFAULT_PLAYER\"" > "$CONFIG_FILE"
        echo "DOWNLOAD_DIR=\"$DEFAULT_DOWNLOAD_DIR\"" >> "$CONFIG_FILE"
        echo "# --- NGUỒN TRUYỆN TRANH (nettruyen | truyenvn | ehentai) ---" >> "$CONFIG_FILE"
        echo "MANGA_SOURCE=\"$DEFAULT_MANGA_SOURCE\"" >> "$CONFIG_FILE"
        echo "MANGA_BASE_URL=\"$DEFAULT_MANGA_BASE_URL\"" >> "$CONFIG_FILE"
        echo "MANGA_SEARCH_FEEDS=\"$DEFAULT_MANGA_SEARCH_FEEDS\"" >> "$CONFIG_FILE"
        echo "MANGA_SEARCH_PAGES=\"$DEFAULT_MANGA_SEARCH_PAGES\"" >> "$CONFIG_FILE"
        echo "MANGA_IMAGE_PROTOCOL=\"$DEFAULT_MANGA_IMAGE_PROTOCOL\"" >> "$CONFIG_FILE"
        echo "MANGA_READER_PROXY=\"$DEFAULT_MANGA_READER_PROXY\"" >> "$CONFIG_FILE"
        echo "EHENTAI_TAG=\"$DEFAULT_EHENTAI_TAG\"" >> "$CONFIG_FILE"
        echo "EHENTAI_CHUNK=\"$DEFAULT_EHENTAI_CHUNK\"" >> "$CONFIG_FILE"
        echo "EHENTAI_COOKIE=\"$DEFAULT_EHENTAI_COOKIE\"" >> "$CONFIG_FILE"
        echo "# --- NGUỒN PHIM KKPHIM (sửa nếu KKPhim đổi domain) ---" >> "$CONFIG_FILE"
        echo "KKPHIM_SITE_URL=\"$DEFAULT_KKPHIM_SITE_URL\"" >> "$CONFIG_FILE"
        echo "KKPHIM_API_URL=\"$DEFAULT_KKPHIM_API_URL\"" >> "$CONFIG_FILE"
        echo "KKPHIM_CDN_URL=\"$DEFAULT_KKPHIM_CDN_URL\"" >> "$CONFIG_FILE"
        echo "KKPHIM_REFERER=\"$DEFAULT_KKPHIM_REFERER\"" >> "$CONFIG_FILE"
        echo "KKPHIM_SEARCH_LIMIT=\"$DEFAULT_KKPHIM_SEARCH_LIMIT\"" >> "$CONFIG_FILE"
        echo "KKPHIM_DETAIL_TTL=\"$DEFAULT_KKPHIM_DETAIL_TTL\"" >> "$CONFIG_FILE"
        echo "KKPHIM_SERVER_PREF=\"$DEFAULT_KKPHIM_SERVER_PREF\"" >> "$CONFIG_FILE"
    fi
    ANISUB_CONFIG_HAS_SOURCE=0
    grep -q '^MANGA_SOURCE=' "$CONFIG_FILE" 2>/dev/null && ANISUB_CONFIG_HAS_SOURCE=1
    source "$CONFIG_FILE"
    PLAYER=${PLAYER:-$DEFAULT_PLAYER}
    DOWNLOAD_DIR=${DOWNLOAD_DIR:-$DEFAULT_DOWNLOAD_DIR}
    MANGA_IMAGE_SCALE=${MANGA_IMAGE_SCALE:-$DEFAULT_MANGA_IMAGE_SCALE}
    MANGA_SOURCE=${MANGA_SOURCE:-$DEFAULT_MANGA_SOURCE}
    MANGA_BASE_URL=${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}
    # Máy đang dùng config cũ (chưa có MANGA_SOURCE) -> chuyển sang nguồn mặc định mới
    if [ "${ANISUB_CONFIG_HAS_SOURCE:-0}" != "1" ]; then
        MANGA_SOURCE="$DEFAULT_MANGA_SOURCE"
        MANGA_BASE_URL="$DEFAULT_MANGA_BASE_URL"
        { echo "MANGA_SOURCE=\"$MANGA_SOURCE\""; echo "MANGA_BASE_URL=\"$MANGA_BASE_URL\""; } >> "$CONFIG_FILE" 2>/dev/null
    fi
    MANGA_SEARCH_FEEDS=${MANGA_SEARCH_FEEDS:-$DEFAULT_MANGA_SEARCH_FEEDS}
    MANGA_SEARCH_PAGES=${MANGA_SEARCH_PAGES:-$DEFAULT_MANGA_SEARCH_PAGES}
    MANGA_IMAGE_PROTOCOL=${MANGA_IMAGE_PROTOCOL:-$DEFAULT_MANGA_IMAGE_PROTOCOL}
    MANGA_READER_PROXY=${MANGA_READER_PROXY-$DEFAULT_MANGA_READER_PROXY}
    case "${MANGA_READER_PROXY:-}" in off|OFF|none|null|0) MANGA_READER_PROXY="" ;; esac
    # e-hentai: tag mặc định + số trang mỗi chapter + cookie đăng nhập (nếu có)
    EHENTAI_TAG=${EHENTAI_TAG:-$DEFAULT_EHENTAI_TAG}
    EHENTAI_CHUNK=${EHENTAI_CHUNK:-$DEFAULT_EHENTAI_CHUNK}
    EHENTAI_COOKIE=${EHENTAI_COOKIE:-$DEFAULT_EHENTAI_COOKIE}
    # Cấu hình nguồn phim KKPhim: config.cfg > giá trị mặc định
    KKPHIM_SITE_URL=${KKPHIM_SITE_URL:-$DEFAULT_KKPHIM_SITE_URL}
    KKPHIM_API_URL=${KKPHIM_API_URL:-$DEFAULT_KKPHIM_API_URL}
    KKPHIM_CDN_URL=${KKPHIM_CDN_URL:-$DEFAULT_KKPHIM_CDN_URL}
    KKPHIM_REFERER=${KKPHIM_REFERER:-$DEFAULT_KKPHIM_REFERER}
    KKPHIM_SEARCH_LIMIT=${KKPHIM_SEARCH_LIMIT:-$DEFAULT_KKPHIM_SEARCH_LIMIT}
    KKPHIM_DETAIL_TTL=${KKPHIM_DETAIL_TTL:-$DEFAULT_KKPHIM_DETAIL_TTL}
    KKPHIM_SERVER_PREF=${KKPHIM_SERVER_PREF:-$DEFAULT_KKPHIM_SERVER_PREF}
    # Chuỗi header cho ffmpeg (mỗi header cách nhau bằng CRLF thật)
    KKPHIM_FFMPEG_HEADERS="Referer: ${KKPHIM_REFERER}"$'\r\n'"User-Agent: ${KKPHIM_USER_AGENT}"$'\r\n'
    mkdir -p "$DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR/cut"
    mkdir -p "$DOWNLOAD_DIR/merged"
    mkdir -p "$CACHE_DIR"
    touch "$HISTORY_FILE" "$FAVORITES_FILE" "$MANGA_HISTORY_FILE" "$MANGA_FAVORITES_FILE"
}
save_config() {
    # Ghi có dấu ngoặc kép để đường dẫn có khoảng trắng vẫn source lại được
    {
        echo "PLAYER=\"$PLAYER\""
        echo "DOWNLOAD_DIR=\"$DOWNLOAD_DIR\""
        echo "MANGA_IMAGE_SCALE=\"$MANGA_IMAGE_SCALE\""
        echo "MANGA_SOURCE=\"$MANGA_SOURCE\""
        echo "MANGA_BASE_URL=\"$MANGA_BASE_URL\""
        echo "MANGA_SEARCH_FEEDS=\"$MANGA_SEARCH_FEEDS\""
        echo "MANGA_SEARCH_PAGES=\"$MANGA_SEARCH_PAGES\""
        echo "MANGA_IMAGE_PROTOCOL=\"$MANGA_IMAGE_PROTOCOL\""
        echo "MANGA_READER_PROXY=\"$MANGA_READER_PROXY\""
        echo "EHENTAI_TAG=\"$EHENTAI_TAG\""
        echo "EHENTAI_CHUNK=\"$EHENTAI_CHUNK\""
        echo "EHENTAI_COOKIE=\"$EHENTAI_COOKIE\""
        echo "# --- NGUỒN PHIM KKPHIM (sửa nếu KKPhim đổi domain) ---"
        echo "KKPHIM_SITE_URL=\"$KKPHIM_SITE_URL\""
        echo "KKPHIM_API_URL=\"$KKPHIM_API_URL\""
        echo "KKPHIM_CDN_URL=\"$KKPHIM_CDN_URL\""
        echo "KKPHIM_REFERER=\"$KKPHIM_REFERER\""
        echo "KKPHIM_SEARCH_LIMIT=\"$KKPHIM_SEARCH_LIMIT\""
        echo "KKPHIM_DETAIL_TTL=\"$KKPHIM_DETAIL_TTL\""
        echo "KKPHIM_SERVER_PREF=\"$KKPHIM_SERVER_PREF\""
    } > "$CONFIG_FILE"
    echo "Cấu hình đã được lưu."
    sleep 1
}
check_dependencies() {
    local missing_deps=()
    local deps=("ffmpeg" "curl" "grep" "yt-dlp" "fzf" "jq" "awk" "sed" "chafa" "perl")
    echo "Kiểm tra các phụ thuộc hệ thống..."
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "LỖI: Thiếu các phụ thuộc sau: ${missing_deps[*]}"
        echo "Vui lòng cài đặt chúng trước khi sử dụng."
        if [[ " ${missing_deps[*]} " == *"chafa"* ]]; then
            echo "Gợi ý: Cài đặt chafa để xem được hình ảnh (apt install chafa / brew install chafa / pkg install chafa)"
        fi
        exit 1
    fi
}

# --- MỞ LINK BẰNG TRÌNH DUYỆT (dùng chung cho phim & truyện) ---
# Mở URL bằng trình duyệt mặc định (trang phim, trang chapter bị chặn...)
open_url() {
    local url="$1"
    [ -z "$url" ] && return 1
    echo "🌐 $url"
    if command -v xdg-open &> /dev/null; then
        xdg-open "$url" > /dev/null 2>&1 &
    elif command -v open &> /dev/null; then
        open "$url" > /dev/null 2>&1 &
    else
        echo "(Không tìm thấy xdg-open/open - hãy copy link và mở thủ công.)"
        sleep 2
    fi
}
add_to_history() {
    local anime_name="$1"
    local episode_number="$2"
    local link="$3"
    local slug="${4:-}"
    local server_index="${5:-}"
    if [ -s "$HISTORY_FILE" ]; then
        awk -F'|' -v n="$anime_name" -v e="$episode_number" '!($2 == n && $3 == e)' \
            "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi
    echo "$(date +%Y-%m-%d\ %H:%M:%S)|${anime_name}|${episode_number}|${link}|${slug}|${server_index}" >> "$HISTORY_FILE"
}
show_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        echo "Lịch sử xem trống."
        sleep 2
        return
    fi
    selected_history=$(tac "$HISTORY_FILE" | fzf --prompt="Lịch sử xem (Enter để xem lại): " --header="Nguồn phim: $SOURCE_NAME ($KKPHIM_SITE_URL) - link cũ sẽ được làm mới trước khi phát" --delimiter='|' --with-nth=1,2,3)
    if [ -n "$selected_history" ]; then
        local link=$(echo "$selected_history" | cut -d'|' -f4)
        local anime_name=$(echo "$selected_history" | cut -d'|' -f2)
        local episode_number=$(echo "$selected_history" | cut -d'|' -f3)
        local slug=$(echo "$selected_history" | cut -d'|' -f5)
        local server_index=$(echo "$selected_history" | cut -d'|' -f6)
        # Link m3u8 của KKPhim chỉ sống được vài phút -> xin link mới theo slug
        if [ -n "$slug" ] && [ "$slug" != "local_file" ]; then
            local fresh_link
            fresh_link=$(kkphim_resolve_episode_link "$slug" "$episode_number" "$server_index")
            if [ -n "$fresh_link" ]; then
                link="$fresh_link"
            else
                echo "⚠️ Không lấy được link mới từ $SOURCE_NAME, thử dùng link đã lưu..."
                sleep 1.5
            fi
        fi
        echo "Đang phát lại: $anime_name - $(episode_label "$episode_number")..."
        add_to_history "$anime_name" "$episode_number" "$link" "$slug" "$server_index"
        play_stream "$link" "$anime_name - $episode_number"
        wait "$PLAYER_PID" 2>/dev/null
    fi
}
add_to_favorites() {
    local name="$1"
    local slug="$2"
    local server_index="${3:-}"
    if grep -qE "\|${slug}(\|.*)?\$" "$FAVORITES_FILE" 2>/dev/null; then
        echo "'$name' đã có trong danh sách yêu thích."
    else
        echo "$name|$slug|$server_index" >> "$FAVORITES_FILE"
        echo "Đã thêm '$name' vào danh sách yêu thích."
    fi
    sleep 2
}
show_favorites() {
    if [ ! -s "$FAVORITES_FILE" ]; then
        echo "Danh sách yêu thích trống."
        sleep 2
        return 1
    fi
    selected_favorite=$(fzf --prompt="Phim yêu thích: " --header="Nguồn phim: $SOURCE_NAME ($KKPHIM_SITE_URL)" --delimiter='|' --with-nth=1 < "$FAVORITES_FILE")
    if [ -n "$selected_favorite" ]; then
        echo "$selected_favorite" 
        return 0
    else
        return 1
    fi
}

# Trạng thái HTTP của lời gọi API/HTTP gần nhất (để báo lỗi chính xác thay vì im
# lặng). Ghi ra file tạm nữa vì hàm API thường được gọi trong $(...) - biến toàn
# cục thay đổi trong subshell sẽ mất ở shell cha, còn file thì vẫn đọc được.
ANISUB_STATUS_FILE="${TMPDIR:-/tmp}/anisub-kkhttp.$$"
KKPHIM_HTTP_STATUS="000"

# ═══════════════════════════════════════════════════════════════════════════════
# NẠP MODULE NGUỒN — src/movie/*.sh (phim) và src/comic/*.sh (truyện tranh)
# ═══════════════════════════════════════════════════════════════════════════════
# Code chính (file này) chỉ giữ: cấu hình, tiện ích, lịch sử/yêu thích, menu và
# phần khởi động. Toàn bộ phần "nguồn" nằm trong src/:
#
#   src/movie/kkphim.sh   nguồn phim KKPhim (API, danh mục, server, tập, phát phim)
#   src/movie/media.sh    tải / cắt / ghép video, xem file local
#   src/comic/core.sh     engine đọc truyện (ảnh, khung đọc, menu, chẩn đoán)
#   src/comic/nettruyen.sh  nguồn nettruyen.info
#   src/comic/truyenvn.sh   nguồn truyenvn.my
#   src/comic/ehentai.sh    nguồn e-hentai.org (truyện tiếng Việt)
#
# Thêm nguồn mới = thêm 1 file .sh vào đúng thư mục, không cần sửa file này.
# Muốn chạy bộ file ở nơi khác: đặt biến môi trường ANISUB_SRC_DIR=/duong/dan/src
# Nơi có thể có src/: biến môi trường -> cạnh script -> trong thư mục config.
# (Người dùng cũ chỉ có mỗi anisub.sh sẽ được tự tải src/ về — xem anisub_ensure_sources.)
ANISUB_SRC_DIR="${ANISUB_SRC_DIR:-}"
UPDATE_REPO_URL="https://codeload.github.com/NiyakiPham/anisub/tar.gz/refs/heads/main"

# Thư mục này có phải bộ nguồn dùng được (có movie/ + comic/ + file .sh)?
anisub_src_looks_ok() {
    local d="${1:-}"
    [ -n "$d" ] && [ -d "$d/movie" ] && [ -d "$d/comic" ] || return 1
    compgen -G "$d/comic/*.sh" > /dev/null 2>&1
}

# Tìm thư mục nguồn đang có trên máy (in ra đường dẫn, lỗi -> return 1)
anisub_find_src() {
    local d
    for d in "${ANISUB_SRC_DIR:-}" "${SCRIPT_DIR:-}/src" "${CONFIG_DIR:-}/src"; do
        [ -n "$d" ] || continue
        if anisub_src_looks_ok "$d"; then
            printf '%s' "$d"
            return 0
        fi
    done
    return 1
}

# Nạp mọi module nguồn trong 1 thư mục src/ (movie/ trước, comic/ sau).
anisub_load_sources() {
    local root="${1:-${ANISUB_SRC_DIR:-$SCRIPT_DIR/src}}"
    local dir f found=0
    for dir in movie comic; do
        [ -d "$root/$dir" ] || continue
        for f in "$root/$dir"/*.sh; do
            [ -f "$f" ] || continue
            # shellcheck source=/dev/null
            . "$f" || { echo "❌ Không nạp được module nguồn: $f" >&2; return 1; }
            found=$((found + 1))
        done
    done
    [ "$found" -gt 0 ]
}

# Tải bộ file nguồn (src/) từ GitHub về $1 (mặc định: cạnh script).
# Dùng cho máy chỉ có mỗi anisub.sh (bản cũ chỉ tải 1 file khi 🔄 Cập nhật).
anisub_fetch_sources() {
    local dest="${1:-$SCRIPT_DIR}" tmpdir archive root
    [ -z "$dest" ] && return 1
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/anisub-src.XXXXXX" 2>/dev/null) || return 1
    archive="$tmpdir/anisub.tar.gz"
    echo "⏳ Chưa có thư mục src/ — đang tải bộ file nguồn từ GitHub..."
    if ! curl -fsSL --max-time 60 -o "$archive" "$UPDATE_REPO_URL" 2>/dev/null; then
        rm -rf "$tmpdir"
        return 1
    fi
    if ! tar -xzf "$archive" -C "$tmpdir" 2>/dev/null; then
        rm -rf "$tmpdir"
        return 1
    fi
    root=$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d -name 'anisub-*' | head -1)
    if [ -z "$root" ] || [ ! -d "$root/src" ]; then
        rm -rf "$tmpdir"
        return 1
    fi
    mkdir -p "$dest" 2>/dev/null
    if [ -d "$dest/src" ]; then
        cp -R "$root/src/." "$dest/src/" 2>/dev/null      # đã có src/ -> ghi đè lên
    else
        cp -R "$root/src" "$dest/src" 2>/dev/null         # chưa có -> tạo mới
    fi
    local rc=$?
    rm -rf "$tmpdir"
    return $rc
}

# Bảo đảm LUÔN có nguồn trước khi mở menu: tìm quanh máy -> tự tải -> báo lỗi rõ ràng.
# Nhờ vậy lỗi "bấm Đọc Truyện Tranh mà không có gì xảy ra" không còn xảy ra nữa.
anisub_ensure_sources() {
    [ "${ANISUB_SOURCES_OK:-0}" = "1" ] && return 0
    local found dest
    if found=$(anisub_find_src); then
        ANISUB_SRC_DIR="$found"
        anisub_load_sources "$ANISUB_SRC_DIR" && { ANISUB_SOURCES_OK=1; return 0; }
    fi
    # Chưa có -> thử tải về cạnh script, không ghi được thì để trong thư mục config
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    for dest in "$SCRIPT_DIR" "$CONFIG_DIR"; do
        [ -w "$dest" ] || continue
        if anisub_fetch_sources "$dest"; then
            if found=$(anisub_find_src); then
                ANISUB_SRC_DIR="$found"
                if anisub_load_sources "$ANISUB_SRC_DIR"; then
                    ANISUB_SOURCES_OK=1
                    echo "✅ Đã tải bộ file nguồn: $ANISUB_SRC_DIR"
                    sleep 1
                    return 0
                fi
            fi
        fi
    done
    echo "❌ anisub cần thư mục src/ (movie/ + comic/) nhưng không tìm thấy và cũng không tải được."
    echo ""
    echo "   Đã tìm ở : ${SCRIPT_DIR}/src"
    echo "              ${CONFIG_DIR}/src"
    echo "   Nguyên nhân thường gặp: chỉ tải mỗi anisub.sh, hoặc bản cũ tự cập nhật 1 file."
    echo ""
    echo "   Cách sửa (chọn 1):"
    echo "     1) git clone https://github.com/NiyakiPham/anisub.git && cd anisub && ./anisub.sh"
    echo "     2) tải bản đầy đủ: https://github.com/NiyakiPham/anisub/archive/refs/heads/main.zip"
    echo "     3) có mạng lại rồi chạy: ./anisub.sh --doctor   (sẽ tự tải src/ về)"
    return 1
}

# Nạp module ngay khi file được source/chạy (im lặng). Nếu thiếu src/ thì
# --version vẫn chạy được, còn trước khi mở menu sẽ gọi anisub_ensure_sources.
ANISUB_SOURCES_OK=0
if _anisub_src=$(anisub_find_src); then
    ANISUB_SRC_DIR="$_anisub_src"
    anisub_load_sources "$ANISUB_SRC_DIR" && ANISUB_SOURCES_OK=1
fi
unset _anisub_src

# --- SETTINGS & UPDATE ---
show_settings() {
    while true; do
        opt=$(echo -e "🎬 Đổi trình phát (Hiện tại: $PLAYER)\n📁 Đổi thư mục tải (Hiện tại: $DOWNLOAD_DIR)\n🎞 Nguồn phim: $SOURCE_NAME ($KKPHIM_SITE_URL)\n📚 Nguồn truyện: $(manga_source_label) (${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL})\n🖼️ Kích thước ảnh manga (Hiện tại: ${MANGA_IMAGE_SCALE}%)\n🔙 Quay lại" | fzf --prompt="⚙️ Cài đặt > ")
        case "$opt" in
            *"Đổi trình phát"*)
                read -r -p "Nhập lệnh trình phát (vd vlc): " inp
                if command -v "$inp" &> /dev/null; then PLAYER="$inp"; save_config; fi ;;
            *"Đổi thư mục tải"*)
                read -r -p "Nhập đường dẫn tuyệt đối: " inp
                DOWNLOAD_DIR="$inp"; mkdir -p "$inp"; save_config ;;
            *"Nguồn phim"*)
                show_source_settings ;;
            *"Nguồn truyện"*)
                show_manga_settings ;;
            *"Kích thước ảnh manga"*)
                echo ""
                echo "╔═══════════════════════════════════════════════════════════╗"
                echo "║  🖼️ ĐIỀU CHỈNH KÍCH THƯỚC HÌNH ẢNH MANGA                  ║"
                echo "║  Giá trị hiện tại: ${MANGA_IMAGE_SCALE}%                                     ║"
                echo "║  Phạm vi cho phép: 50% - 200%                              ║"
                echo "║  Mẹo: 100% = vừa terminal, 130% = 30% lớn hơn              ║"
                echo "╚═══════════════════════════════════════════════════════════╝"
                read -r -p "Nhập kích thước (50-200): " inp
                if [[ "$inp" =~ ^[0-9]+$ ]] && [ "$inp" -ge 50 ] && [ "$inp" -le 200 ]; then
                    MANGA_IMAGE_SCALE="$inp"
                    save_config
                    echo "✅ Đã thay đổi kích thước thành ${MANGA_IMAGE_SCALE}%"
                    sleep 1
                else
                    echo "❌ Giá trị không hợp lệ! Phải từ 50 đến 200."
                    sleep 1
                fi
                ;;
            *) break ;;
        esac
    done
}

# Cập nhật anisub: tải bản mới (anisub.sh + src/) từ GitHub về đúng thư mục đang chạy.
# Dùng archive tar.gz của nhánh main vì code đã tách thành nhiều file.
update_script() {
    local tmpdir archive root remote_ver
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/anisub-update.XXXXXX" 2>/dev/null) || tmpdir=""
    if [ -z "$tmpdir" ]; then
        echo "❌ Không tạo được thư mục tạm để cập nhật."
        sleep 2
        return 1
    fi
    archive="$tmpdir/anisub.tar.gz"
    echo "⏳ Đang tải bản mới từ GitHub..."
    if ! curl -fsSL --max-time 90 -o "$archive" "$UPDATE_REPO_URL"; then
        echo "❌ Không tải được bản mới (mạng lỗi hoặc GitHub chặn). Thử lại sau."
        rm -rf "$tmpdir"
        sleep 2
        return 1
    fi
    if ! tar -xzf "$archive" -C "$tmpdir" 2>/dev/null; then
        echo "❌ File tải về không phải archive hợp lệ."
        rm -rf "$tmpdir"
        sleep 2
        return 1
    fi
    root=$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d -name 'anisub-*' | head -1)
    if [ -z "$root" ] || [ ! -f "$root/anisub.sh" ] || [ ! -d "$root/src" ]; then
        echo "❌ Bản tải về thiếu anisub.sh hoặc src/."
        rm -rf "$tmpdir"
        sleep 2
        return 1
    fi
    remote_ver=$(sed -n 's/^ANISUB_VERSION="\(.*\)"$/\1/p' "$root/anisub.sh" | head -1)
    if [ "$remote_ver" = "$ANISUB_VERSION" ]; then
        echo "✅ Đang là bản mới nhất ($ANISUB_VERSION)."
        rm -rf "$tmpdir"
        sleep 1
        return 0
    fi
    echo "🔁 Có bản mới: ${remote_ver:-?} (đang dùng $ANISUB_VERSION). Đang cài..."
    if ! mkdir -p "$SCRIPT_DIR/src"; then
        echo "❌ Không ghi được vào $SCRIPT_DIR"
        rm -rf "$tmpdir"
        sleep 2
        return 1
    fi
    cp -f "$root/anisub.sh" "$SELF_SCRIPT" && chmod +x "$SELF_SCRIPT" 2>/dev/null
    cp -R "$root/src/." "$SCRIPT_DIR/src/" || {
        echo "❌ Không chép được src/ mới."; rm -rf "$tmpdir"; sleep 2; return 1; }
    rm -rf "$tmpdir"
    echo "✅ Đã cập nhật lên ${remote_ver:-bản mới}. Hãy khởi động lại anisub."
    sleep 1
    return 0
}

# --- DOCTOR: in ra tình trạng thật của anisub (dùng khi "không đọc được truyện") ---
anisub_doctor() {
    echo "🩺 ANISUB DOCTOR · anisub $ANISUB_VERSION"
    echo "══════════════════════════════════════════════════════════"
    echo "📄 Script : $SELF_SCRIPT"
    echo "🧩 Nguồn  : ${ANISUB_SRC_DIR:-(không có)}"
    local f n=0
    for f in "${ANISUB_SRC_DIR:-/nonexistent}"/movie/*.sh "${ANISUB_SRC_DIR:-/nonexistent}"/comic/*.sh; do
        [ -f "$f" ] || continue
        n=$((n + 1))
        printf '   %s %s\n' "✅" "$(basename "$f")"
    done
    if [ "$n" -eq 0 ]; then
        echo "   ❌ Chưa nạp được module nguồn nào"
    else
        echo "   (đã nạp $n module)"
    fi
    echo "📚 Truyện : $(manga_source_label) · ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
    echo "🎬 Phim   : $SOURCE_NAME · $KKPHIM_API_URL"
    echo
    local dep missing=""
    for dep in ffmpeg curl grep yt-dlp fzf jq awk sed chafa perl "$PLAYER"; do
        command -v "$dep" > /dev/null 2>&1 || missing="$missing $dep"
    done
    if [ -z "$missing" ]; then
        echo "🧰 Phụ thuộc: ✅ đủ (ffmpeg, curl, fzf, jq, chafa, perl, $PLAYER...)"
    else
        missing="${missing# }"
        echo "🧰 Phụ thuộc: ⚠️ thiếu: $missing"
        echo "   → cài thêm rồi chạy lại (vd: sudo apt install $missing)"
    fi
    echo
    manga_diagnose --no-pause
    echo
    echo "Nếu vẫn lỗi: gửi nguyên nội dung lệnh này khi báo bug:"
    echo "   ./anisub.sh --doctor 2>&1 | tee anisub-doctor.txt"
    return 0
}

# Chặn trường hợp bấm menu mà module chưa nạp (trước đây bấm không có gì xảy ra).
# $1 = tên hàm cần có, $2 = nhãn module để báo lỗi.
anisub_need_module() {
    local fn="$1" label="$2"
    declare -F "$fn" > /dev/null 2>&1 && return 0
    echo ""
    echo "❌ Chưa nạp được module $label."
    echo "   Thư mục nguồn: ${ANISUB_SRC_DIR:-(không xác định)}"
    echo "   Thường do thiếu/hỏng file trong src/ (bản cũ chỉ có anisub.sh, hoặc cập nhật dở)."
    echo ""
    echo "   Cách sửa:  ./anisub.sh --doctor     (tự tải src/ nếu thiếu)"
    echo "              hoặc git clone https://github.com/NiyakiPham/anisub.git"
    printf 'Nhấn Enter để quay lại... '
    read -r _ || true
    return 1
}

# --- MAIN LOGIC ---
main() {
    trap 'rm -f "$ANISUB_STATUS_FILE" "$MANGA_COOKIE_JAR" "$ANISUB_MANGA_NAV_FILE"; kill $(jobs -p) 2>/dev/null' EXIT
    check_dependencies
    load_config

    while true; do
        clear
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║     █████╗ ███╗   ██╗██╗███████╗██╗   ██╗██████╗      ██████╗██╗     ██╗     ║"
        echo "║    ██╔══██╗████╗  ██║██║██╔════╝██║   ██║██╔══██╗    ██╔════╝██║     ██║     ║"
        echo "║    ███████║██╔██╗ ██║██║███████╗██║   ██║██████╔╝    ██║     ██║     ██║     ║"
        echo "║    ██╔══██║██║╚██╗██║██║╚════██║██║   ██║██╔══██╗    ██║     ██║     ██║     ║"
        echo "║    ██║  ██║██║ ╚████║██║███████║╚██████╔╝██████╔╝    ╚██████╗███████╗██║     ║"
        echo "║    ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚══════╝ ╚═════╝ ╚═════╝      ╚═════╝╚══════╝╚═╝     ║"
        echo "║                   🎬 Anime & 📚 Manga All-in-One CLI 🎬                      ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        main_opt=$(echo -e "🎬 Xem Anime/Phim (KKPhim)\n🍿 Phim mới cập nhật (KKPhim)\n📚 Đọc Truyện Tranh ($(manga_source_label))\n📂 Xem từ Local Anidata\n📜 Lịch sử xem Anime\n⭐ Anime yêu thích\n⚙️ Cài đặt\n🔄 Cập nhật\n🚪 Thoát" | fzf --prompt="🎯 Menu > " --height=50% --reverse --header="🎬 Nguồn phim: $SOURCE_NAME ($KKPHIM_SITE_URL) · API: $KKPHIM_API_URL")

        case "$main_opt" in
            "🎬 Xem Anime/Phim (KKPhim)")
                # Tìm kiếm trực tiếp trên KKPhim: gõ tới đâu hiện gợi ý tới đó
                clear
                anisub_need_module kkphim_search_menu "phim (src/movie/)" && kkphim_search_menu
                ;;
            "🍿 Phim mới cập nhật (KKPhim)")
                clear
                anisub_need_module kkphim_browse_menu "phim (src/movie/)" && kkphim_browse_menu
                ;;
            *"Đọc Truyện Tranh"*)
                clear
                anisub_need_module manga_main_menu "truyện tranh (src/comic/)" && manga_main_menu
                ;;
            "📂 Xem từ Local Anidata") play_anidata_local ;;
            "📜 Lịch sử xem Anime") show_history ;;
            "⭐ Anime yêu thích")
                fav_line=$(show_favorites)
                if [ $? -eq 0 ]; then
                     fname=$(echo "$fav_line" | cut -d'|' -f1)
                     fslug=$(echo "$fav_line" | cut -d'|' -f2)
                     fserver=$(echo "$fav_line" | cut -d'|' -f3)
                     # Lấy lại danh sách tập từ $SOURCE_NAME vì link m3u8 cũ đã hết hạn
                     clear
                     kkphim_play_movie "$fname" "$fslug" "Yêu thích" "$fserver"
                fi
                ;;
            "⚙️ Cài đặt") show_settings ;;
            "🔄 Cập nhật") update_script ;;
            "🚪 Thoát"*) exit 0 ;;
        esac
    done
}

# --- ENTRY POINT ---
# Toàn bộ phần khởi động nằm trong hàm này để:
#   • dòng CUỐI file luôn là 1 lời gọi duy nhất -> tests/bọc ngoài có thể bỏ nó đi
#     (sed '$d') rồi `source` để lấy hàm mà không mở menu;
#   • khi bị `source` (không phải chạy trực tiếp) thì không làm gì cả.
anisub_main_entry() {
    [ "${ANISUB_EXECUTED:-0}" = "1" ] || return 0

    if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-v" ]; then
        echo "anisub $ANISUB_VERSION"
        exit 0
    fi

    # Bảo đảm có src/ trước khi dùng bất cứ thứ gì cần nguồn (tự tải nếu thiếu).
    # Đặt SAU --version để "anisub --version" không bao giờ phải chờ mạng.
    if ! anisub_ensure_sources; then
        exit 1
    fi

    # ANISUB_HELPER: chế độ chạy ngầm để fzf gọi lại mỗi lần gõ (reload/preview).
    # Làm vậy để mọi lời gọi API đều đi qua đúng một nguồn cấu hình KKPhim.
    if [ -n "${ANISUB_HELPER:-}" ]; then
        load_config
        case "$ANISUB_HELPER" in
            search) kkphim_helper_search ;;
            poster) kkphim_helper_poster "$1" ;;
            *) exit 1 ;;
        esac
        exit 0
    fi

    # Kiểm tra sức khoẻ toàn bộ: module, phụ thuộc, nguồn phim/truyện (không cần bấm gì)
    if [ "${1:-}" = "--doctor" ] || [ "${1:-}" = "--check" ]; then
        load_config
        anisub_doctor
        exit $?
    fi

    # Chẩn đoán luồng đọc từ dòng lệnh: ./anisub.sh --manga-selftest [slug|URL]
    if [ "${1:-}" = "--manga-selftest" ]; then
        load_config
        manga_selftest "${2:-}"
        exit $?
    fi

    main "$@"
}

anisub_main_entry "$@"
