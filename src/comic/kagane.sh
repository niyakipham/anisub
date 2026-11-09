# ═══════════════════════════════════════════════════════════════════════════════
# NGUỒN TRUYỆN: KAGANE (kagane.moe)
# ═══════════════════════════════════════════════════════════════════════════════
# Kagane là site tổng hợp manga/manhwa/manhua đa ngôn ngữ (60+), chạy SPA +
# Cloudflare, có API JSON riêng. Những gì anisub dùng:
#
#   Trang truyện : /series/<slug>-<uuid7>
#   Trang đọc    : /series/<slug>-<uuid7>/reader/<book_id>
#   Danh sách    : /search?sort=now | avg_views_week,desc | updated_at,desc | created_at,desc
#   Tìm kiếm     : /search?q=<từ khoá>            (server render -> parse HTML)
#   Chi tiết     : GET  /api/v2/series/<series_id>
#   Chương       : GET  /api/v2/series/<series_id>/books/index?fields=List
#                  -> {count, fields[], groups[], books[[...]]} (mỗi dòng là 1 mảng
#                  theo đúng thứ tự ở fields: book_id, sort_no, chapter_no,
#                  released_at (epoch giây), title, page_count...)
#   Ảnh bìa      : <base>/api/v2/image/<image_id>/compressed
#   Ảnh trang    : POST /api/integrity                     -> {"token","exp"}
#                  POST /api/v2/books/<book_id>?intent=Read (kèm x-integrity-token)
#                    -> {"access_token","cache_url","manifest":{"pages":[...]}}
#                  <cache_url>/api/v2/books/page/original/<book_id>/<page_id>.<ext>?token=<access_token>
#
# Lưu ý khi sửa file này:
#   * Host ảnh trả 404 nếu THIẾU header Origin của site -> mọi request ảnh phải
#     kèm "-H origin: <base>" (kg_download_image lo việc đó).
#   * Token đọc chỉ sống vài phút (cache trên đĩa tới lúc hết hạn); hết hạn thì
#     trang ảnh trả 401/403/507 -> xin lại rồi thử lại 1 lần.
#   * Trang /search chỉ render server cho TRANG ĐẦU; tham số page lạ làm site trả
#     danh sách rỗng, nên anisub chỉ duyệt trang đầu + tìm theo từ khoá.

# Đánh dấu module đã nạp (menu nguồn truyện dựa vào đây để biết bộ src/ đã có
# nguồn kagane hay còn là bản cũ -> nhắc người dùng chạy 🔄 Cập nhật).
KAGANE_MODULE=1

# ─── NHẬN DIỆN NGUỒN ───────────────────────────────────────────────────────────
manga_is_kagane() {
    case "${MANGA_SOURCE:-$DEFAULT_MANGA_SOURCE}" in
        kagane|kg|kagane.moe|kagane.org|kagane.si|kagane.cx|kagane.net) return 0 ;;
        *)                                                              return 1 ;;
    esac
}

# Base URL của Kagane (không có "/" ở cuối)
kg_base() {
    local b="${MANGA_BASE_URL:-${DEFAULT_KAGANE_BASE_URL:-https://kagane.moe}}"
    case "$b" in
        http://*|https://*) : ;;
        "")                 b="https://kagane.moe" ;;
        *)                  b="https://$b" ;;
    esac
    printf '%s' "${b%/}"
}

# Host (không scheme) - dùng cho --resolve của DoH
kg_host() {
    local h
    h=$(kg_base)
    h="${h#*://}"
    printf '%s' "${h%%/*}"
}

# ─── NHẬN DIỆN URL / ID ───────────────────────────────────────────────────────
# Book id (36 ký tự cuối của URL đọc): .../reader/<book_id> hoặc .../reader/chapter-3-<book_id>
kg_book_id() {
    local v="${1:-}"
    v="${v%%\?*}"; v="${v%%#*}"; v="${v%/}"
    v="${v##*/}"
    if [ "${#v}" -ge 36 ]; then printf '%s' "${v: -36}"; else printf '%s' "$v"; fi
}

# Series id (uuid 36 ký tự) từ URL truyện / URL đọc / slug-uuid
kg_series_id() {
    local v="${1:-}"
    v="${v%%\?*}"; v="${v%%#*}"; v="${v%/}"
    case "$v" in
        */reader/*) v="${v%%/reader/*}" ;;
    esac
    case "$v" in
        http://*|https://*) v="${v##*/series/}" ;;
    esac
    v="${v##*/}"
    if [ "${#v}" -ge 36 ]; then printf '%s' "${v: -36}"; else printf '%s' "$v"; fi
}

# Đoạn cuối URL truyện = "<slug>-<uuid>" (giữ nguyên để dựng lại URL / lịch sử)
kg_series_segment() {
    local v="${1:-}"
    v="${v%%\?*}"; v="${v%%#*}"; v="${v%/}"
    case "$v" in
        */reader/*) v="${v%%/reader/*}" ;;
    esac
    case "$v" in
        http://*|https://*) v="${v##*/series/}" ;;
    esac
    printf '%s' "${v##*/}"
}

# URL trang truyện từ slug/segment/URL (truyện chưa có uuid thì vẫn dựng, site tự 404)
kg_series_url() {
    local v="${1:-}"
    local seg
    seg=$(kg_series_segment "$v")
    case "$v" in
        http://*|https://*)
            # link đọc (.../series/<seg>/reader/<book>) -> đưa về trang truyện
            case "$v" in
                */series/*) [ -n "$seg" ] && { printf '%s/series/%s' "${v%%/series/*}" "$seg"; return 0; } ;;
            esac
            printf '%s' "${v%%\?*}"
            return 0 ;;
    esac
    [ -n "$seg" ] || return 1
    printf '%s/series/%s' "$(kg_base)" "$seg"
}

# ─── HTTP / API ───────────────────────────────────────────────────────────────
# IP lấy qua DNS-over-HTTPS, cache ở $CACHE_DIR/doh-<host> (dùng chung với e-hentai)
kg_doh_ip() {
    local host="${1:-}"
    host="${host#*://}"; host="${host%%/*}"; host="${host%%\?*}"
    [ -n "$host" ] || return 1
    local f="${CACHE_DIR}/doh-${host}"
    if [ -s "$f" ]; then head -1 "$f"; return 0; fi
    local ip=""
    if declare -F anisub_doh_resolve > /dev/null 2>&1; then
        ip=$(anisub_doh_resolve "$host" 2>/dev/null) || ip=""
    fi
    [ -n "$ip" ] || return 1
    mkdir -p "$CACHE_DIR" 2>/dev/null
    printf '%s\n' "$ip" > "$f" 2>/dev/null
    printf '%s' "$ip"
}

# Gọi API JSON của Kagane. $1 = GET|POST, $2 = path (hoặc URL tuyệt đối),
# $3 = body (POST). In body ra stdout khi HTTP 2xx; mã HTTP ở MANGA_HTTP_STATUS.
# Header thêm (vd x-integrity-token) đặt qua biến KG_EXTRA_HEADER trước lời gọi.
kg_api_call() {
    local method="${1:-GET}" path="${2:-}" body="${3:-}"
    [ -n "$path" ] || return 1
    if ! command -v jq > /dev/null 2>&1; then
        echo "⚠️ Kagane cần jq để đọc API (cài: sudo apt install jq)" >&2
        return 1
    fi
    local url
    case "$path" in
        http://*|https://*) url="$path" ;;
        /*)                 url="$(kg_base)$path" ;;
        *)                  url="$(kg_base)/$path" ;;
    esac
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/anisub-kg.XXXXXX" 2>/dev/null) || tmp="${TMPDIR:-/tmp}/anisub-kg.$$.tmp"
    local -a args=(-sS -L --compressed --connect-timeout 10 --max-time 25)
    [ -n "${MANGA_PROXY:-}" ] && args+=(--proxy "$MANGA_PROXY")
    args+=(-A "$MANGA_USER_AGENT"
        -H 'accept: application/json, text/plain, */*'
        -H 'accept-language: vi,en;q=0.8'
        -H "origin: $(kg_base)"
        -e "$(kg_base)/"
        -c "$MANGA_COOKIE_JAR" -b "$MANGA_COOKIE_JAR")
    [ -n "${KAGANE_COOKIE:-}" ] && args+=(-H "cookie: $KAGANE_COOKIE")
    [ -n "${KG_EXTRA_HEADER:-}" ] && args+=(-H "$KG_EXTRA_HEADER")
    if [ "$method" = "POST" ]; then
        args+=(-X POST -H 'content-type: application/json' --data "${body:-{\}}")
    fi
    local status rc
    status=$(curl "${args[@]}" -o "$tmp" -w '%{http_code}' "$url" 2>/dev/null); rc=$?
    # DNS nhà mạng chặn (curl 6) -> hỏi IP qua DoH rồi nối thẳng, giống e-hentai
    if [ "$rc" -eq 6 ] && [ "${MANGA_DOH:-auto}" != "off" ]; then
        local ip
        if ip=$(kg_doh_ip "$(kg_host)"); then
            status=$(curl "${args[@]}" --resolve "$(kg_host):443:$ip" -o "$tmp" -w '%{http_code}' "$url" 2>/dev/null); rc=$?
        fi
    fi
    MANGA_HTTP_STATUS="${status:-000}"
    printf '%s' "$MANGA_HTTP_STATUS" > "$ANISUB_STATUS_FILE" 2>/dev/null || true
    printf '%s' "$rc" > "${ANISUB_CURL_ERR_FILE:-/dev/null}" 2>/dev/null || true
    case "$MANGA_HTTP_STATUS" in
        2??)
            if [ -s "$tmp" ]; then cat "$tmp"; rm -f "$tmp"; return 0; fi
            rm -f "$tmp"; return 1 ;;
    esac
    # Giữ body lỗi để chẩn đoán (401/403/507 của API, trang Cloudflare...)
    if [ -s "$tmp" ]; then
        head -c 400 "$tmp" > "${TMPDIR:-/tmp}/anisub-kg-error.txt" 2>/dev/null
    fi
    rm -f "$tmp" 2>/dev/null
    return 1
}

# Gợi ý lỗi cho người dùng cuối (dùng chung cho mọi lệnh gọi API)
kg_http_hint() {
    local what="${1:-Kagane}"
    local code
    code=$(declare -F anisub_last_http > /dev/null 2>&1 && anisub_last_http)
    [ -n "$code" ] || code="${MANGA_HTTP_STATUS:-000}"
    case "$code" in
        000)
            echo "⚠️ $what: không kết nối được (HTTP 000)." >&2
            if declare -F manga_net_hint > /dev/null 2>&1; then
                manga_net_hint "$(kg_base)" "$(anisub_last_curl_err 2>/dev/null)" | sed 's/^/   /' >&2
            fi
            ;;
        401|403|507)
            echo "⚠️ $what: bị chặn/cần token mới (HTTP $code)." >&2
            echo "   Site sau Cloudflare: thử ./anisub.sh --netcheck $(kg_host)" >&2
            echo "   hoặc đặt cookie trình duyệt vào KAGANE_COOKIE (⚙️ Cài đặt)." >&2
            ;;
        404)
            echo "⚠️ $what: không tìm thấy (HTTP 404) - truyện/chương đã bị xoá?" >&2
            ;;
        *)
            echo "⚠️ $what: HTTP $code." >&2
            ;;
    esac
}

# GET HTML (trang /search) - dùng engine chung để hưởng cookie/proxy/DoH
kg_http_get() {
    local path="$1"
    shift
    manga_http_fetch "$path" "$@"
}

# ─── PARSE DANH SÁCH TRUYỆN (HTML /search) ────────────────────────────────────
# -> "Tên|URL truyện|slug-uuid|ảnh bìa" (mỗi dòng 1 truyện)
kg_parse_items() {
    KG_BASE="$(kg_base)" perl -CS -Mutf8 -0777 -ne '
        my $base = $ENV{KG_BASE} // "";
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
            $t =~ s/^\s+//;
            $t =~ s/\s+$//;
            return $t;
        }
        # mọi link truyện: href=".../series/<slug>-<uuid>" (bỏ link đọc /reader/)
        my @hits;
        while (m{<a\b[^>]*?href="(?:https?:)?(?://[^"/]+)?/series/([A-Za-z0-9._~%-]+)(?:[?#][^"]*)?"[^>]*>(.*?)</a>}gs) {
            push @hits, { seg => $1, inner => $2, start => $-[0], stop => $+[0] };
        }
        my $prev = 0;
        my %seen;
        for my $h (@hits) {
            my ($seg, $inner) = ($h->{seg}, $h->{inner});
            next if $seen{$seg}++;
            # ảnh bìa: ảnh API cuối cùng đứng TRƯỚC link này
            my $before = substr($_, $prev, $h->{start} - $prev);
            $prev = $h->{stop};
            my $cover = "";
            while ($before =~ m{(?:https?:)?(?://[^"\s]+)?/api/v2/image/([0-9a-fA-F-]{16,})/(?:compressed|original)}g) {
                $cover = "$base/api/v2/image/$1/compressed";
            }
            my $name = clean($inner);
            if (!length $name || $name =~ m{^\s*$}) {
                (my $p = $seg) =~ s/-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$//;
                $p =~ s/[-_]+/ /g; $p =~ s/\b(\w)/\u$1/g;
                $name = $p;
            }
            print "$name|$base/series/$seg|$seg|$cover\n";
        }
    '
}

# Tham số lọc ngôn ngữ (KAGANE_LANG): "" = mọi ngôn ngữ
kg_lang_param() {
    local l="${KAGANE_LANG:-}"
    [ -n "$l" ] || return 0
    case "$l" in
        *[!A-Za-z-]*) return 0 ;;
    esac
    printf 'languages=%s' "$l"
}

# ─── DANH SÁCH / TÌM KIẾM ─────────────────────────────────────────────────────
# $1 = path (/search), $2.. = tham số (sort=..., q=..., page=...)
kg_list_items() {
    local path="${1:-/search}"
    shift 2>/dev/null || true
    local sort="" q="" page="" kv
    for kv in "$@"; do
        case "$kv" in
            sort=*) sort="${kv#sort=}" ;;
            q=*)    q="${kv#q=}" ;;
            page=*) page="${kv#page=}" ;;
        esac
    done
    # Trang > 1: /search của Kagane chỉ render server trang đầu (tham số page lạ
    # làm danh sách rỗng) -> báo rõ thay vì hiện "không có truyện".
    case "$page" in
        ""|0|1) : ;;
        *)  echo "ℹ️ Kagane chỉ duyệt được trang đầu - dùng 🔍 Tìm kiếm để lọc thay vì sang trang." >&2
            return 0 ;;
    esac
    local -a params=()
    [ -n "$q" ] && params+=("q=$q")
    [ -n "$sort" ] && params+=("sort=$sort")
    local lp
    lp=$(kg_lang_param)
    [ -n "$lp" ] && params+=("$lp")
    local html
    if ! html=$(kg_http_get "$path" "${params[@]}"); then
        kg_http_hint "Danh sách Kagane"
        return 1
    fi
    local items
    items=$(printf '%s' "$html" | kg_parse_items)
    if [ -z "$items" ]; then
        echo "⚠️ Kagane trả trang nhưng không có truyện nào (đổi cấu trúc HTML?)" >&2
        return 1
    fi
    # nhớ ảnh bìa để fzf xem trước ở bước chọn chapter
    printf '%s\n' "$items" | while IFS='|' read -r _n _u _s _c; do
        [ -n "${_c:-}" ] && [ -n "${_s:-}" ] && manga_cover_cache_put "$_s" "$_c"
    done
    printf '%s\n' "$items"
}

kg_search_items() {
    local kw="${1:-}"
    if ! kg_list_items "/search" "q=$kw"; then
        return 1
    fi
}

# ─── DANH SÁCH CHƯƠNG ────────────────────────────────────────────────────────
# API trả "books/index?fields=List": mỗi dòng là mảng theo thứ tự fields[].
# -> "Tên chương|URL đọc|<chapter_no>" xếp tăng dần theo sort_no.
kg_fetch_chapter_list() {
    local target="$1"
    local sid seg
    sid=$(kg_series_id "$target")
    seg=$(kg_series_segment "$target")
    if [ -z "$sid" ]; then
        echo "⚠️ Không đọc được mã truyện Kagane từ \"$target\"." >&2
        echo "   Dán link dạng https://kagane.moe/series/<slug>-<uuid> để chắc chắn đúng." >&2
        return 1
    fi

    # Chi tiết: lấy slug chuẩn + ảnh bìa (danh sách chương không có bìa)
    local details="" slug="" cover=""
    details=$(kg_api_call GET "/api/v2/series/$sid" 2>/dev/null) || details=""
    if [ -n "$details" ]; then
        slug=$(printf '%s' "$details" | jq -r '.slug // empty' 2>/dev/null)
        cover=$(printf '%s' "$details" | jq -r '
            (.main_cover_id // ((.series_covers // [])[0].image_id) // empty)' 2>/dev/null)
        [ -n "$cover" ] && cover="$(kg_base)/api/v2/image/$cover/compressed"
        MANGA_STORY_COVER="$cover"
        if [ -n "$cover" ] && [ -n "$seg" ]; then
            manga_cover_cache_put "$seg" "$cover"
        fi
    fi
    [ -z "$slug" ] && slug=$(printf '%s' "$seg" | sed 's/-[0-9a-fA-F-]\{36\}$//')

    local index
    if ! index=$(kg_api_call GET "/api/v2/series/$sid/books/index?fields=List"); then
        kg_http_hint "Danh sách chương Kagane ($sid)"
        return 1
    fi
    local rows
    rows=$(printf '%s' "$index" | jq -r --arg base "$(kg_base)" --arg slug "$slug" --arg sid "$sid" '
        [ (.fields // []) as $f
          | (.books // [])[]
          | . as $row
          | ($f | to_entries | map({key: (.value|tostring), value: $row[.key]}) | from_entries) ]
        | .[]
        | (.chapter_no // "") as $no
        | (.volume_no // "") as $vol
        | (.title // "" | gsub("^\\s+|\\s+$"; "")) as $title
        | (if ($title | length) > 0 then $title
           elif ($no | length) > 0 then "Ch.\($no)"
           elif ($vol | length) > 0 then "Vol.\($vol)"
           else "#\(.sort_no)" end) as $name
        | (if ($no | length) > 0 then $no else (.sort_no|tostring) end) as $lbl
        | "\($name)|\($base)/series/\($slug)-\($sid)/reader/\(.book_id)|\($lbl)"
    ' 2>/dev/null)
    if [ -z "$rows" ]; then
        echo "⚠️ API Kagane không trả chapter nào cho truyện $sid (truyện chưa có chương?)." >&2
        return 1
    fi
    rows=$(printf '%s\n' "$rows" | sort -s -t'|' -k3,3V)
    # Nhớ lại để Ctrl-G (nhảy tới số chương) dựng được URL đọc
    mkdir -p "$CACHE_DIR" 2>/dev/null
    printf '%s\n' "$rows" > "${CACHE_DIR}/kg-${sid}.list" 2>/dev/null
    printf '%s\n' "$rows"
}

# Số chương -> URL đọc (Ctrl-G): tra trong danh sách vừa tải, lưu ở cache
kg_chapter_url() {
    local page_url="$1" num="$2"
    local sid f
    sid=$(kg_series_id "$page_url")
    f="${CACHE_DIR}/kg-${sid}.list"
    [ -s "$f" ] || return 1
    num="${num//[^0-9.]/}"
    [ -n "$num" ] || return 1
    awk -F'|' -v n="$num" '
        { v = $3; gsub(/\.0+$/, "", v) ; if (v == n) { print $2; found = 1; exit } }
        END { exit(found ? 0 : 1) }' "$f"
}

# ─── TOKEN ĐỌC + ẢNH TRANG ───────────────────────────────────────────────────
# Integrity token (sống ~vài phút): POST /api/integrity, cache tới hạn ở $CACHE_DIR
kg_integrity_token() {
    local f="${CACHE_DIR}/kg-integrity" tok="" exp=0 now
    now=$(date +%s)
    if [ -s "$f" ]; then
        tok=$(sed -n '1p' "$f")
        exp=$(sed -n '2p' "$f")
        case "$exp" in ''|*[!0-9]*) exp=0 ;; esac
        if [ -n "$tok" ] && [ "$exp" -gt "$((now + 20))" ]; then
            printf '%s' "$tok"
            return 0
        fi
    fi
    local json
    if ! json=$(kg_api_call POST "/api/integrity" '{}' 2>/dev/null); then
        kg_http_hint "Xin integrity token"
        return 1
    fi
    tok=$(printf '%s' "$json" | jq -r '.token // empty' 2>/dev/null)
    exp=$(printf '%s' "$json" | jq -r '.exp // 0' 2>/dev/null)
    [ -n "$tok" ] || return 1
    mkdir -p "$CACHE_DIR" 2>/dev/null
    printf '%s\n%s\n' "$tok" "${exp:-0}" > "$f" 2>/dev/null
    printf '%s' "$tok"
}

# Xin "challenge" của 1 book -> JSON {access_token, cache_url, manifest.pages}
# 401/403/507 = token hết hạn/bị chặn -> xin token mới rồi thử lại 1 lần.
kg_challenge() {
    local book_id="${1:-}"
    [ -n "$book_id" ] || return 1
    local tok json attempt
    for attempt in 1 2; do
        tok=$(kg_integrity_token) || return 1
        json=$(KG_EXTRA_HEADER="x-integrity-token: $tok" \
               kg_api_call POST "/api/v2/books/${book_id}?intent=Read" '' 2>/dev/null) && {
            printf '%s' "$json"
            return 0
        }
        # mã HTTP nằm trong file trạng thái (lời gọi API chạy trong subshell)
        case "$(anisub_last_http)" in
            401|403|507) rm -f "${CACHE_DIR}/kg-integrity" 2>/dev/null ;;
            *)           break ;;
        esac
    done
    return 1
}

# JSON challenge (stdin) -> danh sách URL ảnh, $1 = book_id, $2 = original|datasaver
kg_page_urls() {
    jq -r --arg book "${1:-}" --arg mode "${2:-original}" '
        (.cache_url // "") as $cache
        | (.access_token // "") as $tok
        | select(($cache | length) > 0 and ($tok | length) > 0)
        | (.manifest.pages // []) | sort_by(.page_no) | .[]
        | "\($cache|rtrimstr("/"))/api/v2/books/page/\($mode)/\($book)/\(.page_id).\(.ext // "jxl")?token=\($tok)"
    ' 2>/dev/null
}

kg_fetch_chapter_images() {
    local chapter_url="${1:-}"
    [ -z "$chapter_url" ] && return 1
    rm -f "$ANISUB_MANGA_NAV_FILE" 2>/dev/null   # reader tự chuyển chap theo danh sách
    local book_id
    book_id=$(kg_book_id "$chapter_url")
    if [ -z "$book_id" ] || [ "${#book_id}" -lt 8 ]; then
        echo "⚠️ URL chương Kagane không hợp lệ: $chapter_url" >&2
        return 1
    fi
    local json
    if ! json=$(kg_challenge "$book_id"); then
        echo "⚠️ Kagane không cấp quyền đọc chương này (HTTP $(anisub_last_http))." >&2
        echo "   - Thử lại sau vài giây (token chỉ sống vài phút)." >&2
        echo "   - Truyện 18+ có thể cần KAGANE_COOKIE (cookie trình duyệt đã qua bước xác nhận 18+)." >&2
        echo "   - Mở trực tiếp: $chapter_url" >&2
        return 1
    fi
    local urls
    urls=$(printf '%s' "$json" | kg_page_urls "$book_id" original)
    if [ -z "$urls" ]; then
        echo "⚠️ API Kagane trả manifest rỗng (chương chưa có trang ảnh)." >&2
        return 1
    fi
    printf '%s\n' "$urls"
}

# Tải 1 ảnh trang Kagane: host ảnh đòi header Origin của site (thiếu -> 404)
kg_download_image() {
    local url="${1:-}" dest="${2:-}"
    [ -z "$url" ] || [ -z "$dest" ] && return 1
    local tmp="${dest}.part"
    rm -f "$tmp" 2>/dev/null
    local -a proxy_opt=()
    [ -n "${MANGA_PROXY:-}" ] && proxy_opt=(--proxy "$MANGA_PROXY")
    curl -fsSL --compressed --max-time 30 --retry 2 --retry-delay 1 \
        -A "$MANGA_USER_AGENT" "${proxy_opt[@]}" \
        -H "origin: $(kg_base)" \
        -e "$(kg_base)/" \
        -o "$tmp" "$url" >/dev/null 2>&1
    if [ "$(manga_file_is_image "$tmp")" = "1" ]; then
        mv "$tmp" "$dest" 2>/dev/null && return 0
    fi
    rm -f "$tmp" 2>/dev/null
    return 1
}

# ─── CHẨN ĐOÁN ───────────────────────────────────────────────────────────────
kg_diagnose() {
    local pause="${1:-}"
    local base; base=$(kg_base)
    echo "🩺 Chẩn đoán nguồn truyện tranh (kagane)"
    echo "──────────────────────────────────────────────────────────"
    echo "  Nguồn   : $base"
    echo "  API     : $base/api/v2"
    echo "  Token   : ${KAGANE_COOKIE:+đã đặt cookie}${KAGANE_COOKIE:-chưa đặt cookie (chỉ truyện công khai)}"
    echo "  Ngôn ngữ: ${KAGANE_LANG:-mọi ngôn ngữ} (KAGANE_LANG)"
    if declare -F manga_image_protocol > /dev/null 2>&1; then
        echo "  Vẽ ảnh  : ${MANGA_IMAGE_PROTOCOL:-auto} (đang dùng: $(manga_image_protocol))"
    fi

    local html n
    html=$(kg_http_get "/search" "sort=now" 2>/dev/null) || html=""
    if [ -n "$html" ]; then
        n=$(printf '%s' "$html" | kg_parse_items | grep -c '.')
        echo "  → /search?sort=now: HTTP $(anisub_last_http) · parse được $n truyện"
        if [ "$n" -gt 0 ]; then
            echo "     ✅ Duyệt/tìm truyện dùng được"
        else
            echo "     ⚠️ HTTP OK nhưng không parse được mục nào - site đổi cấu trúc HTML"
        fi
    else
        echo "  ❌ không tải được $base/search (HTTP $(anisub_last_http))"
        if declare -F manga_net_hint > /dev/null 2>&1; then
            manga_net_hint "$base" "$(anisub_last_curl_err 2>/dev/null)" | sed 's/^/  /'
        fi
    fi

    # API chi tiết + danh sách chương của truyện đầu tiên tìm được
    local sample seg sid details chapters
    sample=$(printf '%s' "${html:-}" | kg_parse_items 2>/dev/null | head -1)
    seg=$(printf '%s' "$sample" | cut -d'|' -f3)
    sid=$(kg_series_id "$seg")
    echo ""
    if [ -z "$sid" ]; then
        echo "  (bỏ qua phần API: chưa lấy được truyện mẫu)"
    else
        echo "  Truyện mẫu: $(printf '%s' "$sample" | cut -d'|' -f1)"
        if details=$(kg_api_call GET "/api/v2/series/$sid" 2>/dev/null); then
            echo "  ✓ API chi tiết   : OK · $(printf '%s' "$details" | jq -r '.title // "?"' 2>/dev/null)"
        else
            echo "  ✗ API chi tiết   : HTTP $(anisub_last_http)"
        fi
        if chapters=$(kg_fetch_chapter_list "$sid" 2>/dev/null); then
            echo "  ✓ API chương     : $(printf '%s\n' "$chapters" | grep -c '.') chương"
        else
            echo "  ✗ API chương     : HTTP $(anisub_last_http)"
        fi
        local tok
        if tok=$(kg_integrity_token 2>/dev/null); then
            echo "  ✓ Token đọc      : có (${#tok} ký tự)"
        else
            echo "  ✗ Token đọc      : không lấy được (HTTP ${MANGA_HTTP_STATUS:-000}) - ảnh trang sẽ không tải được"
            echo "     → thử ./anisub.sh --netcheck $(kg_host) hoặc đặt KAGANE_COOKIE"
        fi
    fi

    echo ""
    if [ -n "$pause" ] && [ "$pause" != "--no-pause" ]; then
        echo "Nhấn Enter để tiếp tục..."; read -r _
    fi
    return 0
}
