#!/bin/bash

ANISUB_VERSION="2026.11.12c"

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
# Chặn quảng cáo chèn trong playlist HLS (.m3u8): KKPhim nhét khối segment quảng
# cáo ngay trong playlist (thường gặp ở ~phút 15 của phim), bọc bởi #EXT-X-CUE-OUT
# / #EXT-X-CUE-IN. anisub tải playlist, bỏ cả khối quảng cáo + segment khớp mẫu
# rồi mới đưa cho mpv/vlc. Lọc lỗi -> tự phát link gốc.
DEFAULT_KKPHIM_AD_BLOCK=1
# Mẫu nhận diện quảng cáo: so khớp NGUYÊN một thành phần host/đường dẫn
# (tách theo / . - _ ? & =), nên "media"/"load"/"shadow"/"segment_1" không bị
# xoá nhầm; query được bỏ qua nên "?ad=0" cũng không bị coi là quảng cáo.
DEFAULT_KKPHIM_AD_PATTERNS="ad,ads,advert,adserver,adservice,adtag,adslot,preroll,pre-roll,midroll,mid-roll,postroll,quangcao,quang-cao,promo,sponsor,vast,vmap,scte,banner"
# Chọn variant khi playlist là master: first (mặc định, giống trình phát trước
# đây) | max (nét nhất) | số thứ tự (1..N). Variant quá nặng so với mạng -> khựng.
DEFAULT_KKPHIM_AD_VARIANT="first"
# 1 = bỏ luôn khối segment nằm ở tên miền khác với CDN của phim (adserver)
DEFAULT_KKPHIM_AD_FOREIGN_HOST=1
KKPHIM_USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
KKPHIM_SITE_URL=""
KKPHIM_API_URL=""
KKPHIM_CDN_URL=""
KKPHIM_REFERER=""
KKPHIM_SEARCH_LIMIT=""
KKPHIM_DETAIL_TTL=""
KKPHIM_SERVER_PREF=""
KKPHIM_AD_BLOCK=""
KKPHIM_AD_PATTERNS=""
KKPHIM_AD_VARIANT=""
KKPHIM_AD_FOREIGN_HOST=""
KKPHIM_ADFREE_FILE=""
KKPHIM_ADFREE_STATS=""
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
# toon18x   : https://toon18x.com   - webtoon/manhwa 18+ có bản tiếng Việt (/vi);
#             trang render sẵn ở server, chương đọc qua API /api/v1/manga/<slug>/chapters,
#             ảnh trang trên tv1.toon18x.com. URL chương = /vi/manga/<slug>/chapter/<số>.
# kagane    : https://kagane.moe    - site tổng hợp manga/manhwa/manhua đa ngôn
#             ngữ, có API JSON riêng. Truyện /series/<slug>-<uuid>, đọc
#             /series/<slug>-<uuid>/reader/<book_id>; ảnh trang cần token ngắn
#             hạn (anisub tự xin + tự làm mới).
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
# Khi DNS nhà mạng chặn (e-hentai hay bị), anisub tự hỏi IP qua DNS-over-HTTPS
# rồi nối thẳng bằng --resolve. auto = tự dùng khi DNS hỏng, off = tắt.
DEFAULT_MANGA_DOH="auto"
# Proxy riêng cho phần truyện (để trống = dùng biến môi trường https_proxy như curl).
# Ví dụ: socks5h://127.0.0.1:1080 (v2rayN / clash / ssh -D 1080).
DEFAULT_MANGA_PROXY=""
DEFAULT_EHENTAI_TAG="language:vietnamese"
DEFAULT_EHENTAI_CHUNK=20
DEFAULT_EHENTAI_COOKIE=""
KAGANE_LANG=""
KAGANE_COOKIE=""
# Toon18x: mã ngôn ngữ trên URL (để trống = DEFAULT_TOON18X_LOCALE = "vi").
TOON18X_LOCALE=""
# Kagane: ngôn ngữ muốn lọc khi tìm/duyệt ("" = mọi ngôn ngữ, vd "vi" hoặc "en")
# và cookie trình duyệt (chỉ cần cho truyện 18+ đã qua bước xác nhận tuổi).
DEFAULT_KAGANE_BASE_URL="https://kagane.moe"
DEFAULT_KAGANE_LANG=""
DEFAULT_KAGANE_COOKIE=""
# Toon18x: gốc site + mã ngôn ngữ trên URL (/vi). Đổi ngôn ngữ: TOON18X_LOCALE="en".
DEFAULT_TOON18X_BASE_URL="https://toon18x.com"
DEFAULT_TOON18X_LOCALE="vi"
MANGA_SOURCE=""
MANGA_BASE_URL=""
MANGA_SEARCH_FEEDS=""
MANGA_SEARCH_PAGES=""
MANGA_IMAGE_PROTOCOL=""
MANGA_READER_PROXY="$DEFAULT_MANGA_READER_PROXY"
MANGA_DOH="$DEFAULT_MANGA_DOH"
MANGA_PROXY=""
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
        echo "MANGA_DOH=\"$DEFAULT_MANGA_DOH\"" >> "$CONFIG_FILE"
        echo "MANGA_PROXY=\"$DEFAULT_MANGA_PROXY\"" >> "$CONFIG_FILE"
        echo "EHENTAI_TAG=\"$DEFAULT_EHENTAI_TAG\"" >> "$CONFIG_FILE"
        echo "EHENTAI_CHUNK=\"$DEFAULT_EHENTAI_CHUNK\"" >> "$CONFIG_FILE"
        echo "EHENTAI_COOKIE=\"$DEFAULT_EHENTAI_COOKIE\"" >> "$CONFIG_FILE"
        echo "KAGANE_LANG=\"$DEFAULT_KAGANE_LANG\"" >> "$CONFIG_FILE"
        echo "KAGANE_COOKIE=\"$DEFAULT_KAGANE_COOKIE\"" >> "$CONFIG_FILE"
        echo "TOON18X_LOCALE=\"$DEFAULT_TOON18X_LOCALE\"" >> "$CONFIG_FILE"
        echo "# --- NGUỒN PHIM KKPHIM (sửa nếu KKPhim đổi domain) ---" >> "$CONFIG_FILE"
        echo "KKPHIM_SITE_URL=\"$DEFAULT_KKPHIM_SITE_URL\"" >> "$CONFIG_FILE"
        echo "KKPHIM_API_URL=\"$DEFAULT_KKPHIM_API_URL\"" >> "$CONFIG_FILE"
        echo "KKPHIM_CDN_URL=\"$DEFAULT_KKPHIM_CDN_URL\"" >> "$CONFIG_FILE"
        echo "KKPHIM_REFERER=\"$DEFAULT_KKPHIM_REFERER\"" >> "$CONFIG_FILE"
        echo "KKPHIM_SEARCH_LIMIT=\"$DEFAULT_KKPHIM_SEARCH_LIMIT\"" >> "$CONFIG_FILE"
        echo "KKPHIM_DETAIL_TTL=\"$DEFAULT_KKPHIM_DETAIL_TTL\"" >> "$CONFIG_FILE"
        echo "KKPHIM_SERVER_PREF=\"$DEFAULT_KKPHIM_SERVER_PREF\"" >> "$CONFIG_FILE"
        echo "KKPHIM_AD_BLOCK=\"$DEFAULT_KKPHIM_AD_BLOCK\"" >> "$CONFIG_FILE"
        echo "KKPHIM_AD_PATTERNS=\"$DEFAULT_KKPHIM_AD_PATTERNS\"" >> "$CONFIG_FILE"
        echo "KKPHIM_AD_VARIANT=\"$DEFAULT_KKPHIM_AD_VARIANT\"" >> "$CONFIG_FILE"
        echo "KKPHIM_AD_FOREIGN_HOST=\"$DEFAULT_KKPHIM_AD_FOREIGN_HOST\"" >> "$CONFIG_FILE"
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
    MANGA_DOH=${MANGA_DOH:-$DEFAULT_MANGA_DOH}
    MANGA_PROXY=${MANGA_PROXY:-$DEFAULT_MANGA_PROXY}
    # e-hentai: tag mặc định + số trang mỗi chapter + cookie đăng nhập (nếu có)
    EHENTAI_TAG=${EHENTAI_TAG:-$DEFAULT_EHENTAI_TAG}
    EHENTAI_CHUNK=${EHENTAI_CHUNK:-$DEFAULT_EHENTAI_CHUNK}
    EHENTAI_COOKIE=${EHENTAI_COOKIE:-$DEFAULT_EHENTAI_COOKIE}
    # Kagane: ngôn ngữ lọc + cookie (để trống = mọi ngôn ngữ / chỉ truyện công khai)
    KAGANE_LANG=${KAGANE_LANG:-$DEFAULT_KAGANE_LANG}
    KAGANE_COOKIE=${KAGANE_COOKIE:-$DEFAULT_KAGANE_COOKIE}
    TOON18X_LOCALE=${TOON18X_LOCALE:-$DEFAULT_TOON18X_LOCALE}
    # Cấu hình nguồn phim KKPhim: config.cfg > giá trị mặc định
    KKPHIM_SITE_URL=${KKPHIM_SITE_URL:-$DEFAULT_KKPHIM_SITE_URL}
    KKPHIM_API_URL=${KKPHIM_API_URL:-$DEFAULT_KKPHIM_API_URL}
    KKPHIM_CDN_URL=${KKPHIM_CDN_URL:-$DEFAULT_KKPHIM_CDN_URL}
    KKPHIM_REFERER=${KKPHIM_REFERER:-$DEFAULT_KKPHIM_REFERER}
    KKPHIM_SEARCH_LIMIT=${KKPHIM_SEARCH_LIMIT:-$DEFAULT_KKPHIM_SEARCH_LIMIT}
    KKPHIM_DETAIL_TTL=${KKPHIM_DETAIL_TTL:-$DEFAULT_KKPHIM_DETAIL_TTL}
    KKPHIM_SERVER_PREF=${KKPHIM_SERVER_PREF:-$DEFAULT_KKPHIM_SERVER_PREF}
    KKPHIM_AD_BLOCK=${KKPHIM_AD_BLOCK:-$DEFAULT_KKPHIM_AD_BLOCK}
    KKPHIM_AD_PATTERNS=${KKPHIM_AD_PATTERNS:-$DEFAULT_KKPHIM_AD_PATTERNS}
    KKPHIM_AD_VARIANT=${KKPHIM_AD_VARIANT:-$DEFAULT_KKPHIM_AD_VARIANT}
    KKPHIM_AD_FOREIGN_HOST=${KKPHIM_AD_FOREIGN_HOST:-$DEFAULT_KKPHIM_AD_FOREIGN_HOST}
    # Playlist đã lọc + file thống kê dùng chung 1 đường dẫn cố định để trap dọn được
    KKPHIM_ADFREE_FILE="${TMPDIR:-/tmp}/anisub-adfree-$$.m3u8"
    KKPHIM_ADFREE_STATS="${TMPDIR:-/tmp}/anisub-adfree-$$.stats"
    # Chuỗi header cho ffmpeg (mỗi header cách nhau bằng CRLF thật)
    KKPHIM_FFMPEG_HEADERS="Referer: ${KKPHIM_REFERER}"$'\r\n'"User-Agent: ${KKPHIM_USER_AGENT}"$'\r\n'
    mkdir -p "$DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR/cut"
    mkdir -p "$DOWNLOAD_DIR/merged"
    mkdir -p "$CACHE_DIR"
    touch "$HISTORY_FILE" "$FAVORITES_FILE" "$MANGA_HISTORY_FILE" "$MANGA_FAVORITES_FILE"
}
save_config() {
    # Bảo đảm có thư mục cấu hình (lần đầu chạy / người dùng vừa xoá ~/.config/anisub_cli)
    if ! mkdir -p "$CONFIG_DIR" 2>/dev/null; then
        echo "⚠️ Không tạo được thư mục cấu hình: $CONFIG_DIR" >&2
        return 1
    fi
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
        echo "MANGA_DOH=\"$MANGA_DOH\""
        echo "MANGA_PROXY=\"$MANGA_PROXY\""
        echo "EHENTAI_TAG=\"$EHENTAI_TAG\""
        echo "EHENTAI_CHUNK=\"$EHENTAI_CHUNK\""
        echo "EHENTAI_COOKIE=\"$EHENTAI_COOKIE\""
        echo "KAGANE_LANG=\"$KAGANE_LANG\""
        echo "KAGANE_COOKIE=\"$KAGANE_COOKIE\""
        echo "TOON18X_LOCALE=\"${TOON18X_LOCALE:-$DEFAULT_TOON18X_LOCALE}\""
        echo "# --- NGUỒN PHIM KKPHIM (sửa nếu KKPhim đổi domain) ---"
        echo "KKPHIM_SITE_URL=\"$KKPHIM_SITE_URL\""
        echo "KKPHIM_API_URL=\"$KKPHIM_API_URL\""
        echo "KKPHIM_CDN_URL=\"$KKPHIM_CDN_URL\""
        echo "KKPHIM_REFERER=\"$KKPHIM_REFERER\""
        echo "KKPHIM_SEARCH_LIMIT=\"$KKPHIM_SEARCH_LIMIT\""
        echo "KKPHIM_DETAIL_TTL=\"$KKPHIM_DETAIL_TTL\""
        echo "KKPHIM_SERVER_PREF=\"$KKPHIM_SERVER_PREF\""
        echo "KKPHIM_AD_BLOCK=\"${KKPHIM_AD_BLOCK:-$DEFAULT_KKPHIM_AD_BLOCK}\""
        echo "KKPHIM_AD_PATTERNS=\"${KKPHIM_AD_PATTERNS:-$DEFAULT_KKPHIM_AD_PATTERNS}\""
        echo "KKPHIM_AD_VARIANT=\"${KKPHIM_AD_VARIANT:-$DEFAULT_KKPHIM_AD_VARIANT}\""
        echo "KKPHIM_AD_FOREIGN_HOST=\"${KKPHIM_AD_FOREIGN_HOST:-$DEFAULT_KKPHIM_AD_FOREIGN_HOST}\""
    } > "$CONFIG_FILE" 2>/dev/null || {
        echo "⚠️ Không ghi được cấu hình: $CONFIG_FILE" >&2
        return 1
    }
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
# Mã thoát của curl ở lần tải HTML gần nhất (6 DNS, 7 không kết nối, 28 timeout,
# 35/60 TLS...) -> để báo đúng nguyên nhân thay vì chỉ "HTTP 000" chung chung.
ANISUB_CURL_ERR_FILE="${ANISUB_STATUS_FILE}.curl"
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
#   src/comic/kagane.sh     nguồn kagane.moe (manga/manhwa/manhua đa ngôn ngữ)
#   src/comic/toon18x.sh    nguồn toon18x.com (webtoon/manhwa 18+, bản tiếng Việt)
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

# Hàm bắt buộc phải có SAU khi nạp module. Thiếu = bộ nguồn thiếu/hỏng file
# (lỗi kinh điển: src/ chỉ có movie/ nên menu in "manga_source_label: command not found").
ANISUB_REQUIRED_FUNCS="manga_source_label manga_main_menu fetch_chapter_list kkphim_search_menu kkphim_browse_menu"

# Các module nguồn mà bản anisub.sh NÀY cần có. Thiếu file nào = bộ src/ trên máy
# là bản cũ (ví dụ: chưa có nguồn toon18x) -> anisub tự tải lại bộ nguồn, và nếu
# không tải được thì nói rõ thiếu nguồn nào thay vì im lặng.
ANISUB_EXPECTED_COMIC_MODULES="core.sh nettruyen.sh truyenvn.sh ehentai.sh kagane.sh toon18x.sh"

# In ra tên các module còn thiếu trong thư mục nguồn $1 (không in gì = đủ bộ)
anisub_missing_modules() {
    local dir="${1:-}" m
    [ -n "$dir" ] || return 1
    for m in $ANISUB_EXPECTED_COMIC_MODULES; do
        [ -f "$dir/comic/$m" ] || printf '%s\n' "$m"
    done
}

# Tên nguồn để in cho người dùng từ tên file module
anisub_module_source_name() {
    case "${1:-}" in
        core.sh)      printf 'engine' ;;
        nettruyen.sh) printf 'nettruyen' ;;
        truyenvn.sh)  printf 'truyenvn' ;;
        ehentai.sh)   printf 'e-hentai' ;;
        kagane.sh)    printf 'kagane' ;;
        toon18x.sh)   printf 'toon18x' ;;
        *)            printf '%s' "${1%.sh}" ;;
    esac
}

# "kagane, toon18x" - danh sách nguồn còn thiếu, để in trong câu thông báo
anisub_missing_source_names() {
    local m out=""
    for m in $(anisub_missing_modules "${1:-}"); do
        out="${out:+$out, }$(anisub_module_source_name "$m")"
    done
    printf '%s' "$out"
}

# Dự phòng: nếu module truyện chưa nạp được, menu chính vẫn hiển thị được bình
# thường và bấm vào sẽ báo lỗi rõ ràng (không lộ "command not found" ra màn hình).
manga_source_label() {
    printf '%s' "${MANGA_SOURCE:-${DEFAULT_MANGA_SOURCE:-nettruyen}}"
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
    [ "$found" -gt 0 ] || return 1

    local fn miss=""
    for fn in $ANISUB_REQUIRED_FUNCS; do
        declare -F "$fn" > /dev/null 2>&1 || miss="$miss $fn"
    done
    if [ -n "$miss" ]; then
        echo "❌ Bộ nguồn trong $root nạp thiếu:$miss" >&2
        echo "   Thường do thiếu/hỏng file trong $root/comic/ (cần core.sh, nettruyen.sh, truyenvn.sh, ehentai.sh)" >&2
        echo "   Đang có: $(ls "$root"/comic/*.sh 2>/dev/null | xargs -r -n1 basename 2>/dev/null | tr '\n' ' ')" >&2
        return 1
    fi
    return 0
}

# Tải bộ file nguồn (src/) từ GitHub về $1 (mặc định: cạnh script).
# Dùng cho máy chỉ có mỗi anisub.sh (bản cũ chỉ tải 1 file khi 🔄 Cập nhật).
anisub_fetch_sources() {
    local dest="${1:-$SCRIPT_DIR}" tmpdir archive root
    [ -z "$dest" ] && return 1
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/anisub-src.XXXXXX" 2>/dev/null) || return 1
    archive="$tmpdir/anisub.tar.gz"
    echo "⏳ Đang tải bộ file nguồn từ GitHub (~28MB, chờ chút)..."
    if ! curl -fsSL --max-time 180 -o "$archive" "$UPDATE_REPO_URL" 2>/dev/null; then
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

# Bộ src/ đang có nhưng THIẾU module (bản cũ): tải lại bộ nguồn mới vào đúng thư mục
# đó rồi nạp lại. Trả 0 nếu sau khi tải đã đủ module (khi đó ANISUB_SRC_DIR đã trỏ đúng).
anisub_heal_sources() {
    local dir="${1:-}" parent
    [ -n "$dir" ] && [ -d "$dir" ] || return 1
    [ -z "$(anisub_missing_modules "$dir")" ] && return 0
    local names
    names=$(anisub_missing_source_names "$dir")
    echo ""
    echo "🔧 Bộ file nguồn trên máy là bản cũ: thiếu nguồn $names."
    echo "   Đang tự tải bộ nguồn mới từ GitHub (chỉ 1 lần)..."
    case "$dir" in
        */src) parent="${dir%/src}" ;;
        *)     parent="" ;;
    esac
    if [ -z "$parent" ] || [ ! -w "$parent" ]; then
        echo "   ❌ Không ghi được vào $dir (thiếu quyền)."
        echo "      Cách sửa: chạy anisub ở thư mục có quyền ghi, hoặc cập nhật bằng git:"
        echo "        git -C \"${parent:-$dir}\" pull"
        return 1
    fi
    # Bản cài bằng git (có .git, cây làm việc sạch) -> git pull cho gọn, giữ repo khớp
    if [ -d "$parent/.git" ] && command -v git > /dev/null 2>&1 \
       && [ -z "$(git -C "$parent" status --porcelain 2>/dev/null)" ]; then
        echo "   (bản cài bằng git - chạy: git -C \"$parent\" pull)"
        if git -C "$parent" pull --ff-only -q 2>/dev/null; then
            if anisub_load_sources "$dir" && [ -z "$(anisub_missing_modules "$dir")" ]; then
                ANISUB_SRC_DIR="$dir"
                ANISUB_SOURCES_OK=1
                ANISUB_MISSING_MODULES=""
                echo "   ✅ Đã cập nhật bộ nguồn bằng git: $dir"
                sleep 1
                return 0
            fi
        fi
        echo "   ⚠️ git pull không mang về đủ module - chuyển sang tải bản phát hành."
    fi
    if ! anisub_fetch_sources "$parent"; then
        echo "   ❌ Không tải được bộ nguồn mới (mạng lỗi hoặc GitHub chặn)."
        echo "      Có mạng lại thì chạy: ./anisub.sh --update   (hoặc ./anisub.sh --doctor)"
        return 1
    fi
    if anisub_load_sources "$dir"; then
        local still
        still=$(anisub_missing_modules "$dir")
        if [ -z "$still" ]; then
            ANISUB_SRC_DIR="$dir"
            ANISUB_SOURCES_OK=1
            ANISUB_MISSING_MODULES=""
            echo "   ✅ Đã cập nhật bộ nguồn: $dir"
            sleep 1
            return 0
        fi
        echo "   ⚠️ Bản tải về vẫn thiếu module: $(anisub_missing_source_names "$dir")"
    fi
    return 1
}

# Bảo đảm LUÔN có nguồn trước khi mở menu: tìm quanh máy -> tự tải -> báo lỗi rõ ràng.
# Nhờ vậy lỗi "bấm Đọc Truyện Tranh mà không có gì xảy ra" không còn xảy ra nữa.
anisub_ensure_sources() {
    [ "${ANISUB_SOURCES_OK:-0}" = "1" ] && return 0
    local d dest tried=" " looked_ok=0 fallback=""

    # 1) Thử lần lượt mọi thư mục nguồn có sẵn: env -> cạnh script -> thư mục config.
    #    "Trông có vẻ đúng" chưa đủ (file có thể hỏng), nên phải nạp thật mới tin.
    #    Bộ nạp được nhưng THIẾU module (src/ bản cũ) chỉ dùng làm phương án dự phòng,
    #    vì nó thiếu nguồn mới (toon18x, kagane...) -> thử các thư mục khác trước.
    for d in "${ANISUB_SRC_DIR:-}" "${SCRIPT_DIR:-}/src" "${CONFIG_DIR:-}/src"; do
        [ -n "$d" ] || continue
        anisub_src_looks_ok "$d" || continue
        looked_ok=1
        case "$tried" in *" $d "*) continue ;; esac
        tried="$tried$d "
        if anisub_load_sources "$d"; then
            if [ -z "$(anisub_missing_modules "$d")" ]; then
                ANISUB_SRC_DIR="$d"
                ANISUB_SOURCES_OK=1
                ANISUB_MISSING_MODULES=""
                return 0
            fi
            [ -z "$fallback" ] && fallback="$d"
            anisub_debug_log "src thieu module: $d (thieu: $(anisub_missing_modules "$d" | tr '\n' ' '))"
        fi
    done

    # 1b) Chỉ còn bộ src/ cũ (thiếu module) -> tự tải lại bộ nguồn rồi dùng
    if [ -n "$fallback" ]; then
        if anisub_heal_sources "$fallback"; then
            return 0
        fi
        # Tải không được (mạng hỏng?) -> vẫn chạy tiếp bằng bộ cũ, nhưng nói rõ thiếu gì
        ANISUB_SRC_DIR="$fallback"
        ANISUB_SOURCES_OK=1
        ANISUB_MISSING_MODULES=$(anisub_missing_modules "$fallback" | tr '\n' ' ')
        echo ""
        echo "⚠️ Đang dùng bộ nguồn cũ ở $fallback"
        echo "   Thiếu nguồn: $(anisub_missing_source_names "$fallback")"
        echo "   → các nguồn này sẽ KHÔNG hiện trong 📚 Nguồn truyện cho tới khi cập nhật xong."
        echo "   Thử lại khi có mạng: ./anisub.sh --update  (hoặc ./anisub.sh --doctor)"
        echo ""
        sleep 2
        return 0
    fi

    # 2) Có src/ mà không nạp được (file hỏng / tải dở) -> KHÔNG ghi đè lên src/ của
    #    người dùng, báo rõ file nào để họ tự sửa hoặc clone lại.
    if [ "$looked_ok" = "1" ]; then
        echo "❌ Có thư mục src/ nhưng không nạp được module nào."
        echo "   Thư mục đã thử: ${ANISUB_SRC_DIR:-$SCRIPT_DIR/src}"
        echo ""
        echo "   Cách sửa: ./anisub.sh --doctor     (chỉ ra file nào hỏng)"
        echo "             hoặc clone lại bản đầy đủ:"
        echo "             git clone https://github.com/NiyakiPham/anisub.git ~/anisub && cd ~/anisub && ./anisub.sh"
        return 1
    fi

    # 3) Chưa có src/ -> tự tải về cạnh script (không ghi được thì để trong thư mục config)
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    for dest in "$SCRIPT_DIR" "$CONFIG_DIR"; do
        [ -n "$dest" ] && [ -w "$dest" ] || continue
        case "$tried" in *" $dest/src "*) continue ;; esac
        tried="$tried$dest/src "
        anisub_fetch_sources "$dest" || continue
        # Dùng đúng thư mục vừa tải — không dò lại từ đầu (env có thể trỏ vào chỗ hỏng)
        if [ -d "$dest/src" ] && anisub_load_sources "$dest/src"; then
            ANISUB_SRC_DIR="$dest/src"
            ANISUB_SOURCES_OK=1
            echo "✅ Đã tải bộ file nguồn: $ANISUB_SRC_DIR"
            sleep 1
            return 0
        fi
    done

    echo "❌ Không có bộ file nguồn src/ dùng được (cần cả movie/ và comic/)."
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
ANISUB_MISSING_MODULES=""
if _anisub_src=$(anisub_find_src); then
    ANISUB_SRC_DIR="$_anisub_src"
    if anisub_load_sources "$ANISUB_SRC_DIR"; then
        # Nạp được nhưng thiếu module (bộ src/ cũ) thì CHƯA tính là đủ: để
        # anisub_ensure_sources tự tải bộ nguồn mới (nhờ vậy nguồn mới như
        # toon18x mới hiện ra trong ⚙️ Cài đặt → 📚 Nguồn truyện).
        ANISUB_MISSING_MODULES=$(anisub_missing_modules "$ANISUB_SRC_DIR" | tr '\n' ' ')
        [ -z "$ANISUB_MISSING_MODULES" ] && ANISUB_SOURCES_OK=1
    fi
fi
unset _anisub_src

# --- LOG CHẨN ĐOÁN (nhỏ, xoay vòng) ------------------------------------------
# Ghi lại các bước then chốt để khi "bấm vào không có gì xảy ra" vẫn có dữ kiện:
# menu truyện có được vẽ không, fzf trả về gì, nguồn nào đang dùng.
anisub_debug_log() {
    [ -n "${1:-}" ] || return 0
    mkdir -p "$CACHE_DIR" 2>/dev/null || return 0
    printf '%s  %s\n' "$(date '+%H:%M:%S')" "$1" >> "$CACHE_DIR/anisub-debug.log" 2>/dev/null || return 0
    local n
    n=$(wc -l < "$CACHE_DIR/anisub-debug.log" 2>/dev/null || echo 0)
    if [ "${n:-0}" -gt 300 ]; then
        tail -n 200 "$CACHE_DIR/anisub-debug.log" > "$CACHE_DIR/anisub-debug.log.tmp" 2>/dev/null \
            && mv -f "$CACHE_DIR/anisub-debug.log.tmp" "$CACHE_DIR/anisub-debug.log" 2>/dev/null
    fi
    return 0
}

# --- SETTINGS & UPDATE ---
show_settings() {
    while true; do
        local manga_line missing_txt
        manga_line="📚 Nguồn truyện: $(manga_source_label) (${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL})"
        missing_txt=$(anisub_missing_source_names "${ANISUB_SRC_DIR:-}")
        [ -n "$missing_txt" ] && manga_line="$manga_line  ⚠️ thiếu nguồn: $missing_txt"
        opt=$(echo -e "🎬 Đổi trình phát (Hiện tại: $PLAYER)\n📁 Đổi thư mục tải (Hiện tại: $DOWNLOAD_DIR)\n🎞 Nguồn phim: $SOURCE_NAME ($KKPHIM_SITE_URL)\n$manga_line\n🖼️ Kích thước ảnh manga (Hiện tại: ${MANGA_IMAGE_SCALE}%)\n🔙 Quay lại" | fzf --prompt="⚙️ Cài đặt > ")
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
                # Bộ src/ cũ (thiếu module) -> nói rõ + tự tải lại, để nguồn mới
                # (toon18x, kagane...) hiện ra ngay trong menu nguồn truyện.
                local miss_now
                miss_now=$(anisub_missing_source_names "${ANISUB_SRC_DIR:-}")
                if [ -n "$miss_now" ]; then
                    echo ""
                    echo "⚠️ Bộ nguồn trên máy là bản cũ: thiếu nguồn $miss_now."
                    echo "   Vì vậy các nguồn mới chưa hiện trong danh sách nguồn truyện."
                    read -r -p "Tải bộ nguồn mới ngay? (Y/n): " inp
                    case "${inp:-Y}" in
                        [nN]*) echo "   ↩️ Bỏ qua - nguồn $miss_now sẽ chưa dùng được."; sleep 1 ;;
                        *)     anisub_heal_sources "$ANISUB_SRC_DIR" || \
                                   echo "   ⏭ Vẫn mở menu nguồn với bộ cũ." ; sleep 1 ;;
                    esac
                fi
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
    echo "⏳ Đang tải bản mới từ GitHub (~28MB)..."
    if ! curl -fsSL --max-time 180 -o "$archive" "$UPDATE_REPO_URL"; then
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
    # So sánh version thôi CHƯA đủ: bộ src/ có thể là bản cũ (thiếu module như toon18x)
    # dù anisub.sh đã đúng version -> phải cài lại bộ nguồn.
    local missing_here=""
    if [ -d "${SCRIPT_DIR}/src" ]; then
        missing_here=$(anisub_missing_source_names "${SCRIPT_DIR}/src")
    else
        missing_here="toàn bộ src/"
    fi
    if [ "$remote_ver" = "$ANISUB_VERSION" ] && [ -z "$missing_here" ]; then
        echo "✅ Đang là bản mới nhất ($ANISUB_VERSION)."
        rm -rf "$tmpdir"
        sleep 1
        return 0
    fi
    if [ "$remote_ver" = "$ANISUB_VERSION" ]; then
        echo "ℹ️ Code đã là $ANISUB_VERSION nhưng bộ nguồn còn thiếu: $missing_here"
        echo "   → cài lại bộ file nguồn (src/) để có đủ nguồn."
    else
        echo "🔁 Có bản mới: ${remote_ver:-?} (đang dùng $ANISUB_VERSION). Đang cài..."
    fi
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
        local miss_mod
        miss_mod=$(anisub_missing_source_names "${ANISUB_SRC_DIR:-/nonexistent}")
        if [ -n "$miss_mod" ]; then
            echo "   ⚠️ Thiếu module nguồn: $miss_mod → bộ src/ là bản cũ"
            echo "      (chạy ./anisub.sh --update để tải lại bộ nguồn)"
        fi
    fi
    echo "📚 Truyện : $(manga_source_label) · ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
    echo "🎬 Phim   : $SOURCE_NAME · $KKPHIM_API_URL"
    local fzf_ver
    fzf_ver=$(fzf --version 2>/dev/null | head -1)
    [ -n "$fzf_ver" ] || fzf_ver="❌ chưa cài"
    echo "🐚 Môi trường: bash ${BASH_VERSION%%(*} · TERM=${TERM:-?} · fzf $fzf_ver"
    if [ -d "${SCRIPT_DIR:-}/.git" ] && command -v git > /dev/null 2>&1; then
        echo "🔖 Git    : $(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo '?') · $(git -C "$SCRIPT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?') · $(git -C "$SCRIPT_DIR" log -1 --format=%cd --date=short 2>/dev/null || echo '?')"
        local behind
        behind=$(git -C "$SCRIPT_DIR" rev-list --count HEAD..origin/main 2>/dev/null || echo "")
        [ "${behind:-0}" -gt 0 ] 2>/dev/null && echo "   ⚠️ Đang chậm $behind commit so với origin/main → chạy: git pull"
    fi
    local miss=""
    declare -F main > /dev/null 2>&1 || miss="$miss main"
    declare -F manga_main_menu > /dev/null 2>&1 || miss="$miss manga_main_menu"
    declare -F fetch_chapter_list > /dev/null 2>&1 || miss="$miss fetch_chapter_list"
    declare -F kkphim_search_menu > /dev/null 2>&1 || miss="$miss kkphim_search_menu"
    if [ -z "$miss" ]; then
        echo "🧭 Hàm chính : ✅ đủ (main, manga_main_menu, fetch_chapter_list, kkphim_search_menu)"
    else
        echo "🧭 Hàm chính : ❌ thiếu:$miss  → src/ chưa nạp đủ, xem mục 'Nguồn' ở trên"
    fi
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
    if declare -F manga_is_ehentai > /dev/null 2>&1 && manga_is_ehentai; then
        anisub_netcheck
        echo
    else
        echo "🌐 Kiểm tra mạng tới nguồn truyện: ./anisub.sh --netcheck"
        echo
    fi
    manga_diagnose --no-pause
    echo
    local dlog="$CACHE_DIR/anisub-debug.log"
    if [ -s "$dlog" ]; then
        echo "🧾 8 dòng log gần nhất ($dlog):"
        tail -n 8 "$dlog" | sed 's/^/   /'
        echo
    else
        echo "🧾 Chưa có log ($dlog) — log sẽ ghi khi bạn mở 📚 Đọc Truyện Tranh."
        echo
    fi
    echo "Nếu vẫn lỗi: gửi nguyên nội dung lệnh này khi báo bug:"
    echo "   ./anisub.sh --doctor 2>&1 | tee anisub-doctor.txt"
    return 0
}

# Chặn trường hợp bấm menu mà module chưa nạp (trước đây bấm không có gì xảy ra).
# $1 = tên hàm cần có, $2 = nhãn module để báo lỗi.
anisub_need_module() {
    local fn="$1" label="$2"
    declare -F "$fn" > /dev/null 2>&1 && return 0
    # Thử cứu tại chỗ: nạp/tải lại bộ nguồn rồi kiểm tra lần nữa (khỏi phải thoát ra vào)
    echo ""
    echo "⏳ Chưa có module $label — đang thử nạp lại bộ nguồn..."
    ANISUB_SOURCES_OK=0
    anisub_ensure_sources || true
    if declare -F "$fn" > /dev/null 2>&1; then
        echo "✅ Đã nạp được module $label."
        sleep 1
        return 0
    fi
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
    trap 'rm -f "$ANISUB_STATUS_FILE" "$ANISUB_CURL_ERR_FILE" "$MANGA_COOKIE_JAR" "$ANISUB_MANGA_NAV_FILE" "${KKPHIM_ADFREE_FILE:-}" "${KKPHIM_ADFREE_STATS:-}"; kill $(jobs -p) 2>/dev/null' EXIT
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
                if anisub_need_module manga_main_menu "truyện tranh (src/comic/)"; then
                    ANISUB_MANGA_MENU_SHOWN=0
                    ANISUB_MANGA_MENU_PICKS=0
                    anisub_debug_log "main: mở 📚 menu truyện (nguồn=${MANGA_SOURCE:-mặc định}, src=${ANISUB_SRC_DIR:-?}, term=${TERM:-?})"
                    manga_main_menu
                    anisub_debug_log "main: thoát menu truyện (đã vẽ=${ANISUB_MANGA_MENU_SHOWN:-0}, số lựa chọn=${ANISUB_MANGA_MENU_PICKS:-0})"
                    # Vào menu mà chưa chọn được gì = "bấm vào không thấy gì": nói rõ ra
                    if [ "${ANISUB_MANGA_MENU_PICKS:-0}" = "0" ]; then
                        clear
                        echo "⚠️  Chưa vào được menu truyện."
                        echo "    Menu đã vẽ: $([ "${ANISUB_MANGA_MENU_SHOWN:-0}" = "1" ] && echo 'có' || echo 'KHÔNG')"
                        echo "    fzf trả về lựa chọn: ${ANISUB_MANGA_MENU_PICKS:-0} lần"
                        echo ""
                        echo "    Gửi mình kết quả lệnh này để mình chỉ đúng chỗ hỏng:"
                        echo "       ./anisub.sh --doctor"
                        printf '    Nhấn Enter để quay lại menu chính... '
                        read -r _ || true
                    fi
                fi
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

    # Kiểm tra mạng theo từng lớp (DNS -> DoH -> HTTPS): ./anisub.sh --netcheck [host]
    if [ "${1:-}" = "--netcheck" ] || [ "${1:-}" = "--net" ]; then
        load_config
        anisub_netcheck "${2:-}"
        exit $?
    fi

    # Chẩn đoán chặn quảng cáo HLS: ./anisub.sh --kkphim-ad-debug "<link .m3u8>"
    if [ "${1:-}" = "--kkphim-ad-debug" ] || [ "${1:-}" = "--ad-debug" ]; then
        load_config
        shift
        kkphim_ad_report "${1:-}"
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
