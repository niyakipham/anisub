#!/bin/bash

ANISUB_VERSION="2026.11.09f"

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
# Chặn quảng cáo chèn trong playlist HLS (.m3u8): tải playlist, bỏ các segment quảng
# cáo + marker chèn quảng cáo (CUE-OUT/IN, SCTE35) rồi phát bản đã lọc.
DEFAULT_KKPHIM_AD_BLOCK=1
# Mẫu nhận diện quảng cáo: so khớp NGUYÊN một thành phần của host/đường dẫn
# (tách theo / . - _ ? & =), nên "media"/"load"/"shadow" không bị coi là "ad".
DEFAULT_KKPHIM_AD_PATTERNS="ad,ads,advert,adserver,adservice,adtag,preroll,pre-roll,quangcao,quang-cao,promo,sponsor,vast"
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
KKPHIM_ADFREE_FILE=""
KKPHIM_FFMPEG_HEADERS=""

# Local Data File
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Đường dẫn tuyệt đối của chính script — fzf chạy reload/preview bằng shell riêng,
# CWD có thể đã bị đổi (vd sau tính năng Ghép Video) nên phải dùng đường dẫn đầy đủ.
SELF_SCRIPT="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
LOCAL_DATA_FILE="$SCRIPT_DIR/assets/aniw_export_2026-01-14.csv"

# --- NGUỒN TRUYỆN TRANH ------------------------------------------------------
# nettruyen : https://nettruyen.info - CMS kiểu NetTruyen, danh sách chương nằm
#             sẵn trong HTML (không cần API/CSRF).  URL truyện: /truyen-<slug>
#             URL chương:      /truyen-<slug>/chuong-<n>
#             Ảnh trang:       https://net.imgchapter.store/<slug>/<chap>/page_<i>.jpg
# truyenvn  : https://truyenvn.my  - cần API /webapi/stories/list-chapter,
#             URL truyện /truyen-tranh/<slug>, chương /chapter-<n> (giữ để đổi lại).
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
MANGA_SOURCE=""
MANGA_BASE_URL=""
MANGA_SEARCH_FEEDS=""
MANGA_SEARCH_PAGES=""
MANGA_IMAGE_PROTOCOL=""
MANGA_READER_PROXY="$DEFAULT_MANGA_READER_PROXY"
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
        echo "# --- NGUỒN TRUYỆN TRANH (nettruyen | truyenvn) ---" >> "$CONFIG_FILE"
        echo "MANGA_SOURCE=\"$DEFAULT_MANGA_SOURCE\"" >> "$CONFIG_FILE"
        echo "MANGA_BASE_URL=\"$DEFAULT_MANGA_BASE_URL\"" >> "$CONFIG_FILE"
        echo "MANGA_SEARCH_FEEDS=\"$DEFAULT_MANGA_SEARCH_FEEDS\"" >> "$CONFIG_FILE"
        echo "MANGA_SEARCH_PAGES=\"$DEFAULT_MANGA_SEARCH_PAGES\"" >> "$CONFIG_FILE"
        echo "MANGA_IMAGE_PROTOCOL=\"$DEFAULT_MANGA_IMAGE_PROTOCOL\"" >> "$CONFIG_FILE"
        echo "MANGA_READER_PROXY=\"$DEFAULT_MANGA_READER_PROXY\"" >> "$CONFIG_FILE"
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
        echo "# --- NGUỒN PHIM KKPHIM (sửa nếu KKPhim đổi domain) ---"
        echo "KKPHIM_SITE_URL=\"$KKPHIM_SITE_URL\""
        echo "KKPHIM_API_URL=\"$KKPHIM_API_URL\""
        echo "KKPHIM_CDN_URL=\"$KKPHIM_CDN_URL\""
        echo "KKPHIM_REFERER=\"$KKPHIM_REFERER\""
        echo "KKPHIM_AD_BLOCK=\"${KKPHIM_AD_BLOCK:-$DEFAULT_KKPHIM_AD_BLOCK}\""
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

# --- HISTORY FUNCTIONS ---
# Định dạng lịch sử: thời gian|tên phim|tên tập|link|mã slug (KKPhim)|số thứ tự server
# Hai trường cuối cho phép lấy lại link m3u8 MỚI khi xem lại (link cũ đã hết hạn).
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

# --- FAVORITES FUNCTIONS ---
# Định dạng: tên phim|slug (KKPhim)|server index (để trống với dữ liệu cũ vẫn chạy)
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

# ═══════════════════════════════════════════════════════════════════════════════
#  NGUỒN PHIM: KKPHIM  —  https://kkphim.com   (API: https://phimapi.com)
# ═══════════════════════════════════════════════════════════════════════════════
#  Toàn bộ dữ liệu phim đi qua các hàm dưới đây:
#    /v1/api/tim-kiem        -> tìm kiếm từ khóa
#    /v1/api/danh-sach/{slug} -> danh mục (phim-moi-cap-nhat, phim-le, phim-bo, hoat-hinh...)
#    /phim/{slug}             -> chi tiết phim + server phụ đề + danh sách tập + link m3u8
#  Link m3u8 do KKPhim trả về được "mint" theo từng lần gọi API và hết hạn sau vài
#  phút, nên chỉ được cache rất ngắn và luôn xin lại link khi phát lại.
# ═══════════════════════════════════════════════════════════════════════════════

kkphim_cache_prune() {
    # Dọn cache cũ hơn 3 ngày (poster / chi tiết phim)
    [ -d "$CACHE_DIR" ] || return 0
    find "$CACHE_DIR" -maxdepth 1 -type f -mtime +3 -delete 2>/dev/null
    return 0
}

# Trạng thái HTTP của lời gọi API gần nhất (để báo lỗi chính xác thay vì im lặng).
# Ghi ra file tạm nữa vì hàm API thường được gọi trong $(...) - biến toàn cục
# thay đổi trong subshell sẽ mất ở shell cha, còn file thì vẫn đọc được.
KKPHIM_HTTP_STATUS="000"
ANISUB_STATUS_FILE="${TMPDIR:-/tmp}/anisub-kkhttp.$$"

# Mã HTTP của lời gọi API gần nhất (đọc xuyên subshell)
anisub_last_http() {
    local s="${KKPHIM_HTTP_STATUS:-}"
    if { [ -z "$s" ] || [ "$s" = "000" ]; } && [ -r "$ANISUB_STATUS_FILE" ]; then
        s=$(head -c 3 "$ANISUB_STATUS_FILE" 2>/dev/null)
    fi
    printf '%s' "${s:-000}"
}

# Gọi 1 endpoint của KKPhim API, in JSON ra stdout (lỗi -> trả về 1).
# Tham số 2+ dạng key=value sẽ được curl -G --data-urlencode tự mã hoá, nhờ vậy
# từ khóa tiếng Việt / có khoảng trắng / có & không làm hỏng query string.
kkphim_api_get() {
    local path="$1"
    shift
    [ -z "$path" ] && return 1
    # Tự bù nếu chưa load_config (tránh gọi vào đường dẫn tương đối rồi fail âm thầm)
    local base="${KKPHIM_API_URL:-$DEFAULT_KKPHIM_API_URL}"
    [[ "$path" != /* ]] && path="/$path"
    local -a opts=()
    local kv
    for kv in "$@"; do
        [ -n "$kv" ] && opts+=(--data-urlencode "$kv")
    done
    local tmp status
    tmp=$(mktemp "${TMPDIR:-/tmp}/anisub-kkapi.XXXXXX" 2>/dev/null) || tmp="${TMPDIR:-/tmp}/anisub-kkapi.$$.tmp"
    status=$(curl -sS -G -L --compressed --max-time 25 --retry 2 --retry-delay 1 \
        -A "$KKPHIM_USER_AGENT" \
        -H "accept: application/json" \
        -H "accept-language: vi,en;q=0.8" \
        -H "referer: ${KKPHIM_REFERER:-$DEFAULT_KKPHIM_REFERER}" \
        -H "origin: ${KKPHIM_SITE_URL:-$DEFAULT_KKPHIM_SITE_URL}" \
        -o "$tmp" -w '%{http_code}' \
        "${opts[@]}" \
        "${base%/}${path}" 2>/dev/null)
    KKPHIM_HTTP_STATUS="${status:-000}"
    printf '%s' "$KKPHIM_HTTP_STATUS" > "$ANISUB_STATUS_FILE" 2>/dev/null || true
    case "$KKPHIM_HTTP_STATUS" in
        2??)
            if [ -s "$tmp" ]; then
                cat "$tmp"; rm -f "$tmp"
                return 0
            fi
            ;;
    esac
    rm -f "$tmp"
    return 1
}

# KKPhim trả ảnh ở 2 dạng: URL tuyệt đối (https://phimimg.com/...) hoặc đường dẫn
# tương đối (uploads/movies/...). kkphim_format_items chuẩn hoá hết về URL tuyệt đối
# bằng APP_DOMAIN_CDN_IMAGE trả về kèm trong từng response.

# Trang phim trên website KKPhim - dùng khi muốn xem trên trình duyệt
kkphim_movie_url() {
    printf '%s/phim/%s' "${KKPHIM_SITE_URL:-$DEFAULT_KKPHIM_SITE_URL}" "$1"
}

# Slug hợp lệ của KKPhim hay không? (dùng để phân biệt phim online với dữ liệu Local)
kkphim_is_online_slug() {
    case "${1:-}" in
        ""|local_file) return 1 ;;
        *) [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] ;;
    esac
}

# --- TÌM KIẾM & DANH MỤC ---
kkphim_search_json() {          # $1 = từ khóa, $2 = trang (tuỳ chọn)
    local keyword="${1:-}"
    [ "${#keyword}" -lt 2 ] && return 1
    kkphim_api_get "/v1/api/tim-kiem" \
        "keyword=$keyword" "page=${2:-1}" "limit=${KKPHIM_SEARCH_LIMIT:-24}"
}

kkphim_category_json() {        # $1 = slug danh mục, $2 = trang
    local cat="${1:-}"
    cat="${cat//[^A-Za-z0-9._-]/}"
    [ -z "$cat" ] && return 1
    kkphim_api_get "/v1/api/danh-sach/${cat}" \
        "page=${2:-1}" "limit=${KKPHIM_SEARCH_LIMIT:-24}"
}

# Chuẩn hoá JSON danh sách phim thành dòng cho fzf:
#   "Tên phim (năm)|slug|URL poster|tập hiện tại · chất lượng · ngôn ngữ · thời lượng"
# Chấp nhận cả format v1 ({data:{items}}) lẫn format cũ ({items}).
kkphim_format_items() {
    jq -r '
        def s: if . == null then "" else tostring end;
        def img($u; $cdn): ($u | s) as $x
            | if ($x == "" or $x == "null") then ""
              elif ($x | test("^https?://")) then $x
              else ($cdn + "/" + ($x | ltrimstr("/"))) end;
        def meta: [ .episode_current, .quality, .lang, .time ]
            | map(select(. != null and (. | tostring) != "")) | join(" · ");
        (.data // .) as $root
        | (($root.APP_DOMAIN_CDN_IMAGE // "") | s | sub("/+$"; "")) as $cdn
        | ($root.items // [])[]
        | "\(.name // .origin_name // "Phim") (\((if (.year|s) == "" then "?" else (.year|s) end)))|\(.slug // "")|\(img(.poster_url // .thumb_url; $cdn))|\(meta)"
    ' 2>/dev/null | sed '/^$/d'
}

# Dòng thông báo khi fzf không có kết quả (slug rỗng -> caller bỏ qua)
kkphim_notice_line() {
    printf '%s|%s||\n' "${1:-}" "__noop__"
}

# Chế độ "reload" cho fzf: đọc từ khóa từ KKPHIM_QUERY, in danh sách phim
kkphim_helper_search() {
    kkphim_search_items "${KKPHIM_QUERY:-}"
}


# Danh sách kết quả cho 1 từ khóa (dùng chung cho fzf reload và tìm 1 lần)
kkphim_search_items() {
    local q="${1:-}"
    if [ "${#q}" -lt 2 ]; then
        kkphim_notice_line "💡 Gõ tối thiểu 2 ký tự để tìm kiếm trên $SOURCE_NAME..."
        return 0
    fi
    local json lines
    if ! json=$(kkphim_search_json "$q" 1); then
        kkphim_notice_line "⚠️ $SOURCE_NAME không trả về dữ liệu (HTTP $(anisub_last_http)) - thử lại, kiểm tra mạng/proxy, hoặc đổi KKPHIM_API_URL trong Cài đặt"
        return 0
    fi
    lines=$(printf '%s' "$json" | kkphim_format_items)
    if [ -z "$lines" ]; then
        kkphim_notice_line "😶 Không tìm thấy phim nào với \"$q\" trên $SOURCE_NAME"
        return 0
    fi
    printf '%s\n' "$lines"
}

# Chế độ "preview" cho fzf: render poster KKPhim bằng chafa (cache ảnh tạm)
kkphim_helper_poster() {
    local url="${KKPHIM_POSTER:-$1}"
    if [ -z "$url" ] || [[ "$url" != http* ]]; then
        echo "🖼  Không có poster cho mục này."
        return 0
    fi
    kkphim_cache_prune
    local tmp="$CACHE_DIR/poster-$(printf '%s' "$url" | cksum | tr -d ' ').img"
    if [ ! -s "$tmp" ]; then
        curl -fsSL --max-time 20 -A "$KKPHIM_USER_AGENT" -e "$KKPHIM_REFERER" -o "$tmp" "$url" 2>/dev/null
    fi
    if [ ! -s "$tmp" ]; then
        echo "⚠️ Không tải được poster từ CDN $KKPHIM_CDN_URL"
        echo "   (mạng chậm hoặc ảnh bị gỡ)"
        return 0
    fi
    local cols="${FZF_PREVIEW_COLUMNS:-40}" rows="${FZF_PREVIEW_LINES:-20}"
    [ "$cols" -gt 10 ] 2>/dev/null || cols=40
    [ "$rows" -gt 10 ] 2>/dev/null || rows=20
    chafa --size="$((cols - 4))x$((rows - 4))" "$tmp" 2>/dev/null
    return 0
}

# Danh mục của KKPhim: "Nhãn|slug danh mục"
kkphim_categories() {
    cat <<'EOF'
🆕 Phim mới cập nhật|phim-moi-cap-nhat
🧚 Anime / Hoạt Hình|hoat-hinh
📺 Phim bộ nhiều tập|phim-bo
🎬 Phim lẻ (movie)|phim-le
🎥 Phim chiếu rạp|phim-chieu-rap
EOF
}

# Lấy 1 trang danh mục -> "Tên (năm)|slug|poster|meta" (+ dòng điều hướng trang)
kkphim_category_items() {         # $1 slug danh mục, $2 trang
    local cat="$1" page="${2:-1}" json lines total cur
    json=$(kkphim_category_json "$cat" "$page")
    if [ -z "$json" ]; then
        kkphim_notice_line "⚠️ Không tải được danh mục '$cat' (HTTP $(anisub_last_http)) - thử lại hoặc kiểm tra mạng/proxy"
        return 0
    fi
    lines=$(printf '%s' "$json" | kkphim_format_items)
    if [ -z "$lines" ]; then
        kkphim_notice_line "⚠️ Danh mục '$cat' trả về 0 phim (HTTP $(anisub_last_http)) - thử lại hoặc chọn trang khác"
        return 0
    fi
    printf '%s\n' "$lines"
    total=$(printf '%s' "$json" | jq -r '((.data // .) | (.params.pagination.totalPages // .pagination.totalPages // 1))' 2>/dev/null)
    cur=$(printf '%s' "$json" | jq -r '((.data // .) | (.params.pagination.currentPage // .pagination.currentPage // 1))' 2>/dev/null)
    [[ "$total" =~ ^[0-9]+$ ]] || total=1
    [[ "$cur" =~ ^[0-9]+$ ]] || cur="$page"
    if [ "$cur" -gt 1 ]; then
        printf '⏮  Trang trước (trang %s/%s)|__noop__||page:%s\n' "$cur" "$total" "$((cur - 1))"
    fi
    if [ "$cur" -lt "$total" ]; then
        printf '⏭  Trang sau (trang %s/%s)|__noop__||page:%s\n' "$cur" "$total" "$((cur + 1))"
    fi
    return 0
}

# --- CHI TIẾT PHIM (có cache) ---
kkphim_file_age() {
    local f="$1" mt
    mt=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null)
    [[ "$mt" =~ ^[0-9]+$ ]] || { printf '999999999'; return 0; }
    printf '%s' $(( $(date +%s) - mt ))
}

kkphim_detail_file() {
    printf '%s/kkphim-%s.json' "$CACHE_DIR" "$(printf '%s' "${1:-}" | tr -c 'A-Za-z0-9_-' '_')"
}

# Lấy JSON chi tiết phim. $2 = "1" để bỏ cache (xin link m3u8 mới nhất)
kkphim_detail_json() {
    local slug="$1" force="${2:-0}" file json status
    [ -z "$slug" ] && return 1
    file=$(kkphim_detail_file "$slug")
    if [ "$force" != "1" ] && [ -s "$file" ]; then
        if [ "$(kkphim_file_age "$file")" -lt "${KKPHIM_DETAIL_TTL:-600}" ]; then
            cat "$file"
            return 0
        fi
    fi
    json=$(kkphim_api_get "/phim/${slug}")
    status=$(printf '%s' "$json" | jq -r '.status' 2>/dev/null)
    if [ "$status" != "true" ]; then
        if [ -s "$file" ]; then           # mạng lỗi -> dùng bản cache cũ
            cat "$file"
            return 0
        fi
        return 1
    fi
    mkdir -p "$CACHE_DIR"
    printf '%s' "$json" > "$file"
    printf '%s' "$json"
}

# --- SERVER & TẬP PHIM ---
# "index|Tên server|số tập"
kkphim_server_list() {
    jq -r '(.episodes // []) | to_entries[]
        | "\(.key)|\(.value.server_name // "Server \(.key + 1)")|\((.value.server_data // []) | length)"' 2>/dev/null
}

# Các mẫu tên server khớp với KKPHIM_SERVER_PREF (đặt tên kiểu không dấu)
kkphim_server_pref_patterns() {
    local pref="${1:-auto}"
    pref="${pref,,}"   # bash hạ chữ hoa, giữ nguyên ký tự tiếng Việt
    case "$pref" in
        auto|""|default|none) return 0 ;;
        vietsub|sub|vs) printf 'vietsub\nsub\n' ;;
        long-tieng|longtieng|dub|voice|lt) printf 'lồng tiếng\nlong tieng\nlongtieng\n' ;;
        thuyet-minh|thuyetminh|tm) printf 'thuyết minh\nthuyet minh\nthuyetminh\n' ;;
        *) printf '%s\n' "$pref" ;;
    esac
}

# Chọn server theo sở thích trong config; không khớp thì lấy server đầu tiên
kkphim_pref_server_index() {
    local json="$1"
    local -a patterns
    mapfile -t patterns < <(kkphim_server_pref_patterns "${KKPHIM_SERVER_PREF:-auto}")
    local first="" chosen="" i name count pat lname
    while IFS='|' read -r i name count; do
        [[ "$i" =~ ^[0-9]+$ ]] || continue
        [ -z "$first" ] && first="$i"
        if [ -z "$chosen" ] && [ ${#patterns[@]} -gt 0 ]; then
            lname="${name,,}"
            for pat in "${patterns[@]}"; do
                [ -z "$pat" ] && continue
                case "$lname" in
                    *"$pat"*) chosen="$i"; break ;;
                esac
            done
        fi
    done < <(printf '%s\n' "$json" | kkphim_server_list)
    printf '%s' "${chosen:-$first}"
}

# Danh sách tập của 1 server: "Tên tập|m3u8|embed|slug tập"
# Nếu server chỉ có link embed thì bóc ?url=... ra để field 2 luôn là link phát.
kkphim_episode_list() {
    local json="$1" idx="${2:-0}" raw="" line="" direct=""
    [[ "$idx" =~ ^[0-9]+$ ]] || idx=0
    raw=$(printf '%s' "$json" | jq -r --argjson i "$idx" '
        def s: if . == null then "" else tostring end;
        (.episodes // []) as $eps
        | (if ($i >= 0 and $i < ($eps | length)) then $eps[$i] else {} end) as $srv
        | (($srv.server_data) // [])[]
        | "\(.name // .slug // "Tập")|\(.link_m3u8 | s)|\(.link_embed | s)|\(.slug | s)"
    ' 2>/dev/null)
    [ -z "$raw" ] && return 0
    if ! printf '%s\n' "$raw" | grep -qE '^[^|]*\|\|'; then
        printf '%s' "$raw"
        return 0
    fi
    local out=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if [[ "$line" =~ ^[^|]*\|\| ]]; then
            if direct=$(kkphim_stream_url_from_line "$line"); then
                line=$(printf '%s' "$line" | awk -F'|' -v OFS='|' -v d="$direct" '{$2=d; print}')
            fi
        fi
        out+="$line"$'\n'
    done <<< "$raw"
    printf '%s' "${out%$'\n'}"
}

# Bóc link phát trực tiếp từ 1 dòng tập phim.
# Ưu tiên link_m3u8; nếu API chỉ đưa link_embed thì bóc tham số ?url= của embed.
kkphim_stream_url_from_line() {
    local line="$1" m3u8 embed direct
    m3u8=$(printf '%s' "$line" | cut -d'|' -f2)
    case "$m3u8" in
        http*) printf '%s' "$m3u8"; return 0 ;;
    esac
    embed=$(printf '%s' "$line" | cut -d'|' -f3)
    [ -z "$embed" ] && return 1
    direct=$(printf '%s' "$embed" | sed -n 's/.*[?&]url=\([^&]*\).*/\1/p')
    [ -z "$direct" ] && return 1
    direct=$(printf '%b' "$(printf '%s' "$direct" | sed 's/+/ /g; s/%/\\x/g')")
    case "$direct" in
        http*) printf '%s' "$direct"; return 0 ;;
    esac
    return 1
}

# Link embed (trang player) của tập phim, dùng để mở trình duyệt
kkphim_embed_url_from_line() {
    printf '%s' "${1:-}" | cut -d'|' -f3
}

# Tìm 1 tập theo đúng tên trong danh sách "Tên|m3u8|embed|slug"
kkphim_find_episode() {
    printf '%s\n' "${2:-}" | awk -F'|' -v n="${1:-}" '$1 == n {print; exit}'
}

# Xin lại link m3u8 MỚI CHO 1 tập (khi link trong lịch sử đã hết hạn)
# $1 slug, $2 tên tập, $3 server index (có thể trống)
kkphim_resolve_episode_link() {
    local slug="$1" ep_name="$2" idx="${3:-}"
    kkphim_is_online_slug "$slug" || return 1
    local json
    json=$(kkphim_detail_json "$slug" 1) || json=$(kkphim_detail_json "$slug") || return 1
    [[ "$idx" =~ ^[0-9]+$ ]] || idx=$(kkphim_pref_server_index "$json")
    local line i
    line=$(kkphim_find_episode "$ep_name" "$(kkphim_episode_list "$json" "$idx")")
    if [ -z "$line" ]; then
        while IFS='|' read -r i _name _count; do
            [[ "$i" =~ ^[0-9]+$ ]] || continue
            line=$(kkphim_find_episode "$ep_name" "$(kkphim_episode_list "$json" "$i")")
            [ -n "$line" ] && break
        done < <(printf '%s\n' "$json" | kkphim_server_list)
    fi
    [ -z "$line" ] && return 1
    kkphim_stream_url_from_line "$line"
}

# Chọn server phụ đề / thuyết minh (fzf) -> in ra index server
kkphim_choose_server() {
    local json="$1" servers count auto_idx
    servers=$(printf '%s' "$json" | kkphim_server_list)
    count=$(printf '%s\n' "$servers" | grep -c '^[0-9]*|')
    auto_idx=$(kkphim_pref_server_index "$json")
    if [ -z "$servers" ]; then
        printf '0'
        return 1
    fi
    # Chỉ 1 server, hoặc người dùng đã đặt sẵn KKPHIM_SERVER_PREF -> dùng luôn
    if [ "$count" -le 1 ] || { [ -n "${KKPHIM_SERVER_PREF:-}" ] && [ "${KKPHIM_SERVER_PREF:-auto}" != "auto" ]; }; then
        printf '%s' "${auto_idx:-0}"
        return 0
    fi
    local sel
    sel=$(printf '%s\n' "$servers" \
        | awk -F'|' -v cur="${auto_idx:-0}" '{printf "%s%s. %s (%s tập)|%s\n", ($1 == cur ? "✔ " : "   "), $1 + 1, $2, $3, $1}' \
        | fzf --prompt="Chọn nguồn phát ($SOURCE_NAME) > " \
              --header="🔉 Server phụ đề / thuyết minh — ✔ là server được ưu tiên" \
              --delimiter='|' --with-nth=1)
    if [ -z "$sel" ]; then
        printf '%s' "${auto_idx:-0}"
        return 0
    fi
    printf '%s' "$sel" | cut -d'|' -f2
}

# Đổi server khi đang phát: in "server_index|tên tập|link". Danh sách tập mới được
# ghi ra file tạm (biến toàn cục không sống sót sau $(...) ), caller đọc lại bằng
# kkphim_switched_list để next/prev chạy đúng server mới.
KK_SWITCHED_LIST_FILE="${TMPDIR:-/tmp}/anisub_switched_list.$$"
kkphim_switched_list() {
    [ -s "$KK_SWITCHED_LIST_FILE" ] || return 1
    cat "$KK_SWITCHED_LIST_FILE"
    rm -f "$KK_SWITCHED_LIST_FILE"
    return 0
}

kkphim_switch_server() {
    local slug="$1" ep_name="$2" cur_idx="${3:-}"
    kkphim_is_online_slug "$slug" || return 1
    local json servers sel idx eps line name link
    rm -f "$KK_SWITCHED_LIST_FILE"
    json=$(kkphim_detail_json "$slug" 1) || json=$(kkphim_detail_json "$slug") || return 1
    servers=$(printf '%s' "$json" | kkphim_server_list)
    [ -z "$servers" ] && return 1
    sel=$(printf '%s\n' "$servers" \
        | awk -F'|' -v cur="$cur_idx" '{printf "%s%s. %s (%s tập)|%s\n", ($1 == cur ? "✔ " : "   "), $1 + 1, $2, $3, $1}' \
        | fzf --prompt="Chọn server mới > " --header="🔉 Đổi nguồn phát (✔ là server đang xem)" \
              --delimiter='|' --with-nth=1)
    idx=$(printf '%s' "$sel" | cut -d'|' -f2)
    [[ "$idx" =~ ^[0-9]+$ ]] || return 1
    eps=$(kkphim_episode_list "$json" "$idx")
    if [ -z "$eps" ]; then
        # ghi ra stderr vì hàm này trả kết quả qua stdout
        echo "⚠️ Server đó chưa có tập nào." >&2
        sleep 1.5
        return 1
    fi
    line=$(kkphim_find_episode "$ep_name" "$eps")
    if [ -z "$line" ]; then
        line=$(printf '%s\n' "$eps" | head -1)
        echo "ℹ️ Server mới không có '$ep_name', chuyển sang tập đầu danh sách." >&2
        sleep 1.5
    fi
    link=$(kkphim_stream_url_from_line "$line") || return 1
    printf '%s\n' "$eps" > "$KK_SWITCHED_LIST_FILE"
    name=$(printf '%s' "$line" | cut -d'|' -f1)
    printf '%s|%s|%s' "$idx" "$name" "$link"
}

# Chẩn đoán nhanh nguồn phim: phụ thuộc + phiên bản fzf + thử 1 lần tìm kiếm.
# Hữu ích khi "không tìm thấy phim" mà không rõ nguyên nhân.
kkphim_diagnose_source() {
    local fail=0 dep
    local site="${KKPHIM_SITE_URL:-$DEFAULT_KKPHIM_SITE_URL}"
    local api="${KKPHIM_API_URL:-$DEFAULT_KKPHIM_API_URL}"
    local ref="${KKPHIM_REFERER:-$DEFAULT_KKPHIM_REFERER}"
    echo "🩺 Chẩn đoán nguồn phim $SOURCE_NAME"
    echo "──────────────────────────────────────────────────────────"
    # Danh sách giống check_dependencies - thiếu bất kỳ món nào là script không chạy được
    for dep in curl grep jq fzf awk sed chafa perl; do
        if command -v "$dep" > /dev/null 2>&1; then
            printf '  %s %-7s %s\n' "✅" "$dep" "$("$dep" --version 2>&1 | head -1)"
        else
            printf '  ❌ %-7s chưa được cài (apt install %s)\n' "$dep" "$dep"
            fail=$((fail + 1))
        fi
    done
    printf '  %s %-7s %s\n' "$(command -v "$PLAYER" > /dev/null 2>&1 && echo ✅ || echo ❌)" "$PLAYER" "$(command -v "$PLAYER" > /dev/null 2>&1 && "$PLAYER" --version 2>&1 | head -1 || echo 'không tìm thấy lệnh')"

    echo
    echo "  fzf: $(command -v fzf > /dev/null 2>&1 && fzf --version 2>&1 | head -1 || echo '(chưa cài)')"
    if command -v fzf > /dev/null 2>&1; then
        if kkphim_fzf_can_reload; then
            echo "     ✅ hỗ trợ reload (gõ tới đâu gợi ý tới đó)"
        else
            echo "     ⚠️  quá cũ (không có action reload:, cần fzf >= 0.19)"
            echo "         anisub sẽ tự dùng chế độ tìm 1 lần: gõ từ khóa -> Enter -> chọn phim"
        fi
    fi
    echo "  Script: ${SELF_SCRIPT:-<không rõ>} $([ -r "${SELF_SCRIPT:-}" ] && echo '✅ đọc được' || echo '⚠️ không đọc được -> không dùng được reload/preview')"
    echo "  Nguồn : site=${site%/} api=${api%/} cdn=${KKPHIM_CDN_URL:-$DEFAULT_KKPHIM_CDN_URL}"
    echo "  Cấu hình: limit=$KKPHIM_SEARCH_LIMIT ttl=${KKPHIM_DETAIL_TTL}s pref=${KKPHIM_SERVER_PREF:-auto} ($CONFIG_FILE)"

    echo
    local probe_url="${api%/}/v1/api/tim-kiem?keyword=naruto&limit=1"
    local probe_body="" probe_code="000" probe_n="0"
    echo "  → Gọi thử API:"
    echo "     ${probe_url}"
    probe_body=$(mktemp 2>/dev/null || echo "/tmp/anisub-probe.$$")
    probe_code=$(curl -sS -L --compressed --max-time 25 \
        -A "$KKPHIM_USER_AGENT" -H "accept: application/json" -H "accept-language: vi,en" \
        -e "${ref%/}/" -o "$probe_body" -w '%{http_code}' "${probe_url}" 2>/dev/null)
    probe_code=${probe_code:-000}
    case "$probe_code" in
        2??)
            probe_n=$(jq -r '[(.data.items // .items // [])[] | .slug] | length' "$probe_body" 2>/dev/null)
            [ -z "$probe_n" ] && probe_n="0"
            if [ "$probe_n" -gt 0 ] 2>/dev/null; then
                echo "     ✅ HTTP ${probe_code} · ${probe_n} kết quả → tìm kiếm hoạt động bình thường"
            else
                echo "     ⚠️  HTTP ${probe_code} nhưng không đọc được danh sách phim"
                echo "         (JSON khác cấu trúc mong đợi - KKPhim có thể đã đổi phiên bản API):"
                head -c 300 "$probe_body" 2>/dev/null; echo ""
                fail=$((fail + 1))
            fi
            ;;
        000)
            echo "     ❌ không kết nối được - kiểm tra mạng / DNS / proxy / VPN"
            fail=$((fail + 1))
            ;;
        *)
            echo "     ❌ HTTP ${probe_code} - API trả về lỗi (site có thể đang bảo trì"
            echo "         hoặc chặn theo khu vực). Nội dung trả về (300 ký tự đầu):"
            head -c 300 "$probe_body" 2>/dev/null; echo ""
            fail=$((fail + 1))
            ;;
    esac
    rm -f "$probe_body"

    echo "  → Thử tải trang ${site%/} ..."
    local site_status
    site_status=$(curl -sS -o /dev/null -L --max-time 20 -A "$KKPHIM_USER_AGENT" \
        -w '%{http_code}' "${site%/}/" 2>/dev/null)
    case "${site_status:-000}" in
        2??|3??) echo "     ✅ HTTP $site_status" ;;
        *)       echo "     ⚠️  HTTP ${site_status:-000} - trang web không với được (API vẫn có thể chạy)" ;;
    esac

    echo "──────────────────────────────────────────────────────────"
    if [ "$fail" -eq 0 ]; then
        echo "✅ Mọi bước đều OK"
    else
        echo "❌ Có $fail bước lỗi - vui lòng gửi kèm phần trên khi báo bug"
    fi
    echo
    printf 'Nhấn Enter để quay lại... '
    read -r _
    return 0
}

# Mở URL bằng trình duyệt mặc định (dùng cho trang phim / trang embed của KKPhim)
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

# Lấy link phát từ 1 dòng "Tên|m3u8|embed|slug" (dòng của dữ liệu Local chỉ có
# "Tên|link" nên fallback sang field 2 là vừa).
kkphim_line_link() {
    local direct
    if direct=$(kkphim_stream_url_from_line "${1:-}"); then
        printf '%s' "$direct"
        return 0
    fi
    printf '%s' "${1:-}" | cut -d'|' -f2
}

# ═══ CHẶN QUẢNG CÁO TRONG PLAYLIST HLS (.m3u8) ═══════════════════════════════
# KKPhim chèn quảng cáo bằng cách thêm segment lạ vào chính playlist HLS (SSAI),
# kèm marker #EXT-X-CUE-OUT / #EXT-OATCLS-SCTE35. Trình phát chỉ phát đúng những
# gì playlist ghi, nên muốn chặn thì phải lọc playlist rồi phát bản đã lọc:
#   - bỏ segment có host/đường dẫn khớp mẫu quảng cáo
#   - bỏ marker chèn quảng cáo (CUE-OUT/CUE-IN, SCTE35, ASSET)
#   - đổi URL tương đối -> tuyệt đối để file local vẫn tải được segment
#   - giữ nguyên #EXT-X-KEY / #EXT-X-MAP (khoá giải mã) và toàn bộ phần còn lại
# Không lọc được (mạng lỗi, playlist lạ) thì phát đúng link gốc như trước.
kkphim_ad_block_enabled() {
    case "$(printf '%s' "${KKPHIM_AD_BLOCK:-$DEFAULT_KKPHIM_AD_BLOCK}" | tr 'A-Z' 'a-z')" in
        0|off|no|false|tat|tắt) return 1 ;;
        *)                      return 0 ;;
    esac
}

# Ghép URL tương đối của playlist với URL gốc của nó.
kkphim_abs_url() {
    local base="$1" rel="$2"
    case "$rel" in
        http://*|https://*) printf '%s' "$rel"; return 0 ;;
        //*)                printf 'https:%s' "$rel"; return 0 ;;
    esac
    local origin path
    origin=$(printf '%s' "$base" | sed -n 's#^\(https\?://[^/]*\).*#\1#p')
    [ -z "$origin" ] && origin="${KKPHIM_CDN_URL:-$DEFAULT_KKPHIM_CDN_URL}"
    case "$rel" in
        /*) printf '%s%s' "$origin" "$rel" ;;
        *)
            path="${base%%\?*}"
            path="${path%/*}"
            printf '%s/%s' "$path" "$rel"
            ;;
    esac
}

# Tải nội dung text (playlist) -> stdout. Giữ Referer/UA như trình phát.
kkphim_fetch_text() {
    local url="$1" tmp code
    tmp=$(mktemp "${TMPDIR:-/tmp}/anisub-hls.XXXXXX" 2>/dev/null) || return 1
    code=$(curl -sSL --compressed --max-time 20 \
        -A "$KKPHIM_USER_AGENT" -e "${KKPHIM_REFERER:-$DEFAULT_KKPHIM_REFERER}" \
        -o "$tmp" -w '%{http_code}' "$url" 2>/dev/null)
    if [ "$code" != "200" ] || [ ! -s "$tmp" ]; then
        rm -f "$tmp" 2>/dev/null
        return 1
    fi
    cat "$tmp"
    rm -f "$tmp" 2>/dev/null
    return 0
}

# Lọc 1 playlist (đọc stdin, $1 = URL gốc của playlist). In ra playlist đã lọc.
kkphim_playlist_filter() {
    KKPHIM_AD_PATTERNS="${KKPHIM_AD_PATTERNS:-$DEFAULT_KKPHIM_AD_PATTERNS}" \
    KKPHIM_BASE="$1" \
    perl -CS -Mutf8 -0777 -ne '
        my $base = $ENV{KKPHIM_BASE} // "";
        my @pats = grep { length } map { lc } split /[,\s]+/, ($ENV{KKPHIM_AD_PATTERNS} // "");
        my ($origin) = $base =~ m{^(https?://[^/]+)};
        $origin //= "";
        sub abs_url {
            my ($u) = @_;
            return $u if $u =~ m{^https?://}i;
            return "https:$u" if $u =~ m{^//};
            return $origin . $u if $u =~ m{^/};
            my $p = $base; $p =~ s{[?#].*$}{}; $p =~ s{/[^/]*$}{};
            return "$p/$u";
        }
        sub is_ad {
            my ($u) = @_;
            $u =~ s{[?#].*$}{};                 # bỏ query/hash: tránh nhầm ?ad=0
            my @parts = grep { length } split m{[/.\-_\s]+}, lc($u);
            for my $p (@parts) {
                for my $pat (@pats) {
                    return 1 if $p eq $pat || $p =~ /^\Q$pat\E[0-9]*$/;
                }
            }
            return 0;
        }
        my @out; my @pending; my ($kept, $removed) = (0, 0);
        for my $line (split /\r?\n/, $_) {
            my $l = $line;
            $l =~ s/^\s+|\s+$//g;
            next if $l eq "";
            if ($l =~ m{^#}) {
                # marker chèn quảng cáo -> bỏ luôn
                next if $l =~ m{^#EXT-X-CUE-(?:OUT|IN)\b}i;
                next if $l =~ m{^#EXT-(?:OATCLS-)?SCTE35\b}i;
                next if $l =~ m{^#EXT-X-ASSET\b}i;
                # URI="..." trong tag -> tuyệt đối hoá
                $l =~ s{(URI=")([^"]*)(")}{$1 . abs_url($2) . $3}ge;
                # tag mô tả segment -> chờ xem segment có bị bỏ không
                if ($l =~ m{^#EXT(?:INF|-X-BYTERANGE|-X-DISCONTINUITY|-X-PROGRAM-DATE-TIME)\b}i) {
                    push @pending, $l;
                    next;
                }
                push @out, @pending; @pending = ();
                push @out, $l;
                next;
            }
            my $u = abs_url($l);
            if (is_ad($u)) { @pending = (); $removed++; next }
            push @out, @pending; @pending = ();
            push @out, $u;
            $kept++;
        }
        push @out, @pending;
        exit 2 if $kept == 0;                   # không còn segment nào -> đừng dùng
        # Chuẩn hoá thành VOD: playlist kiểu live (thiếu ENDLIST) sẽ bị trình phát
        # tải lại mỗi TARGETDURATION giây; bản lọc là ảnh chụp tĩnh nên phát 3 giây
        # lại khựng 3 giây. Thêm ENDLIST + PLAYLIST-TYPE:VOD, đưa MEDIA-SEQUENCE về 0.
        my ($has_end, $has_type, $inserted) = (0, 0, 0);
        for my $l (@out) {
            $has_end  = 1 if $l =~ m{^#EXT-X-ENDLIST}i;
            $has_type = 1 if $l =~ m{^#EXT-X-PLAYLIST-TYPE:}i;
        }
        my @final;
        for my $l (@out) {
            next if $l =~ m{^#EXT-X-MEDIA-SEQUENCE:}i;
            next if $l =~ m{^#EXT-X-DISCONTINUITY-SEQUENCE:}i;
            push @final, $l;
            if (!$has_type && !$inserted && $l =~ m{^#EXT-X-TARGETDURATION:}i) {
                push @final, "#EXT-X-PLAYLIST-TYPE:VOD";
                $inserted = 1;
            }
        }
        if (!$inserted && !$has_type) {         # playlist không có TARGETDURATION
            splice @final, 1, 0, "#EXT-X-PLAYLIST-TYPE:VOD";
        }
        splice @final, 1, 0, "#EXT-X-MEDIA-SEQUENCE:0", "#EXT-X-DISCONTINUITY-SEQUENCE:0";
        push @final, "#EXT-X-ENDLIST" unless $has_end;
        print join("\n", @final), "\n";
    '
}

# Tải playlist (tự chọn variant nếu là master playlist) rồi lọc quảng cáo.
# In ra đường dẫn file .m3u8 đã lọc; lỗi thì trả về 1.
kkphim_adfree_playlist() {
    local url="$1" text variant filtered out
    text=$(kkphim_fetch_text "$url") || return 1
    case "$text" in
        *"#EXTM3U"*) : ;;
        *)           return 1 ;;
    esac
    # master playlist: chọn variant băng thông cao nhất rồi tải playlist con
    if printf '%s' "$text" | grep -q '#EXT-X-STREAM-INF'; then
        variant=$(printf '%s\n' "$text" | perl -ne '
            if (/^#EXT-X-STREAM-INF:.*BANDWIDTH=(\d+)/i) { $bw = $1; next }
            next if /^#/ || /^\s*$/;
            chomp;
            if (defined $bw && $bw > ($best // -1)) { $best = $bw; $uri = $_ }
            END { print $uri // "" }')
        [ -z "$variant" ] && return 1
        url=$(kkphim_abs_url "$url" "$variant")
        text=$(kkphim_fetch_text "$url") || return 1
    fi
    filtered=$(printf '%s' "$text" | kkphim_playlist_filter "$url" 2>/dev/null) || return 1
    [ -z "$filtered" ] && return 1
    out="${TMPDIR:-/tmp}/anisub-adfree-$$.m3u8"
    printf '%s\n' "$filtered" > "$out" 2>/dev/null || return 1
    # lưu lại 2 bản (bản gốc + bản đã lọc) để đối chiếu khi cần báo lỗi
    if [ -n "${CACHE_DIR:-}" ] && mkdir -p "$CACHE_DIR" 2>/dev/null; then
        printf '%s\n' "$text" > "$CACHE_DIR/kkphim-playlist-original.m3u8" 2>/dev/null
        cp "$out" "$CACHE_DIR/kkphim-playlist-filtered.m3u8" 2>/dev/null
    fi
    printf '%s' "$out"
}

# URL để đưa cho trình phát: nếu là .m3u8 và đang bật chặn quảng cáo thì trả về
# playlist đã lọc (kèm thông báo), lỗi thì trả lại đúng link gốc.
kkphim_play_url() {
    local url="$1" f
    case "$url" in
        *.m3u8*|*m3u8*) : ;;
        *)              printf '%s' "$url"; return 0 ;;
    esac
    kkphim_ad_block_enabled || { printf '%s' "$url"; return 0; }
    if f=$(kkphim_adfree_playlist "$url" 2>/dev/null) && [ -n "$f" ] && [ -s "$f" ]; then
        KKPHIM_ADFREE_FILE="$f"
        echo "🚫 Đã lọc quảng cáo trong playlist HLS." >&2
        printf '%s' "$f"
    else
        [ -n "${KKPHIM_ADFREE_FILE:-}" ] && rm -f "$KKPHIM_ADFREE_FILE" 2>/dev/null
        KKPHIM_ADFREE_FILE=""
        printf '%s' "$url"
    fi
}

# Chẩn đoán chặn quảng cáo: tải playlist, lọc, in ra số segment/host bị bỏ và
# lưu 2 bản playlist (gốc + đã lọc) để gửi kèm khi báo lỗi.
kkphim_ad_report() {
    local url="${1:-}"
    if [ -z "$url" ]; then
        echo "Cách dùng: ./anisub.sh --kkphim-ad-debug <link m3u8>"
        return 1
    fi
    echo "🚫 CHẨN ĐOÁN CHẶN QUẢNG CÁO (anisub $ANISUB_VERSION)"
    echo "   URL: $url"
    case "$(printf '%s' "${KKPHIM_AD_BLOCK:-$DEFAULT_KKPHIM_AD_BLOCK}" | tr 'A-Z' 'a-z')" in
        0|off|no|false|tat|tắt) echo "   ⚠️ Đang TẮT chặn quảng cáo (KKPHIM_AD_BLOCK=0)." ;;
    esac
    local out code
    out=$(kkphim_adfree_playlist "$url" 2>/dev/null) || {
        code=$(anisub_last_http 2>/dev/null)
        echo "   ❌ Không tải/lọc được playlist này."
        echo "      → thử: curl -sSL -o /tmp/pl.m3u8 '$url' rồi mở file xem có #EXTM3U không"
        return 1
    }
    local orig="${CACHE_DIR:-${TMPDIR:-/tmp}}/kkphim-playlist-original.m3u8"
    local filt="${CACHE_DIR:-${TMPDIR:-/tmp}}/kkphim-playlist-filtered.m3u8"
    local n_orig n_filt n_drop
    n_orig=$(grep -cE '^https?://|^[^#[:space:]].*\.(ts|m4s|mp4|aac)' "$orig" 2>/dev/null)
    n_filt=$(grep -cE '^https?://|^[^#[:space:]].*\.(ts|m4s|mp4|aac)' "$filt" 2>/dev/null)
    n_drop=$(( ${n_orig:-0} - ${n_filt:-0} ))
    echo "   ✔ Playlist tải được · segment: giữ ${n_filt:-0} / bỏ ${n_drop:-0}"
    if [ "${n_drop:-0}" -gt 0 ]; then
        echo "   ── segment bị bỏ:"
        comm -23 <(grep -E '^https?://' "$orig" 2>/dev/null | sort -u) \
                 <(grep -E '^https?://' "$filt" 2>/dev/null | sort -u) | head -8 | sed 's/^/      · /'
    fi
    if grep -q '#EXT-X-ENDLIST' "$orig" 2>/dev/null; then
        echo "   ── kiểu playlist gốc: VOD (có #EXT-X-ENDLIST)"
    else
        echo "   ── kiểu playlist gốc: LIVE/thiếu ENDLIST → đã thêm ENDLIST + PLAYLIST-TYPE:VOD"
        echo "      (nếu không thêm, trình phát tải lại playlist mỗi 3 giây -> phát 3s lại khựng 3s)"
    fi
    echo "   ── danh sách host trong playlist:"
    grep -E '^https?://' "$filt" 2>/dev/null | sed -E 's#^https?://([^/]+)/.*#\1#' | sort | uniq -c | sort -rn | head -6 | sed 's/^/      /'
    echo "   📄 Đã lưu: $orig"
    echo "              $filt"
    echo "   Gửi 2 file này khi báo lỗi để bổ sung mẫu nhận diện quảng cáo."
    return 0
}

play_stream() {
    local url="$1"
    local title="$2"

    if [ -z "$url" ]; then
        echo "❌ Link trống - không phát được."
        sleep 1.5
        return 1
    fi
    if ! command -v "$PLAYER" &> /dev/null; then
        echo "❌ Không tìm thấy trình phát '$PLAYER'. Vào ⚙️ Cài đặt để đổi trình phát khác."
        sleep 2
        return 1
    fi

    # Kill any existing player instance to avoid conflicts
    killall "$PLAYER" 2>/dev/null

    # Chặn quảng cáo: nếu link là playlist HLS, phát bản đã lọc segment quảng cáo
    local play_url
    play_url=$(kkphim_play_url "$url")
    [ -z "$play_url" ] && play_url="$url"

    # CDN phim của KKPhim kiểm tra Referer/User-Agent, vì vậy truyền header
    # cho những trình phát có hỗ trợ; trình phát khác dùng link thô.
    case "$PLAYER" in
        mpv)
            mpv "$play_url" --no-terminal --profile=sw-fast --audio-display=no \
                --cache=yes --cache-secs=30 --demuxer-readahead-secs=30 \
                --no-keepaspect-window --title="Anisub: $title" \
                --referrer="$KKPHIM_REFERER" --user-agent="$KKPHIM_USER_AGENT" \
                --http-header-fields="Referer: $KKPHIM_REFERER" &
            ;;
        vlc)
            vlc --referrer="$KKPHIM_REFERER" --user-agent="$KKPHIM_USER_AGENT" \
                "$play_url" &
            ;;
        *)
            "$PLAYER" "$play_url" &
            ;;
    esac
    PLAYER_PID=$!
    PLAY_START_TS=$(date +%s)
}

# --- LUỒNG XEM PHIM (KKPhim) ---
# Chọn server + tập cho 1 phim rồi phát.
# $1 tên hiển thị, $2 slug, [$3 mô tả nhỏ], [$4 server index (bỏ trống = tự động)]
kkphim_play_movie() {
    local name="$1" slug="$2" meta="${3:-}" forced_server="${4:-}"
    if [ -z "$slug" ] || [ "$slug" = "__noop__" ]; then
        return 1
    fi
    echo "⏳ Đang tải dữ liệu phim từ $SOURCE_NAME ($KKPHIM_SITE_URL)..."
    local json
    if ! json=$(kkphim_detail_json "$slug"); then
        echo "❌ Không lấy được thông tin phim từ $SOURCE_NAME (slug: $slug)."
        echo "   Kiểm tra lại mạng hoặc KKPHIM_API_URL trong $CONFIG_FILE"
        sleep 2.5
        return 1
    fi

    local server_idx
    if [[ "$forced_server" =~ ^[0-9]+$ ]]; then
        server_idx="$forced_server"
    else
        server_idx=$(kkphim_choose_server "$json")
    fi
    [[ "$server_idx" =~ ^[0-9]+$ ]] || server_idx=0

    local eps
    eps=$(kkphim_episode_list "$json" "$server_idx")
    if [ -z "$eps" ]; then
        # server đó trống (hoặc index cũ không còn) -> lấy server đầu tiên có tập
        server_idx=$(printf '%s\n' "$json" | kkphim_server_list | awk -F'|' '$3 + 0 > 0 {print $1; exit}')
        [[ "$server_idx" =~ ^[0-9]+$ ]] || server_idx=0
        eps=$(kkphim_episode_list "$json" "$server_idx")
    fi
    if [ -z "$eps" ]; then
        echo "❌ Phim này chưa có nguồn phát trên $SOURCE_NAME."
        echo "   Bạn có thể mở trang phim để xem chi tiết: $(kkphim_movie_url "$slug")"
        sleep 2.5
        return 1
    fi

    local ep_count
    ep_count=$(printf '%s\n' "$eps" | grep -c '.')
    local sel_ep
    sel_ep=$(printf '%s\n' "$eps" | fzf --prompt="[$name] Chọn tập > " \
        --header="🎬 $name${meta:+ · $meta} · $ep_count tập · $SOURCE_NAME" \
        --delimiter='|' --with-nth=1)
    [ -z "$sel_ep" ] && return 1

    local ename elink
    ename=$(printf '%s' "$sel_ep" | cut -d'|' -f1)
    if ! elink=$(kkphim_stream_url_from_line "$sel_ep"); then
        local embed
        embed=$(kkphim_embed_url_from_line "$sel_ep")
        echo "⚠️ $SOURCE_NAME không trả link trực tiếp cho tập này."
        if [ -n "$embed" ]; then
            local go=""
            printf 'Mở link embed bằng trình duyệt? [y/N] '
            read -r go
            [[ "$go" =~ ^[yY] ]] && open_url "$embed"
        fi
        sleep 1.5
        return 1
    fi

    add_to_history "$name" "$ename" "$elink" "$slug" "$server_idx"
    manage_currently_playing "$name" "$ename" "$elink" "$eps" "$slug" "$server_idx"
}

# $1 = dòng "Tên (năm)|slug|poster|meta" lấy từ danh sách tìm kiếm / danh mục
kkphim_play_movie_line() {
    local line="$1"
    local name slug meta
    name=$(printf '%s' "$line" | cut -d'|' -f1)
    slug=$(printf '%s' "$line" | cut -d'|' -f2)
    meta=$(printf '%s' "$line" | cut -d'|' -f4)
    kkphim_play_movie "$name" "$slug" "$meta"
}

# --- TÌM KIẾM ---
# fzf có hành động "reload:" từ 0.19 và sự kiện "start:" chỉ từ 0.25. Bản cũ hơn
# (Ubuntu 20.04: 0.19.5, Debian 10: 0.17.5) báo lỗi parse "--bind" rồi thoát ngay ->
# cửa sổ tìm không mở, trông như "không tìm kiếm được phim". Vì vậy: không dùng
# "start:", và nếu fzf không có "reload:" thì chuyển sang chế độ tìm 1 lần.
kkphim_fzf_can_reload() {
    if [ -n "${KKPHIM_FZF_RELOAD:-}" ]; then
        return "$KKPHIM_FZF_RELOAD"
    fi
    if fzf --help 2>&1 | grep -q 'reload:'; then
        KKPHIM_FZF_RELOAD=0
    else
        KKPHIM_FZF_RELOAD=1
    fi
    return "$KKPHIM_FZF_RELOAD"
}

# fzf chạy lệnh reload/preview bằng shell riêng nên cần file script thật trên đĩa
# (không dùng được nếu người dùng chạy "curl ... | bash")
kkphim_search_can_helper() {
    [ -n "$SELF_SCRIPT" ] && [ -f "$SELF_SCRIPT" ] && [ -r "$SELF_SCRIPT" ]
}

# Dự phòng: nhập từ khóa 1 lần rồi tìm (không cần reload, không cần helper)
kkphim_search_once() {
    local poster_cmd="$1" kw="" sel lines
    printf '🔍 Nhập tên phim cần tìm (%s): ' "$SOURCE_NAME"
    read -r kw
    [ "${#kw}" -lt 2 ] && return 1
    lines=$(kkphim_search_items "$kw")
    sel=$(printf '%s\n' "$lines" | fzf --prompt="Kết quả \"$kw\" > " \
        --header="🎬 $SOURCE_NAME · $KKPHIM_SITE_URL (gõ để lọc trong kết quả vừa tải)" \
        --delimiter='|' --with-nth=1 \
        --preview "$poster_cmd" --preview-window=right:40%:wrap)
    [ -z "$sel" ] && return 1
    kkphim_play_movie_line "$sel"
}

# Tìm kiếm trực tiếp trên KKPhim (gõ tới đâu hiện gợi ý tới đó + poster)
kkphim_search_menu() {
    local reload_cmd poster_cmd
    poster_cmd="ANISUB_HELPER=poster KKPHIM_POSTER='{3}' bash '$SELF_SCRIPT'"

    if ! kkphim_fzf_can_reload || ! kkphim_search_can_helper; then
        kkphim_search_once "$poster_cmd"
        return $?
    fi

    # không dùng "start:reload:" (sự kiện start chỉ có từ fzf 0.25) - danh sách
    # khởi tạo đưa thẳng qua stdin, fzf cũ vẫn mở được cửa sổ
    reload_cmd="ANISUB_HELPER=search KKPHIM_QUERY='{q}' bash '$SELF_SCRIPT'"
    local sel fzf_err
    fzf_err=$(mktemp "${TMPDIR:-/tmp}/anisub-fzf.XXXXXX" 2>/dev/null) || fzf_err="${TMPDIR:-/tmp}/anisub-fzf.$$.err"
    sel=$(kkphim_notice_line "💡 Gõ tên phim để tìm trên $SOURCE_NAME (tối thiểu 2 ký tự)..." \
        | fzf --disabled \
              --prompt="🔍 Gõ tên phim ($SOURCE_NAME): " \
              --header="🎬 Nguồn: $SOURCE_NAME · $KKPHIM_SITE_URL — gõ >= 2 ký tự để xem gợi ý, Enter để chọn" \
              --bind "change:reload:$reload_cmd" \
              --delimiter='|' \
              --with-nth=1 \
              --preview "$poster_cmd" \
              --preview-window=right:40%:wrap 2>"$fzf_err")

    # fzf lỗi tham số (bản quá cũ, không nhận bind/preview) -> tự chuyển sang
    # chế độ tìm 1 lần thay vì đóng cửa sổ ngay
    if [ -z "$sel" ] && [ -s "$fzf_err" ] \
        && grep -qiE 'invalid|unknown|usage|error|flag' "$fzf_err" 2>/dev/null; then
        echo "⚠️ fzf không nhận tham số: $(head -1 "$fzf_err")"
        sleep 1.5
        rm -f "$fzf_err"
        kkphim_search_once "$poster_cmd"
        return $?
    fi
    rm -f "$fzf_err"

    if [ -n "$sel" ]; then
        clear
        kkphim_play_movie_line "$sel"
    fi
}

# Duyệt phim theo danh mục của KKPhim (mới cập nhật / anime / phim bộ / phim lẻ)
kkphim_browse_menu() {
    local cat_line cat page sel
    cat_line=$(kkphim_categories | fzf --prompt="Chọn danh mục $SOURCE_NAME > " --header="🍿 Danh sách phim lấy từ $KKPHIM_SITE_URL" --delimiter='|' --with-nth=1)
    [ -z "$cat_line" ] && return 1
    cat=$(printf '%s' "$cat_line" | cut -d'|' -f2)

    page=1
    while true; do
        clear
        echo "⏳ Đang tải danh mục '$cat' (trang $page) từ $SOURCE_NAME..."
        sel=$(kkphim_category_items "$cat" "$page" | fzf --prompt="🍿 $cat · trang $page > " \
            --header="🎬 $SOURCE_NAME · chọn phim để xem · dòng ⏮/⏭ để đổi trang" \
            --delimiter='|' --with-nth=1)
        if [ -z "$sel" ]; then
            return 1
        fi
        if [[ "$sel" == *"||page:"* ]]; then
            page=$(printf '%s' "$sel" | awk -F'|' '{print $4}' | sed 's/^page://')
            [[ "$page" =~ ^[0-9]+$ ]] || page=1
            continue
        fi
        clear
        kkphim_play_movie_line "$sel"
        return 0
    done
}

# --- HELPER FOR NEXT/PREV LOGIC ---
find_adjacent_episode() {
    local current_name="$1"
    local list_raw="$2"
    local mode="$3" # "next" or "prev"
    
    # Convert list to array
    mapfile -t eps_array <<< "$list_raw"
    
    local current_index=-1
    for i in "${!eps_array[@]}"; do
        # Extract name from "Name|Link"
        local ep_name=$(echo "${eps_array[$i]}" | cut -d'|' -f1)
        if [ "$ep_name" = "$current_name" ]; then
            current_index=$i
            break
        fi
    done
    
    if [ $current_index -eq -1 ]; then
        return 1
    fi
    
    local target_index
    if [ "$mode" = "next" ]; then
        target_index=$((current_index + 1))
    else
        target_index=$((current_index - 1))
    fi
    
    if [ $target_index -ge 0 ] && [ $target_index -lt ${#eps_array[@]} ]; then
        echo "${eps_array[$target_index]}"
        return 0
    fi
    
    return 1
}

# KKPhim/Anidata trả tên tập đã kèm chữ "Tập" (VD: "Tập 12") - tránh in thành
# "Tập Tập 12" trong tiêu đề trình phát.
episode_label() {
    case "${1:-}" in
        "") printf 'Tập ?' ;;
        Tập\ *|tap\ *|Tap\ *|TAP\ *|Episode\ *|episode\ *|Chapter\ *|Full|full) printf '%s' "$1" ;;
        *) printf 'Tập %s' "$1" ;;
    esac
}

# --- CONTROL PLAYER MENU ---
manage_currently_playing() {
    local name="$1"
    local current_ep_name="$2"
    local link="$3"
    local episode_list_raw="$4"
    local anime_slug="$5"
    local server_index="${6:-}"
    local user_wants_quit=0
    local online=0
    kkphim_is_online_slug "$anime_slug" && online=1
    
    play_stream "$link" "$name - $(episode_label "$current_ep_name")"
    
    # Loop while player is running
    while kill -0 "$PLAYER_PID" 2>/dev/null; do
        header="Đang phát: $name - $(episode_label "$current_ep_name")"
        if [ "$online" -eq 1 ]; then
            source_note="Nguồn: $SOURCE_NAME · $KKPHIM_SITE_URL"
        else
            source_note="Nguồn: Local Anidata"
        fi
        menu_items="⏭ Tiếp theo\n⏮ Trước đó\n📜 Chọn tập khác"
        [ "$online" -eq 1 ] && menu_items+="\n🔉 Đổi server / ngôn ngữ\n🔄 Làm mới link tập"
        menu_items+="\n⬇ Tải tập này\n✂ Cắt Video (1 lần)\n✂✂ Cắt Video (Nhiều lần)\n🧬 Ghép Video\n❤️ Thêm vào Yêu Thích"
        [ "$online" -eq 1 ] && menu_items+="\n🌐 Mở trang phim trên trình duyệt"
        menu_items+="\n🔙 Quay lại Menu Chính"
        action=$(echo -e "$menu_items" | fzf --prompt="$header > " --header="[Player đang chạy. Chọn tác vụ không cần tắt player] · $source_note")
        
        case "$action" in
            "⏭ Tiếp theo")
                kill "$PLAYER_PID" 2>/dev/null
                sleep 0.5
                # Logic tự động chuyển tập tiếp theo
                next_data=$(find_adjacent_episode "$current_ep_name" "$episode_list_raw" "next")
                if [ -n "$next_data" ]; then
                    current_ep_name=$(echo "$next_data" | cut -d'|' -f1)
                    link=$(kkphim_line_link "$next_data")
                    add_to_history "$name" "$current_ep_name" "$link" "$anime_slug" "$server_index"
                    play_stream "$link" "$name - $(episode_label "$current_ep_name")"
                else
                    echo "Đã hết tập (Tập cuối)."
                    sleep 1
                    # If end of list, maybe restart player with current ep or just stop
                    # Here we break loop to return to selection or exit
                    user_wants_quit=1
                fi
                ;;
            "⏮ Trước đó")
                kill "$PLAYER_PID" 2>/dev/null
                sleep 0.5
                # Logic tự động chuyển tập trước
                prev_data=$(find_adjacent_episode "$current_ep_name" "$episode_list_raw" "prev")
                if [ -n "$prev_data" ]; then
                    current_ep_name=$(echo "$prev_data" | cut -d'|' -f1)
                    link=$(kkphim_line_link "$prev_data")
                    add_to_history "$name" "$current_ep_name" "$link" "$anime_slug" "$server_index"
                    play_stream "$link" "$name - $(episode_label "$current_ep_name")"
                else
                    echo "Đây là tập đầu tiên."
                    sleep 1
                    play_stream "$link" "$name - $(episode_label "$current_ep_name")" # Resume
                fi
                ;;
            "📜 Chọn tập khác")
                kill "$PLAYER_PID" 2>/dev/null
                new_selection=$(echo "$episode_list_raw" | fzf --prompt="Chọn tập: " --header="🎬 $name · $source_note" --delimiter='|' --with-nth=1)
                 if [ -n "$new_selection" ]; then
                     current_ep_name=$(echo "$new_selection" | cut -d'|' -f1)
                     link=$(kkphim_line_link "$new_selection")
                     add_to_history "$name" "$current_ep_name" "$link" "$anime_slug" "$server_index"
                     play_stream "$link" "$name - $(episode_label "$current_ep_name")"
                 else
                     # User cancelled selection, replay current
                     play_stream "$link" "$name - $(episode_label "$current_ep_name")"
                 fi
                ;;
            "🔉 Đổi server / ngôn ngữ")
                if [ "$online" -ne 1 ]; then
                    echo "⚠️ Chỉ đổi được server khi xem online từ $SOURCE_NAME."
                    sleep 1.5
                else
                    kill "$PLAYER_PID" 2>/dev/null
                    sleep 0.3
                    local new_list=""
                    swapped=$(kkphim_switch_server "$anime_slug" "$current_ep_name" "$server_index")
                    if [ -n "$swapped" ]; then
                        server_index=$(echo "$swapped" | cut -d'|' -f1)
                        current_ep_name=$(echo "$swapped" | cut -d'|' -f2)
                        link=$(echo "$swapped" | cut -d'|' -f3)
                        new_list=$(kkphim_switched_list) && episode_list_raw="$new_list"
                        add_to_history "$name" "$current_ep_name" "$link" "$anime_slug" "$server_index"
                        play_stream "$link" "$name - $(episode_label "$current_ep_name")"
                    else
                        echo "ℹ️ Giữ nguyên server đang phát."
                        play_stream "$link" "$name - $(episode_label "$current_ep_name")"
                    fi
                fi
                ;;
            "🔄 Làm mới link tập")
                if [ "$online" -ne 1 ]; then
                    echo "⚠️ Link này không thuộc $SOURCE_NAME nên không cần làm mới."
                    sleep 1.5
                else
                    fresh_link=$(kkphim_resolve_episode_link "$anime_slug" "$current_ep_name" "$server_index")
                    if [ -n "$fresh_link" ]; then
                        link="$fresh_link"
                        add_to_history "$name" "$current_ep_name" "$link" "$anime_slug" "$server_index"
                        echo "✅ Đã lấy link m3u8 mới từ $SOURCE_NAME."
                        sleep 1
                    else
                        echo "❌ Không lấy được link mới (mạng lỗi hoặc phim bị gỡ)."
                        sleep 2
                    fi
                fi
                ;;
            "⬇ Tải tập này") download_video "$link" "$name - $(episode_label "$current_ep_name")" & ;;
            "✂ Cắt Video (1 lần)") cut_video_logic "$link" "single" ;;
            "✂✂ Cắt Video (Nhiều lần)") cut_video_logic "$link" "multi" ;;
            "🧬 Ghép Video") merge_video_logic ;;
            "❤️ Thêm vào Yêu Thích") add_to_favorites "$name" "$anime_slug" "$server_index" ;;
            "🌐 Mở trang phim trên trình duyệt")
                if [ "$online" -eq 1 ]; then
                    open_url "$(kkphim_movie_url "$anime_slug")"
                else
                    echo "⚠️ Bản này đang xem từ dữ liệu Local, không có trang nguồn."
                    sleep 1.5
                fi
                ;;
            "🔙 Quay lại Menu Chính") kill "$PLAYER_PID" 2>/dev/null; user_wants_quit=1; break ;;
             *) kill "$PLAYER_PID" 2>/dev/null; user_wants_quit=1; break ;;
        esac
    done

    # --- XỬ LÝ KHI VIDEO XEM HẾT (KHI PLAYER TỰ ĐỘNG TẮT) ---
    if [ $user_wants_quit -eq 0 ]; then
        clear
        local played_for=$(( $(date +%s) - ${PLAY_START_TS:-$(date +%s)} ))
        # Link m3u8 của $SOURCE_NAME hết hạn sau vài phút: nếu trình phát chết ngay
        # thì gợi ý xin link mới / đổi server (giới hạn 2 vòng để không đệ quy mãi).
        if [ "$online" -eq 1 ] && [ "$played_for" -lt 8 ] && [ "${KK_LINK_RETRY:-0}" -lt 2 ]; then
            echo "⚠️  Trình phát tắt sau ${played_for}s - link m3u8 của $SOURCE_NAME chỉ"
            echo "    có hiệu lực vài phút sau khi gọi API."
            local retry_action
            retry_action=$(echo -e "🔄 Lấy link mới và phát lại\n🔉 Đổi server / ngôn ngữ khác\n🌐 Mở phim trên trình duyệt\n🔙 Quay lại Menu Chính" | fzf --prompt="Link có vẻ đã hết hạn > ")
            case "$retry_action" in
                "🔄"*)
                    local new_link
                    new_link=$(kkphim_resolve_episode_link "$anime_slug" "$current_ep_name" "$server_index")
                    [ -n "$new_link" ] && link="$new_link"
                    ;;
                "🔉"*)
                    local swapped_now
                    swapped_now=$(kkphim_switch_server "$anime_slug" "$current_ep_name" "$server_index")
                    if [ -n "$swapped_now" ]; then
                        server_index=$(echo "$swapped_now" | cut -d'|' -f1)
                        current_ep_name=$(echo "$swapped_now" | cut -d'|' -f2)
                        link=$(echo "$swapped_now" | cut -d'|' -f3)
                        local list_now=""
                        list_now=$(kkphim_switched_list) && episode_list_raw="$list_now"
                    fi
                    ;;
                "🌐"*)
                    open_url "$(kkphim_movie_url "$anime_slug")"
                    KK_LINK_RETRY=0
                    return
                    ;;
                *)
                    KK_LINK_RETRY=0
                    return
                    ;;
            esac
            KK_LINK_RETRY=$(( ${KK_LINK_RETRY:-0} + 1 ))
            manage_currently_playing "$name" "$current_ep_name" "$link" "$episode_list_raw" "$anime_slug" "$server_index"
            KK_LINK_RETRY=$(( KK_LINK_RETRY - 1 ))
            return
        fi
        echo "-----------------------------------"
        echo "  Đã xem xong: $name - $current_ep_name"
        echo "-----------------------------------"
        
        # Tìm tập tiếp theo để gợi ý
        next_ep_data=$(find_adjacent_episode "$current_ep_name" "$episode_list_raw" "next")
        local next_option=""
        if [ -n "$next_ep_data" ]; then
            local next_name=$(echo "$next_ep_data" | cut -d'|' -f1)
            next_option="▶ Phát Tập Tiếp Theo: $next_name\n"
        fi

        end_action=$(echo -e "${next_option}🔄 Xem lại tập này\n🔙 Quay lại Menu Chính" | fzf --prompt="Bạn muốn làm gì tiếp theo? > ")
        
        case "$end_action" in
            "▶ Phát Tập Tiếp Theo"*)
                # Recursive call để chơi tập tiếp theo
                local n_name=$(echo "$next_ep_data" | cut -d'|' -f1)
                local n_link=$(kkphim_line_link "$next_ep_data")
                manage_currently_playing "$name" "$n_name" "$n_link" "$episode_list_raw" "$anime_slug" "$server_index"
                ;;
            "🔄 Xem lại tập này")
                manage_currently_playing "$name" "$current_ep_name" "$link" "$episode_list_raw" "$anime_slug" "$server_index"
                ;;
            *)
                # Quay lại menu chính (không làm gì cả, loop sẽ thoát)
                ;;
        esac
    fi
}

# --- MEDIA PROCESSING FUNCTIONS ---
download_video() {
    local url="$1"
    local filename="$2"
    local folder="$DOWNLOAD_DIR/$(echo "$filename" | awk -F' - ' '{print $1}')"
    
    mkdir -p "$folder"
    safe_name=$(echo "$filename" | sed 's/[^a-zA-Z0-9 .-]/_/g')
    
    echo "Đang tải xuống: $safe_name... (nguồn: $SOURCE_NAME)"
    if command -v yt-dlp &> /dev/null; then
        yt-dlp --referer "$KKPHIM_REFERER" --user-agent "$KKPHIM_USER_AGENT" \
            "$url" -o "$folder/$safe_name.mp4"
    else
        ffmpeg -hide_banner -loglevel error -headers "$KKPHIM_FFMPEG_HEADERS" \
            -protocol_whitelist "file,http,https,tcp,tls,crypto" -allowed_extensions ALL \
            -i "$url" -c copy -bsf:a aac_adtstoasc "$folder/$safe_name.mp4"
    fi
    echo "Đã tải xong: $folder/$safe_name.mp4"
    sleep 2
}

cut_video_logic() {
    local input_url="$1"
    local mode="$2"
    local dest_dir="$DOWNLOAD_DIR/cut"
    mkdir -p "$dest_dir"

    # Link của $SOURCE_NAME là HLS trực tuyến: ffmpeg cần Referer + whitelist protocol
    local -a input_args=()
    case "$input_url" in
        http*)
            input_args=(-headers "$KKPHIM_FFMPEG_HEADERS"
                        -protocol_whitelist "file,http,https,tcp,tls,crypto"
                        -allowed_extensions ALL)
            ;;
    esac

    echo "=== CHẾ ĐỘ CẮT VIDEO (Fix lỗi hình ảnh) ==="
    echo "Lưu ý: Nhập chính xác thời gian trên trình phát đang xem."
    
    if [ "$mode" == "single" ]; then
        read -r -p "Nhập thời gian bắt đầu (VD: 00:10:30): " start_time
        read -r -p "Nhập thời gian kết thúc (VD: 00:11:00): " end_time
        output_name="cut_$(date +%s).mp4"
        
        echo "Đang xử lý (Re-encoding)..."
        ffmpeg "${input_args[@]}" -i "$input_url" -ss "$start_time" -to "$end_time" \
            -c:v libx264 -preset fast -crf 23 -c:a aac \
            "$dest_dir/$output_name" -hide_banner -loglevel error
        
        echo "Xong! File lưu tại: $dest_dir/$output_name"
    
    elif [ "$mode" == "multi" ]; then
        read -r -p "Số lượng đoạn cần cắt: " count
        for ((i=1; i<=count; i++)); do
            echo "--- Đoạn $i ---"
            read -r -p "Bắt đầu (HH:MM:SS): " start_t
            read -r -p "Kết thúc (HH:MM:SS): " end_t
            output_name="cut_${i}_$(date +%s).mp4"
            
            echo "Đang xử lý đoạn $i..."
            ffmpeg "${input_args[@]}" -i "$input_url" -ss "$start_t" -to "$end_t" \
                -c:v libx264 -preset fast -crf 23 -c:a aac \
                "$dest_dir/$output_name" -hide_banner -loglevel error

            echo "Đã lưu đoạn $i: $output_name"
        done
        echo "Hoàn tất cắt nhiều đoạn."
    fi
    sleep 3
}

merge_video_logic() {
    local cut_dir="$DOWNLOAD_DIR/cut"
    local merge_dir="$DOWNLOAD_DIR/merged"
    mkdir -p "$merge_dir"
    
    if [ -z "$(ls -A "$cut_dir")" ]; then
        echo "Thư mục '$cut_dir' trống. Hãy cắt video trước."
        sleep 2
        return
    fi

    echo "Chọn các video để ghép (TAB để chọn nhiều, ENTER xác nhận):"
    cd "$cut_dir" || return
    selected_files=$(find . -maxdepth 1 -name "*.mp4" | sed 's|^\./||' | fzf -m --prompt="Chọn file để ghép > ")
    
    if [ -z "$selected_files" ]; then
        return
    fi

    list_txt="$cut_dir/merge_list.txt"
    > "$list_txt"
    
    echo "File đã chọn:"
    while IFS= read -r file; do
        echo "file '$file'" >> "$list_txt"
        echo " - $file"
    done <<< "$selected_files"
    
    output_name="merged_$(date +%s).mp4"
    echo "Đang ghép video..."
    ffmpeg -f concat -safe 0 -i "$list_txt" -c copy "$merge_dir/$output_name" -hide_banner -loglevel error
    
    rm "$list_txt"
    echo "Xong! Video ghép lưu tại: $merge_dir/$output_name"
    sleep 3
}

# --- LOCAL FILE HANDLER ---
play_anidata_local() {
    echo "Kiểm tra dữ liệu Local tại: $LOCAL_DATA_FILE"
    
    if [ ! -f "$LOCAL_DATA_FILE" ]; then
        echo "Đang tải dữ liệu mới..."
        local data_url="https://raw.githubusercontent.com/niyakipham/anisub/refs/heads/main/assets/aniw_export_2026-01-14.csv"
        mkdir -p "$SCRIPT_DIR/assets"
        curl -L "$data_url" -o "$LOCAL_DATA_FILE"
        if [ ! -f "$LOCAL_DATA_FILE" ]; then
            echo "Lỗi: Không tải được file dữ liệu."
            sleep 2; return
        fi
    fi

    local anime_list=$(sed '1d;s/"//g' "$LOCAL_DATA_FILE" | awk -F',' '{print $1}' | sort -u)
    local selected_anime=$(echo "$anime_list" | fzf --prompt="[Local] Chọn Anime: ")
    if [ -z "$selected_anime" ]; then return; fi

    local episodes=$(grep "^\"${selected_anime}\"," "$LOCAL_DATA_FILE" | sed 's/"//g' | awk -F',' '{print "Tập " $2 "|" $4}')
    if [ -z "$episodes" ]; then
         episodes=$(grep "^${selected_anime}," "$LOCAL_DATA_FILE" | sed 's/"//g' | awk -F',' '{print "Tập " $2 "|" $4}')
    fi

    local selected_line=$(echo "$episodes" | fzf --prompt="Chọn tập: " --delimiter='|' --with-nth=1)
    if [ -n "$selected_line" ]; then
         local ep_name=$(echo "$selected_line" | cut -d'|' -f1)
         local link=$(echo "$selected_line" | cut -d'|' -f2 | tr -d '[:space:]')
         
         add_to_history "$selected_anime (Local)" "$ep_name" "$link"
         manage_currently_playing "$selected_anime" "$ep_name" "$link" "$episodes" "local_file"
    fi
}

# --- SETTINGS & UPDATE ---
# Cài đặt riêng cho nguồn phim KKPhim (domain, server ưu tiên, cache)
show_source_settings() {
    local opt inp pref
    while true; do
        local ad_state="bật"
        kkphim_ad_block_enabled || ad_state="tắt"
        opt=$(echo -e "🩺 Kiểm tra kết nối & phụ thuộc\n🌐 Trang web nguồn: $KKPHIM_SITE_URL\n🔌 API nguồn: $KKPHIM_API_URL\n🖼️ CDN ảnh: $KKPHIM_CDN_URL\n🔉 Server ưu tiên: ${KKPHIM_SERVER_PREF:-auto}\n🔎 Số kết quả tìm kiếm: ${KKPHIM_SEARCH_LIMIT:-24}\n⏱️ Cache chi tiết phim: ${KKPHIM_DETAIL_TTL:-600}s\n🚫 Chặn quảng cáo trong m3u8: $ad_state\n🏷️ Mẫu nhận diện quảng cáo: ${KKPHIM_AD_PATTERNS:-$DEFAULT_KKPHIM_AD_PATTERNS}\n🧹 Xóa cache nguồn phim\n🔙 Quay lại" | fzf --prompt="🎞 Nguồn phim ($SOURCE_NAME) > " --header="Tài liệu API của KKPhim: $KKPHIM_SITE_URL/api-document · lỗi tìm kiếm? chạy 🩺 trước")
        case "$opt" in
            *"Kiểm tra kết nối"*)
                clear
                kkphim_diagnose_source
                ;;
            *"Trang web nguồn"*)
                read -r -p "Nhập URL trang web (Enter = $DEFAULT_KKPHIM_SITE_URL): " inp
                KKPHIM_SITE_URL="${inp:-$DEFAULT_KKPHIM_SITE_URL}"
                KKPHIM_REFERER="${KKPHIM_SITE_URL%/}/"
                save_config ;;
            *"API nguồn"*)
                read -r -p "Nhập URL API (Enter = $DEFAULT_KKPHIM_API_URL): " inp
                KKPHIM_API_URL="${inp:-$DEFAULT_KKPHIM_API_URL}"
                save_config ;;
            *"CDN ảnh"*)
                read -r -p "Nhập URL CDN ảnh (Enter = $DEFAULT_KKPHIM_CDN_URL): " inp
                KKPHIM_CDN_URL="${inp:-$DEFAULT_KKPHIM_CDN_URL}"
                save_config ;;
            *"Server ưu tiên"*)
                pref=$(printf '%s\n' "auto|Tự động (server đầu tiên của phim)" "vietsub|Vietsub" "long-tieng|Lồng tiếng" "thuyet-minh|Thuyết minh" | fzf --prompt="Server ưu tiên > " --delimiter='|' --with-nth=1 --header="Chọn nguồn phụ đề mặc định khi phát phim từ $SOURCE_NAME")
                KKPHIM_SERVER_PREF="${pref%%|*}"
                [ -z "$KKPHIM_SERVER_PREF" ] && KKPHIM_SERVER_PREF="auto"
                echo "🔉 Server ưu tiên: $KKPHIM_SERVER_PREF"
                save_config ;;
            *"Số kết quả tìm kiếm"*)
                read -r -p "Số kết quả mỗi trang (Enter = $DEFAULT_KKPHIM_SEARCH_LIMIT): " inp
                inp="${inp:-$DEFAULT_KKPHIM_SEARCH_LIMIT}"
                if [[ "$inp" =~ ^[0-9]+$ ]] && [ "$inp" -ge 1 ]; then
                    [ "$inp" -gt 64 ] && inp=64      # API của KKPhim giới hạn 64 kết quả/trang
                    KKPHIM_SEARCH_LIMIT="$inp"
                    save_config
                else
                    echo "❌ Phải là số từ 1 đến 64."; sleep 1
                fi ;;
            *"Cache chi tiết phim"*)
                read -r -p "Số giây giữ cache chi tiết phim (Enter = $DEFAULT_KKPHIM_DETAIL_TTL): " inp
                inp="${inp:-$DEFAULT_KKPHIM_DETAIL_TTL}"
                if [[ "$inp" =~ ^[0-9]+$ ]] && [ "$inp" -ge 0 ]; then
                    KKPHIM_DETAIL_TTL="$inp"
                    save_config
                    [ "${KKPHIM_DETAIL_TTL:-0}" -gt 1800 ] && echo "⚠️ Cache lâu quá 30 phút: link m3u8 có thể đã hết hạn." && sleep 2
                else
                    echo "❌ Phải là số giây."; sleep 1
                fi ;;
            *"Chặn quảng cáo"*)
                if kkphim_ad_block_enabled; then
                    KKPHIM_AD_BLOCK=0
                    echo "⏹ Đã TẮT chặn quảng cáo (phát nguyên playlist gốc)."
                else
                    KKPHIM_AD_BLOCK=1
                    echo "✅ Đã BẬT chặn quảng cáo (lọc segment quảng cáo trong m3u8)."
                fi
                save_config
                sleep 1.2 ;;
            *"Mẫu nhận diện quảng cáo"*)
                echo "🏷️ Các mẫu cách nhau bằng dấu phẩy; so khớp nguyên 1 thành phần"
                echo "   của host/đường dẫn (vd: ad, ads, preroll, quangcao, vast)."
                echo "   Mặc định: $DEFAULT_KKPHIM_AD_PATTERNS"
                read -r -p "Mẫu mới (Enter = giữ nguyên): " inp
                if [ -n "$inp" ]; then
                    KKPHIM_AD_PATTERNS="$inp"
                    save_config
                    echo "✅ Đã lưu: $KKPHIM_AD_PATTERNS"
                    sleep 1.2
                fi ;;
            *"Xóa cache"*)
                rm -f "$CACHE_DIR"/kkphim-*.json "$CACHE_DIR"/poster-* 2>/dev/null
                echo "🧹 Đã dọn cache dữ liệu phim."
                sleep 1 ;;
            *) break ;;
        esac
    done
}

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

update_script() {
    local remote=$(curl -s "$SCRIPT_URL")
    if [ -n "$remote" ]; then
         if ! diff -q "$0" <(echo "$remote") >/dev/null; then
             echo "Phát hiện bản cập nhật. Đang cài..."
             echo "$remote" > "$0"
             echo "Xong. Hãy khởi động lại."
             exit 0
         else
             echo "Phiên bản hiện tại là mới nhất."
             sleep 1
         fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# ██████╗ ██████╗ ███╗   ██╗ ██████╗  █████╗     ██████╗ ███████╗ █████╗ ██████╗ ███████╗██████╗ 
# ██╔══██╗██╔══██╗████╗  ██║██╔════╝ ██╔══██╗    ██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗
# ██████╔╝██████╔╝██╔██╗ ██║██║  ███╗███████║    ██████╔╝█████╗  ███████║██║  ██║█████╗  ██████╔╝
# ██╔═══╝ ██╔══██╗██║╚██╗██║██║   ██║██╔══██║    ██╔══██╗██╔══╝  ██╔══██║██║  ██║██╔══╝  ██╔══██╗
# ██║     ██║  ██║██║ ╚████║╚██████╔╝██║  ██║    ██║  ██║███████╗██║  ██║██████╔╝███████╗██║  ██║
# ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝    ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝
# MANGA READER - NGUỒN TRUYENVN (https://truyenvn.my)
# ═══════════════════════════════════════════════════════════════════════════════
# Lưu ý khi bảo trì: TruyenVN đã bỏ WordPress nên không còn
#   /?s=tu-khoa&post_type=wp-manga
# nữa; trang /tim-kiem cũng KHÔNG lọc theo ?q= ở phía server (kết quả trả về là
# danh sách mới cập nhật, phần lọc do JavaScript của web tự làm). Vì vậy anisub
# tìm truyện bằng cách: tải các danh sách của site rồi tự lọc theo từ khóa
# (không phân biệt hoa/thường và có dấu/không dấu).
# URL nguồn nằm trong config.cfg (MANGA_BASE_URL) - sửa khi họ đổi domain.

MANGA_BASE_URL="${MANGA_BASE_URL:-}"

# Gọi 1 URL của TruyenVN, in nội dung ra stdout (lỗi -> return 1).
# Tham số 2+ dạng key=value được curl -G --data-urlencode tự mã hoá.
manga_http_fetch() {
    local target="$1"
    shift
    [ -z "$target" ] && return 1
    local base="${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
    target=$(manga_abs_url "$target")   # đường dẫn tương đối -> tuyệt đối theo MANGA_BASE_URL
    local -a opts=()
    local kv
    for kv in "$@"; do
        [ -n "$kv" ] && opts+=(--data-urlencode "$kv")
    done
    # Trang chapter của TruyenVN có thể trả bản rút gọn (không có <img>) tùy request.
    # Vì vậy hỗ trợ nhiều "kiểu request": normal | minimal | bot (xem fetch_chapter_images).
    local variant="${MANGA_FETCH_VARIANT:-normal}"
    local ua="$MANGA_USER_AGENT"
    local referer="${base%/}/"
    local -a cookie_opts=(-c "$MANGA_COOKIE_JAR" -b "$MANGA_COOKIE_JAR")
    local -a hdr_opts=(
        -H "accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"
        -H "accept-language: vi,en;q=0.8"
        -H "sec-fetch-dest: document"
        -H "sec-fetch-mode: navigate"
        -H "sec-fetch-site: none"
        -H "sec-fetch-user: ?1"
        "${MANGA_BROWSER_HEADERS[@]}"
    )
    case "$variant" in
        minimal)
            cookie_opts=()
            referer=""
            hdr_opts=(-H "accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            ;;
        bot)
            cookie_opts=()
            referer=""
            ua="Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
            hdr_opts=(-H "accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            ;;
    esac
    local tmp status
    tmp=$(mktemp "${TMPDIR:-/tmp}/anisub-manga.XXXXXX" 2>/dev/null) || tmp="${TMPDIR:-/tmp}/anisub-manga.$$.tmp"
    local -a referer_opt=()
    [ -n "$referer" ] && referer_opt=(-e "$referer")
    # kiểu dự phòng (minimal/bot) chạy nhanh: không retry, timeout ngắn -> đỡ bắt chờ
    local -a retry_opt=(--retry 2 --retry-delay 1)
    local max_time=25
    if [ "$variant" != "normal" ]; then
        retry_opt=(--retry 0)
        max_time=15
    fi
    status=$(curl -sS -G -L --compressed --max-time "$max_time" "${retry_opt[@]}" \
        -A "$ua" \
        "${cookie_opts[@]}" \
        "${hdr_opts[@]}" \
        "${referer_opt[@]}" \
        -o "$tmp" -w '%{http_code}' \
        "${opts[@]}" \
        "${target}" 2>/dev/null)
    MANGA_HTTP_STATUS="${status:-000}"
    printf '%s' "$MANGA_HTTP_STATUS" > "$ANISUB_STATUS_FILE" 2>/dev/null || true
    case "$MANGA_HTTP_STATUS" in
        2??)
            if [ -s "$tmp" ]; then
                cat "$tmp"; rm -f "$tmp"
                return 0
            fi
            ;;
    esac
    rm -f "$tmp"
    return 1
}

# Gọi API POST (form-urlencoded) của TruyenVN, dùng cho /webapi/stories/list-chapter.
# $1 = path/URL, $2 = body, $3 = CSRF token, $4 = Referer (đúng là trang truyện)
# In body ra stdout; mã HTTP lưu ở MANGA_HTTP_STATUS; lỗi -> return 1.
manga_http_post() {
    local target="$1"
    local body="$2"
    local token="${3:-}"
    local referer="${4:-}"
    [ -z "$target" ] && return 1
    target=$(manga_abs_url "$target")
    local -a opts=()
    [ -n "$token" ]   && opts+=(-H "X-CSRF-TOKEN: $token")
    [ -n "$referer" ] && opts+=(-e "$referer")
    local tmp status
    tmp=$(mktemp "${TMPDIR:-/tmp}/anisub-manga-api.XXXXXX" 2>/dev/null) || tmp="${TMPDIR:-/tmp}/anisub-manga-api.$$.tmp"
    status=$(curl -sS -L --compressed --max-time 25 --retry 1 --retry-delay 1 \
        -A "$MANGA_USER_AGENT" \
        -c "$MANGA_COOKIE_JAR" -b "$MANGA_COOKIE_JAR" \
        -H "accept: application/json, text/javascript, */*; q=0.01" \
        -H "accept-language: vi,en;q=0.8" \
        -H "X-Requested-With: XMLHttpRequest" \
        -H "content-type: application/x-www-form-urlencoded; charset=UTF-8" \
        -H "sec-fetch-dest: empty" \
        -H "sec-fetch-mode: cors" \
        -H "sec-fetch-site: same-origin" \
        "${MANGA_BROWSER_HEADERS[@]}" \
        "${opts[@]}" \
        --data "$body" \
        -o "$tmp" -w '%{http_code}' \
        "$target" 2>/dev/null)
    MANGA_HTTP_STATUS="${status:-000}"
    printf '%s' "$MANGA_HTTP_STATUS" > "$ANISUB_STATUS_FILE" 2>/dev/null || true
    case "$MANGA_HTTP_STATUS" in
        2??)
            if [ -s "$tmp" ]; then
                cat "$tmp"; rm -f "$tmp"
                return 0
            fi
            ;;
    esac
    rm -f "$tmp"
    return 1
}

# story_id nhúng trong trang truyện (`"story_id": 12189`) - API bắt buộc cần id này
manga_story_id() {
    perl -0777 -ne '
        print $1 and exit if /"story_id"\s*:\s*"?([0-9]+)/;
        print $1 and exit if /\bstory_id\s*=\s*["\x27]?([0-9]+)/;
    ' 2>/dev/null
}

# CSRF token trong <meta name="csrf-token" content="..."> (thiếu -> API trả HTTP 419)
manga_csrf_token() {
    perl -0777 -ne '
        while (/<meta\b[^>]*>/gi) {
            my $t = $&;
            next unless $t =~ /name\s*=\s*["\x27]csrf-token["\x27]/i;
            print $1 and exit if $t =~ /content\s*=\s*["\x27]([^"\x27]+)/i;
        }
        print $1 and exit if /"csrf[-_]?token"\s*:\s*"([^"]+)"/i;
        print $1 and exit if /name\s*=\s*["\x27]_token["\x27][^>]*content\s*=\s*["\x27]([^"\x27]+)/i;
    ' 2>/dev/null
}

# Rút "data":{"html":"..."} từ JSON của API rồi giải escape (\", \/, \n, \uXXXX)
manga_json_html() {
    perl -CS -Mutf8 -0777 -ne '
        my $j = $_;
        if ($j =~ /"html"\s*:\s*"((?:[^"\\]|\\.)*)"/s) {
            my $h = $1;
            $h =~ s/\\u([0-9a-fA-F]{4})/chr(hex($1))/ge;
            $h =~ s/\\n/\n/g;
            $h =~ s/\\r//g;
            $h =~ s/\\t/ /g;
            $h =~ s/\\\//\//g;
            $h =~ s/\\"/"/g;
            $h =~ s/\\\\/\\/g;
            print $h;
        }
    ' 2>/dev/null
}

# Trang truyện KHÔNG render danh sách chapter: HTML chỉ có 2 link "Đọc từ đầu"
# (chapter-0) và "Chap mới nhất" (chapter cuối). Danh sách thật do JS của web lấy từ
#   POST /webapi/stories/list-chapter   body: story_id=<id>&routeName=story.detail
#   header: X-CSRF-TOKEN + X-Requested-With + Referer  ->  {"data":{"html":"..."}}
# Hàm này in HTML đầy đủ để fetch_chapter_list parse; API lỗi thì fallback về trang
# truyện (chỉ còn chapter đầu/cuối) và nói rõ lý do ra stderr.
# Cửa sổ phiên của web chỉ 60 giây nên gặp HTTP 419 thì tải lại trang lấy token mới.
manga_chapter_list_html() {
    local page_url="$1"
    local html
    if ! html=$(manga_http_fetch "$page_url"); then
        return 1
    fi
    MANGA_STORY_COVER=$(printf '%s' "$html" | manga_page_cover)
    [ -n "$MANGA_STORY_COVER" ] && manga_cover_cache_put "${page_url##*/}" "$MANGA_STORY_COVER"
    local story_id token
    story_id=$(printf '%s' "$html" | manga_story_id)
    # Không thấy "story_id" trong HTML thì suy từ ảnh bìa: imggo.net/books/<id>/cover_*.jpg
    if [ -z "$story_id" ] && [ -n "$MANGA_STORY_COVER" ]; then
        story_id=$(printf '%s' "$MANGA_STORY_COVER" | sed -n 's#.*/books/\([0-9][0-9]*\)/.*#\1#p')
    fi
    token=$(printf '%s' "$html" | manga_csrf_token)
    if [ -n "$story_id" ]; then
        local body="story_id=$story_id&routeName=story.detail"
        local attempt=1 resp frag
        while [ "$attempt" -le 2 ]; do
            if resp=$(manga_http_post "/webapi/stories/list-chapter" "$body" "$token" "$page_url"); then
                frag=$(printf '%s' "$resp" | manga_json_html)
                if [ -n "$frag" ]; then
                    printf '%s' "$frag"
                    return 0
                fi
            fi
            if [ "$(anisub_last_http)" != "419" ]; then
                break
            fi
            # Hết phiên 60s -> tải lại trang để lấy CSRF token mới rồi thử lại
            html=$(manga_http_fetch "$page_url") || break
            token=$(printf '%s' "$html" | manga_csrf_token)
            [ -z "$token" ] && break
            attempt=$((attempt + 1))
        done
        echo "⚠️ Không lấy được danh sách chapter đầy đủ từ API (HTTP $(anisub_last_http)) - chỉ còn chapter đầu/cuối" >&2
    else
        echo "⚠️ Không tìm thấy story_id/CSRF trong trang truyện - danh sách chapter có thể thiếu" >&2
    fi
    printf '%s' "$html"
    return 0
}

# Nhớ ảnh bìa theo slug (ghi ra file vì fetch_chapter_list chạy trong subshell $(...))
manga_cover_cache_put() {
    local slug="${1:-}" cover="${2:-}"
    [ -z "$slug" ] || [ -z "$cover" ] && return 0
    mkdir -p "$CACHE_DIR" 2>/dev/null
    local tmp="${CACHE_DIR}/manga-covers.txt"
    { grep -v "^${slug}|" "$tmp" 2>/dev/null; printf '%s|%s\n' "$slug" "$cover"; } > "${tmp}.new" 2>/dev/null &&
        mv "${tmp}.new" "$tmp" 2>/dev/null
    return 0
}

manga_cover_cache_get() {
    local slug="${1:-}"
    [ -z "$slug" ] && return 0
    sed -n "s/^${slug}|//p" "${CACHE_DIR}/manga-covers.txt" 2>/dev/null | tail -1
}

# Ảnh bìa của truyện, lấy từ og:image (hoặc <img> bìa đầu tiên) trong trang truyện
manga_page_cover() {
    MANGA_BASE_URL="${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}" perl -CS -Mutf8 -0777 -ne '
        my $base = $ENV{MANGA_BASE_URL} // ""; $base =~ s{/$}{};
        my $u = "";
        if (/(?:og:image|twitter:image)["\x27]?\s*(?:property|name)?[^>]*content\s*=\s*["\x27]([^"\x27]+)/i) {
            $u = $1;
        } elsif (/<img\b[^>]*\b(?:class|src)\s*=\s*["\x27][^"\x27]*(?:cover|summary_image|book)[^"\x27]*["\x27][^>]*>/i) {
            my $tag = $&;
            ($u) = $tag =~ /(?:data-(?:lazy-)?src|src)\s*=\s*["\x27]([^"\x27]+)/i;
        }
        $u = "" unless defined $u;
        $u =~ s/&amp;/&/g; $u =~ s/^\s+|\s+$//g;
        $u = "https:$u" if $u =~ m{^//};
        $u = "$base$u" if $u =~ m{^/};
        print $u;
    ' 2>/dev/null
}

# ═══ NGUỒN NETTRUYEN (nettruyen.info) ═══════════════════════════════════════
# CMS kiểu NetTruyen: danh sách chương nằm sẵn trong HTML trang truyện (không cần
# API/CSRF), ảnh trang đọc có dạng https://net.imgchapter.store/<slug>/<chap>/page_<i>.jpg
# Nhãn hiển thị của nguồn đang dùng
manga_source_label() {
    if manga_is_nettruyen; then printf 'nettruyen'; else printf 'TruyenVN'; fi
}

manga_is_nettruyen() {
    case "${MANGA_SOURCE:-$DEFAULT_MANGA_SOURCE}" in
        nettruyen|nt|nettruyen.info) return 0 ;;
        *)                           return 1 ;;
    esac
}

# slug hoặc URL -> "truyen-<slug>" (route trên nettruyen)
nt_route_of() {
    local v="${1:-}"
    case "$v" in
        http://*|https://*)
            # URL chương .../truyen-<slug>/chuong-N -> lấy đoạn truyen-<slug>
            local r
            r=$(printf '%s' "$v" | sed -n 's#.*/\(truyen-[A-Za-z0-9_.-]*\)/.*#\1#p')
            if [ -n "$r" ]; then
                printf '%s' "$r"
                return 0
            fi
            v="${v%%\?*}"; v="${v%/}"; v="${v##*/}" ;;
    esac
    v="${v#/}"
    case "$v" in
        "")       : ;;
        truyen-*) printf '%s' "$v" ;;
        *)        printf 'truyen-%s' "$v" ;;
    esac
}

# Có phải URL chương của nettruyen (/truyen-.../chuong-N) -> in ra "route|chap"
nt_chapter_parts() {
    local u="${1:-}"
    printf '%s' "$u" | sed -n 's#.*/\(truyen-[A-Za-z0-9_.-]*\)/chuong-\([0-9][0-9.-]*\).*#\1|\2#p'
}

# Số chapter -> URL chương của nguồn đang dùng
manga_chapter_url() {
    local page_url="$1" num="$2"
    num="${num//[^0-9.]/}"
    [ -z "$num" ] && return 1
    if manga_is_nettruyen; then
        printf '%s/chuong-%s' "${page_url%/}" "$num"
    else
        printf '%s/chapter-%s' "${page_url%/}" "${num//./-}"
    fi
}

# HTML danh sách truyện (trang chủ / thể loại / tìm kiếm) -> name|url|slug|cover
nt_parse_items() {
    MANGA_BASE_URL="${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}" perl -CS -Mutf8 -0777 -ne '
        my $base = $ENV{MANGA_BASE_URL} // ""; $base =~ s{/$}{};
        sub clean {
            my $t = shift // "";
            $t =~ s/<[^>]*>/ /g;
            $t =~ s/&nbsp;/ /g;
            $t =~ s/&amp;/&/g;
            $t =~ s/&quot;/"/g;
            $t =~ s/&#0?39;|&apos;/chr(39)/ge;
            $t =~ s/&lt;/</g;
            $t =~ s/&gt;/>/g;
            $t =~ s/\s+/ /g;
            $t =~ s/^ |$//g;
            return $t;
        }
        # ảnh bìa: /images/<slug>.jpg hoặc /storage/thumbnails/<slug>.jpg
        my %cover;
        while (/(?:images|storage\/thumbnails|storage\/covers)\/([A-Za-z0-9_.\-]+)\.(?:jpe?g|png|webp)/gi) {
            my $k = $1;
            $cover{$k} = "$base/$&" unless exists $cover{$k};
        }
        my (%name, %score, @order, %seen);
        while (/<a\b([^>]*)>(.*?)<\/a>/gs) {
            my ($attrs, $inner) = ($1, $2);
            my ($href) = $attrs =~ /href\s*=\s*(?:"([^"]*)"|'\''([^'\'']*)'\''|([^\s">]+))/;
            next unless defined $href && length $href;
            next unless $href =~ m{(?:^|/)(truyen-[A-Za-z0-9_.\-]+)/?(?:[?#].*)?$};
            my $route = $1;
            next if $href =~ m{/chuong-};
            my ($nm, $sc) = ("", 0);
            if ($attrs =~ /title\s*=\s*(?:"([^"]*)"|'\''([^'\'']*)'\'')/) {
                $nm = clean(defined $1 ? $1 : $2);
                $nm =~ s/^Truy(?:en|ện) tranh\s+//i;
                $sc = 4 if length $nm;
            }
            if ($sc < 4) {
                my $txt = clean($inner);
                if (length($txt) >= 2 && $txt !~ /^(chapter|chap|đọc|xem|theo dõi)\b/i) { $nm = $txt; $sc = 3 }
            }
            if ($sc < 3) {
                my ($alt) = $inner =~ /alt\s*=\s*(?:"([^"]*)"|'\''([^'\'']*)'\'')/;
                $alt = clean($alt);
                if (length($alt) >= 2) { $nm = $alt; $sc = 2 }
            }
            if (!length $nm) {
                (my $p = $route) =~ s/^truyen-//;
                $p =~ s/[-_]+/ /g; $p =~ s/\b(\w)/\u$1/g;
                $nm = $p; $sc = 1;
            }
            if (!exists $seen{$route}) { push @order, $route; $seen{$route} = 1; $name{$route} = $nm; $score{$route} = $sc }
            elsif ($score{$route} < $sc) { $name{$route} = $nm; $score{$route} = $sc }
            if ($inner =~ /<img\b([^>]*)>/i) {
                my $ia = $1;
                my $cv = "";
                if ($ia =~ /data-(?:lazy-)?(?:src|original|echo)\s*=\s*(?:"([^"]*)"|'\''([^'\'']*)'\'')/i) {
                    $cv = defined $1 ? $1 : $2;
                } elsif ($ia =~ /\ssrc\s*=\s*(?:"([^"]*)"|'\''([^'\'']*)'\'')/i) {
                    $cv = defined $1 ? $1 : $2;
                }
                $cv = "" unless defined $cv;
                $cv =~ s/&amp;/&/g; $cv =~ s/^\s+|\s+$//g;
                $cv = "" if $cv =~ m{^data:}i;
                $cv = "https:$cv" if $cv =~ m{^//};
                $cv = "$base$cv" if $cv =~ m{^/};
                if (length $cv && !exists $cover{"__$route"}) { $cover{"__$route"} = $cv }
            }
        }
        for my $route (@order) {
            my $key = $route; $key =~ s/^truyen-//;
            my $cv = $cover{"__$route"} // $cover{$key} // "";
            print "$name{$route}|$base/$route|$route|$cv\n";
        }
    '
}

# Tìm kiếm trên nettruyen: /tim-kiem?keyword=<kw>
nt_search_items() {
    local kw="${1:-}"
    local html items filtered
    if ! html=$(manga_http_fetch "/tim-kiem" "keyword=$kw"); then
        echo "⚠️ Không tìm được (HTTP $(anisub_last_http)) - kiểm tra mạng hoặc ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}" >&2
        return 1
    fi
    items=$(printf '%s' "$html" | nt_parse_items)
    if [ -z "$items" ]; then
        echo "⚠️ Trang tìm kiếm không trả về truyện nào (web đổi cấu trúc hoặc từ khoá quá lạ)." >&2
        return 1
    fi
    # Web có thể trả cả danh sách chung -> lọc lại theo từ khoá; không khớp thì giữ nguyên
    filtered=$(printf '%s\n' "$items" | manga_match_items "$kw")
    if [ -n "$filtered" ]; then
        printf '%s\n' "$filtered"
    else
        printf '%s\n' "$items"
    fi
}

# Danh sách chương từ trang truyện (server render): name|url|chuong-N (cũ ->mới)
nt_fetch_chapter_list() {
    local target="$1"
    local page_url
    page_url=$(manga_manga_url "$target")
    [ -z "$page_url" ] && return 1
    local route="${page_url##*/}"
    local html
    if ! html=$(manga_http_fetch "$page_url"); then
        echo "⚠️ Không tải được trang truyện ($route) - HTTP $(anisub_last_http)" >&2
        return 1
    fi
    MANGA_STORY_COVER=$(printf '%s' "$html" | manga_page_cover)
    [ -n "$MANGA_STORY_COVER" ] && manga_cover_cache_put "$route" "$MANGA_STORY_COVER"
    printf '%s' "$html" | MANGA_BASE_URL="${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}" NT_ROUTE="$route" \
        perl -CS -Mutf8 -0777 -ne '
        my $base = $ENV{MANGA_BASE_URL} // ""; $base =~ s{/$}{};
        my $route = $ENV{NT_ROUTE} // "";
        my (%seen, @out);
        while (/<a\b([^>]*)>(.*?)<\/a>/gs) {
            my ($attrs, $inner) = ($1, $2);
            my ($href) = $attrs =~ /href\s*=\s*(?:"([^"]*)"|'\''([^'\'']*)'\''|([^\s">]+))/;
            next unless defined $href && length $href;
            next unless $href =~ m{/(truyen-[A-Za-z0-9_.\-]+)/chuong-([0-9][0-9.\-]*)/?(?:[?#].*)?$};
            my ($r, $num) = ($1, $2);
            next if length($route) && $r ne $route;
            my $u = $href;
            $u = "$base$u" if $u =~ m{^/};
            next if $seen{$u}++;
            my $txt = $inner; $txt =~ s/<[^>]*>/ /g; $txt =~ s/\s+/ /g; $txt =~ s/^ |$//g;
            my $name = ($txt =~ /^chapter\b/i && length $txt <= 40) ? $txt : "Chapter $num";
            printf "%s|%s|chuong-%s\n", $name, $u, $num;
        }
    ' | sort -s -t'|' -k3,3V
}

# Ảnh trang đọc của nettruyen: ưu tiên URL dạng .../page_<i>.jpg
nt_parse_image_urls() {
    MANGA_NT_IMAGE_HOST="${MANGA_NT_IMAGE_HOST:-https://net.imgchapter.store}" \
    perl -CS -Mutf8 -0777 -ne '
        my $host = $ENV{MANGA_NT_IMAGE_HOST} // "https://net.imgchapter.store";
        $host =~ s{/$}{};
        my %page; my @other;
        while (m{(?:(?:https?:)?//|/)[^"\x27\s<>()]*?/page[_-]?([0-9]+)\.(?:jpe?g|png|webp|avif)}gi) {
            my ($i, $u) = ($1, $&);
            $u = "https:$u" if $u =~ m{^//};
            $u = "$host$u" if $u =~ m{^/};
            $page{$i + 0} = $u unless exists $page{$i + 0};
        }
        while (m{((?:https?:)?//[^"\x27\s<>()]*imgchapter[^"\x27\s<>()]*\.(?:jpe?g|png|webp|avif))}gi) {
            push @other, $1;
        }
        print "$page{$_}\n" for sort { $a <=> $b } keys %page;
        if (!%page) { my %s; print "$_\n" for grep { !$s{$_}++ } @other; }
    '
}

# Dự phòng: tự dò trang ảnh theo mẫu URL (HEAD từng trang, dừng khi trượt 3 lần)
nt_probe_page_urls() {
    local chapter_url="$1"
    local parts slug chap
    parts=$(nt_chapter_parts "$chapter_url")
    [ -z "$parts" ] && return 1
    slug="${parts%%|*}"
    chap="${parts##*|}"
    slug="${slug#truyen-}"
    case "$chap" in *[!0-9]*|"") return 1 ;; esac
    local host="${MANGA_NT_IMAGE_HOST:-https://net.imgchapter.store}"
    local i code misses=0 found=0
    for i in $(seq 0 299); do
        code=$(curl -s -I --max-time 10 -A "$MANGA_USER_AGENT" -o /dev/null -w '%{http_code}' \
            "$host/$slug/$chap/page_$i.jpg" 2>/dev/null)
        if [ "$code" = "200" ]; then
            printf '%s/%s/%s/page_%s.jpg\n' "$host" "$slug" "$chap" "$i"
            misses=0; found=1
        else
            misses=$((misses + 1))
            [ "$misses" -ge 3 ] && break
        fi
    done
    [ "$found" = "1" ]
}

# Lấy ảnh trang đọc của nettruyen (thử trực tiếp -> reader-proxy -> tự dò mẫu URL)
nt_fetch_chapter_images() {
    local chapter_url="$1"
    [ -z "$chapter_url" ] && return 1
    rm -f "$ANISUB_MANGA_NAV_FILE" 2>/dev/null   # không dùng link chuyển chap của chapter cũ
    local html="" found=""
    html=$(MANGA_FETCH_VARIANT=normal manga_http_fetch "$chapter_url" 2>/dev/null) || html=""
    [ -n "$html" ] && found=$(printf '%s' "$html" | nt_parse_image_urls)
    if [ -z "$found" ]; then
        html=$(manga_proxy_fetch "$chapter_url" 2>/dev/null) || html=""
        [ -n "$html" ] && found=$(printf '%s' "$html" | nt_parse_image_urls)
        [ -n "$found" ] && echo "ℹ️ Đã lấy danh sách ảnh qua ${MANGA_READER_PROXY:-reader-proxy}." >&2
    fi
    if [ -z "$found" ]; then
        found=$(nt_probe_page_urls "$chapter_url" 2>/dev/null)
        [ -n "$found" ] && echo "ℹ️ Trang đọc không trả ảnh - đã tự dò theo mẫu URL." >&2
    fi
    if [ -z "$html" ] && [ -z "$found" ]; then
        echo "⚠️ Không tải được chapter (HTTP $(anisub_last_http))" >&2
        return 1
    fi
    # Nhớ "Chap trước/Chap sau" để reader chuyển chap được kể cả khi thiếu danh sách
    if [ -n "$html" ]; then
        local nav nav_prev nav_next
        nav=$(printf '%s' "$html" | manga_parse_nav)
        if [ -n "$nav" ]; then
            nav_prev="${nav%%|*}"
            nav_next="${nav##*|}"
            [ -n "$nav_prev" ] && nav_prev=$(manga_abs_url "$nav_prev")
            [ -n "$nav_next" ] && nav_next=$(manga_abs_url "$nav_next")
            printf '%s|%s\n' "$nav_prev" "$nav_next" > "$ANISUB_MANGA_NAV_FILE" 2>/dev/null
        fi
    fi
    [ -z "$found" ] && manga_debug_dump "$chapter_url" "$html"
    printf '%s\n' "$found"
}

# URL trang truyện từ slug (hoặc trả nguyên URL nếu đã là URL tuyệt đối)
manga_manga_url() {
    local base="${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
    case "${1:-}" in
        http://*|https://*) printf '%s' "${1%/}" ;;
        "")                 printf '' ;;
        truyen-*)           printf '%s/%s' "$base" "${1#/}" | sed 's#/$##' ;;   # route nettruyen
        *)                  if manga_is_nettruyen; then
                                printf '%s/truyen-%s' "$base" "${1#/}" | sed 's#/$##'
                            else
                                printf '%s/truyen-tranh/%s' "$base" "${1#/}" | sed 's#/$##'
                            fi ;;
    esac
}

# Chuyển href tương đối trong HTML thành URL tuyệt đối
manga_abs_url() {
    local u="${1:-}"
    local base="${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
    case "$u" in
        http://*|https://*) printf '%s' "${u%/}" ;;
        "//"*)              printf 'https:%s' "${u%/}" ;;
        /*)                 printf '%s%s' "${base%/}" "${u%/}" ;;
        *)                  printf '%s/%s' "${base%/}" "${u#/}" ;;
    esac
}

# Chuẩn hoá tên để so khớp: bỏ dấu tiếng Việt, chữ hoa, ký tự lạ
manga_norm() {
    perl -CS -Mutf8 -MUnicode::Normalize -pe '
        $_ = lc NFD($_);
        s/\pM//g;
        s/đ/d/g;
        s/[^a-z0-9]+/ /g;
        s/^ +//; s/ +$//;
    ' 2>/dev/null || tr 'A-Z' 'a-z'
}

# Lọc các dòng "Tên|URL|slug" theo từ khóa (mọi từ khóa đều phải xuất hiện)
manga_match_items() {
    local kw="$1"
    [ -z "$kw" ] && { cat; return 0; }
    MANGA_KW="$kw" perl -CS -Mutf8 -MUnicode::Normalize -ne '
        sub nm {
            my $s = shift // "";
            $s = lc NFD($s);
            $s =~ s/\pM//g;
            $s =~ s/\x{0111}/d/g;
            $s =~ s/[^a-z0-9]+/ /g;
            $s =~ s/^ +//; $s =~ s/ +$//;
            return $s;
        }
        BEGIN {
            my $raw = defined $ENV{MANGA_KW} ? $ENV{MANGA_KW} : "";
            utf8::decode($raw);          # %ENV luôn là byte -> phải tự decode
            @need = grep { length } split /\s+/, nm($raw);
        }
        chomp;
        my ($t, $u, $s) = split /\|/, $_, 3;
        my $hay = nm("$t " . ($s // ""));
        my $all = @need ? 1 : 1;
        for my $n (@need) { $all = 0 if index($hay, $n) < 0 }
        print "$_\n" if $all;
    '
}

# ═══ ẢNH: tải & vẽ trong terminal ═══════════════════════════════════════════
# Lưu ý quan trọng: CDN ảnh của TruyenVN (imggo.net) trả 403 với MỌI request có
# header Referer (web của họ cũng dùng <img referrerpolicy="no-referrer">). Vì vậy
# khi tải ảnh bìa / ảnh trang truyện TUYỆT ĐỐI không gửi Referer.
MANGA_COVER_CACHE="${CACHE_DIR}/manga-covers"

# Giao thức vẽ ảnh cho chafa: kitty | sixel | iterm | symbols
# auto: chỉ chọn kitty/sixel/iterm khi terminal chắc chắn hỗ trợ, còn lại dùng
# symbols (vẽ bằng ký tự) để ảnh LUÔN hiện - trước đây ép sixels nên terminal
# không hỗ trợ thì không thấy gì cả.
manga_image_protocol() {
    local want="${MANGA_IMAGE_PROTOCOL:-$DEFAULT_MANGA_IMAGE_PROTOCOL}"
    case "$want" in
        kitty|sixel|iterm|symbols) printf '%s' "$want"; return 0 ;;
    esac
    case "${TERM:-}" in
        *kitty*) printf 'kitty'; return 0 ;;
        *sixel*) printf 'sixel'; return 0 ;;
        foot*|xterm-foot*) printf 'sixel'; return 0 ;;
    esac
    case "${TERM_PROGRAM:-}" in
        iTerm.app|WezTerm|mintty|contour|mlterm|ghostty) printf 'iterm'; return 0 ;;
        Apple_Terminal) printf 'symbols'; return 0 ;;
    esac
    [ -n "${KITTY_WINDOW_ID:-}" ] && { printf 'kitty'; return 0; }
    [ -n "${WEZTERM_PANE:-}" ]    && { printf 'iterm'; return 0; }
    [ "${LC_TERMINAL:-}" = "iTerm2" ] && { printf 'iterm'; return 0; }
    printf 'symbols'
}

# Tham số chafa cho từng giao thức (dùng chung cho preview fzf & script sinh ra)
manga_chafa_args() {
    case "$(manga_image_protocol)" in
        kitty)   printf '%s' '-f kitty' ;;
        sixel)   printf '%s' '-f sixels' ;;
        iterm)   printf '%s' '-f iterm' ;;
        *)       printf '%s' '-f symbols --symbols=block --colors=256' ;;
    esac
}

# 1 nếu file là ảnh thật (đọc magic bytes) - tránh trường hợp CDN trả trang HTML
# lỗi (403) mà vẫn lưu thành .jpg rồi chafa không vẽ được gì.
manga_file_is_image() {
    local f="${1:-}"
    [ -s "$f" ] || { printf '0'; return 1; }
    local magic
    magic=$(head -c 16 "$f" 2>/dev/null | od -An -tx1 2>/dev/null | tr -d ' \n')
    if [ -n "$magic" ]; then
        case "$magic" in
            ffd8ff*|89504e47*|47494638*|52494646*|424d*|*66747970*)
                printf '1'; return 0 ;;
        esac
        if command -v file >/dev/null 2>&1; then
            case "$(file -b "$f" 2>/dev/null)" in
                *image*|*JPEG*|*PNG*|*Web/P*|*GIF*) printf '1'; return 0 ;;
            esac
        fi
        printf '0'; return 1     # đọc được magic mà không khớp ảnh -> không phải ảnh
    fi
    if command -v file >/dev/null 2>&1; then
        case "$(file -b "$f" 2>/dev/null)" in
            *image*|*JPEG*|*PNG*|*Web/P*|*GIF*) printf '1'; return 0 ;;
            *) printf '0'; return 1 ;;
        esac
    fi
    # Máy thiếu cả `od` lẫn `file` thì đừng chặn oan (curl -f đã lo phần HTTP lỗi)
    printf '1'; return 0
}

# Tải 1 ảnh (KHÔNG Referer) -> $2. return 0 nếu file tải về đúng là ảnh.
manga_download_image() {
    local url="${1:-}" dest="${2:-}"
    [ -z "$url" ] || [ -z "$dest" ] && return 1
    local tmp="${dest}.part"
    rm -f "$tmp" 2>/dev/null
    # Lần 1: KHÔNG Referer (CDN của TruyenVN - imggo.net - trả 403 nếu có Referer)
    curl -fsSL --compressed --max-time 30 --retry 2 --retry-delay 1 \
        -A "$MANGA_USER_AGENT" \
        -o "$tmp" "$url" >/dev/null 2>&1
    if [ "$(manga_file_is_image "$tmp")" = "1" ]; then
        mv "$tmp" "$dest" 2>/dev/null && return 0
    fi
    # Lần 2: có Referer (một số mirror/CDN lại bắt buộc) - nhận cái nào ra ảnh thật
    rm -f "$tmp" 2>/dev/null
    curl -fsSL --compressed --max-time 30 --retry 1 --retry-delay 1 \
        -A "$MANGA_USER_AGENT" \
        -e "${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}/" \
        -o "$tmp" "$url" >/dev/null 2>&1
    if [ "$(manga_file_is_image "$tmp")" = "1" ]; then
        mv "$tmp" "$dest" 2>/dev/null && return 0
    fi
    rm -f "$tmp" 2>/dev/null
    return 1
}

# HTML trang chapter (stdin) -> "prev|next": link "Chap trước" / "Chap sau".
# Trang chapter được render ở server nên đây là đường dự phòng khi API danh sách
# chapter hỏng: vẫn chuyển được chap mà không cần danh sách đầy đủ.
manga_parse_nav() {
    MANGA_BASE_URL="${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}" perl -CS -Mutf8 -0777 -ne '
        my $base = $ENV{MANGA_BASE_URL} // ""; $base =~ s{/$}{};
        my ($prev, $next) = ("", "");
        while (/<a\b([^>]*)>(.*?)<\/a>/gs) {
            my ($attrs, $inner) = ($1, $2);
            my ($href) = $attrs =~ /href\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27|([^\s">]+))/;
            next unless defined $href && length $href;
            $href =~ s/&amp;/&/g;
            $href = "https:$href" if $href =~ m{^//};
            $href = "$base$href" if $href =~ m{^/};
            my $txt = $inner;
            $txt =~ s/<[^>]*>/ /g;
            $txt =~ s/&nbsp;/ /g;
            $txt =~ s/\s+/ /g;
            $txt =~ s/^[^A-Za-zÀ-ỹ]+//;                 # bỏ « ‹ ← ở đầu
            $txt =~ s/\s+$//;
            my ($rel) = $attrs =~ /rel\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27)/ ? ($1 // $2) : "";
            $rel = "" unless defined $rel;
            if (!length $prev && ($rel =~ /\bprev\b/i || $txt =~ /^(chap\s*)?(tr(?:ư|u)(?:ớ|o)c|prev(?:ious)?|back)\b/i)) {
                $prev = $href;
            }
            if (!length $next && ($rel =~ /\bnext\b/i || $txt =~ /^(chap\s*)?(sau|ti(?:ế|e)p|next)\b/i)) {
                $next = $href;
            }
        }
        if (!length $prev || !length $next) {     # markdown: [Chap trước](url)
            while (/\[([^\]]{1,40})\]\(\s*(https?:[^)\s]+)\s*\)/g) {
                my ($txt, $href) = ($1, $2);
                $txt =~ s/^[^A-Za-zÀ-ỹ]+//;
                $txt =~ s/\s+$//;
                if (!length $prev && $txt =~ /^(chap\s*)?(tr(?:ư|u)(?:ớ|o)c|prev(?:ious)?|back)\b/i) { $prev = $href }
                if (!length $next && $txt =~ /^(chap\s*)?(sau|ti(?:ế|e)p|next)\b/i) { $next = $href }
            }
        }
        print "$prev|$next";
    ' 2>/dev/null
}

# Đọc "Chap trước|Chap sau" đã lưu của chapter vừa tải
manga_saved_nav() {
    [ -s "$ANISUB_MANGA_NAV_FILE" ] && cat "$ANISUB_MANGA_NAV_FILE"
    return 0
}

# Sinh (1 lần) script preview ảnh bìa cho fzf, in ra đường dẫn script.
# Dùng: fzf --preview "$(manga_cover_preview_script) {}"
# Script nhận dòng "Tên|URL|slug|ảnh-bìa" (hoặc --info-file để chỉ preview 1 bìa).
manga_cover_preview_script() {
    local script="${CACHE_DIR}/manga-cover-preview.sh"
    local chafa_args
    chafa_args=$(manga_chafa_args)
    mkdir -p "$MANGA_COVER_CACHE" 2>/dev/null
    cat > "$script" <<EOF
#!/bin/bash
# (anisub tự sinh - đừng sửa tay) preview ảnh bìa truyện tranh trong fzf
info_file=""
args=()
for a in "\$@"; do
    case "\$a" in
        --info-file) info_pending=1 ;;
        *) if [ -n "\${info_pending:-}" ]; then info_file="\$a"; info_pending=""; else args+=("\$a"); fi ;;
    esac
done
line="\${args[0]:-}"
if [ -n "\$info_file" ] && [ -s "\$info_file" ]; then
    name=\$(cut -d'|' -f1 "\$info_file")
    cover=\$(cut -d'|' -f2 "\$info_file")
else
    name=\$(printf '%s' "\$line" | awk -F'|' '{print \$1}')
    cover=\$(printf '%s' "\$line" | awk -F'|' '{print \$4}')
fi
cache="$MANGA_COVER_CACHE"
mkdir -p "\$cache" 2>/dev/null
if [ -z "\$cover" ]; then
    printf '\n  🖼️  Mục này không có ảnh bìa\n\n  %s\n' "\$name"
    exit 0
fi
key=\$(printf '%s' "\$cover" | cksum | cut -d' ' -f1)
file="\$cache/\$key.img"
if [ ! -s "\$file" ]; then
    # không gửi Referer: CDN ảnh trả 403 nếu có Referer
    curl -fsSL --compressed --max-time 20 -A "$MANGA_USER_AGENT" -o "\$file.part" "\$cover" >/dev/null 2>&1
    if [ -s "\$file.part" ]; then mv "\$file.part" "\$file"; else rm -f "\$file.part"; fi
fi
printf '\n  📖 %s\n\n' "\$name"
if [ ! -s "\$file" ]; then
    printf '  ❌ Không tải được ảnh bìa\n  %s\n' "\$cover"
    exit 0
fi
if command -v chafa >/dev/null 2>&1; then
    cols=\$(( \${FZF_PREVIEW_COLUMNS:-60} - 2 ))
    lines=\$(( \${FZF_PREVIEW_LINES:-30} - 5 ))
    [ "\$cols" -lt 10 ] && cols=10
    [ "\$lines" -lt 6 ] && lines=6
    chafa $chafa_args --size="\${cols}x\${lines}" --animate=off "\$file" 2>/dev/null
else
    printf '  (chưa cài chafa nên không vẽ được ảnh)\n  %s\n' "\$cover"
fi
EOF
    chmod +x "$script" 2>/dev/null
    printf '%s' "$script"
}

# Ghi thông tin truyện ra file tạm để script preview đọc (tránh lỗi quote tên truyện)
# $1 = tên, $2 = ảnh bìa -> in ra đường dẫn file
manga_preview_info_file() {
    local name="${1:-}" cover="${2:-}"
    mkdir -p "$CACHE_DIR" 2>/dev/null
    local file="${CACHE_DIR}/manga-preview-info.txt"
    : > "$file"
    printf '%s|%s\n' "$name" "$cover" > "$file"
    printf '%s' "$file"
}

# --- MANGA HISTORY ---
add_to_manga_history() {
    local manga_name="$1"
    local chapter_name="$2"
    local manga_slug="$3"
    touch "$MANGA_HISTORY_FILE" 2>/dev/null
    # Định dạng file: thời gian|tên truyện|tên chapter|slug
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/anisub-mhist.XXXXXX" 2>/dev/null) || return 0
    awk -F'|' -v n="$manga_name" -v c="$chapter_name" -v s="$manga_slug" \
        '!(NF >= 4 && $2 == n && $3 == c && $4 == s)' "$MANGA_HISTORY_FILE" > "$tmp" 2>/dev/null
    printf '%s|%s|%s|%s\n' "$(date +%Y-%m-%d\ %H:%M:%S)" "$manga_name" "$chapter_name" "$manga_slug" >> "$tmp"
    mv "$tmp" "$MANGA_HISTORY_FILE"
    return 0
}

show_manga_history() {
    if [ ! -s "$MANGA_HISTORY_FILE" ]; then
        echo "📚 Lịch sử đọc truyện trống."
        sleep 2
        return 1
    fi
    selected=$(tac "$MANGA_HISTORY_FILE" | fzf --prompt="📜 Lịch sử đọc > " --delimiter='|' --with-nth=1,2,3 \
        --header="╔══════════════════════════════════════════╗
║  📚 LỊCH SỬ ĐỌC TRUYỆN TRANH             ║
╚══════════════════════════════════════════╝")
    if [ -n "$selected" ]; then
        local manga_name=$(echo "$selected" | cut -d'|' -f2)
        local chapter_name=$(echo "$selected" | cut -d'|' -f3)
        local manga_slug=$(echo "$selected" | cut -d'|' -f4)
        echo "$manga_name|$manga_slug|$chapter_name"
        return 0
    fi
    return 1
}

# --- MANGA FAVORITES ---
add_to_manga_favorites() {
    local name="$1"
    local slug="$2"
    if grep -q "|$slug$" "$MANGA_FAVORITES_FILE"; then
        echo "💫 '$name' đã có trong danh sách yêu thích."
    else
        echo "$name|$slug" >> "$MANGA_FAVORITES_FILE"
        echo "⭐ Đã thêm '$name' vào danh sách yêu thích!"
    fi
    sleep 1
}

show_manga_favorites() {
    if [ ! -s "$MANGA_FAVORITES_FILE" ]; then
        echo "⭐ Danh sách yêu thích trống."
        sleep 2
        return 1
    fi
    selected=$(fzf --prompt="⭐ Truyện yêu thích > " --delimiter='|' --with-nth=1 \
        --header="╔══════════════════════════════════════════╗
║  ⭐ TRUYỆN TRANH YÊU THÍCH               ║
╚══════════════════════════════════════════╝" < "$MANGA_FAVORITES_FILE")
    if [ -n "$selected" ]; then
        echo "$selected"
        return 0
    fi
    return 1
}


# ═══ PARSE HTML của TruyenVN ════════════════════════════════════════════════
# Mọi link truyện có dạng /truyen-tranh/<slug> (link chương là /truyen-tranh/<slug>/<chap>
# nên bị loại đúng). Tên lấy theo độ tin cậy: title="" > text trong thẻ > alt="".
# Parser danh sách truyện: chọn theo nguồn đang dùng
manga_parse_items() {
    if manga_is_nettruyen; then nt_parse_items; else manga_parse_items_pp; fi
}

# TruyenVN (Madara): /truyen-tranh/<slug>
manga_parse_items_pp() {
    MANGA_BASE_URL="${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}" perl -CS -Mutf8 -0777 -ne '
        my %ENA = (acute => 0x301, grave => 0x300, tilde => 0x303, circ => 0x302,
                   uml => 0x308, ring => 0x30A, cedil => 0x327, dot => 0x307,
                   macr => 0x304, breve => 0x306, caron => 0x30C, ogon => 0x328);
        my %ENC = (amp => "&", lt => "<", gt => ">", quot => chr(34), apos => chr(39),
                   nbsp => " ", middot => chr(0xB7), ndash => chr(0x2013), mdash => chr(0x2014),
                   hellip => chr(0x2026), laquo => chr(0xAB), raquo => chr(0xBB), copy => chr(0xA9));
        eval { require Unicode::Normalize; Unicode::Normalize->import(qw(NFC)); 1 } or do { *NFC = sub { $_[0] } };
        sub ent {
            my $k = shift;
            return chr($1) if $k =~ /^#([0-9]+)$/;
            return chr(hex($1)) if $k =~ /^#[xX]([0-9a-fA-F]+)$/;
            return $ENC{$k} if exists $ENC{$k};
            my $n = lc $k;
            if ($n =~ /^([a-z])(acute|grave|tilde|circ|uml|ring|cedil|dot|macr|breve|caron|ogon)$/) {
                my $b = $1;
                $b = uc $b if substr($k, 0, 1) =~ /[A-Z]/;
                return NFC($b . chr($ENA{$2}));
            }
            return "";
        }
        sub clean {
            my $t = shift;
            $t = "" unless defined $t;
            $t =~ s/<[^>]*>/ /g;
            $t =~ s/&(#?[0-9a-zA-Z]+);/ent($1)/ge;   # giải HTML entity (dạng số và dạng tên)
            $t =~ s/\|/-/g;                          # không để tên chứa "|" làm hỏng định dạng "tên|url"
            $t =~ s/\s+/ /g;
            $t =~ s/^ |$//g;
            $t =~ s/\s*(thumb|thumbnail|cover|poster|b[ìi]a)\s*$//i;
            return $t;
        }
        sub prettify {
            my $s = shift;
            $s =~ s/^-+|-+$//g;
            $s =~ s/[-_]+/ /g;
            $s =~ s/\b(\w)/\u$1/g;
            return $s;
        }
        my $base = $ENV{MANGA_BASE_URL} // "";
        $base =~ s{/$}{};
        my (%score, %name, %cover, @order);
        while ($_ =~ /<a\b([^>]*)>(.*?)<\/a>/gs) {
            my ($attrs, $inner) = ($1, $2);
            my ($href) = $attrs =~ /href\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27|([^\s">]+))/;
            $href = defined $href ? $href : "";
            $href =~ s/&amp;/&/g;
            next unless $href =~ m{(?:^|/)truyen-tranh/([A-Za-z0-9_.\-]+)/?$};
            my $slug = $1;
            next unless length $slug;
            my ($nm, $sc) = ("", 0);
            if ($attrs =~ /title\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27)/) {
                $nm = clean(defined $1 ? $1 : $2); $sc = 4;
            }
            if ($sc < 4) {
                my $txt = clean($inner);
                if (length($txt) >= 2 && $txt !~ /^(xem|doc|đọc|đọc từ đầu|chapter|chap)\b/i) {
                    $nm = $txt; $sc = 3;
                }
            }
            if ($sc < 3) {
                my ($alt) = $inner =~ /alt\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27)/;
                $alt = clean($alt);
                if (length($alt) >= 2) { $nm = $alt; $sc = 2; }
            }
            if (!length $nm) { $nm = prettify($slug); $sc = 1; }
            # ảnh bìa: <img> nằm ngay trong thẻ <a> (class của web hay đổi nên đọc
            # mọi thuộc tính ảnh: data-src/data-original > src)
            my $cv = "";
            if ($inner =~ /<img\b([^>]*)>/i) {
                my $ia = $1;
                if ($ia =~ /data-(?:lazy-)?(?:src|original|echo)\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27)/i) {
                    $cv = defined $1 ? $1 : $2;
                } elsif ($ia =~ /\ssrc\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27)/i) {
                    $cv = defined $1 ? $1 : $2;
                }
                $cv = "" unless defined $cv;
                $cv =~ s/&amp;/&/g;
                $cv =~ s/^\s+|\s+$//g;
                $cv = "" if $cv =~ m{^data:}i;
                $cv = "https:$cv" if $cv =~ m{^//};
                $cv = "$base$cv" if $cv =~ m{^/};
            }
            if (!exists $name{$slug}) { push @order, $slug; $name{$slug} = $nm; $score{$slug} = $sc; }
            elsif ($score{$slug} < $sc) { $name{$slug} = $nm; $score{$slug} = $sc; }
            $cover{$slug} = $cv if length $cv && !length($cover{$slug} // "");
        }
        for my $slug (@order) {
            my $u = "$base/truyen-tranh/$slug";
            my $cv = $cover{$slug} // "";
            print "$name{$slug}|$u|$slug|$cv\n";
        }
    '
}

# Tải 1 danh sách của TruyenVN -> "Tên|URL|slug"
# $1 = path (bắt đầu bằng /) hoặc URL tuyệt đối, $2.. = key=value
manga_list_items() {
    local path="$1"
    shift
    local html=""
    if ! html=$(manga_http_fetch "$path" "$@"); then
        echo "⚠️ Không tải được $path (HTTP ${MANGA_HTTP_STATUS:-000}) - kiểm tra mạng hoặc MANGA_BASE_URL" >&2
        return 1
    fi
    local items
    items=$(printf '%s' "$html" | manga_parse_items)
    [ -z "$items" ] && return 0
    # nhớ ảnh bìa để bước chọn chapter preview được (chạy trong subshell -> chỉ ghi file)
    printf '%s\n' "$items" | while IFS='|' read -r _n _u _s _c; do
        [ -n "${_c:-}" ] && [ -n "${_s:-}" ] && manga_cover_cache_put "$_s" "$_c"
    done
    printf '%s\n' "$items"
}

# Tìm truyện: thử /tim-kiem?q= trước, nếu web không lọc server-side thì lọc trong
# các danh sách (MANGA_SEARCH_FEEDS x MANGA_SEARCH_PAGES).
manga_search_items() {
    local kw="${1:-}"
    kw="${kw#"${kw%%[![:space:]]*}"}"
    kw="${kw%"${kw##*[![:space:]]}"}"
    if [ "${#kw}" -lt 2 ]; then
        echo "💡 Gõ tối thiểu 2 ký tự để tìm truyện ($(manga_source_label))..." >&2
        return 1
    fi
    if manga_is_nettruyen; then
        nt_search_items "$kw"
        return $?
    fi
    local pages="${MANGA_SEARCH_PAGES:-$DEFAULT_MANGA_SEARCH_PAGES}"
    [[ "$pages" =~ ^[0-9]+$ ]] || pages="$DEFAULT_MANGA_SEARCH_PAGES"
    [ "$pages" -lt 1 ] && pages=1
    [ "$pages" -gt 5 ] && pages=5
    local feeds="${MANGA_SEARCH_FEEDS:-$DEFAULT_MANGA_SEARCH_FEEDS}"
    local html="" found="" p feed
    local tries=0 ok=0

    for p in $(seq 1 "$pages"); do
        tries=$((tries + 1))
        if html=$(manga_http_fetch "/tim-kiem" "search=$kw" "page=$p"); then
            ok=$((ok + 1))
            found=$(printf '%s' "$html" | manga_parse_items | manga_match_items "$kw")
            if [ -n "$found" ]; then
                printf '%s\n' "$found"
                return 0
            fi
        fi
    done

    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/anisub-mangasrc.XXXXXX" 2>/dev/null) || tmp="${TMPDIR:-/tmp}/anisub-mangasrc.$$.tmp"
    local IFS=","
    for feed in $feeds; do
        IFS=","
        feed="${feed//[^A-Za-z0-9._-]/}"
        [ -z "$feed" ] && continue
        for p in $(seq 1 "$pages"); do
            tries=$((tries + 1))
            if html=$(manga_http_fetch "/tim-kiem" "m_orderby=$feed" "page=$p"); then
                ok=$((ok + 1))
                printf '%s\n' "$html" | manga_parse_items >> "$tmp"
            fi
        done
    done
    unset IFS
    found=""
    if [ -s "$tmp" ]; then
        found=$(awk -F'|' '!seen[$3]++' "$tmp" | manga_match_items "$kw")
    fi
    rm -f "$tmp"

    if [ -n "$found" ]; then
        printf '%s\n' "$found"
        return 0
    fi
    if [ "$ok" -eq 0 ]; then
        echo "⚠️ Không kết nối được TruyenVN (HTTP $(anisub_last_http)) - thử lại, hoặc sửa MANGA_BASE_URL trong Cài đặt" >&2
        return 1
    fi
    echo "😶 Không tìm thấy truyện khớp với \"$kw\" trong $tries trang vừa tải" >&2
    echo "💡 Thử: ít từ hơn / không dấu, hoặc dùng 🗂 Theo thể loại, 🔗 Dán link truyện" >&2
    return 1
}


# --- FETCH CHAPTER LIST ---
fetch_chapter_list() {
    local target="$1"
    if manga_is_nettruyen; then
        nt_fetch_chapter_list "$target"
        return $?
    fi
    local page_url
    page_url=$(manga_manga_url "$target")
    if [ -z "$page_url" ]; then
        echo "⚠️ Slug truyện rỗng - không tải được danh sách chapter." >&2
        return 1
    fi
    local slug="${page_url##*/}"
    local html=""
    # Trang truyện chỉ có 2 link chapter -> phải lấy danh sách thật qua API web
    # (/webapi/stories/list-chapter); API lỗi thì vẫn dùng trang truyện làm fallback.
    if ! html=$(manga_chapter_list_html "$page_url"); then
        echo "⚠️ Không tải được trang truyện ($slug) - HTTP $(anisub_last_http)" >&2
        return 1
    fi
    local tmp n=0
    tmp=$(mktemp "${TMPDIR:-/tmp}/anisub-chaps.XXXXXX" 2>/dev/null) || tmp="${TMPDIR:-/tmp}/anisub-chaps.$$.tmp"
    printf '%s' "$html" | manga_parse_chapters "$slug" > "$tmp"
    # Slug trên URL có thể khác slug trong link chapter (web đổi tên truyện / mirror) ->
    # thử lại không lọc theo slug trước khi bỏ cuộc.
    if [ ! -s "$tmp" ]; then
        printf '%s' "$html" | manga_parse_chapters "" > "$tmp"
    fi
    if [ -s "$tmp" ]; then
        cat "$tmp"
        n=$(grep -c '.' "$tmp")
    fi
    rm -f "$tmp"
    [ "$n" -gt 0 ]
}

# HTML (stdin) -> "Tên|URL|slug-chap", sắp xếp theo số chương (9 < 9.5 < 10).
# $1 = slug truyện; rỗng nghĩa là chấp nhận link chapter của mọi truyện.
manga_parse_chapters() {
    local slug="${1:-}"
MANGA_SLUG="$slug" MANGA_BASE_URL="${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}" perl -CS -Mutf8 -0777 -ne '
            my $base = $ENV{MANGA_BASE_URL} // ""; $base =~ s{/$}{};
            my $slug = $ENV{MANGA_SLUG} // "";
            my $q = length $slug ? quotemeta($slug) : "";
            my $link_re;
            if (length $q) {
                $link_re = qr{truyen-tranh/$q/([A-Za-z0-9_.\-]+(?:/[A-Za-z0-9_.\-]+)*)/?$};
            } else {
                # Không biết slug: lấy slug xuất hiện nhiều nhất trong HTML (bỏ link
                # "truyện khác" lẫn vào) rồi lọc theo slug đó.
                my %sc; $sc{$1}++ while ($_ =~ m{truyen-tranh/([A-Za-z0-9_.\-]+)/[A-Za-z0-9_.\-]+}g);
                my ($best) = sort { $sc{$b} <=> $sc{$a} } keys %sc;
                $best = "" unless defined $best;
                $link_re = length $best
                    ? qr{truyen-tranh/\Q$best\E/([A-Za-z0-9_.\-]+(?:/[A-Za-z0-9_.\-]+)*)/?$}
                    : qr{truyen-tranh/[A-Za-z0-9_.\-]+/([A-Za-z0-9_.\-]+(?:/[A-Za-z0-9_.\-]+)*)/?$};
            }
            my (%seen, @out);
            while ($_ =~ /<a\b([^>]*)>(.*?)<\/a>/gs) {
                my ($attrs, $inner) = ($1, $2);
                my ($href) = $attrs =~ /href\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27|([^\s">]+))/;
                $href = defined $href ? $href : "";
                $href =~ s/&amp;/&/g;
                next unless $href =~ $link_re;
                my $cslug = $1;
                $cslug =~ s{/}{-}g;
                next if $cslug =~ /^(danh-sach|tap-chi|-)$/;
                my $url;
                if ($href =~ m{^https?://}i) { $url = $href }
                elsif ($href =~ m{^//})       { $url = "https:$href" }
                elsif ($href =~ m{^/})        { my ($h) = $base =~ m{^(https?://[^/]+)}; $url = ($h // $base) . $href }
                else                          { $url = "$base/$href" }
                $url =~ s{/$}{};
                next if $seen{$url}++;
                my $txt = $inner;
                $txt =~ s/<[^>]*>/ /g;
                $txt =~ s/&nbsp;/ /g; $txt =~ s/&amp;/&/g;
                $txt =~ s/\s+/ /g; $txt =~ s/^ |$//g;
                # ưu tiên nhãn chương ở đầu ("Chapter 242", "Chap 90", "Vol. 1 Ch. 2"),
                # phần còn lại (giờ cập nhật, ngày đăng) chỉ là trang trí của web
                if ($txt =~ /^((?:vol\.?\s*[0-9]+\s*)?(?:chapter|chap|ch\.|ch|episode|ep|tap)\s*[-_.:]?\s*[0-9]+(?:[.,][0-9]+)?)/i) {
                    $txt = $1;
                } else {
                    $txt =~ s/\s*[-–|:]?\s*\d{4}-\d\d-\d\d.*$//;      # " - 2026-11-08 05:01:00"
                    $txt =~ s/\s*[-–|:]?\s*[0-9]+\s+\S+\s+tr\S*\s*$//i; # " 8 giờ trước"
                }
                $txt =~ s/\s+$//;
                # tên chương phải chứa số, nếu không thì suy ra từ URL (vd "Đọc từ đầu")
                if ($txt !~ /[0-9]/) {
                    my $nice = $cslug;
                    $nice =~ s/^chapter[-_]?/Chapter /i;
                    $nice =~ s/^tap[-_]?/Tập /i;
                    $nice =~ s/[-_]/ /g;
                    $txt = $nice;
                }
                my ($num) = $cslug =~ /([0-9]+(?:[.,][0-9]+)?)/;
                if (!$num) { ($num) = $txt =~ /([0-9]+(?:[.,][0-9]+)?)/ }
                $num =~ s/,/./;
                $cslug =~ s/\|/-/g;
                printf "%.6f|%s|%s|%s\n", (defined $num && $num ne "" ? $num : -1), $txt, $url, $cslug;
            }
    ' \
        | sort -s -t'|' -k1,1g \
        | awk -F'|' '{ sub(/^[^|]*\|/, "", $0); print }'
}

# --- FETCH CHAPTER IMAGES ---
# Lấy URL ảnh của 1 chapter. Không phụ thuộc tên class: tìm mọi URL ảnh trong
# trang (thuộc tính src/data-src của <img>, hoặc mảng JSON dạng chapterImages),
# loại ảnh phụ (logo/avatar/cover/thumb), rồi ưu tiên ảnh có chứa slug truyện.
fetch_chapter_images() {
    local chapter_url="$1"
    local prefer_slug="${2:-}"
    [ -z "$chapter_url" ] && return 1
    if [ -n "$(nt_chapter_parts "$chapter_url")" ]; then
        nt_fetch_chapter_images "$chapter_url"
        return $?
    fi
    rm -f "$ANISUB_MANGA_NAV_FILE" 2>/dev/null   # không dùng link chuyển chap của chapter cũ
    local variant html="" last_html="" found="" used_variant=""
    for variant in normal minimal bot proxy; do
        if [ "$variant" = "proxy" ]; then
            html=$(manga_proxy_fetch "$chapter_url" 2>/dev/null) || html=""
        else
            html=$(MANGA_FETCH_VARIANT="$variant" manga_http_fetch "$chapter_url" 2>/dev/null) || html=""
        fi
        [ -z "$html" ] && continue
        last_html="$html"
        found=$(printf '%s' "$html" | MANGA_PREFER="$prefer_slug" \
            MANGA_BASE_URL="${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}" perl -CS -Mutf8 -0777 -ne '
        my $doc = $_;
        $doc =~ s{\\+/}{/}g;                       # bỏ escape trong JSON: \/ (hoặc \\/) -> /
        my @cand;
        # 1) mọi thẻ <img>/<source>: data-src, data-lazy-src, data-original, src, srcset...
        my @attrs = qw(data-src data-lazy-src data-original data-echo data-file data-url
                       data-img data-image data-thumb src);
        while ($doc =~ /<(?:img|source)\b([^>]*)>/gsi) {
            my $a = $1;
            for my $at (@attrs) {
                next unless $a =~ /\b\Q$at\E\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27)/i;
                my $u = defined $1 ? $1 : $2;
                push @cand, $u if defined $u && length $u;
            }
            while ($a =~ /\bsrcset\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27)/gi) {
                my $set = defined $1 ? $1 : $2;
                for my $part (split /,/, $set) {
                    $part =~ s/^\s+|\s+$//g;
                    $part =~ s/\s+\S+$//;           # bỏ "800w"/"2x"
                    push @cand, $part if length $part;
                }
            }
        }
        # 2) mọi URL ảnh trong trang (kể cả trong JSON/JS): tuyệt đối, //host, hoặc /duong-dan
        while ($doc =~ m{(["\x27(=])((?:(?:https?:)?//|/)[^"\x27\s<>()]+?\.(?:jpe?g|png|webp|gif|avif)(?:\?[^"\x27\s<>]*)?)}gi) {
            push @cand, $2;
        }
        my $base = $ENV{MANGA_BASE_URL} // ""; $base =~ s{/$}{};
        my $prefer = $ENV{MANGA_PREFER} // "";
        my (@keep, %seen);
        for my $u (@cand) {
            next unless defined $u && length $u;
            $u =~ s/&amp;/&/g;
            $u =~ s/^\s+|\s+$//g;
            next if $u =~ m{^data:}i;                 # ảnh placeholder base64
            $u =~ s{^//}{https://};
            $u = "$base$u" if $u =~ m{^/};            # đường dẫn tương đối -> tuyệt đối
            next unless $u =~ m{^https?://}i;
            next if $u =~ /\.(svg|ico)(\?|$)/i;
            next if $u =~ /(logo|icon|avatar|thumb|thumbnail|cover|poster|banner|ads?|emoji|flag|loading|placeholder|sprite|facebook|twitter|zalo|recaptcha)/i;
            next if $seen{$u}++;
            push @keep, $u;
        }
        if (length $prefer) {
            my @better = grep { index($_, "/$prefer/") >= 0 } @keep;
            @keep = @better if @better >= 2;
        }
        print "$_\n" for @keep;
    ')
        if [ -n "$found" ]; then
            used_variant="$variant"
            break
        fi
    done
    if [ "$used_variant" = "proxy" ]; then
        echo "ℹ️ Trang chapter bị chặn với máy này — đã lấy danh sách ảnh qua ${MANGA_READER_PROXY:-reader-proxy}." >&2
        echo "   (tắt bằng MANGA_READER_PROXY=\"\" trong ⚙️ Cài đặt)" >&2
    fi
    if [ -z "$last_html" ]; then
        echo "⚠️ Không tải được chapter (HTTP $(anisub_last_http))" >&2
        return 1
    fi
    html="$last_html"
    # Nhớ "Chap trước/Chap sau" để reader chuyển chap được kể cả khi thiếu danh sách
    local nav nav_prev nav_next
    nav=$(printf '%s' "$html" | manga_parse_nav)
    if [ -n "$nav" ]; then
        nav_prev="${nav%%|*}"
        nav_next="${nav##*|}"
        [ -n "$nav_prev" ] && nav_prev=$(manga_abs_url "$nav_prev")
        [ -n "$nav_next" ] && nav_next=$(manga_abs_url "$nav_next")
        printf '%s|%s\n' "$nav_prev" "$nav_next" > "$ANISUB_MANGA_NAV_FILE" 2>/dev/null
    fi
    if [ -z "$found" ]; then
        manga_debug_dump "$chapter_url" "$html"
        echo "⚠️ Đã thử 4 kiểu request (normal/minimal/bot/proxy) mà không thấy ảnh nào." >&2
    fi
    printf '%s\n' "$found"
}

# Tải trang qua dịch vụ đọc hộ (mặc định https://r.jina.ai/<url>): dùng khi máy mình
# bị chặn/bị trả bản rút gọn. Trả về markdown, ảnh vẫn ở dạng ![](https://...jpg).
manga_proxy_fetch() {
    local target="${1:-}"
    [ -z "$target" ] && return 1
    local proxy="${MANGA_READER_PROXY:-}"
    case "$proxy" in ""|off|OFF|0|none|null) return 1 ;; esac
    target=$(manga_abs_url "$target")
    local tmp status
    tmp=$(mktemp "${TMPDIR:-/tmp}/anisub-proxy.XXXXXX" 2>/dev/null) || tmp="${TMPDIR:-/tmp}/anisub-proxy.$$.tmp"
    status=$(curl -sS -L --compressed --max-time 45 --retry 1 \
        -A "$MANGA_USER_AGENT" \
        -H "accept: text/plain,text/markdown,*/*" \
        -o "$tmp" -w '%{http_code}' \
        "${proxy%/}/$target" 2>/dev/null)
    MANGA_PROXY_STATUS="${status:-000}"
    case "$MANGA_PROXY_STATUS" in
        2??)
            if [ -s "$tmp" ]; then
                cat "$tmp"; rm -f "$tmp"
                return 0
            fi
            ;;
    esac
    rm -f "$tmp"
    return 1
}

# HTML trang chapter có phải trang "kiểm tra trình duyệt" (Cloudflare) không
manga_looks_challenged() {
    printf '%s' "$1" | grep -qiE '_cf_chl_opt|cf-browser-verification|cf_chl_|just a moment|checking your browser|enable javascript and cookies'
}

# Khi không tìm được ảnh: ghi báo cáo ngắn để người dùng gửi kèm khi báo lỗi
manga_debug_dump() {
    local url="$1" html="$2"
    local dir="${CACHE_DIR:-${TMPDIR:-/tmp}}"
    local f="$dir/manga-debug.txt"
    mkdir -p "$dir" 2>/dev/null
    {
        echo "url      : $url"
        echo "http     : $(anisub_last_http)"
        echo "base     : ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
        echo "bytes    : $(printf '%s' "$html" | wc -c | tr -d ' ')"
        echo "img tags : $(printf '%s' "$html" | grep -oi '<img' | wc -l | tr -d ' ')"
        echo "jpg/png  : $(printf '%s' "$html" | grep -oiE '\.(jpe?g|png|webp)' | wc -l | tr -d ' ')"
        echo "imggo    : $(printf '%s' "$html" | grep -oi 'imggo' | wc -l | tr -d ' ')"
        if manga_looks_challenged "$html"; then echo "challenge: YES (Cloudflare)"; else echo "challenge: no"; fi
        echo "title    : $(printf '%s' "$html" | perl -0777 -ne 'print $1 if /<title[^>]*>(.*?)<\/title>/si' 2>/dev/null | head -c 120)"
        echo "--- 300 ký tự quanh .reading-content ---"
        printf '%s' "$html" | perl -0777 -ne 'if (/reading-content/i) { s/.*?(reading-content)/$1/s; print substr($_,0,300) }' 2>/dev/null
        echo ""
    } > "$f" 2>/dev/null
    [ -f "$f" ] && echo "🔎 Đã ghi chẩn đoán: $f" >&2
    return 0
}

# --- PREFETCH IMAGES ---
# Tải song song các trang của chapter vào cache. KHÔNG gửi Referer: CDN ảnh của
# TruyenVN (imggo.net) trả 403 với mọi request có Referer -> đây chính là lý do
# trước đây mở chapter mà không thấy ảnh nào.
prefetch_chapter_images() {
    local cache_dir="$1"
    shift
    local -a images=("$@")
    local total=${#images[@]}
    [ "$total" -eq 0 ] && return 0
    mkdir -p "$cache_dir"

    local max_jobs=5 job_count=0 idx filepath
    for ((idx = 0; idx < total; idx++)); do
        filepath=$(printf '%s/%03d.img' "$cache_dir" $((idx + 1)))
        [ -s "$filepath" ] && continue
        ( manga_download_image "${images[$idx]}" "$filepath" ) &
        job_count=$((job_count + 1))
        if [ "$job_count" -ge "$max_jobs" ]; then
            wait -n 2>/dev/null || wait
            job_count=$((job_count - 1))
        fi
    done
    wait 2>/dev/null
    return 0
}

# --- DISPLAY FULL CHAPTER (fzf + preview ảnh) --------------------------------
# Giao thức vẽ ảnh do manga_image_protocol quyết định (kitty/sixel/iterm/symbols)
# nên ảnh luôn hiện, không còn cảnh "ép sixels" rồi terminal không vẽ được gì.
display_full_chapter() {
    local manga_name="$1"
    local chapter_name="$2"
    shift 2
    local -a images=("$@")
    local total_pages=${#images[@]}
    [ "$total_pages" -eq 0 ] && return 1

    local cache_dir
    cache_dir=$(mktemp -d "${TMPDIR:-/tmp}/anisub_manga_ch.XXXXXX" 2>/dev/null) \
        || cache_dir="${TMPDIR:-/tmp}/anisub_manga_ch.$$"
    mkdir -p "$cache_dir" 2>/dev/null

    # Danh sách URL (1 dòng / trang) để script preview tự tải khi cần
    local url_file="$cache_dir/urls.txt"
    printf '%s\n' "${images[@]}" > "$url_file"

    local chafa_args scale="$MANGA_IMAGE_SCALE"
    chafa_args=$(manga_chafa_args)
    [[ "$scale" =~ ^[0-9]+$ ]] || scale="$DEFAULT_MANGA_IMAGE_SCALE"

    # 1. Script mở ảnh bằng ứng dụng ngoài (Enter)
    cat <<EOF > "$cache_dir/open.sh"
#!/bin/bash
# (anisub tự sinh) tải 1 trang rồi mở bằng ứng dụng xem ảnh của hệ thống
line="\$1"
page_num=\$(printf '%s' "\$line" | awk '{print \$2}' | cut -d'/' -f1)
[ -z "\$page_num" ] && exit 0
target_file="$cache_dir/\${page_num}.img"
url_file="$url_file"
if [ ! -s "\$target_file" ]; then
    idx=\$(printf '%s' "\$page_num" | sed 's/^0*//'); [ -z "\$idx" ] && idx=1
    url=\$(sed -n "\${idx}p" "\$url_file")
    if [ -n "\$url" ]; then
        curl -fsSL --compressed --max-time 30 -A "$MANGA_USER_AGENT" -o "\$target_file.part" "\$url" >/dev/null 2>&1 &&
            mv "\$target_file.part" "\$target_file" 2>/dev/null
        rm -f "\$target_file.part" 2>/dev/null
    fi
fi
if [ ! -s "\$target_file" ]; then
    echo "❌ Không tải được trang \${page_num} (mạng/CDN chặn)"
    sleep 1.5
    exit 0
fi
if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "\$target_file" >/dev/null 2>&1 &
elif command -v open >/dev/null 2>&1; then
    open "\$target_file" >/dev/null 2>&1 &
else
    echo "📁 Ảnh đã lưu: \$target_file"
    sleep 2
fi
EOF
    chmod +x "$cache_dir/open.sh" 2>/dev/null

    # 2. Script preview trong fzf
    cat <<EOF > "$cache_dir/preview.sh"
#!/bin/bash
# (anisub tự sinh) xem trước 1 trang truyện trong fzf
line="\$1"
page_num=\$(printf '%s' "\$line" | awk '{print \$2}' | cut -d'/' -f1)
[ -z "\$page_num" ] && exit 0
target_file="$cache_dir/\${page_num}.img"
url_file="$url_file"

sleep 0.08

# Lấy từ cache, thiếu thì tải ngay (KHÔNG gửi Referer - CDN trả 403 nếu có)
if [ ! -s "\$target_file" ]; then
    idx=\$(printf '%s' "\$page_num" | sed 's/^0*//'); [ -z "\$idx" ] && idx=1
    url=\$(sed -n "\${idx}p" "\$url_file")
    if [ -n "\$url" ]; then
        curl -fsSL --compressed --max-time 30 -A "$MANGA_USER_AGENT" -o "\$target_file.part" "\$url" >/dev/null 2>&1
        if [ -s "\$target_file.part" ]; then mv "\$target_file.part" "\$target_file"; else rm -f "\$target_file.part"; fi
    fi
fi

if [ ! -s "\$target_file" ]; then
    echo "❌ Không tải được trang \${page_num}"
    echo "   (kiểm tra mạng, hoặc ảnh đã bị xoá khỏi CDN)"
    exit 0
fi

width=0; height=0
if command -v identify >/dev/null 2>&1; then
    dims=\$(identify -format "%w %h" "\$target_file" 2>/dev/null)
    width=\$(printf '%s' "\$dims" | awk '{print \$1}')
    height=\$(printf '%s' "\$dims" | awk '{print \$2}')
elif command -v file >/dev/null 2>&1; then
    res=\$(file -b "\$target_file" 2>/dev/null)
    dims=\$(printf '%s' "\$res" | sed -n 's/.* \([0-9][0-9]*\) *x *\([0-9][0-9]*\).*/\1 \2/p')
    width=\$(printf '%s' "\$dims" | awk '{print \$1}')
    height=\$(printf '%s' "\$dims" | awk '{print \$2}')
fi
[[ "\$width" =~ ^[0-9]+$ ]] || width=0
[[ "\$height" =~ ^[0-9]+$ ]] || height=0

cols=\$(( (FZF_PREVIEW_COLUMNS - 2) * $scale / 100 ))
lines=\$(( (FZF_PREVIEW_LINES - 3) * $scale / 100 ))
[ "\$cols" -lt 10 ] && cols=10
[ "\$lines" -lt 6 ] && lines=6
[ "\$cols" -gt \$((FZF_PREVIEW_COLUMNS - 1)) ] && cols=\$((FZF_PREVIEW_COLUMNS - 1))
[ "\$lines" -gt \$((FZF_PREVIEW_LINES - 1)) ] && lines=\$((FZF_PREVIEW_LINES - 1))

if command -v chafa >/dev/null 2>&1; then
    chafa $chafa_args --size="\${cols}x\${lines}" --animate=off "\$target_file" 2>/dev/null
else
    echo "⚠️ Chưa cài chafa nên không vẽ được ảnh."
    echo "   Cài: sudo apt install chafa   (hoặc dùng Enter để mở ảnh ngoài)"
fi
echo
echo "📄 Trang \${page_num} / $total_pages · \${width}x\${height}"
EOF
    chmod +x "$cache_dir/preview.sh" 2>/dev/null

    # 3. Tải trước vài trang đầu để preview hiện ngay
    prefetch_chapter_images "$cache_dir" "${images[@]}" >/dev/null 2>&1 &
    local prefetch_pid=$!
    trap "rm -rf '$cache_dir'; kill $prefetch_pid 2>/dev/null" EXIT

    # 4. Danh sách trang cho fzf
    local list_input="" i p_str
    for ((i = 1; i <= total_pages; i++)); do
        p_str=$(printf "%03d" "$i")
        list_input+="Trang ${p_str}/${total_pages}"$'\n'
    done

    printf '%s' "$list_input" | fzf \
        --layout=reverse \
        --ansi \
        --header="📖 $manga_name - $chapter_name · $total_pages trang" \
        --prompt="Xem ảnh · Enter: mở ngoài · Esc: quay lại > " \
        --preview "$cache_dir/preview.sh {}" \
        --preview-window="right:70%" \
        --bind "enter:execute-silent($cache_dir/open.sh {})" \
        --bind "ctrl-c:abort" \
        --bind "esc:abort"

    # 5. Dọn cache
    kill "$prefetch_pid" 2>/dev/null
    rm -rf "$cache_dir"
}

# --- READ MANGA CHAPTER (Continuous Scroll) ---
read_manga_chapter() {
    local manga_name="$1"
    local manga_slug="$2"
    local chapter_name="$3"
    local chapter_url="$4"
    local chapter_list_raw="$5"
    local nav_prev="" nav_next=""

    while true; do
        clear
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║  ⏳ ĐANG TẢI CHAPTER...                                                      ║"
        printf "║  📖 %-70s ║\n" "$manga_name"
        printf "║  📑 %-70s ║\n" "$chapter_name"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        
        # Lấy danh sách ảnh (ưu tiên ảnh có chứa slug truyện -> loại thumbnail/cover)
        mapfile -t images < <(fetch_chapter_images "$chapter_url" "$manga_slug")
        
        if [ ${#images[@]} -eq 0 ]; then
            echo ""
            echo "❌ Không tìm thấy hình ảnh trong chapter này!"
            echo "   HTTP $(anisub_last_http) · URL: $chapter_url"
            local dbg="${CACHE_DIR:-${TMPDIR:-/tmp}}/manga-debug.txt"
            if [ -f "$dbg" ]; then
                echo "   Chẩn đoán: $(grep -E '^(img tags|jpg/png|imggo|challenge|bytes)' "$dbg" 2>/dev/null | tr '\n' ' ')"
                echo "   File đầy đủ: $dbg"
            fi
            echo "   Nhấn [r] để thử lại, [c] để chọn chapter khác, [o] mở trang chapter bằng trình duyệt, [q] để thoát."
            read -rsn1 key
            case "$key" in
                'r') continue ;;
                'c') return 0 ;;
                'o') open_url "$chapter_url" ;;
                'q') return 1 ;;
            esac
            continue
        fi
        
        add_to_manga_history "$manga_name" "$chapter_name" "$manga_slug"
        
        # Clear và hiển thị toàn bộ chapter (continuous scroll)
        clear
        display_full_chapter "$manga_name" "$chapter_name" "${images[@]}"
        
        # Input Loop to prevent re-rendering on invalid key
        echo ""
        echo "⌨️  n: chap sau · p: chap trước · c: chọn chap khác · r: tải lại · f: ⭐ yêu thích · q: thoát"
        while true; do
            if ! read -rsn1 key < /dev/tty 2>/dev/null; then
                echo ""
                echo "⚠️ Không đọc được bàn phím (/dev/tty) - nhấn Enter để quay lại."
                read -r _ 2>/dev/null || true
                return 0
            fi
            case "$key" in
                'n')  # Next chapter
                    next_chap=$(manga_neighbor_chapter "$chapter_list_raw" "$chapter_name" next)
                    if [ -n "$next_chap" ]; then
                        chapter_name=$(printf '%s' "$next_chap" | cut -d'|' -f1)
                        chapter_url=$(printf '%s' "$next_chap" | cut -d'|' -f2)
                        break 2 # Break inner loop, continue outer (reload new chap)
                    fi
                    # Danh sách thiếu (API lỗi) -> dùng link "Chap sau" của chính trang
                    nav_next=$(manga_saved_nav | cut -d'|' -f2)
                    if [ -n "$nav_next" ]; then
                        chapter_url="$nav_next"
                        chapter_name=$(manga_chapter_name_from_url "$nav_next")
                        break 2
                    fi
                    echo ""
                    echo "📚 Đây là chapter mới nhất! (Phím bất kỳ để tiếp tục)"
                    ;;
                'p')  # Previous chapter
                    prev_chap=$(manga_neighbor_chapter "$chapter_list_raw" "$chapter_name" prev)
                    if [ -n "$prev_chap" ]; then
                        chapter_name=$(printf '%s' "$prev_chap" | cut -d'|' -f1)
                        chapter_url=$(printf '%s' "$prev_chap" | cut -d'|' -f2)
                        break 2 # Break inner loop, continue outer (reload new chap)
                    fi
                    nav_prev=$(manga_saved_nav | cut -d'|' -f1)
                    if [ -n "$nav_prev" ]; then
                        chapter_url="$nav_prev"
                        chapter_name=$(manga_chapter_name_from_url "$nav_prev")
                        break 2
                    fi
                    echo ""
                    echo "📚 Đây là chapter đầu tiên! (Phím bất kỳ để tiếp tục)"
                    ;;
                'c')  # Change chapter
                    return 0
                    ;;
                'f')  # Add to favorites
                    add_to_manga_favorites "$manga_name" "$manga_slug"
                    echo ""
                    echo "⭐ Đã thêm vào yêu thích!"
                    # Stay in inner loop
                    ;;
                'r')  # Reload current chapter
                    break # Break inner loop, outer loop repeats (reloads current)
                    ;;
                '+' | '=')  # Zoom in
                    MANGA_IMAGE_SCALE=$((MANGA_IMAGE_SCALE + 10))
                    if [ $MANGA_IMAGE_SCALE -gt 200 ]; then MANGA_IMAGE_SCALE=200; fi
                    save_config
                    echo "Img Scale: $MANGA_IMAGE_SCALE%"
                    # Stay in inner loop
                    ;;
                '-' | '_')  # Zoom out
                    MANGA_IMAGE_SCALE=$((MANGA_IMAGE_SCALE - 10))
                    if [ $MANGA_IMAGE_SCALE -lt 50 ]; then MANGA_IMAGE_SCALE=50; fi
                    save_config
                    echo "Img Scale: $MANGA_IMAGE_SCALE%"
                    # Stay in inner loop
                    ;;
                'q')  # Quit
                    return 1
                    ;;
                *) 
                    # Invalid key, do nothing (stay in inner loop)
                    ;;
            esac
        done
    done
}

# Chẩn đoán nhanh toàn bộ luồng đọc: anisub.sh --manga-selftest <slug|URL>
# In từng bước kèm HTTP để biết chính xác hỏng ở đâu (trang truyện / API danh sách
# chapter / trang chapter / tải ảnh / chafa).
manga_selftest() {
    local default_target="bocchi-the-rock"
    manga_is_nettruyen && default_target="one-piece-dao-hai-tac"
    local target="${1:-$default_target}"
    local base="${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
    echo "🧪 KIỂM TRA ĐỌC TRUYỆN"
    echo "   anisub: $ANISUB_VERSION · nguồn: ${MANGA_SOURCE:-$DEFAULT_MANGA_SOURCE} ($base) · ảnh: ${MANGA_IMAGE_PROTOCOL:-auto}"
    echo ""

    local page_url
    page_url=$(manga_manga_url "$target")
    local slug="${page_url##*/}"
    echo "1️⃣  Trang truyện: $page_url"
    local html http
    html=$(manga_http_fetch "$page_url")
    http=$(anisub_last_http)
    echo "    HTTP $http · $(printf '%s' "$html" | wc -c | tr -d ' ') byte"
    if [ -z "$html" ]; then
        echo "    ❌ Không tải được trang truyện."
        echo "       → Kiểm tra mạng, hoặc MANGA_BASE_URL đã đổi tên miền."
        return 1
    fi
    if ! manga_is_nettruyen; then
        local sid tok
        sid=$(printf '%s' "$html" | manga_story_id)
        tok=$(printf '%s' "$html" | manga_csrf_token)
        echo "    story_id: ${sid:-(không thấy)}"
        if [ -n "$tok" ]; then echo "    csrf-token: có"; else echo "    csrf-token: KHÔNG thấy"; fi
    fi
    echo ""

    echo "2️⃣  Danh sách chapter"
    local chapters count
    chapters=$(fetch_chapter_list "$target")
    count=$(printf '%s\n' "$chapters" | grep -c '.')
    echo "    HTTP $(anisub_last_http) · $count chapter"
    if [ "$count" -le 2 ]; then
        echo "    ⚠️  Ít chapter -> API có thể bị chặn. Không sao: vẫn đọc được,"
        echo "        chuyển chap bằng n/p (dựa vào link \"Chap trước/sau\" của trang) hoặc Ctrl-G."
    else
        echo "    mới nhất: $(printf '%s\n' "$chapters" | tail -1 | cut -d'|' -f1)"
        echo "    đầu tiên: $(printf '%s\n' "$chapters" | head -1 | cut -d'|' -f1)"
    fi
    echo ""

    local chap_url
    chap_url=$(printf '%s\n' "$chapters" | tail -1 | cut -d'|' -f2)
    [ -z "$chap_url" ] && chap_url=$(manga_chapter_url "$page_url" 1)
    echo "3️⃣  Trang chapter: $chap_url"
    local imgs nimg nav
    imgs=$(fetch_chapter_images "$chap_url" "$slug")
    nimg=$(printf '%s\n' "$imgs" | grep -c '.')
    nav=$(manga_saved_nav)
    # bỏ qua nav còn sót lại từ nguồn khác (đổi nguồn thì link kiểu cũ vô nghĩa)
    if manga_is_nettruyen; then
        case "$nav" in *chuong-*) : ;; *) nav="" ;; esac
    else
        case "$nav" in *"/chapter-"*) : ;; *) nav="" ;; esac
    fi
    if [ -z "$nav" ] || [ "$nav" = "|" ]; then   # chưa đọc lần nào -> đọc thẳng từ trang
        local chtml=""
        chtml=$(manga_http_fetch "$chap_url" 2>/dev/null) || chtml=""
        if [ -n "$chtml" ]; then
            nav=$(printf '%s' "$chtml" | manga_parse_nav)
        fi
        case "$nav" in ""|"|") nav="" ;; esac
    fi
    echo "    HTTP $(anisub_last_http) · $nimg ảnh"
    echo "    chap trước|sau: ${nav:-(không thấy link)}"
    if [ "$nimg" -eq 0 ]; then
        echo "    ❌ Không tìm thấy ảnh -> trang chapter đổi cấu trúc hoặc bị chặn."
        local dbg="${CACHE_DIR:-${TMPDIR:-/tmp}}/manga-debug.txt"
        if [ -f "$dbg" ]; then
            sed -n '1,9p' "$dbg" | sed 's/^/    /'
        fi
        echo "       Mở thử bằng trình duyệt: $chap_url"
        return 1
    fi
    echo ""

    echo "4️⃣  Tải thử 1 ảnh"
    local first tmpd dest size magic
    first=$(printf '%s\n' "$imgs" | head -1)
    tmpd=$(mktemp -d "${TMPDIR:-/tmp}/anisub-selftest.XXXXXX" 2>/dev/null) || tmpd="${TMPDIR:-/tmp}/anisub-selftest.$$"
    dest="$tmpd/001.img"
    if manga_download_image "$first" "$dest"; then
        size=$(wc -c < "$dest" | tr -d ' ')
        magic=$(od -An -tx1 -N4 "$dest" 2>/dev/null | tr -d ' \n')
        echo "    ✅ OK · $size byte · magic $magic"
        echo "    URL: $first"
    else
        echo "    ❌ Tải ảnh thất bại (đã thử cả có và không Referer)."
        echo "    URL: $first"
        rm -rf "$tmpd"
        return 1
    fi
    rm -rf "$tmpd"
    echo ""

    echo "5️⃣  Hiển thị ảnh trong terminal"
    if command -v chafa &>/dev/null; then
        echo "    ✅ chafa: $(command -v chafa)"
    else
        echo "    ❌ chưa cài chafa (apt install chafa / brew install chafa / pkg install chafa)"
    fi
    echo "    TERM=${TERM:-?} ${TERM_PROGRAM:-}"
    echo ""
    echo "✅ Luồng đọc hoạt động."
    echo "   Nếu giao diện vẫn lỗi: anisub.sh → 📚 Truyện tranh → 🩺 Kiểm tra nguồn truyện"
    return 0
}

# ═══ LUỒNG ĐỌC TRUYỆN ═══════════════════════════════════════════════════════
# Chọn chapter bằng fzf. In ra "tên|url", hoặc "__goto__|" khi bấm Ctrl-G
# (Ctrl-G = nhập số chapter bất kỳ, dùng khi danh sách chapter bị thiếu).
manga_pick_chapter_line() {
    local header="$1" prompt="$2" chapters="$3"
    shift 3
    local out key sel
    out=$(printf '%s\n' "$chapters" | fzf --expect=ctrl-g \
        --prompt="$prompt" \
        --header="$header · Ctrl-G: nhập số chapter" \
        --delimiter='|' --with-nth=1 --tac "$@")
    [ -z "$out" ] && return 1
    # fzf --expect in phím ở dòng đầu (Enter = dòng rỗng). Bản fzf cũ chỉ in phím khi
    # thật sự bấm phím đó -> nếu chỉ có 1 dòng thì đó chính là chapter được chọn.
    if [ "$(printf '%s\n' "$out" | wc -l)" -le 1 ]; then
        key=""
        sel="$out"
    else
        key=$(printf '%s\n' "$out" | head -1)
        sel=$(printf '%s\n' "$out" | tail -n +2 | head -1)
    fi
    if [ "$key" = "ctrl-g" ]; then
        printf '__goto__|\n'
        return 0
    fi
    [ -z "$sel" ] && return 1
    printf '%s\n' "$sel"
}

# Tên hiển thị suy từ URL chapter: .../chapter-9-5 -> "Chapter 9.5"
manga_chapter_name_from_url() {
    local url="${1:-}"
    local cslug="${url##*/}"
    cslug="${cslug%.html}"
    local name
    name=$(printf '%s' "$cslug" | sed 's/^chapter-//; s/^chuong-//; s/^chap-//; s/-/./g')
    if [ -z "$name" ] || [ "$name" = "$cslug" ]; then
        printf '%s' "$cslug"
    else
        case "$cslug" in
            chuong-*) printf 'Chapter %s' "$name" ;;
            chap-*)   printf 'Chap %s' "$name" ;;
            *)      printf 'Chapter %s' "$name" ;;
        esac
    fi
}

# Dòng chapter kế tiếp / trước đó trong danh sách: $1=list $2=tên hiện tại $3=next|prev
manga_neighbor_chapter() {
    local list="$1" cur="$2" dir="${3:-next}" line
    [ -z "$list" ] || [ -z "$cur" ] && return 1
    if [ "$dir" = "prev" ]; then
        line=$(printf '%s\n' "$list" | grep -B1 -F -- "${cur}|" | head -1)
    else
        line=$(printf '%s\n' "$list" | grep -A1 -F -- "${cur}|" | tail -1)
    fi
    [ -z "$line" ] && return 1
    [ "$(printf '%s' "$line" | cut -d'|' -f1)" = "$cur" ] && return 1
    printf '%s\n' "$line"
}
# Tìm 1 dòng chapter theo tên hoặc slug đã lưu trong lịch sử ("chapter-242",
# "Chapter 242", "242"...). In ra đúng dòng "Tên|URL|slug-chap" từ danh sách.
manga_find_chapter() {
    local list="$1" want="$2"
    [ -z "$want" ] && return 1
    local key hit
    key=$(printf '%s' "$want" | manga_norm)
    hit=$(printf '%s\n' "$list" | awk -F'|' -v key="$key" '
        function nm(x) { gsub(/[^a-z0-9.]/, "", x); return x }
        { if (key != "" && (nm($1) == nm(key) || nm($3) == nm(key))) { print; exit } }')
    if [ -z "$hit" ]; then
        local num
        num=$(printf '%s' "$want" | grep -oE '[0-9]+([.,][0-9]+)?' | tail -1)
        if [ -n "$num" ]; then
            hit=$(printf '%s\n' "$list" | awk -F'|' -v n="$num" '
                { if (match($3, /[0-9]+([.,][0-9]+)?$/)) {
                      v = substr($3, RSTART, RLENGTH) + 0
                      if (v == n + 0) { print; exit }
                  } }')
        fi
    fi
    [ -n "$hit" ] && { printf '%s\n' "$hit"; return 0; }
    return 1
}

# Đọc 1 mục "Tên|URL|slug" từ danh sách: tải chapter -> chọn -> vào vòng đọc
manga_open_item() {
    local line="$1"
    local name url slug
    name=$(printf '%s' "$line" | cut -d'|' -f1)
    url=$(printf '%s' "$line" | cut -d'|' -f2)
    slug=$(printf '%s' "$line" | cut -d'|' -f3)
    [ -z "$slug" ] && slug="${url##*/}"
    manga_read_manga "$name" "$slug"
}

# Mở truyện theo slug/URL: chọn chapter rồi đọc (dùng cho tìm kiếm, lịch sử, dán link)
manga_read_manga() {
    local name="$1" slug_or_url="$2" start_chap="${3:-}"
    local page_url
    page_url=$(manga_manga_url "$slug_or_url")
    local slug="${page_url##*/}"
    local target="$slug"
    # dán link đầy đủ (mirror khác) -> giữ nguyên URL đó khi tải trang truyện
    case "$slug_or_url" in http*) target="$page_url" ;; esac
    local chapters
    chapters=$(fetch_chapter_list "$target")
    if [ -z "$chapters" ]; then
        echo "❌ Không lấy được danh sách chapter cho \"$name\"."
        echo "   HTTP $(anisub_last_http) · MANGA_BASE_URL=${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
        echo "   Nếu truyện đã đổi tên miền, cập nhật MANGA_BASE_URL trong ⚙️ Cài đặt → 📚 Nguồn truyện."
        sleep 3
        return 1
    fi
    local count
    count=$(printf '%s\n' "$chapters" | grep -c '.')
    if [ "$count" -le 2 ]; then
        echo "⚠️ Chỉ lấy được $count chapter (API danh sách chapter có thể bị chặn)."
        echo "   Vẫn đọc được bình thường: chọn 1 chapter rồi dùng n/p, hoặc Ctrl-G để nhảy tới số chapter."
        sleep 2.5
    fi
    local sel=""
    if [ -n "$start_chap" ]; then
        if sel=$(manga_find_chapter "$chapters" "$start_chap"); then
            :
        else
            echo "⚠️ Không thấy chapter \"$start_chap\" trong $count chapter - chọn lại."
            sleep 1.5
        fi
    fi
    # Preview ảnh bìa + thông tin truyện khi chọn chapter (MANGA_STORY_COVER do
    # fetch_chapter_list lấy được từ og:image của trang truyện)
    local -a preview_opts=()
    if [ -n "$name" ]; then
        local info_file cover
        cover=$(manga_cover_cache_get "$slug")
        [ -z "$cover" ] && cover="${MANGA_STORY_COVER:-}"
        info_file=$(manga_preview_info_file "$name" "$cover")
        preview_opts=(--preview "'$(manga_cover_preview_script)' --info-file '$info_file' {}" --preview-window='right:40%')
    fi
    local first_prompt="📑 Chọn chapter > "
    local header="📖 $name · $count chapter · mới nhất ở đầu, Enter để đọc"
    [ "$count" -le 2 ] && header="📖 $name · $count chapter · Ctrl-G: nhập số chapter để nhảy tới"
    if [ -z "$sel" ]; then
        sel=$(manga_pick_chapter_line "$header" "$first_prompt" "$chapters" "${preview_opts[@]}")
    fi
    [ -z "$sel" ] && return 1
    local chap_name chap_url rc chap_no
    while [ -n "$sel" ]; do
        if [ "${sel%%|*}" = "__goto__" ]; then
            printf '\n📥 Nhập số chapter muốn đọc (vd 120 hoặc 9.5): '
            read -r chap_no || chap_no=""
            chap_no=$(printf '%s' "${chap_no:-}" | tr -cd '0-9.')
            if [ -z "$chap_no" ]; then
                sel=$(manga_pick_chapter_line "$header" "$first_prompt" "$chapters" "${preview_opts[@]}")
                continue
            fi
            chap_url=$(manga_chapter_url "$page_url" "$chap_no")
            if [ -z "$chap_url" ]; then
                sel=$(manga_pick_chapter_line "$header" "$first_prompt" "$chapters" "${preview_opts[@]}")
                continue
            fi
            chap_name=$(manga_chapter_name_from_url "$chap_url")
        else
            chap_name=$(printf '%s' "$sel" | cut -d'|' -f1)
            chap_url=$(printf '%s' "$sel" | cut -d'|' -f2)
        fi
        read_manga_chapter "$name" "$slug" "$chap_name" "$chap_url" "$chapters"
        rc=$?
        if [ "$rc" -eq 1 ]; then return 0; fi
        sel=$(manga_pick_chapter_line "📖 $name · $count chapter" "📑 Chọn chapter khác > " "$chapters" "${preview_opts[@]}")
    done
    return 0
}

# Duyệt 1 danh sách của TruyenVN theo trang ($1 = path, $2 = tiêu đề)
manga_browse_menu() {
    local path="$1" title="${2:-Danh sách truyện}" page=1
    shift 2 2>/dev/null || shift 1
    local -a extra=("$@")
    while true; do
        clear
        echo "⏳ Đang tải \"$path\" (trang $page) từ ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}..."
        local items
        items=$(manga_list_items "$path" "page=$page" "${extra[@]}")
        if [ -z "$items" ]; then
            echo "⚠️ Trang này không có truyện nào (HTTP $(anisub_last_http))."
            if [ "$page" -gt 1 ]; then
                echo "   Quay lại trang $((page - 1))? (Enter = quay lại, q = thoát)"
                read -r back
                [[ "$back" =~ ^[qQ]$ ]] && return 1
                page=$((page - 1))
                continue
            fi
            sleep 2
            return 1
        fi
        local n sel preview_script
        n=$(printf '%s\n' "$items" | grep -c '.')
        preview_script=$(manga_cover_preview_script)
        sel=$(printf '%s\n⏭  Trang sau (trang %s · %s truyện)|__next__|__next__|\n' \
            "$items" "$((page + 1))" "$n" | fzf --prompt="📖 $title · trang $page > " \
                --header="📚 ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL} · $n truyện · xem bìa bên phải (Esc để quay lại)" \
                --delimiter='|' --with-nth=1 \
                --preview "'$preview_script' {}" --preview-window='right:45%')
        case "$sel" in
            "")                       return 1 ;;
            *"__next__"*)  page=$((page + 1)); continue ;;
        esac
        manga_open_item "$sel"
        return 0
    done
}

# Danh sách mặc định (mới cập nhật / hot / đọc nhiều) theo nguồn
manga_browse_latest() {
    if manga_is_nettruyen; then
        manga_browse_menu "/" "Truyện mới cập nhật"
    else
        manga_browse_menu "/tim-kiem" "Truyện mới cập nhật" "m_orderby=latest"
    fi
}

manga_browse_hot() {
    if manga_is_nettruyen; then
        manga_browse_menu "/truyen-tranh-hot" "Truyện hot"
    else
        manga_browse_menu "/tim-kiem" "Truyện hot" "m_orderby=trending"
    fi
}

manga_browse_views() {
    if manga_is_nettruyen; then
        manga_browse_menu "/the-loai/hot" "Truyện đọc nhiều"
    else
        manga_browse_menu "/tim-kiem" "Truyện đọc nhiều" "m_orderby=views"
    fi
}

manga_genres() {
    if manga_is_nettruyen; then
        printf '%s\n' \
            "🀄 Manga / Nhật Bản|manga" \
            "🇰🇷 Manhwa / Hàn Quốc|manhwa" \
            "🇨🇳 Manhua / Trung Quốc|manhua" \
            "💥 Hành động (Action)|action" \
            "❤️ Lãng mạn (Romance)|romance" \
            "😂 Hài hước (Comedy)|comedy" \
            "🧚 Fantasy|fantasy" \
            "🎭 Chính kịch (Drama)|drama" \
            "👻 Kinh dị (Horror)|kinh-di" \
            "🏫 Học đường (School Life)|school-life" \
            "⚔️ Shounen|shounen" \
            "🌈 Webtoon|webtoon" \
            "🎨 Truyện màu|truyen-mau" \
            "🌸 Ngôn tình|ngon-tinh" \
            "🀄 Huyền huyễn|huyen-huyen" \
            "⏳ Xuyên không|xuyen-khong" \
            "🔁 Chuyển sinh|chuyen-sinh" \
            "🏯 Cổ đại|co-dai" \
            "🥋 Võ thuật (Martial Arts)|martial-arts" \
            "🍃 Đời thường (Slice of Life)|slice-of-life" \
            "🔍 Bí ẩn (Mystery)|mystery" \
            "👁 Siêu nhiên (Supernatural)|sieu-nang-luc" \
            "💔 Bi kịch (Tragedy)|tragedy" \
            "⚽ Thể thao (Sports)|sports" \
            "🕵️ Seinen|seinen" \
            "👧 Shoujo|shoujo" \
            "🔞 Mature|mature" \
            "💗 Đam mỹ|dam-my" \
            "🌺 Yuri|yuri" \
            "📖 One Shot|one-shot"
        return 0
    fi
    printf '%s\n' \
        "🀄 Manga / Nhật Bản|manga" \
        "🇨🇳 Manhwa / Hàn Quốc|manhwa" \
        "🐉 Manhua / Trung Quốc|manhua" \
        "💥 Hành động (Action)|action" \
        "😂 Hài hước (Comedy)|comedy" \
        "🎭 Chính kịch (Drama)|drama" \
        "🧚 Fantasy|fantasy" \
        "❤️ Lãng mạn (Romance)|romance" \
        "🍃 Đời thường (Slice of Life)|slice-of-life" \
        "🔍 Bí ẩn (Mystery)|mystery" \
        "🚀 Khoa học (Sci-Fi)|sci-fi" \
        "🌈 Boy Love (BL)|boylove"
}

manga_genre_menu() {
    local gline gslug gname
    gline=$(manga_genres | fzf --prompt="🗂 Chọn thể loại > " \
        --header="📚 Thể loại lấy từ ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}/the-loai/...")
    [ -z "$gline" ] && return 1
    gname=$(printf '%s' "$gline" | cut -d'|' -f1)
    gslug=$(printf '%s' "$gline" | cut -d'|' -f2)
    gslug="${gslug//[^A-Za-z0-9._-]/}"
    [ -z "$gslug" ] && return 1
    manga_browse_menu "/the-loai/${gslug}" "$gname"
}

# Kiểm tra nhanh nguồn truyện: kết nối + parse được bao nhiêu mục
manga_diagnose() {
    echo "💡 Chẩn đoán nhanh từ dòng lệnh: ./anisub.sh --manga-selftest <slug|URL> (anisub $ANISUB_VERSION)"
    echo ""
    local base="${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
    echo "🩺 Chẩn đoán nguồn truyện tranh ($(manga_source_label))"
    echo "──────────────────────────────────────────────────────────"
    printf '  %s %-7s %s\n' "$(command -v curl > /dev/null 2>&1 && echo ✅ || echo ❌)" "curl" "$(command -v curl > /dev/null 2>&1 && curl --version 2>&1 | head -1 || echo 'không tìm thấy lệnh')"
    printf '  %s %-7s %s\n' "$(command -v perl > /dev/null 2>&1 && echo ✅ || echo ❌)" "perl" "$(command -v perl > /dev/null 2>&1 && perl -v 2>&1 | sed -n '3p' | sed 's/^ *//')"
    printf '  %s %-7s %s\n' "$(command -v fzf > /dev/null 2>&1 && echo ✅ || echo ❌)" "fzf" "$(command -v fzf > /dev/null 2>&1 && fzf --version 2>&1 | head -1 || echo 'không tìm thấy lệnh')"
    printf '  %s %-7s %s\n' "$(command -v chafa > /dev/null 2>&1 && echo ✅ || echo ⚠️)" "chafa" "$(command -v chafa > /dev/null 2>&1 && chafa --version 2>&1 | head -1 || echo 'chưa cài - xem ảnh trong fzf sẽ không có')"
    echo "  Nguồn  : $base"
    if manga_is_nettruyen; then
        echo "  Trang chủ + thể loại: /, /the-loai/<slug> · ảnh: net.imgchapter.store"
    else
        echo "  Tìm kiếm: feeds=${MANGA_SEARCH_FEEDS:-$DEFAULT_MANGA_SEARCH_FEEDS} · pages=${MANGA_SEARCH_PAGES:-$DEFAULT_MANGA_SEARCH_PAGES}"
    fi
    echo
    local html
    local list_path="/tim-kiem" list_desc="/tim-kiem?m_orderby=latest"
    if manga_is_nettruyen; then
        list_path="/"; list_desc="/"
        html=$(manga_http_fetch "$list_path")
    else
        html=$(manga_http_fetch "$list_path" "m_orderby=latest" "page=1")
    fi
    if [ -n "$html" ]; then
        local n
        n=$(printf '%s' "$html" | manga_parse_items | grep -c '.')
        echo "  → ${base}${list_desc} : HTTP $(anisub_last_http) · parse được $n truyện"
        if [ "$n" -gt 0 ]; then
            echo "     ✅ còn dùng được (đổi domain khác thì sửa MANGA_BASE_URL)"
            printf '%s\n' "$(printf '%s' "$html" | manga_parse_items | head -3 | cut -d'|' -f1)" | sed 's/^/        · /'
        else
            echo "     ⚠️ HTTP OK nhưng không parse được mục nào - web đã đổi cấu trúc HTML"
            echo "       (báo cáo lên repo để cập nhật bộ lọc)"
        fi
    else
        echo "  ❌ không tải được $base$list_path (HTTP $(anisub_last_http))"
        echo "     Kiểm tra mạng/proxy, hoặc đổi nguồn/domain trong 📚 Nguồn truyện."
    fi

    echo
    echo "  ── Đọc thử 1 truyện ──────────────────────────────────"
    local sample
    sample=$(printf '%s' "${html:-}" | manga_parse_items 2>/dev/null | head -1)
    if [ -z "$sample" ]; then
        echo "  (bỏ qua: chưa lấy được danh sách truyện)"
    else
        local s_name s_url s_slug chap_list chap_count chap_url
        s_name=$(printf '%s' "$sample" | cut -d'|' -f1)
        s_url=$(printf '%s' "$sample" | cut -d'|' -f2)
        s_slug=$(printf '%s' "$sample" | cut -d'|' -f3)
        echo "  Truyện mẫu: $s_name"
        chap_list=$(fetch_chapter_list "$s_url" 2>/dev/null)
        chap_count=$(printf '%s\n' "$chap_list" | grep -c '.')
        if [ "$chap_count" -ge 3 ]; then
            echo "  ✅ danh sách chapter: $chap_count chapter"
        elif [ "$chap_count" -gt 0 ]; then
            echo "  ⚠️ danh sách chapter chỉ có $chap_count mục - web có thể đã đổi cấu trúc"
            echo "     (dùng n/p hoặc Ctrl-G để chuyển chapter nếu thiếu)"
        else
            echo "  ❌ không lấy được chapter nào (HTTP $(anisub_last_http))"
        fi
        chap_url=$(printf '%s\n' "$chap_list" | head -1 | cut -d'|' -f2)
        if [ -n "$chap_url" ]; then
            local imgs img_count first_img tmp_img
            imgs=$(fetch_chapter_images "$chap_url" "$s_slug" 2>/dev/null)
            img_count=$(printf '%s\n' "$imgs" | grep -c '.')
            echo "  → chapter đầu ( $(printf '%s\n' "$chap_list" | head -1 | cut -d'|' -f1) ): $img_count ảnh"
            first_img=$(printf '%s\n' "$imgs" | head -1)
            if [ -n "$first_img" ]; then
                tmp_img=$(mktemp "${TMPDIR:-/tmp}/anisub-diag.XXXXXX" 2>/dev/null) || tmp_img=""
                if [ -n "$tmp_img" ] && manga_download_image "$first_img" "$tmp_img"; then
                    echo "  ✅ tải thử ảnh đầu tiên: OK ($(du -h "$tmp_img" 2>/dev/null | cut -f1))"
                else
                    echo "  ❌ tải thử ảnh đầu tiên thất bại (CDN chặn hoặc mạng lỗi)"
                fi
                [ -n "$tmp_img" ] && rm -f "$tmp_img"
            fi
        fi
    fi
    echo "  Giao thức vẽ ảnh: $(manga_image_protocol) (đổi trong 📚 Nguồn truyện → Kiểu hiển thị ảnh)"
    echo "──────────────────────────────────────────────────────────"
    printf 'Nhấn Enter để quay lại... '
    read -r _
    return 0
}

# Cấu hình riêng cho nguồn truyện
show_manga_settings() {
    local opt inp
    while true; do
        opt=$(echo -e "🩺 Kiểm tra nguồn truyện\n🧪 Kiểm tra đọc truyện (chẩn đoán)\n🔁 Đổi nguồn truyện (nettruyen ⇄ truyenvn)\n🛡 Dịch vụ đọc hộ khi bị chặn: ${MANGA_READER_PROXY:-tắt}\n🌐 Trang web nguồn: ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}\n🔎 Danh sách dùng khi tìm kiếm: ${MANGA_SEARCH_FEEDS:-$DEFAULT_MANGA_SEARCH_FEEDS}\n📄 Số trang tải cho mỗi danh sách: ${MANGA_SEARCH_PAGES:-$DEFAULT_MANGA_SEARCH_PAGES}\n🖼️ Kiểu hiển thị ảnh: ${MANGA_IMAGE_PROTOCOL:-$DEFAULT_MANGA_IMAGE_PROTOCOL} (đang dùng: $(manga_image_protocol))\n🔙 Quay lại" \
            | fzf --prompt="📚 Nguồn truyện ($(manga_source_label)) > " --header="$(manga_source_label): ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}")
        case "$opt" in
            *"Đổi nguồn truyện"*)
                clear
                echo "🔁 ĐỔI NGUỒN TRUYỆN TRANH"
                echo "  Đang dùng: $(manga_source_label) - ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
                echo ""
                echo "  1) nettruyen  (https://nettruyen.info)  - mặc định, ảnh nhanh, đủ truyện"
                echo "  2) truyenvn   (https://truyenvn.my)     - nguồn cũ (cần API chapter)"
                echo ""
                read -r -p "Chọn nguồn (1/2, Enter = giữ nguyên): " inp
                case "${inp:-}" in
                    1) MANGA_SOURCE="nettruyen"; MANGA_BASE_URL="https://nettruyen.info" ;;
                    2) MANGA_SOURCE="truyenvn";  MANGA_BASE_URL="https://truyenvn.my" ;;
                    *) : ;;
                esac
                save_config
                echo "✅ Nguồn: $(manga_source_label) - ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
                sleep 1.2
                ;;
            *"Kiểm tra nguồn truyện"*)
                clear
                manga_diagnose
                ;;
            *"Kiểm tra đọc truyện"*)
                clear
                local st_target=""
                local st_def="bocchi-the-rock"
                manga_is_nettruyen && st_def="one-piece-dao-hai-tac"
                printf '🧪 Nhập slug hoặc link truyện (Enter = %s): ' "$st_def"
                read -r st_target
                [ -z "$st_target" ] && st_target="$st_def"
                mkdir -p "$CACHE_DIR" 2>/dev/null
                manga_selftest "$st_target" 2>&1 | tee "$CACHE_DIR/manga-selftest.txt"
                echo ""
                echo "📄 Đã lưu: $CACHE_DIR/manga-selftest.txt"
                echo "Nhấn Enter để tiếp tục..."; read -r _
                ;;
            *"Dịch vụ đọc hộ"*)
                clear
                echo "🛡 DỊCH VỤ ĐỌC HỘ (dùng khi trang chapter chặn máy bạn)"
                echo "  Mặc định: $DEFAULT_MANGA_READER_PROXY"
                echo "  anisub chỉ gọi dịch vụ này khi 3 kiểu tải trực tiếp đều không ra ảnh."
                echo "  Nhập URL dịch vụ khác, hoặc 'off' để tắt (không gửi link truyện ra ngoài)."
                read -r -p "Dịch vụ đọc hộ (Enter = giữ nguyên): " inp
                case "${inp:-}" in
                    "")  : ;;
                    off|OFF|none|null|0) MANGA_READER_PROXY="" ;;
                    *)   MANGA_READER_PROXY="${inp%/}" ;;
                esac
                save_config
                echo "✅ Đã lưu: ${MANGA_READER_PROXY:-tắt}"
                sleep 1.2
                ;;
            *"Trang web nguồn"*)
                read -r -p "Nhập URL trang truyện (Enter = $DEFAULT_MANGA_BASE_URL): " inp
                MANGA_BASE_URL="${inp:-$DEFAULT_MANGA_BASE_URL}"
                MANGA_BASE_URL="${MANGA_BASE_URL%/}"
                save_config
                echo "✅ Đã lưu: $MANGA_BASE_URL"
                sleep 1.2
                ;;
            *"Danh sách dùng khi tìm kiếm"*)
                read -r -p "Các danh sách (phân cách bằng dấu phẩy, Enter = $DEFAULT_MANGA_SEARCH_FEEDS): " inp
                MANGA_SEARCH_FEEDS="${inp:-$DEFAULT_MANGA_SEARCH_FEEDS}"
                save_config
                echo "✅ Đã lưu: $MANGA_SEARCH_FEEDS"
                sleep 1.2
                ;;
            *"Số trang tải"*)
                read -r -p "Số trang cho mỗi danh sách khi tìm (1-5, Enter = $DEFAULT_MANGA_SEARCH_PAGES): " inp
                if [ -z "$inp" ]; then
                    MANGA_SEARCH_PAGES="$DEFAULT_MANGA_SEARCH_PAGES"
                elif [[ "$inp" =~ ^[0-9]+$ ]] && [ "$inp" -ge 1 ] && [ "$inp" -le 5 ]; then
                    MANGA_SEARCH_PAGES="$inp"
                else
                    echo "⚠️ Bỏ qua (cần số từ 1 đến 5)"; sleep 1.2; continue
                fi
                save_config
                echo "✅ Đã lưu: $MANGA_SEARCH_PAGES trang"
                sleep 1.2
                ;;
            *"Kiểu hiển thị ảnh"*)
                clear
                echo "╔═══════════════════════════════════════════════════════════╗"
                echo "║  🖼️ KIỂU HIỂN THỊ ẢNH TRUYỆN                              ║"
                echo "╚═══════════════════════════════════════════════════════════╝"
                echo "  auto    : tự nhận terminal (khuyên dùng)"
                echo "  symbols : vẽ bằng ký tự - hiện hình ở MỌI terminal"
                echo "  kitty   : ảnh nét (kitty, ghostty...)"
                echo "  sixel   : ảnh nét (xterm/wezterm/foot có sixel)"
                echo "  iterm   : ảnh nét (iTerm2, WezTerm, mintty)"
                echo "  Hiện tại: ${MANGA_IMAGE_PROTOCOL:-$DEFAULT_MANGA_IMAGE_PROTOCOL} → đang dùng: $(manga_image_protocol)"
                echo
                read -r -p "Chọn (auto/symbols/kitty/sixel/iterm, Enter = auto): " inp
                inp="${inp:-auto}"
                case "$inp" in
                    auto|symbols|kitty|sixel|iterm)
                        MANGA_IMAGE_PROTOCOL="$inp"
                        save_config
                        echo "✅ Đã lưu: $MANGA_IMAGE_PROTOCOL (đang dùng: $(manga_image_protocol))"
                        ;;
                    *) echo "⚠️ Bỏ qua (chỉ nhận auto/symbols/kitty/sixel/iterm)" ;;
                esac
                sleep 1.4
                ;;
            *"Quay lại"*) return 0 ;;
            *)              return 0 ;;
        esac
    done
}

# --- MANGA MAIN MENU ---
manga_main_menu() {
    while true; do
        clear
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                              ║"
        echo "║   ████████╗██████╗ ██╗   ██╗██╗   ██╗███████╗███╗   ██╗██╗   ██╗███╗   ██╗   ║"
        echo "║   ╚══██╔══╝██╔══██╗██║   ██║╚██╗ ██╔╝██╔════╝████╗  ██║██║   ██║████╗  ██║   ║"
        echo "║      ██║   ██████╔╝██║   ██║ ╚████╔╝ █████╗  ██╔██╗ ██║██║   ██║██╔██╗ ██║   ║"
        echo "║      ██║   ██╔══██╗██║   ██║  ╚██╔╝  ██╔══╝  ██║╚██╗██║╚██╗ ██╔╝██║╚██╗██║   ║"
        echo "║      ██║   ██║  ██║╚██████╔╝   ██║   ███████╗██║ ╚████║ ╚████╔╝ ██║ ╚████║   ║"
        echo "║      ╚═╝   ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚══════╝╚═╝  ╚═══╝  ╚═══╝  ╚═╝  ╚═══╝   ║"
        echo "║                    📚 MANGA READER · TruyenVN 📚                             ║"
        printf "║  v%-10s %-62s║\n" "$ANISUB_VERSION" "${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
        echo "║                                                                              ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        echo ""

        main_opt=$(echo -e "🔍 Tìm kiếm truyện tranh\n📖 Truyện mới cập nhật\n🔥 Truyện hot\n👀 Truyện đọc nhiều\n🗂 Theo thể loại\n🔗 Mở bằng link / slug\n📜 Lịch sử đọc\n⭐ Truyện yêu thích\n🧪 Kiểm tra đọc truyện (chẩn đoán)\n🔙 Quay lại Menu Chính" | \
            fzf --prompt="📚 Menu > " --height=45% --reverse \
                --header="Nguồn truyện: ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL} · tìm kiếm = tải danh sách rồi lọc theo từ khóa")

        case "$main_opt" in
            "🔍 Tìm kiếm truyện tranh")
                local kw=""
                printf '🔍 Nhập tên truyện cần tìm (%s): ' "$(manga_source_label)"
                read -r kw
                if [ "${#kw}" -lt 2 ]; then
                    echo "⚠️ Từ khóa quá ngắn (cần tối thiểu 2 ký tự)."
                    sleep 1.5
                    continue
                fi
                echo "⏳ Đang tìm \\"$kw\\" trên $(manga_source_label)..."
                local items n sel
                items=$(manga_search_items "$kw")
                if [ -z "$items" ]; then
                    echo "Nhấn Enter để quay lại menu truyện..."
                    read -r _
                    continue
                fi
                n=$(printf '%s\n' "$items" | grep -c '.')
                sel=$(printf '%s\n' "$items" | fzf --prompt="📚 $n kết quả cho \\"$kw\\" > " \
                    --header="📚 Gõ để lọc lại trong $n kết quả · Enter để mở danh sách chapter" \
                    --delimiter='|' --with-nth=1 \
                    --preview "'$(manga_cover_preview_script)' {}" --preview-window='right:45%')
                [ -n "$sel" ] && manga_open_item "$sel"
                ;;
            "📖 Truyện mới cập nhật")  manga_browse_latest ;;
            "🔥 Truyện hot")          manga_browse_hot ;;
            "👀 Truyện đọc nhiều")     manga_browse_views ;;
            "🗂 Theo thể loại")        manga_genre_menu ;;
            "🔗 Mở bằng link / slug")
                local inp="" slug="" chap=""
                local ex_route="truyen-tranh/bocchi-the-rock"
                manga_is_nettruyen && ex_route="truyen-one-piece-dao-hai-tac"
                printf '🔗 Dán link trang truyện (vd %s/%s) hoặc slug: ' "${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}" "$ex_route"
                read -r inp
                inp="${inp#"${inp%%[![:space:]]*}"}"
                inp="${inp%"${inp##*[![:space:]]}"}"
                if [[ "$inp" == */truyen-tranh/* ]]; then
                    slug=$(printf '%s' "$inp" | sed -n 's#.*/truyen-tranh/\([^/?#]*\).*#\1#p')
                    chap=$(printf '%s' "$inp" | sed -n 's#.*/truyen-tranh/[^/?#]*/\([^/?#]*\).*#\1#p')
                else
                    slug="${inp##*/}"
                fi
                slug="${slug%.html}"
                if [ -z "$slug" ]; then
                    echo "❌ Không đọc được slug từ liên kết đó."
                    sleep 1.5
                    continue
                fi
                manga_read_manga "$(printf '%s' "$slug" | sed 's/[-_]/ /g')" "$slug" "$chap"
                ;;
            "📜 Lịch sử đọc")
                local hline
                hline=$(show_manga_history) || continue
                manga_read_manga "$(printf '%s' "$hline" | cut -d'|' -f1)" \
                    "$(printf '%s' "$hline" | cut -d'|' -f2)" \
                    "$(printf '%s' "$hline" | cut -d'|' -f3)"
                ;;
            "⭐ Truyện yêu thích")
                local fline
                fline=$(show_manga_favorites) || continue
                manga_read_manga "$(printf '%s' "$fline" | cut -d'|' -f1)" "$(printf '%s' "$fline" | cut -d'|' -f2)"
                ;;
            "🧪 Kiểm tra đọc truyện"*)
                local st_target=""
                local st_def="bocchi-the-rock"
                manga_is_nettruyen && st_def="one-piece-dao-hai-tac"
                printf '🧪 Nhập slug hoặc link truyện (Enter = %s): ' "$st_def"
                read -r st_target
                [ -z "$st_target" ] && st_target="$st_def"
                mkdir -p "$CACHE_DIR" 2>/dev/null
                local st_out="$CACHE_DIR/manga-selftest.txt"
                manga_selftest "$st_target" 2>&1 | tee "$st_out"
                echo ""
                echo "📄 Đã lưu kết quả vào: $st_out"
                echo "   (gửi nội dung file này khi báo lỗi để được hỗ trợ nhanh)"
                echo "Nhấn Enter để quay lại menu truyện..."
                read -r _
                ;;
            "🔙 Quay lại"*) return 0 ;;
            *)              return 0 ;;
        esac
    done
}


# --- MAIN LOGIC ---
main() {
    trap 'rm -f "$ANISUB_STATUS_FILE" "$MANGA_COOKIE_JAR" "$ANISUB_MANGA_NAV_FILE" "${TMPDIR:-/tmp}/anisub-adfree-$$.m3u8"; kill $(jobs -p) 2>/dev/null' EXIT
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
                kkphim_search_menu
                ;;
            "🍿 Phim mới cập nhật (KKPhim)")
                clear
                kkphim_browse_menu
                ;;
            *"Đọc Truyện Tranh"*)      manga_main_menu ;;
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

# Chẩn đoán luồng đọc từ dòng lệnh: ./anisub.sh --manga-selftest [slug|URL]
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-v" ]; then
    echo "anisub $ANISUB_VERSION"
    exit 0
fi

if [ "${1:-}" = "--kkphim-ad-debug" ]; then
    load_config
    shift
    kkphim_ad_report "${1:-}"
    exit $?
fi

if [ "${1:-}" = "--manga-selftest" ]; then
    load_config
    manga_selftest "${2:-}"
    exit $?
fi

main
