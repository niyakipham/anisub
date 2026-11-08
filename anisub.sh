#!/bin/bash

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DATA_FILE="$SCRIPT_DIR/assets/aniw_export_2026-01-14.csv"

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
        echo "# --- NGUỒN PHIM KKPHIM (sửa nếu KKPhim đổi domain) ---" >> "$CONFIG_FILE"
        echo "KKPHIM_SITE_URL=\"$DEFAULT_KKPHIM_SITE_URL\"" >> "$CONFIG_FILE"
        echo "KKPHIM_API_URL=\"$DEFAULT_KKPHIM_API_URL\"" >> "$CONFIG_FILE"
        echo "KKPHIM_CDN_URL=\"$DEFAULT_KKPHIM_CDN_URL\"" >> "$CONFIG_FILE"
        echo "KKPHIM_REFERER=\"$DEFAULT_KKPHIM_REFERER\"" >> "$CONFIG_FILE"
        echo "KKPHIM_SEARCH_LIMIT=\"$DEFAULT_KKPHIM_SEARCH_LIMIT\"" >> "$CONFIG_FILE"
        echo "KKPHIM_DETAIL_TTL=\"$DEFAULT_KKPHIM_DETAIL_TTL\"" >> "$CONFIG_FILE"
        echo "KKPHIM_SERVER_PREF=\"$DEFAULT_KKPHIM_SERVER_PREF\"" >> "$CONFIG_FILE"
    fi
    source "$CONFIG_FILE"
    PLAYER=${PLAYER:-$DEFAULT_PLAYER}
    DOWNLOAD_DIR=${DOWNLOAD_DIR:-$DEFAULT_DOWNLOAD_DIR}
    MANGA_IMAGE_SCALE=${MANGA_IMAGE_SCALE:-$DEFAULT_MANGA_IMAGE_SCALE}
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

# Gọi 1 endpoint của KKPhim API, in JSON ra stdout (lỗi -> trả về 1)
kkphim_api_get() {
    local path="$1"
    [ -z "$path" ] && return 1
    curl -fsSL --compressed --max-time 25 \
        -A "$KKPHIM_USER_AGENT" \
        -H "accept: application/json" \
        "${KKPHIM_API_URL%/}${path}" 2>/dev/null
}

# Mã hoá URL (tên phim tiếng Việt có dấu & khoảng trắng) bằng jq
kkphim_uri() {
    jq -rn --arg s "${1:-}" '$s | @uri' 2>/dev/null
}

# KKPhim trả ảnh ở 2 dạng: URL tuyệt đối (https://phimimg.com/...) hoặc đường dẫn
# tương đối (uploads/movies/...). kkphim_format_items chuẩn hoá hết về URL tuyệt đối
# bằng APP_DOMAIN_CDN_IMAGE trả về kèm trong từng response.

# Trang phim trên website KKPhim - dùng khi muốn xem trên trình duyệt
kkphim_movie_url() {
    printf '%s/phim/%s' "${KKPHIM_SITE_URL%/}" "$1"
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
    local encoded
    encoded=$(kkphim_uri "${1:-}")
    [ -z "$encoded" ] && return 1
    kkphim_api_get "/v1/api/tim-kiem?keyword=${encoded}&page=${2:-1}&limit=${KKPHIM_SEARCH_LIMIT}"
}

kkphim_category_json() {        # $1 = slug danh mục, $2 = trang
    local encoded
    encoded=$(kkphim_uri "${1:-}")
    [ -z "$encoded" ] && return 1
    kkphim_api_get "/v1/api/danh-sach/${encoded}?page=${2:-1}&limit=${KKPHIM_SEARCH_LIMIT}"
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
    local q="${KKPHIM_QUERY:-}"
    if [ "${#q}" -lt 2 ]; then
        kkphim_notice_line "💡 Gõ tối thiểu 2 ký tự để tìm kiếm trên $SOURCE_NAME..."
        return 0
    fi
    local json
    json=$(kkphim_search_json "$q" 1)
    if [ -z "$json" ]; then
        kkphim_notice_line "⚠️ Không kết nối được $SOURCE_NAME ($KKPHIM_API_URL) - kiểm tra mạng/proxy"
        return 0
    fi
    local lines
    lines=$(printf '%s' "$json" | kkphim_format_items)
    if [ -z "$lines" ]; then
        kkphim_notice_line "😶 Không tìm thấy phim nào với từ khóa \"$q\" trên $SOURCE_NAME"
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
        kkphim_notice_line "⚠️ Không kết nối được $SOURCE_NAME ($KKPHIM_API_URL) - kiểm tra mạng/proxy"
        return 0
    fi
    lines=$(printf '%s' "$json" | kkphim_format_items)
    [ -n "$lines" ] && printf '%s\n' "$lines"
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

    # CDN phim của KKPhim kiểm tra Referer/User-Agent, vì vậy truyền header
    # cho những trình phát có hỗ trợ; trình phát khác dùng link thô.
    case "$PLAYER" in
        mpv)
            mpv "$url" --no-terminal --profile=sw-fast --audio-display=no \
                --no-keepaspect-window --title="Anisub: $title" \
                --referrer="$KKPHIM_REFERER" --user-agent="$KKPHIM_USER_AGENT" \
                --http-header-fields="Referer: $KKPHIM_REFERER" &
            ;;
        vlc)
            vlc --referrer="$KKPHIM_REFERER" --user-agent="$KKPHIM_USER_AGENT" \
                "$url" &
            ;;
        *)
            "$PLAYER" "$url" &
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

# Tìm kiếm trực tiếp trên KKPhim (gõ tới đâu hiện gợi ý tới đó + poster)
kkphim_search_menu() {
    local sel
    sel=$(fzf --disabled \
        --prompt="🔍 Gõ tên phim ($SOURCE_NAME): " \
        --header="🎬 Nguồn: $SOURCE_NAME · $KKPHIM_SITE_URL — gõ >= 2 ký tự để xem gợi ý, Enter để chọn" \
        --bind "start:reload:ANISUB_HELPER=search KKPHIM_QUERY='' bash '$0'" \
        --bind "change:reload:ANISUB_HELPER=search KKPHIM_QUERY='{q}' bash '$0'" \
        --delimiter='|' \
        --with-nth=1 \
        --preview "ANISUB_HELPER=poster KKPHIM_POSTER='{3}' bash '$0'" \
        --preview-window=right:40%:wrap)

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
        opt=$(echo -e "🌐 Trang web nguồn: $KKPHIM_SITE_URL\n🔌 API nguồn: $KKPHIM_API_URL\n🖼️ CDN ảnh: $KKPHIM_CDN_URL\n🔉 Server ưu tiên: ${KKPHIM_SERVER_PREF:-auto}\n🔎 Số kết quả tìm kiếm: ${KKPHIM_SEARCH_LIMIT:-24}\n⏱️ Cache chi tiết phim: ${KKPHIM_DETAIL_TTL:-600}s\n🧹 Xóa cache nguồn phim\n🔙 Quay lại" | fzf --prompt="🎞 Nguồn phim ($SOURCE_NAME) > " --header="Tài liệu API của KKPhim: $KKPHIM_SITE_URL/api-document")
        case "$opt" in
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
        opt=$(echo -e "🎬 Đổi trình phát (Hiện tại: $PLAYER)\n📁 Đổi thư mục tải (Hiện tại: $DOWNLOAD_DIR)\n🎞 Nguồn phim: $SOURCE_NAME ($KKPHIM_SITE_URL)\n🖼️ Kích thước ảnh manga (Hiện tại: ${MANGA_IMAGE_SCALE}%)\n🔙 Quay lại" | fzf --prompt="⚙️ Cài đặt > ")
        case "$opt" in
            *"Đổi trình phát"*)
                read -r -p "Nhập lệnh trình phát (vd vlc): " inp
                if command -v "$inp" &> /dev/null; then PLAYER="$inp"; save_config; fi ;;
            *"Đổi thư mục tải"*)
                read -r -p "Nhập đường dẫn tuyệt đối: " inp
                DOWNLOAD_DIR="$inp"; mkdir -p "$inp"; save_config ;;
            *"Nguồn phim"*)
                show_source_settings ;;
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
# MANGA READER - TRUYENVN.SHOP
# ═══════════════════════════════════════════════════════════════════════════════

MANGA_BASE_URL="https://truyenvn.shop"

# --- MANGA HISTORY ---
add_to_manga_history() {
    local manga_name="$1"
    local chapter_name="$2"
    local manga_slug="$3"
    sed -i "/|${manga_slug}|${chapter_name}|/d" "$MANGA_HISTORY_FILE"
    echo "$(date +%Y-%m-%d\ %H:%M:%S)|${manga_name}|${chapter_name}|${manga_slug}" >> "$MANGA_HISTORY_FILE"
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

# --- FETCH CHAPTER LIST ---
fetch_chapter_list() {
    local manga_slug="$1"
    local url="${MANGA_BASE_URL}/truyen-tranh/${manga_slug}/"
    
    # Fetch HTML và extract tất cả chapter links
    # Website có nhiều format khác nhau:
    # - /truyen-tranh/soeun/chapter-1/
    # - /truyen-tranh/one-piece/one-piece-chapter-1088/
    curl -s "$url" \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" | \
        grep -oP 'href="https://truyenvn\.shop/truyen-tranh/'"$manga_slug"'/[^"]+/"' | \
        sed 's/href="//;s/"$//' | \
        grep -v "/$manga_slug/$" | \
        sort -u | \
        while read -r chap_url; do
            # Extract chapter name từ URL
            local chap_name=$(echo "$chap_url" | sed "s|.*/truyen-tranh/$manga_slug/||;s|/$||" | \
                sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
            # Format lại cho đẹp
            chap_name=$(echo "$chap_name" | sed 's/Chapter/Chapter/i')
            echo "$chap_name|$chap_url"
        done | \
        # Sắp xếp theo số chapter (extract số từ tên)
        sort -t'|' -k1 -V
}

# --- FETCH CHAPTER IMAGES ---
fetch_chapter_images() {
    local chapter_url="$1"
    local temp_html=$(mktemp /tmp/anisub_chap_XXXXXX.html)
    
    # 1. Tải HTML về file tạm để xử lý ổn định
    curl -s "$chapter_url" \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
        -H "Referer: ${MANGA_BASE_URL}/" \
        -o "$temp_html"
        
    if [ ! -s "$temp_html" ]; then
        rm -f "$temp_html"
        return 1
    fi
    
    # 2. Extract URLs - Support Lazy Loading & Scope to Content
    # Scope vào class "reading-content" để tránh ảnh thumbnail của truyện khác
    perl -0777 -ne '
    my $content = $_;
    
    # Try to find the reading content div more loosely
    if ($content =~ /(<div[^>]*class=[\"\x27][^\"\x27]*reading-content[^>]*>)/si) {
        # Start from the match
        $content = $'"'"'; # $'"'"' is post-match (using single quote hack for shell)
        
        # Stop at "comments", "related", "entry-footer" or common footer classes
        # Use a list of potential footer markers
        if ($content =~ /(class=[\"\x27][^\"\x27]*(related-reading|entry-footer|comments|footer-widgets)[^\"\x27]*[\"\x27]|id=[\"\x27]comments[\"\x27])/i) {
             $content = $` ; 
        }
    }
    
    while ($content =~ /<img\s+([^>]+)>/gi) {
        my $attrs = $1;
        my $url = "";
        # Check priority attributes
        if ($attrs =~ /data-(?:src|original|lazy-src|eco)=[\"\x27]([^\"\x27]+)[\"\x27]/i) {
            $url = $1;
        } elsif ($attrs =~ /\ssrc=[\"\x27]([^\"\x27]+)[\"\x27]/i) {
            $url = $1;
        }
        
        # Clean up URL (trim whitespace)
        $url =~ s/^\s+|\s+$//g;
        
        # Decode HTML entities if needed (basic chars)
        $url =~ s/&amp;/&/g;
        
        if ($url ne "") { print "$url\n"; }
    }' "$temp_html" | \
        grep -iE '\.(jpg|jpeg|png|webp|gif)' | \
        grep "^http" | \
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
        grep -viE 'logo|icon|avatar|thumb|banner|facebook|twitter|share|google|recaptcha|popup' | \
        grep -v '^$' | \
        awk '!seen[$0]++' > "${temp_html}.list"
        
    # Check if list is empty
    if [ ! -s "${temp_html}.list" ]; then 
        echo "" >&2 # Suppress visual error for user, handle in caller
    else
        cat "${temp_html}.list"
    fi
    rm -f "${temp_html}" "${temp_html}.list"
}

# --- PREFETCH IMAGES ---
prefetch_chapter_images() {
    local cache_dir="$1"
    shift
    local images=("$@")
    
    mkdir -p "$cache_dir"
    
    # Download in parallel (background jobs)
    local max_jobs=5
    local job_count=0
    
    local idx=0
    for url in "${images[@]}"; do
        local filename=$(printf "%03d.jpg" $((idx + 1))) # 001.jpg, 002.jpg...
        local filepath="$cache_dir/$filename"
        
        # Skip if exists
        if [ ! -f "$filepath" ]; then
            (
                curl -sL "$url" \
                     -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
                     -H "Referer: ${MANGA_BASE_URL}/" \
                     -o "$filepath.tmp" && mv "$filepath.tmp" "$filepath"
            ) &
            
            ((job_count++))
            if [ $job_count -ge $max_jobs ]; then
                wait -n
                ((job_count--))
            fi
        fi
        ((idx++))
    done
    wait # Wait for all remaining jobs
}

# --- DISPLAY FULL CHAPTER (FZF "Smart Mode") ---
# --- DISPLAY FULL CHAPTER (FZF "Smart Mode" + Fallback) ---
display_full_chapter() {
    local manga_name="$1"
    local chapter_name="$2"
    shift 2
    local images=("$@")
    local total_pages=${#images[@]}
    
    # Cache Directory Setup
    local session_id=$(date +%s)
    local cache_dir="/tmp/anisub_cache_$session_id"
    mkdir -p "$cache_dir"
    
    # 1. Create URL Map for Fallback (lines 1..N)
    local url_file="$cache_dir/urls.txt"
    printf "%s\n" "${images[@]}" > "$url_file"
    
    # 2. Create Open Helper
    cat <<EOF > "$cache_dir/open.sh"
#!/bin/bash
current_line="\$1"
page_num=\$(echo "\$current_line" | awk '{print \$2}' | cut -d'/' -f1)
target_file="$cache_dir/\${page_num}.jpg"
# Try downloading if missing (using curl line from url file)
if [ ! -f "\$target_file" ]; then
    idx=\$(echo "\$page_num" | sed 's/^0*//')
    url=\$(sed -n "\${idx}p" "$url_file")
    curl -sL "\$url" \
         -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
         -H "Referer: ${MANGA_BASE_URL}/" \
         -o "\$target_file.tmp" && mv "\$target_file.tmp" "\$target_file"
fi
if [ -f "\$target_file" ]; then
    xdg-open "\$target_file" >/dev/null 2>&1 &
fi
EOF
    chmod +x "$cache_dir/open.sh"

    # Create Preview Script Helper
    cat <<EOF > "$cache_dir/preview.sh"
#!/bin/bash
current_line="\$1"
page_num=\$(echo "\$current_line" | awk '{print \$2}' | cut -d'/' -f1)
target_file="$cache_dir/\${page_num}.jpg"

# DEBOUNCE
sleep 0.15

# [ CLEANUP ] Force clear previous graphics (Crucial for Kitty)
if [[ "\$TERM" == "xterm-kitty" ]]; then
    printf '\x1b_Ga=d,d=A\x1b\\'
fi

# [ FALLBACK ] Check Cache or Download
if [ ! -s "\$target_file" ]; then
    idx=\$(echo "\$page_num" | sed 's/^0*//'); [ -z "\$idx" ] && idx=0 
    url=\$(sed -n "\${idx}p" "$url_file")
    
    if [ -n "\$url" ]; then
        # Try download silently
        curl -fsL "\$url" -H "Referer: ${MANGA_BASE_URL}/" -H "User-Agent: Mozilla/5.0" -o "\$target_file.tmp" >/dev/null 2>&1
        
        if [ -s "\$target_file.tmp" ]; then
            mv "\$target_file.tmp" "\$target_file" >/dev/null 2>&1
        else
            rm -f "\$target_file.tmp" >/dev/null 2>&1
        fi
    fi
fi

if [ ! -s "\$target_file" ]; then
    echo "❌ Tải lỗi. (Mạng kém?)"
    exit 1
fi

# [ INFO ]
fsize=\$(du -h "\$target_file" | cut -f1)

# [ DIMENSION CHECK ]
width=0
height=0

if command -v identify &>/dev/null; then
    dims=\$(identify -format "%w %h" "\$target_file" 2>/dev/null)
    width=\$(echo "\$dims" | awk '{print \$1}')
    height=\$(echo "\$dims" | awk '{print \$2}')
elif command -v file &>/dev/null; then
    res=\$(file "\$target_file")
    if [[ \$res =~ ([0-9]+)x([0-9]+) ]]; then
        width=\${BASH_REMATCH[1]}
        height=\${BASH_REMATCH[2]}
    fi
fi

if [ -z "\$width" ] || [ "\$width" -eq 0 ]; then width=1; height=1; fi
ratio=\$((height / width))

echo "📁 \${page_num} [\$fsize]"

# [ RENDER ] Logic
# 1. Webtoon Strip (Ratio >= 3) -> Text Mode for Scrolling
if [ \$ratio -ge 3 ]; then
     safe_cols=\$((FZF_PREVIEW_COLUMNS - 4))
     if [ \$safe_cols -lt 10 ]; then safe_cols=10; fi
     chafa -f symbols --symbols=all --size="\${safe_cols}x" --animate=off "\$target_file"

# 2. Normal Page -> Graphic Mode (Kitty/Sixel)
else
    safe_cols=\$((FZF_PREVIEW_COLUMNS - 4))
    safe_lines=\$((FZF_PREVIEW_LINES - 3))
    if [ \$safe_cols -lt 10 ]; then safe_cols=10; fi

    if [[ "\$TERM" == "xterm-kitty" ]]; then
        # Force Kitty Protocol
        chafa -f kitty --size="\${safe_cols}x\${safe_lines}" --animate=off "\$target_file"
    else
        # Force Sixel Protocol (Assuming terminal supports it if not Kitty)
        # We REMOVE the fallback to symbols to force HD or nothing.
        # If chafa fails (exit code), FZF will just show nothing or error, better than blurry symbols.
        chafa -f sixels --size="\${safe_cols}x\${safe_lines}" --animate=off "\$target_file"
    fi
fi
EOF
    chmod +x "$cache_dir/preview.sh"

    # Start Prefetching in Background
    prefetch_chapter_images "$cache_dir" "${images[@]}" >/dev/null 2>&1 &
    local prefetch_pid=$!
    
    # Cleanup Trap (ensure cache is deleted on exit)
    trap "rm -rf '$cache_dir'; kill $prefetch_pid 2>/dev/null" EXIT
    
    # Prepare Input list for FZF
    list_input=""
    for ((i=1; i<=total_pages; i++)); do
        p_str=$(printf "%03d" $i)
        list_input+="Trang ${p_str}/${total_pages}"$'\n'
    done
    
    # FZF Execution
    echo -n "$list_input" | fzf \
        --layout=reverse \
        --ansi \
        --header="📖 $manga_name - $chapter_name" \
        --prompt="Xem ảnh HD | Enter: Mở ngoài > " \
        --preview "$cache_dir/preview.sh {}" \
        --preview-window="right:75%" \
        --bind "enter:execute-silent($cache_dir/open.sh {})" \
        --bind "ctrl-c:abort"
        
    # Clean up at end of chapter
    rm -rf "$cache_dir"
}

# --- READ MANGA CHAPTER (Continuous Scroll) ---
read_manga_chapter() {
    local manga_name="$1"
    local manga_slug="$2"
    local chapter_name="$3"
    local chapter_url="$4"
    local chapter_list_raw="$5"
    
    while true; do
        clear
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║  ⏳ ĐANG TẢI CHAPTER...                                                      ║"
        printf "║  📖 %-70s ║\n" "$manga_name"
        printf "║  📑 %-70s ║\n" "$chapter_name"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        
        # Lấy danh sách ảnh
        mapfile -t images < <(fetch_chapter_images "$chapter_url")
        
        if [ ${#images[@]} -eq 0 ]; then
            echo ""
            echo "❌ Không tìm thấy hình ảnh trong chapter này!"
            echo "Nhấn [r] để thử lại, [c] để chọn chapter khác, hoặc [q] để thoát."
            read -rsn1 key
            case "$key" in
                'r') continue ;;
                'c') return 0 ;;
                'q') return 1 ;;
            esac
            continue
        fi
        
        add_to_manga_history "$manga_name" "$chapter_name" "$manga_slug"
        
        # Clear và hiển thị toàn bộ chapter (continuous scroll)
        clear
        display_full_chapter "$manga_name" "$chapter_name" "${images[@]}"
        
        # Input Loop to prevent re-rendering on invalid key
        while true; do
            read -rsn1 key < /dev/tty
            case "$key" in
                'n')  # Next chapter
                    next_chap=$(echo "$chapter_list_raw" | grep -A1 "^${chapter_name}|" | tail -1)
                    if [ -n "$next_chap" ] && [ "$next_chap" != "${chapter_name}|"* ]; then
                        chapter_name=$(echo "$next_chap" | cut -d'|' -f1)
                        chapter_url=$(echo "$next_chap" | cut -d'|' -f2)
                        break 2 # Break inner loop, continue outer (reload new chap)
                    else
                        echo ""
                        echo "📚 Đây là chapter mới nhất! (Phím bất kỳ để tiếp tục)"
                        # Stay in inner loop
                    fi
                    ;;
                'p')  # Previous chapter
                    prev_chap=$(echo "$chapter_list_raw" | grep -B1 "^${chapter_name}|" | head -1)
                    if [ -n "$prev_chap" ] && [ "$prev_chap" != "${chapter_name}|"* ]; then
                        chapter_name=$(echo "$prev_chap" | cut -d'|' -f1)
                        chapter_url=$(echo "$prev_chap" | cut -d'|' -f2)
                        break 2 # Break inner loop, continue outer (reload new chap)
                    else
                        echo ""
                        echo "📚 Đây là chapter đầu tiên! (Phím bất kỳ để tiếp tục)"
                        # Stay in inner loop
                    fi
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
        echo "║                        📚 MANGA READER 📚                                    ║"
        echo "║                                                                              ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        
        main_opt=$(echo -e "🔍 Tìm kiếm truyện tranh\n📖 Truyện mới cập nhật\n📜 Lịch sử đọc\n⭐ Truyện yêu thích\n🔙 Quay lại Menu Chính" | \
            fzf --prompt="📚 Menu > " --height=40% --reverse)
        
        case "$main_opt" in
            "🔍 Tìm kiếm truyện tranh")
                # Search với fzf dynamic
                sel=$(fzf --disabled \
                    --prompt="🔍 Gõ tên truyện: " \
                    --header="╔══════════════════════════════════════════╗
║  Nhập >= 2 ký tự để tìm kiếm             ║
╚══════════════════════════════════════════╝" \
                    --bind "change:reload:
                        query={q};
                        if [ \${#query} -ge 2 ]; then
                            encoded_q=\$(echo \"\$query\" | sed 's/ /%20/g');
                            curl -s \"https://truyenvn.shop/?s=\$encoded_q&post_type=wp-manga\" | \
                            grep -oP '<a href=\"https://truyenvn.shop/truyen-tranh/[^\"]+\"[^>]*title=\"[^\"]+\"' | \
                            sed 's/<a href=\"\([^\"]*\)\"[^>]*title=\"\([^\"]*\)\"/\2|\1/' | \
                            head -20;
                        else
                            echo 'Vui lòng nhập tên truyện...';
                        fi" \
                    --delimiter='|' \
                    --with-nth=1)
                
                if [ -n "$sel" ] && [[ "$sel" != "Vui lòng"* ]]; then
                    manga_name=$(echo "$sel" | cut -d'|' -f1)
                    manga_url=$(echo "$sel" | cut -d'|' -f2)
                    manga_slug=$(echo "$manga_url" | sed 's|.*/truyen-tranh/\([^/]*\)/.*|\1|')
                    
                    # Lấy danh sách chapter
                    echo "⏳ Đang tải danh sách chapter..."
                    chapter_list=$(fetch_chapter_list "$manga_slug")
                    
                    if [ -z "$chapter_list" ]; then
                        echo "❌ Không tìm thấy chapter!"
                        sleep 2
                        continue
                    fi
                    
                    # Chọn chapter
                    sel_chap=$(echo "$chapter_list" | fzf --prompt="📑 Chọn chapter > " --delimiter='|' --with-nth=1 --tac \
                        --header="╔══════════════════════════════════════════╗
║  📖 $manga_name
╚══════════════════════════════════════════╝")
                    
                    if [ -n "$sel_chap" ]; then
                        chap_name=$(echo "$sel_chap" | cut -d'|' -f1)
                        chap_url=$(echo "$sel_chap" | cut -d'|' -f2)
                        
                        while true; do
                            read_manga_chapter "$manga_name" "$manga_slug" "$chap_name" "$chap_url" "$chapter_list"
                            result=$?
                            if [ $result -eq 1 ]; then
                                break  # User quit
                            fi
                            # User wants to change chapter
                            sel_chap=$(echo "$chapter_list" | fzf --prompt="📑 Chọn chapter > " --delimiter='|' --with-nth=1 --tac)
                            if [ -z "$sel_chap" ]; then
                                break
                            fi
                            chap_name=$(echo "$sel_chap" | cut -d'|' -f1)
                            chap_url=$(echo "$sel_chap" | cut -d'|' -f2)
                        done
                    fi
                fi
                ;;
                
            "📖 Truyện mới cập nhật")
                echo "⏳ Đang tải danh sách truyện mới..."
                manga_list=$(curl -s "${MANGA_BASE_URL}/truyen-tranh/" | \
                    grep -oP '<a href="https://truyenvn.shop/truyen-tranh/[^"]+/"[^>]*title="[^"]+"' | \
                    sed 's/<a href="\([^"]*\)"[^>]*title="\([^"]*\)"/\2|\1/' | \
                    head -30)
                
                sel=$(echo "$manga_list" | fzf --prompt="📖 Chọn truyện > " --delimiter='|' --with-nth=1 \
                    --header="╔══════════════════════════════════════════╗
║  📖 TRUYỆN MỚI CẬP NHẬT                  ║
╚══════════════════════════════════════════╝")
                
                if [ -n "$sel" ]; then
                    manga_name=$(echo "$sel" | cut -d'|' -f1)
                    manga_url=$(echo "$sel" | cut -d'|' -f2)
                    manga_slug=$(echo "$manga_url" | sed 's|.*/truyen-tranh/\([^/]*\)/.*|\1|')
                    
                    chapter_list=$(fetch_chapter_list "$manga_slug")
                    
                    if [ -z "$chapter_list" ]; then
                        echo "❌ Không tìm thấy chapter!"
                        sleep 2
                        continue
                    fi
                    
                    sel_chap=$(echo "$chapter_list" | fzf --prompt="📑 Chọn chapter > " --delimiter='|' --with-nth=1 --tac \
                        --header="📖 $manga_name")
                    
                    if [ -n "$sel_chap" ]; then
                        chap_name=$(echo "$sel_chap" | cut -d'|' -f1)
                        chap_url=$(echo "$sel_chap" | cut -d'|' -f2)
                        
                        while true; do
                            read_manga_chapter "$manga_name" "$manga_slug" "$chap_name" "$chap_url" "$chapter_list"
                            result=$?
                            if [ $result -eq 1 ]; then break; fi
                            sel_chap=$(echo "$chapter_list" | fzf --prompt="📑 Chọn chapter > " --delimiter='|' --with-nth=1 --tac)
                            if [ -z "$sel_chap" ]; then break; fi
                            chap_name=$(echo "$sel_chap" | cut -d'|' -f1)
                            chap_url=$(echo "$sel_chap" | cut -d'|' -f2)
                        done
                    fi
                fi
                ;;
                
            "📜 Lịch sử đọc")
                history_result=$(show_manga_history)
                if [ $? -eq 0 ]; then
                    manga_name=$(echo "$history_result" | cut -d'|' -f1)
                    manga_slug=$(echo "$history_result" | cut -d'|' -f2)
                    chapter_name=$(echo "$history_result" | cut -d'|' -f3)
                    
                    chapter_list=$(fetch_chapter_list "$manga_slug")
                    chap_url="${MANGA_BASE_URL}/truyen-tranh/${manga_slug}/${chapter_name}/"
                    
                    # Chuẩn hóa chapter name
                    chap_name_display=$(echo "$chapter_name" | sed 's/chapter-/Chapter /')
                    
                    while true; do
                        read_manga_chapter "$manga_name" "$manga_slug" "$chap_name_display" "$chap_url" "$chapter_list"
                        result=$?
                        if [ $result -eq 1 ]; then break; fi
                        sel_chap=$(echo "$chapter_list" | fzf --prompt="📑 Chọn chapter > " --delimiter='|' --with-nth=1 --tac)
                        if [ -z "$sel_chap" ]; then break; fi
                        chap_name_display=$(echo "$sel_chap" | cut -d'|' -f1)
                        chap_url=$(echo "$sel_chap" | cut -d'|' -f2)
                    done
                fi
                ;;
                
            "⭐ Truyện yêu thích")
                fav_result=$(show_manga_favorites)
                if [ $? -eq 0 ]; then
                    manga_name=$(echo "$fav_result" | cut -d'|' -f1)
                    manga_slug=$(echo "$fav_result" | cut -d'|' -f2)
                    
                    chapter_list=$(fetch_chapter_list "$manga_slug")
                    
                    if [ -z "$chapter_list" ]; then
                        echo "❌ Không tìm thấy chapter!"
                        sleep 2
                        continue
                    fi
                    
                    sel_chap=$(echo "$chapter_list" | fzf --prompt="📑 Chọn chapter > " --delimiter='|' --with-nth=1 --tac \
                        --header="⭐ $manga_name")
                    
                    if [ -n "$sel_chap" ]; then
                        chap_name=$(echo "$sel_chap" | cut -d'|' -f1)
                        chap_url=$(echo "$sel_chap" | cut -d'|' -f2)
                        
                        while true; do
                            read_manga_chapter "$manga_name" "$manga_slug" "$chap_name" "$chap_url" "$chapter_list"
                            result=$?
                            if [ $result -eq 1 ]; then break; fi
                            sel_chap=$(echo "$chapter_list" | fzf --prompt="📑 Chọn chapter > " --delimiter='|' --with-nth=1 --tac)
                            if [ -z "$sel_chap" ]; then break; fi
                            chap_name=$(echo "$sel_chap" | cut -d'|' -f1)
                            chap_url=$(echo "$sel_chap" | cut -d'|' -f2)
                        done
                    fi
                fi
                ;;
                
            "🔙 Quay lại Menu Chính"|*)
                return
                ;;
        esac
    done
}

# --- MAIN LOGIC ---
main() {
    trap 'kill $(jobs -p) 2>/dev/null' EXIT
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
        main_opt=$(echo -e "🎬 Xem Anime/Phim (KKPhim)\n🍿 Phim mới cập nhật (KKPhim)\n📚 Đọc Truyện Tranh (TruyenVN)\n📂 Xem từ Local Anidata\n📜 Lịch sử xem Anime\n⭐ Anime yêu thích\n⚙️ Cài đặt\n🔄 Cập nhật\n🚪 Thoát" | fzf --prompt="🎯 Menu > " --height=50% --reverse --header="🎬 Nguồn phim: $SOURCE_NAME ($KKPHIM_SITE_URL) · API: $KKPHIM_API_URL")

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
            "📚 Đọc Truyện Tranh (TruyenVN)") manga_main_menu ;;
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

main
