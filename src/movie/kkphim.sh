# ═══════════════════════════════════════════════════════════════════════════════
# NGUỒN PHIM: KKPHIM (https://kkphim.com)
# ═══════════════════════════════════════════════════════════════════════════════
# Module này chứa TOÀN BỘ phần phim của anisub: gọi API KKPhim (tìm kiếm, danh mục,
# chi tiết phim, server, danh sách tập), chọn server/tập, phát phim (mpv/vlc) và
# menu điều khiển trình phát đang chạy.
#   + Trang web : https://kkphim.com   -> trang phim, poster, Referer khi phát
#   + API       : https://phimapi.com  -> RESTful API (tài liệu: /api-document)
#   + CDN ảnh   : https://phimimg.com  -> ảnh poster
# Được nạp tự động bởi anisub.sh (xem anisub_load_sources).

kkphim_cache_prune() {
    # Dọn cache cũ hơn 3 ngày (poster / chi tiết phim)
    [ -d "$CACHE_DIR" ] || return 0
    find "$CACHE_DIR" -maxdepth 1 -type f -mtime +3 -delete 2>/dev/null
    return 0
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

# File tạm ghi danh sách tập sau khi đổi server (biến toàn cục không sống sót sau $(...))
KK_SWITCHED_LIST_FILE="${TMPDIR:-/tmp}/anisub_switched_list.$$"

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

# ═══════════════════════════════════════════════════════════════════════════════
# CHẶN QUẢNG CÁO TRONG PLAYLIST HLS (.m3u8)
# ═══════════════════════════════════════════════════════════════════════════════
# KKPhim chèn quảng cáo kiểu SSAI: khối segment quảng cáo nằm NGAY TRONG playlist
# (thường bọc bởi #EXT-X-CUE-OUT / … / #EXT-X-CUE-IN, có khi chỉ có CUE-OUT kèm
# thời lượng). Trình phát phát đúng những gì playlist ghi, nên muốn bỏ quảng cáo
# (điển hình là khối chèn giữa phim ở ~phút 15) thì phải lọc playlist trước khi
# phát. Bản lọc:
#   • bỏ TOÀN BỘ khối nằm giữa CUE-OUT và CUE-IN — kể cả khi segment quảng cáo
#     nằm CÙNG host với phim (đây là lý do bản lọc theo mẫu URL trước đây vẫn để
#     lọt quảng cáo), hoặc đúng bằng thời lượng ghi trong CUE-OUT;
#   • bỏ segment có host/đường dẫn khớp KKPHIM_AD_PATTERNS;
#   • bỏ khối ngắn nằm ở tên miền "lạ" (adserver) khi CDN của phim chiếm >=70%;
#   • chèn #EXT-X-DISCONTINUITY đúng chỗ cắt để trình phát nối tiếp, không khựng;
#   • tuyệt đối hoá URL (#EXT-X-KEY / #EXT-X-MAP / segment) cho file local;
#   • chuẩn hoá thành VOD (#EXT-X-PLAYLIST-TYPE:VOD + #EXT-X-ENDLIST) vì playlist
#     kiểu live bị tải lại mỗi TARGETDURATION giây -> "phát vài giây lại khựng";
#   • GIỮ NGUYÊN #EXT-X-MEDIA-SEQUENCE / #EXT-X-DISCONTINUITY-SEQUENCE (đó là IV
#     mặc định của AES-128 và mốc BYTERANGE — đổi là giải mã sai, phim giật).
# Không tải/lọc được (mạng lỗi, playlist lạ, mã hoá AES-128 không kèm IV) thì
# anisub phát ĐÚNG link gốc — không bao giờ làm bạn không xem được phim.
kkphim_ad_block_enabled() {
    case "$(printf '%s' "${KKPHIM_AD_BLOCK:-$DEFAULT_KKPHIM_AD_BLOCK}" | tr 'A-Z' 'a-z')" in
        0|off|no|false|tat|tắt) return 1 ;;
        *)                      return 0 ;;
    esac
}

kkphim_ad_foreign_enabled() {
    case "$(printf '%s' "${KKPHIM_AD_FOREIGN_HOST:-$DEFAULT_KKPHIM_AD_FOREIGN_HOST}" | tr 'A-Z' 'a-z')" in
        0|off|no|false|tat|tắt) return 1 ;;
        *)                      return 0 ;;
    esac
}

# File perl lọc playlist: cạnh module này, hoặc trong bộ src/ đang dùng.
kkphim_hls_filter_script() {
    local p moddir
    moddir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)
    for p in "${ANISUB_SRC_DIR:-}/movie/hls_adfree.pl" \
             "${SCRIPT_DIR:-}/src/movie/hls_adfree.pl" \
             "${CONFIG_DIR:-}/src/movie/hls_adfree.pl" \
             "${moddir:-}/hls_adfree.pl"; do
        [ -n "$p" ] && [ -f "$p" ] && { printf '%s' "$p"; return 0; }
    done
    return 1
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

# Tải nội dung playlist (giữ Referer/UA như trình phát).
kkphim_fetch_playlist() {
    local url="$1" tmp code
    tmp=$(mktemp "${TMPDIR:-/tmp}/anisub-hls.XXXXXX" 2>/dev/null) || return 1
    code=$(curl -sSL --compressed --max-time 20 --retry 1 --retry-delay 1 \
        -A "$KKPHIM_USER_AGENT" -e "${KKPHIM_REFERER:-$DEFAULT_KKPHIM_REFERER}" \
        -o "$tmp" -w '%{http_code}' "$url" 2>/dev/null)
    if [ "$code" != "200" ] || [ ! -s "$tmp" ]; then
        rm -f "$tmp" 2>/dev/null
        return 1
    fi
    cat "$tmp"
    rm -f "$tmp" 2>/dev/null
}

# Chọn variant trong master playlist: first (mặc định, giống trình phát) | max | 1..9
kkphim_pick_variant() {
    printf '%s\n' "$1" | KKPHIM_AD_VARIANT="${KKPHIM_AD_VARIANT:-first}" perl -ne '
        my $want = lc($ENV{KKPHIM_AD_VARIANT} // "first");
        if (/^#EXT-X-STREAM-INF:.*BANDWIDTH=(\d+)/i) { $bw = $1; next }
        next if /^#/ || /^\s*$/;
        chomp;
        if (defined $bw) { push @v, [$bw, $_]; $bw = undef }
        END {
            exit 0 unless @v;
            if ($want eq "max") {
                @v = sort { $b->[0] <=> $a->[0] } @v;
                print $v[0][1];
            } elsif ($want =~ /^\d+$/ && $want >= 1 && $want <= @v) {
                print $v[$want - 1][1];
            } else {
                print $v[0][1];          # first
            }
        }' 2>/dev/null
}

# Đọc 1 khoá trong file thống kê của lần lọc gần nhất.
kkphim_ad_stat() {
    local key="$1" f="${KKPHIM_ADFREE_STATS:-${TMPDIR:-/tmp}/anisub-adfree-$$.stats}"
    [ -s "$f" ] || return 0
    sed -n "s/^${key}=//p" "$f" 2>/dev/null | head -1
}

# Tải + lọc playlist, in ra đường dẫn file .m3u8 đã lọc. Lỗi -> return 1.
kkphim_adfree_playlist() {
    local url="$1" text variant filtered out stats pl
    pl=$(kkphim_hls_filter_script) || return 1
    command -v perl > /dev/null 2>&1 || return 1
    text=$(kkphim_fetch_playlist "$url") || return 1
    case "$text" in *"#EXTM3U"*) : ;; *) return 1 ;; esac

    # Master playlist -> chọn 1 variant rồi tải playlist con.
    if printf '%s' "$text" | grep -q '#EXT-X-STREAM-INF'; then
        variant=$(kkphim_pick_variant "$text")
        [ -z "$variant" ] && return 1
        url=$(kkphim_abs_url "$url" "$variant")
        text=$(kkphim_fetch_playlist "$url") || return 1
        case "$text" in *"#EXTM3U"*) : ;; *) return 1 ;; esac
    fi

    # AES-128 mà KHÔNG kèm IV: IV suy từ số thứ tự segment, bỏ segment là giải mã
    # sai toàn bộ -> thà phát bản gốc còn hơn hỏng phim.
    if printf '%s' "$text" | grep -i 'METHOD=AES-128' | grep -qvi 'IV='; then
        echo "⚠️  Playlist mã hoá AES-128 không kèm IV - bỏ qua lọc để không hỏng phim." >&2
        return 1
    fi

    # Chẩn đoán: giữ lại playlist gốc (bản media playlist đang dùng) để đối chiếu
    if [ "${KKPHIM_AD_SAVE:-0}" = "1" ]; then
        mkdir -p "$CACHE_DIR" 2>/dev/null
        printf '%s\n' "$text" > "${KKPHIM_AD_ORIGINAL_FILE:-$CACHE_DIR/kkphim-playlist-original.m3u8}" 2>/dev/null
    fi

    stats="${KKPHIM_ADFREE_STATS:-${TMPDIR:-/tmp}/anisub-adfree-$$.stats}"
    rm -f "$stats" 2>/dev/null
    filtered=$(printf '%s\n' "$text" \
        | KKPHIM_BASE="$url" \
          KKPHIM_AD_PATTERNS="${KKPHIM_AD_PATTERNS:-$DEFAULT_KKPHIM_AD_PATTERNS}" \
          KKPHIM_AD_FOREIGN_HOST="${KKPHIM_AD_FOREIGN_HOST:-$DEFAULT_KKPHIM_AD_FOREIGN_HOST}" \
          KKPHIM_AD_STATS="$stats" \
          perl "$pl" 2>/dev/null) || return 1
    [ -z "$filtered" ] && return 1
    printf '%s\n' "$filtered" | grep -qE '^[^#[:space:]]' || return 1

    out="${KKPHIM_ADFREE_FILE:-${TMPDIR:-/tmp}/anisub-adfree-$$.m3u8}"
    printf '%s\n' "$filtered" > "$out" 2>/dev/null || return 1
    printf '%s' "$out"
}

# URL đưa cho trình phát: .m3u8 + đang bật chặn quảng cáo -> bản đã lọc.
# Không lọc được thì trả lại đúng link gốc.
kkphim_play_url() {
    local url="${1:-}" f dropped secs
    case "$url" in
        *m3u8*) : ;;
        *)      printf '%s' "$url"; return 0 ;;
    esac
    kkphim_ad_block_enabled || { printf '%s' "$url"; return 0; }
    if f=$(kkphim_adfree_playlist "$url" 2>/dev/null) && [ -n "$f" ] && [ -s "$f" ]; then
        dropped=$(kkphim_ad_stat dropped)
        secs=$(kkphim_ad_stat dropped_sec)
        if [ "${dropped:-0}" -gt 0 ] 2>/dev/null; then
            printf '🚫 Đã lọc %s đoạn quảng cáo (~%ss) khỏi playlist HLS.\n' \
                "$dropped" "${secs:-0}" >&2
            anisub_debug_log "adblock: bo ${dropped} segment (~${secs}s) cua $url" 2>/dev/null
        fi
        printf '%s' "$f"
    else
        anisub_debug_log "adblock: khong loc duoc $url -> phat link goc" 2>/dev/null
        printf '%s' "$url"
    fi
}

# Chẩn đoán chặn quảng cáo: ./anisub.sh --kkphim-ad-debug <link m3u8>
kkphim_ad_report() {
    local url="${1:-}"
    if [ -z "$url" ]; then
        echo "Cách dùng: ./anisub.sh --kkphim-ad-debug <link .m3u8>"
        echo "   (lấy link m3u8 bằng: 🎬 Xem Anime/Phim -> chọn tập -> 🔄 Làm mới link tập,"
        echo "    hoặc xem mục Chẩn đoán trong ⚙️ Cài đặt → 🎞 Nguồn phim)"
        return 1
    fi
    echo "🚫 CHẨN ĐOÁN CHẶN QUẢNG CÁO (anisub $ANISUB_VERSION)"
    echo "   URL          : $url"
    echo "   Bật chặn     : $(kkphim_ad_block_enabled && echo 'có' || echo 'KHÔNG (KKPHIM_AD_BLOCK=0)')"
    echo "   Variant      : ${KKPHIM_AD_VARIANT:-first}"
    echo "   Mẫu nhận diện: ${KKPHIM_AD_PATTERNS:-$DEFAULT_KKPHIM_AD_PATTERNS}"
    echo "   Host lạ      : $(kkphim_ad_foreign_enabled && echo 'bỏ khối ở tên miền khác' || echo 'tắt')"
    local out pl
    pl=$(kkphim_hls_filter_script) || pl=""
    KKPHIM_AD_SAVE=1
    if ! out=$(kkphim_adfree_playlist "$url" 2>&1); then
        KKPHIM_AD_SAVE=0
        echo "   ❌ Không tải/lọc được playlist này (xem thông báo ngay trên)."
        echo "      → kiểm tra: curl -sSL -o /tmp/pl.m3u8 \"$url\" && head -20 /tmp/pl.m3u8"
        return 1
    fi
    KKPHIM_AD_SAVE=0
    local kept dropped secs total
    kept=$(kkphim_ad_stat kept); dropped=$(kkphim_ad_stat dropped)
    secs=$(kkphim_ad_stat dropped_sec); total=$(kkphim_ad_stat segments)
    echo "   ✔ Playlist tải được · segment giữ ${kept:-?} / bỏ ${dropped:-0} (tổng ${total:-?})"
    echo "     thời lượng đã bỏ: ~${secs:-0}s"
    echo "     lý do: cue=$(kkphim_ad_stat reason_cue) mẫu-url=$(kkphim_ad_stat reason_pattern) tên-miền=$(kkphim_ad_stat reason_host) khối-lạ=$(kkphim_ad_stat reason_block)"

    # Bản đồ khối theo #EXT-X-DISCONTINUITY: thấy ngay vì sao khối ở 2:56 bị bỏ
    # mà khối ở 14:58 không (khác host / thư mục / đuôi / kiểu #EXTINF ở chỗ nào).
    local orig="${KKPHIM_AD_ORIGINAL_FILE:-$CACHE_DIR/kkphim-playlist-original.m3u8}"
    if [ -s "$orig" ] && [ -n "$pl" ]; then
        echo "   ── bản đồ khối (theo #EXT-X-DISCONTINUITY):"
        KKPHIM_AD_MODE=blocks KKPHIM_BASE="$url" \
            KKPHIM_AD_PATTERNS="${KKPHIM_AD_PATTERNS:-$DEFAULT_KKPHIM_AD_PATTERNS}" \
            perl "$pl" < "$orig" 2>/dev/null | sed 's/^/      /'
        cp "$out" "$CACHE_DIR/kkphim-playlist-filtered.m3u8" 2>/dev/null
        echo "   📄 Playlist GỐC     : $orig"
        echo "   📄 Playlist ĐÃ LỌC  : $CACHE_DIR/kkphim-playlist-filtered.m3u8"
    fi
    if [ "${dropped:-0}" -gt 0 ] 2>/dev/null && [ -s "${KKPHIM_ADFREE_STATS:-${TMPDIR:-/tmp}/anisub-adfree-$$.stats}" ]; then
        echo "   ── segment bị bỏ (tối đa 25):"
        sed -n 's/^url=/      · /p' "${KKPHIM_ADFREE_STATS:-${TMPDIR:-/tmp}/anisub-adfree-$$.stats}" 2>/dev/null
    fi
    [ -s "${KKPHIM_AD_ORIGINAL_FILE:-$CACHE_DIR/kkphim-playlist-original.m3u8}" ] || \
        echo "   📄 Playlist đã lọc: $out"
    echo "   💡 Khối ở ~2:56 bị bỏ được mà khối ở ~14:58 không? So 2 dòng ⚠️ trong"
    echo "      bản đồ khối ở trên: chúng khác nhau ở host / thư mục / đuôi / kiểu #EXTINF."
    echo "   → Gửi 2 file playlist (gốc + đã lọc) khi báo lỗi để thêm luật nhận diện."
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

    # Nếu là playlist .m3u8 và đang bật chặn quảng cáo: phát bản đã lọc (quảng cáo
    # chèn giữa phim ~phút 15 nằm ngay trong playlist nên phải lọc trước khi phát).
    # Không lọc được thì kkphim_play_url trả lại đúng link gốc.
    local play_url
    play_url=$(kkphim_play_url "$url")
    [ -z "$play_url" ] && play_url="$url"

    # CDN phim của KKPhim kiểm tra Referer/User-Agent, vì vậy truyền header
    # cho những trình phát có hỗ trợ; trình phát khác dùng link thô.
    case "$PLAYER" in
        mpv)
            mpv "$play_url" --no-terminal --profile=sw-fast --audio-display=no \
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

# --- SETTINGS & UPDATE ---
# Cài đặt riêng cho nguồn phim KKPhim (domain, server ưu tiên, cache)
show_source_settings() {
    local opt inp pref
    while true; do
        local ad_state
        ad_state=$(kkphim_ad_block_enabled && echo 'bật' || echo 'tắt')
        opt=$(echo -e "🩺 Kiểm tra kết nối & phụ thuộc\n🌐 Trang web nguồn: $KKPHIM_SITE_URL\n🔌 API nguồn: $KKPHIM_API_URL\n🖼️ CDN ảnh: $KKPHIM_CDN_URL\n🔉 Server ưu tiên: ${KKPHIM_SERVER_PREF:-auto}\n🔎 Số kết quả tìm kiếm: ${KKPHIM_SEARCH_LIMIT:-24}\n⏱️ Cache chi tiết phim: ${KKPHIM_DETAIL_TTL:-600}s\n🚫 Chặn quảng cáo trong m3u8: $ad_state\n🎚️ Chất lượng khi lọc quảng cáo: ${KKPHIM_AD_VARIANT:-first}\n🏷️ Mẫu nhận diện quảng cáo\n🧹 Xóa cache nguồn phim\n🔙 Quay lại" | fzf --prompt="🎞 Nguồn phim ($SOURCE_NAME) > " --header="Tài liệu API của KKPhim: $KKPHIM_SITE_URL/api-document · lỗi tìm kiếm? chạy 🩺 trước")
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
            *"Chặn quảng cáo trong m3u8"*)
                local ad_pick
                ad_pick=$(printf '%s\n' "1|Bật (bỏ đoạn quảng cáo chèn trong playlist)" "0|Tắt (phát đúng link gốc)" \
                    | fzf --prompt="Chặn quảng cáo HLS > " --delimiter='|' --with-nth=2 --header="Quảng cáo của $SOURCE_NAME nằm ngay trong playlist .m3u8 nên phải lọc trước khi phát")
                [ -z "$ad_pick" ] && continue
                KKPHIM_AD_BLOCK="${ad_pick%%|*}"
                save_config
                echo "🚫 Chặn quảng cáo trong m3u8: $(kkphim_ad_block_enabled && echo 'BẬT' || echo 'TẮT')"
                sleep 1 ;;
            *"Chất lượng khi lọc quảng cáo"*)
                local v_pick
                v_pick=$(printf '%s\n' "first|Variant đầu tiên (nhẹ nhất, giữ mượt như trình phát)" "max|Variant băng thông cao nhất (nét nhất, dễ khựng nếu mạng yếu)" "1|Variant 1" "2|Variant 2" "3|Variant 3" \
                    | fzf --prompt="Variant khi lọc > " --delimiter='|' --with-nth=2)
                [ -z "$v_pick" ] && continue
                KKPHIM_AD_VARIANT="${v_pick%%|*}"
                save_config
                echo "🎚️ Variant khi lọc quảng cáo: $KKPHIM_AD_VARIANT"
                sleep 1 ;;
            *"Mẫu nhận diện quảng cáo"*)
                echo "Hiện tại: ${KKPHIM_AD_PATTERNS:-$DEFAULT_KKPHIM_AD_PATTERNS}"
                echo "  (các mẫu cách nhau bằng dấu phẩy; so khớp nguyên một thành phần host/đường dẫn)"
                read -r -p "Nhập mẫu mới (Enter = giữ nguyên, 'reset' = mặc định): " inp
                case "$inp" in
                    "")    continue ;;
                    reset) KKPHIM_AD_PATTERNS="$DEFAULT_KKPHIM_AD_PATTERNS" ;;
                    *)     KKPHIM_AD_PATTERNS="$inp" ;;
                esac
                save_config
                echo "🏷️ Mẫu nhận diện: $KKPHIM_AD_PATTERNS"
                sleep 1 ;;
            *"Xóa cache"*)
                rm -f "$CACHE_DIR"/kkphim-*.json "$CACHE_DIR"/poster-* 2>/dev/null
                echo "🧹 Đã dọn cache dữ liệu phim."
                sleep 1 ;;
            *) break ;;
        esac
    done
}
