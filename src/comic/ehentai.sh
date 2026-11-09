# ═══════════════════════════════════════════════════════════════════════════════
# NGUỒN TRUYỆN: E-HENTAI (https://e-hentai.org)
# ═══════════════════════════════════════════════════════════════════════════════
# e-hentai là hệ gallery ảnh: mỗi gallery (/g/<id>/<token>/) là "1 truyện", bên
# trong có N trang ảnh. anisub chia N trang thành từng nhóm (mặc định 20 trang)
# và hiển thị mỗi nhóm như "1 chapter" -> chọn/đọc/chuyển trang bằng đúng bộ menu
# sẵn có (fzf, cuộn liên tục, n/p, lịch sử, yêu thích...).
#
# Điểm cần biết khi bảo trì:
#   • Mỗi trang ảnh (/s/<token>/<gid>-<i>) mới là nơi có link ảnh thật (<img id="img">).
#     Vì vậy đọc 1 nhóm 20 trang = 20 request; anisub CACHE link ảnh theo gallery
#     (cache/ehentai/img-<gid>-<i>.url) nên lần đọc sau gần như tức thì.
#   • Trang danh sách phân trang bằng ?next=<id> (không phải ?page=N) nên menu duyệt
#     của e-hentai đọc link "Next >" từ chính trang vừa tải.
#   • Gallery giới hạn/18+ cần cookie đăng nhập: đặt EHENTAI_COOKIE trong Cài đặt.
#   • e-hentai chặn khi tải quá nhanh ("Excessive pageloads") -> có delay giữa các
#     request (EHENTAI_DELAY, mặc định 0.4s).

DEFAULT_MANGA_EHENTAI_URL="https://e-hentai.org"
EHENTAI_FALLBACK_BASE="https://e-hentai.org"

# Địa chỉ site (dùng chung MANGA_BASE_URL để đổi mirror được như các nguồn khác)
eh_base() {
    local b="${MANGA_BASE_URL:-}"
    case "$b" in
        ""|*nettruyen*|*truyenvn*) b="$EHENTAI_FALLBACK_BASE" ;;
    esac
    printf '%s' "${b%/}"
}

manga_is_ehentai() {
    case "${MANGA_SOURCE:-$DEFAULT_MANGA_SOURCE}" in
        ehentai|eh|e-hentai|e-hentai.org|exhentai) return 0 ;;
        *)                                          return 1 ;;
    esac
}

eh_tag() { printf '%s' "${EHENTAI_TAG:-$DEFAULT_EHENTAI_TAG}"; }

# Trang danh sách mặc định = tag tiếng Việt (đúng như yêu cầu)
eh_start_url() { printf '/tag/%s' "$(eh_tag)"; }

# Số trang ảnh gộp vào 1 "chapter" (5..100)
eh_chunk_size() {
    local n="${EHENTAI_CHUNK:-$DEFAULT_EHENTAI_CHUNK}"
    [[ "$n" =~ ^[0-9]+$ ]] || n="$DEFAULT_EHENTAI_CHUNK"
    [ "$n" -lt 5 ] && n=5
    [ "$n" -gt 100 ] && n=100
    printf '%s' "$n"
}

eh_delay() {
    local d="${EHENTAI_DELAY:-0.4}"
    [[ "$d" =~ ^[0-9]+([.][0-9]+)?$ ]] || d=0.4
    printf '%s' "$d"
}

# ─── URL ──────────────────────────────────────────────────────────────────────
eh_gallery_id() {
    printf '%s' "${1:-}" | sed -n 's#.*/g/\([0-9]\{1,\}\).*#\1#p' | head -1
}

eh_gallery_token() {
    printf '%s' "${1:-}" | sed -n 's#.*/g/[0-9]\{1,\}/\([0-9A-Za-z]\{1,\}\).*#\1#p' | head -1
}

# Chuẩn hoá "id/token", "/g/id/token/", URL gallery... -> URL gallery đầy đủ
eh_gallery_url() {
    local u="${1:-}" base
    base=$(eh_base)
    u="${u%%#*}"                      # bỏ #pN (đánh dấu nhóm trang)
    case "$u" in
        "")      return 1 ;;
        http*)   : ;;
        //*)     u="https:$u" ;;
        /g/*)    u="$base$u" ;;
        *)       u="$base/g/${u#/}" ;;   # "123/abc" hoặc "123"
    esac
    local gid tok
    gid=$(eh_gallery_id "$u")
    tok=$(eh_gallery_token "$u")
    if [ -z "$gid" ]; then
        return 1
    fi
    if [ -n "$tok" ]; then
        printf '%s/g/%s/%s/' "$base" "$gid" "$tok"
    else
        printf '%s/g/%s/' "$base" "$gid"   # web tự redirect sang URL đủ token
    fi
}

eh_is_gallery_url() {
    case "${1:-}" in
        *"/g/"[0-9]*) return 0 ;;
    esac
    return 1
}

# ─── HTTP ─────────────────────────────────────────────────────────────────────
# Tải 1 trang của e-hentai. $1 = đường dẫn (/tag/...) hoặc URL đầy đủ;
# $2.. = key=value sẽ được curl -G --data-urlencode mã hoá.
# URL đầy đủ để in ra cho người dùng thấy (path tương đối -> https://e-hentai.org/...)
eh_full_url() {
    case "${1:-}" in
        http*) printf '%s' "$1" ;;
        *)     printf '%s/%s' "$(eh_base)" "${1#/}" ;;
    esac
}

eh_fetch() {
    local path="${1:-}"
    shift 2>/dev/null || true
    [ -z "$path" ] && return 1
    local base url
    base=$(eh_base)
    case "$path" in
        http*) url="$path" ;;
        *)     url="$base/${path#/}" ;;
    esac
    local -a q=()
    local kv
    for kv in "$@"; do
        [ -n "$kv" ] && q+=(--data-urlencode "$kv")
    done
    # nw=1: bỏ qua trang cảnh báo nội dung; cookie người dùng (nếu có) để xem
    # gallery giới hạn / 18+.
    local cookie="nw=1"
    [ -n "${EHENTAI_COOKIE:-}" ] && cookie="nw=1; ${EHENTAI_COOKIE}"
    local tmp status
    tmp=$(mktemp "${TMPDIR:-/tmp}/anisub-eh.XXXXXX" 2>/dev/null) || tmp="${TMPDIR:-/tmp}/anisub-eh.$$.tmp"
    status=$(curl -sS -G -L --compressed --connect-timeout 10 --max-time 30 --retry 1 --retry-delay 1 \
        -A "${MANGA_USER_AGENT:-Mozilla/5.0}" \
        -b "$cookie" \
        -c "${MANGA_COOKIE_JAR:-/dev/null}" \
        -e "$base/" \
        -H "accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
        -H "accept-language: vi,en;q=0.8" \
        -o "$tmp" -w '%{http_code}' \
        "${q[@]}" "$url" 2>/dev/null)
    local curl_rc=$?
    MANGA_HTTP_STATUS="${status:-000}"
    printf '%s' "$MANGA_HTTP_STATUS" > "${ANISUB_STATUS_FILE:-/dev/null}" 2>/dev/null || true
    printf '%s' "$curl_rc" > "${ANISUB_CURL_ERR_FILE:-/dev/null}" 2>/dev/null || true
    case "$MANGA_HTTP_STATUS" in
        2??)
            if [ -s "$tmp" ]; then
                cat "$tmp"
                rm -f "$tmp"
                return 0
            fi
            ;;
    esac
    rm -f "$tmp"
    return 1
}

# Thông báo lỗi hay gặp của e-hentai (in ra stderr, không làm hỏng luồng)
eh_explain_error() {
    local html="${1:-}"
    case "$html" in
        *"Excessive pageloads"*)
            echo "⚠️ e-hentai tạm chặn vì tải quá nhanh (Excessive pageloads). Chờ 2-5 phút rồi thử lại." >&2 ;;
        *"temporarily banned"*|*"banned from commenting"*)
            echo "⚠️ IP của bạn đang bị e-hentai tạm khoá. Chờ vài phút (hoặc đổi mạng) rồi thử lại." >&2 ;;
        *"requires you to be logged in"*|*"not logged in"*|*"Content Warning"*)
            echo "⚠️ Gallery này cần đăng nhập/18+. Thêm cookie vào ⚙️ Cài đặt → 📚 Nguồn truyện → 🍪 Cookie e-hentai." >&2 ;;
        *"This gallery is not available"*|*"has been removed"*)
            echo "⚠️ Gallery không còn tồn tại (bị xoá hoặc sai link)." >&2 ;;
        *)
            echo "⚠️ e-hentai trả trang lạ (HTTP $(anisub_last_http)) - có thể đang bảo trì." >&2 ;;
    esac
}

# ─── PARSE ────────────────────────────────────────────────────────────────────
# HTML danh sách (tag / tìm kiếm / trang chủ) -> "Tên · N trang|URL|gid|ảnh bìa"
# Tên lấy từ alt của ảnh thumbnail (ổn định ở mọi kiểu hiển thị), ảnh bìa lấy từ
# chính thẻ <img> đó, số trang lấy trong đoạn HTML ngay sau mục (trước mục kế tiếp).
eh_parse_items() {
    EHENTAI_BASE="$(eh_base)" perl -CS -Mutf8 -0777 -ne '
        my $base = $ENV{EHENTAI_BASE} // "https://e-hentai.org"; $base =~ s{/$}{};
        sub clean {
            my $t = shift // "";
            $t =~ s/<[^>]*>/ /g;
            $t =~ s/&nbsp;/ /g; $t =~ s/&amp;/&/g; $t =~ s/&quot;/"/g;
            $t =~ s/&#39;/\x27/g; $t =~ s/&lt;/</g; $t =~ s/&gt;/>/g;
            $t =~ s/\s+/ /g; $t =~ s/^ //; $t =~ s/ $//g;
            return $t;
        }
        my (%seen, @out);
        while (m{<a\b([^>]*)>(.*?)</a>}gs) {
            my ($at, $inner) = ($1, $2);
            my ($h1, $h2) = $at =~ /href\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27)/;
            my $href = defined $h1 ? $h1 : $h2;
            next unless defined $href && $href =~ m{/g/(\d+)/([0-9A-Za-z]+)};
            my ($gid, $tok) = ($1, $2);
            next if $seen{$gid}++;
            my ($alt)  = $inner =~ /\balt\s*=\s*"([^"]*)"/;
            my ($gl, $gl2) = $inner =~ /class="glink"[^>]*>(.*?)<\//s;
            my $title = defined $alt ? $alt : "";
            $title = $gl if $title !~ /\S/ && defined $gl;
            $title = clean($title);
            # ảnh bìa: ảnh trong chính thẻ <a> (thumbnail)
            my ($cover) = $inner =~ /\b(?:data-src|src)\s*=\s*"([^"]+?(?:\.jpe?g|\.png|\.webp|\.gif)[^"]*)"/i;
            if (!defined $cover) {
                ($cover) = $inner =~ /background-image\s*:\s*url\(\s*["\x27]?([^"\x27)]+)/i;
            }
            if (defined $cover) {
                if    ($cover =~ m{^//})  { $cover = "https:$cover" }
                elsif ($cover =~ m{^/})   { $cover = "$base$cover" }
            } else { $cover = "" }
            # số trang: đoạn ngay sau mục, dừng ở gallery kế tiếp. Anchor tiêu đề
            # của CHÍNH gallery này nằm ngay sau thumbnail nên phải xoá nó trước,
            # nếu không "đoạn sau mục" sẽ rỗng và mất số trang.
            my $rest = substr($_, pos($_), 2500);
            $rest =~ s{/g/\Q$gid\E/[0-9A-Za-z]+/?}{ }g;
            my ($seg) = $rest =~ /^(.*?)(?=\/g\/\d+\/[0-9A-Za-z]+)/s;
            $seg = $rest unless defined $seg;
            my ($pages) = $seg =~ /([\d][\d.,]*)\s*pages?\b/i;
            if (defined $pages) { $pages =~ s/[.,]//g }
            my $name = $title;
            if (defined $pages && $pages =~ /^\d+$/ && $pages > 0) { $name .= " · $pages trang" }
            push @out, join("|", $name, "$base/g/$gid/$tok/", $gid, $cover);
        }
        print "$_\n" for @out;
    '
}

# HTML trang gallery -> tổng số trang ảnh (0 nếu không đọc được)
eh_parse_total_pages() {
    perl -CS -Mutf8 -0777 -ne '
        my $n = 0;
        if (m{class="gdt2"[^>]*>\s*([\d,]+)\s*pages?}i)      { $n = $1 }
        elsif (m{>\s*([\d,]+)\s*pages?\s*<}i)                { $n = $1 }
        elsif (m{([\d,]+)\s*pages}i)                         { $n = $1 }
        $n =~ s/[.,]//g if defined $n;
        print $n;
    '
}

# HTML trang gallery -> ảnh bìa (gd1/gd2 hoặc og:image)
eh_parse_cover() {
    perl -CS -Mutf8 -0777 -ne '
        my $u = "";
        if (m{id="gd[12]"(.*?)(?:id="gd[12]"|\z)}s) {
            my $blk = $1;
            ($u) = $blk =~ /\bsrc\s*=\s*"([^"]+)"/;
        }
        if (!$u && m{<meta[^>]+(?:property|name)="(?:og:image|twitter:image)"[^>]+content="([^"]+)"}i) {
            $u = $1;
        }
        print $u;
    '
}

# HTML trang gallery -> link các trang ảnh (/s/<token>/<gid>-<i>), đúng thứ tự
eh_parse_page_links() {
    EHENTAI_BASE="$(eh_base)" perl -CS -Mutf8 -0777 -ne '
        my $base = $ENV{EHENTAI_BASE} // "https://e-hentai.org"; $base =~ s{/$}{};
        my (%seen, @out);
        while (m{<a\b[^>]*href\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27)}g) {
            my $u = defined $1 ? $1 : $2;
            next unless defined $u && $u =~ m{/s/[0-9A-Za-z]+/\d+-\d+};
            $u = "$base$u" if $u =~ m{^/};
            $u = "https:$u" if $u =~ m{^//};
            next if $seen{$u}++;
            $u =~ s/#.*$//;
            push @out, $u;
        }
        print "$_\n" for @out;
    '
}

# HTML trang ảnh -> URL ảnh thật
eh_parse_image_src() {
    perl -CS -Mutf8 -0777 -ne '
        my $u = "";
        while (m{<img\b[^>]*>}g) {
            my $tag = $&;
            next unless $tag =~ /\bid\s*=\s*["\x27]?img\b/;
            ($u) = $tag =~ /\bsrc\s*=\s*"([^"]+)"/;
            ($u) = $tag =~ /\bdata-src\s*=\s*"([^"]+)"/ unless $u;
            last if $u;
        }
        if (!$u) {
            # kiểu cũ: <a id="img" href="...">
            ($u) = m{<a\b[^>]*id="img"[^>]*href="([^"]+)"}i;
        }
        if (!$u) {
            # dự phòng: ảnh lớn bất kỳ (bỏ ảnh giao diện của ehgt.org)
            while (m{(https?://[^"\x27\s>]+?\.(?:jpe?g|png|gif|webp)(?:\?[^"\x27\s>]*)?)}gi) {
                my $c = $1;
                next if $c =~ m{ehgt\.org/(?:g|img)/}i;
                next if $c =~ /(logo|favicon|blank|loading)/i;
                $u = $c; last;
            }
        }
        print $u;
    '
}

# HTML danh sách -> URL trang kế tiếp (link "Next >"), rỗng nếu hết trang
eh_parse_next() {
    EHENTAI_BASE="$(eh_base)" perl -CS -Mutf8 -0777 -ne '
        my $base = $ENV{EHENTAI_BASE} // "https://e-hentai.org"; $base =~ s{/$}{};
        while (m{<a\b[^>]*href\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27)[^>]*>(.*?)</a>}gs) {
            my ($u) = (defined $1 ? $1 : $2);
            my $txt = $3 // "";
            next unless defined $u;
            $txt =~ s/<[^>]*>//g;
            $txt =~ s/&gt;/>/g; $txt =~ s/&nbsp;/ /g;
            $txt =~ s/\s+//g;
            next unless $txt =~ /^Next>?$/i;
            $u = "$base$u" if $u =~ m{^/};
            $u = "https:$u" if $u =~ m{^//};
            print $u;
            last;
        }
    '
}

# ─── DANH SÁCH / TÌM KIẾM ────────────────────────────────────────────────────
eh_list_items() {
    local path="${1:-}"
    shift 2>/dev/null || true
    local html items
    if ! html=$(eh_fetch "$path" "$@"); then
        echo "⚠️ Không tải được $(eh_full_url "$path") (HTTP $(anisub_last_http))." >&2
        if [ "$(anisub_last_http)" = "000" ]; then
            manga_net_hint "$(eh_base)" "$(anisub_last_curl_err)" >&2
        fi
        return 1
    fi
    items=$(printf '%s' "$html" | eh_parse_items)
    if [ -z "$items" ]; then
        eh_explain_error "$html"
        echo "😶 Trang không có gallery nào (tag/sai từ khóa, hoặc web đổi cấu trúc)." >&2
        return 1
    fi
    # nhớ ảnh bìa (chạy trong subshell -> ghi file)
    printf '%s\n' "$items" | while IFS='|' read -r _n _u _g _c; do
        [ -n "${_c:-}" ] && [ -n "${_g:-}" ] && manga_cover_cache_put "$_g" "$_c"
    done
    printf '%s\n' "$items"
}

eh_search_items() {
    local kw="${1:-}"
    if [ "${#kw}" -lt 2 ]; then
        echo "💡 Gõ tối thiểu 2 ký tự để tìm trên e-hentai..." >&2
        return 1
    fi
    # Không truyền tag vào f_search (tag đã là danh sách riêng) -> tìm toàn site
    eh_list_items "/" "f_search=$kw" "f_sname=on" "f_stags=on" "f_sh=on"
}

# Menu duyệt e-hentai: phân trang bằng link "Next >" nên có menu riêng.
eh_browse_menu() {
    local url="${1:-$(eh_start_url)}" title="${2:-Truyện tiếng Việt}"
    [ -z "$url" ] && url=$(eh_start_url)
    while true; do
        clear
        echo "⏳ Đang tải: $(eh_full_url "$url")"
        local html items next n
        if ! html=$(eh_fetch "$url"); then
            echo "❌ Không tải được trang này (HTTP $(anisub_last_http))."
            if [ "$(anisub_last_http)" = "000" ]; then
                manga_net_hint "$(eh_base)" "$(anisub_last_curl_err)"
            else
                echo "   Máy chủ trả lỗi — thử lại sau, hoặc thêm cookie e-hentai trong Cài đặt."
            fi
            echo ""
            printf '   1 = chuyển sang nettruyen (truyện tranh thường) · Enter = quay lại: '
            local ch=""
            read -r -n 1 ch || true
            echo ""
            if [ "${ch:-}" = "1" ]; then
                MANGA_SOURCE="nettruyen"
                MANGA_BASE_URL="${DEFAULT_MANGA_BASE_URL:-https://nettruyen.info}"
                save_config 2>/dev/null || true
                echo "✅ Đã chuyển nguồn truyện sang nettruyen."
                sleep 1
                return 2
            fi
            return 1
        fi
        items=$(printf '%s' "$html" | eh_parse_items)
        next=$(printf '%s' "$html" | eh_parse_next)
        if [ -z "$items" ]; then
            eh_explain_error "$html"
            echo "😶 Không có gallery nào trên trang này."
            echo "   Mẹo: e-hentai có tag ít kết quả hơn -> đổi tag trong Cài đặt."
            printf 'Nhấn Enter để quay lại... '
            read -r _
            return 1
        fi
        n=$(printf '%s\n' "$items" | grep -c '.')
        printf '%s\n' "$items" | while IFS='|' read -r _nn _uu _gg _cc; do
            [ -n "${_cc:-}" ] && [ -n "${_gg:-}" ] && manga_cover_cache_put "$_gg" "$_cc"
        done
        local -a rows=()
        rows+=("$(printf '%s' "$items")")
        [ -n "$next" ] && rows+=("⏭  Trang sau|__next__|__next__|")
        rows+=("🔎 Tìm kiếm từ khóa khác|__search__|__search__|")
        rows+=("🏷  Đổi tag (danh sách có sẵn)|__tag__|__tag__|")
        local sel preview_script
        preview_script=$(manga_cover_preview_script)
        sel=$(printf '%s\n' "${rows[@]}" | fzf --prompt="📖 $title · $n truyện > " \
            --header="🌐 $(eh_base) · $url · Enter để mở · xem bìa bên phải" \
            --delimiter='|' --with-nth=1 \
            --preview "'$preview_script' {}" --preview-window='right:45%')
        case "$sel" in
            "")             return 1 ;;
            *"__next__"*)   url="$next" ; [ -z "$next" ] && url="$url" ; continue ;;
            *"__search__"*)
                local kw=""
                printf '🔍 Tìm trên e-hentai: '
                read -r kw
                [ -z "$kw" ] && continue
                url="?f_search=$kw&f_sname=on&f_stags=on&f_sh=on"
                title="Tìm: $kw"
                continue ;;
            *"__tag__"*)
                local tline
                tline=$(eh_genres | fzf --prompt="🏷 Chọn tag > " --header="e-hentai: tag càng hẹp càng ít quảng cáo/kết quả rác")
                [ -z "$tline" ] && continue
                url="/?f_search=${tline#*|}"
                title="${tline%%|*}"
                continue ;;
        esac
        manga_open_item "$sel"
        return 0
    done
}

# ─── CHAPTER (= NHÓM TRANG ẢNH) ──────────────────────────────────────────────
# Gallery -> "Trang 1–20/123|URL#p0|gid#p0" ... (tăng dần để n/p chạy đúng)
eh_fetch_chapter_list() {
    local target="${1:-}"
    local gallery
    gallery=$(eh_gallery_url "$target") || {
        echo "⚠️ Link không phải gallery e-hentai (dạng /g/<id>/<token>/)." >&2
        return 1
    }
    local html total
    if ! html=$(eh_fetch "$gallery"); then
        echo "⚠️ Không tải được gallery (HTTP $(anisub_last_http))." >&2
        return 1
    fi
    total=$(printf '%s' "$html" | eh_parse_total_pages)
    if ! [[ "$total" =~ ^[0-9]+$ ]] || [ "$total" -lt 1 ]; then
        eh_explain_error "$html"
        echo "⚠️ Không đọc được số trang của gallery này." >&2
        echo "   Mở bằng trình duyệt để xem: $gallery" >&2
        return 1
    fi
    local gid tok cover
    gid=$(eh_gallery_id "$gallery")
    tok=$(eh_gallery_token "$gallery")
    cover=$(printf '%s' "$html" | eh_parse_cover)
    if [ -n "$cover" ] && [ -n "$gid" ]; then
        manga_cover_cache_put "$gid" "$cover"
        [ -n "$tok" ] && manga_cover_cache_put "$gid/$tok" "$cover"
        MANGA_STORY_COVER="$cover"
    fi
    local size from to name
    size=$(eh_chunk_size)
    from=0
    while [ "$from" -lt "$total" ]; do
        to=$((from + size))
        [ "$to" -gt "$total" ] && to=$total
        name="Trang $((from + 1))–$to/$total"
        printf '%s|%s#p%s|%s#p%s\n' "$name" "$gallery" "$from" "$gid" "$from"
        from=$to
    done
    return 0
}

# Nhảy tới trang thứ N (Ctrl-G): N -> URL chapter chứa trang đó
eh_chapter_url() {
    local gallery n
    gallery=$(eh_gallery_url "${1:-}") || return 1
    n="${2:-1}"
    n="${n//[^0-9]/}"
    [ -z "$n" ] && return 1
    [ "$n" -lt 1 ] && n=1
    local size
    size=$(eh_chunk_size)
    local from=$(((n - 1) / size * size))
    printf '%s#p%s' "$gallery" "$from"
}

# Thư mục cache link ảnh
eh_cache_dir() {
    local d="${CACHE_DIR}/ehentai"
    mkdir -p "$d" 2>/dev/null || return 1
    printf '%s' "$d"
}

# Link các trang ảnh của gallery, lấy dần từng trang 20 thumbnail (có cache).
# $1 = URL gallery, $2 = cần ít nhất bao nhiêu link
eh_gallery_page_links() {
    local gallery="$1" need="${2:-20}"
    local gid dir
    gid=$(eh_gallery_id "$gallery")
    [ -z "$gid" ] && return 1
    dir=$(eh_cache_dir) || return 1
    local -a all=()
    local p=0 f
    while [ "${#all[@]}" -lt "$need" ] && [ "$p" -le 1000 ]; do
        f="$dir/pages-$gid-$p.tsv"
        if [ ! -s "$f" ]; then
            local html
            if ! html=$(eh_fetch "${gallery}?p=$p"); then
                [ "$p" -eq 0 ] && return 1
                break
            fi
            if printf '%s' "$html" | grep -q 'id="img"'; then
                # gallery chỉ có 1 trang: trang gallery chính là trang ảnh
                printf '%s\n' "$gallery" > "$f"
            else
                printf '%s' "$html" | eh_parse_page_links > "$f"
            fi
        fi
        local before="${#all[@]}" frag
        while IFS= read -r frag; do
            [ -n "$frag" ] || continue
            case " ${all[*]} " in *" $frag "*) continue ;; esac
            all+=("$frag")
        done < "$f"
        [ "${#all[@]}" -eq "$before" ] && break
        # trang cuối (không có gallery mới) -> dừng, tránh tải mãi
        [ "$(grep -c . "$f" 2>/dev/null || echo 0)" -eq 0 ] && break
        p=$((p + 1))
    done
    [ "${#all[@]}" -eq 0 ] && return 1
    printf '%s\n' "${all[@]}"
}

# URL ảnh thật của 1 trang ảnh (cache theo gid + số thứ tự)
eh_image_url() {
    local page="$1" gid="${2:-0}" idx="${3:-0}"
    local dir f
    dir=$(eh_cache_dir) || { printf '' ; return 1; }
    f="$dir/img-$gid-$idx.url"
    if [ -s "$f" ]; then
        head -1 "$f"
        return 0
    fi
    local html src
    if ! html=$(eh_fetch "$page"); then
        echo "⚠️ Không tải được trang ảnh $page (HTTP $(anisub_last_http))." >&2
        return 1
    fi
    src=$(printf '%s' "$html" | eh_parse_image_src)
    if [ -z "$src" ]; then
        eh_explain_error "$html"
        return 1
    fi
    printf '%s\n' "$src" > "$f" 2>/dev/null
    printf '%s\n' "$src"
}

# Chapter (nhóm trang ảnh) -> danh sách URL ảnh
eh_fetch_chapter_images() {
    local chapter_url="${1:-}"
    local gallery from gid
    gallery=$(eh_gallery_url "$chapter_url") || return 1
    gid=$(eh_gallery_id "$gallery")
    from=$(printf '%s' "$chapter_url" | sed -n 's/.*#p\([0-9]\{1,\}\)$/\1/p')
    from="${from:-0}"
    [[ "$from" =~ ^[0-9]+$ ]] || from=0
    local size to
    size=$(eh_chunk_size)
    to=$((from + size))
    local -a pages=()
    mapfile -t pages < <(eh_gallery_page_links "$gallery" "$to")
    if [ "${#pages[@]}" -eq 0 ]; then
        echo "⚠️ Không lấy được danh sách trang ảnh của gallery." >&2
        return 1
    fi
    if [ "$from" -ge "${#pages[@]}" ]; then
        echo "⚠️ Gallery chỉ có ${#pages[@]} trang ảnh (đang đòi từ trang $((from + 1)))." >&2
        echo "   Mẹo: mở lại gallery rồi chọn nhóm khác, hoặc giảm EHENTAI_CHUNK." >&2
        return 1
    fi
    local i img delay shown=0
    delay=$(eh_delay)
    for ((i = from; i < to && i < ${#pages[@]}; i++)); do
        local cached=0
        [ -s "${CACHE_DIR}/ehentai/img-$gid-$i.url" ] && cached=1
        [ "$cached" -eq 0 ] && printf '⏳ Đang lấy link ảnh %d/%d...  \r' \
            "$((i - from + 1))" "$((to - from > ${#pages[@]} - from ? ${#pages[@]} - from : to - from))" >&2
        img=$(eh_image_url "${pages[$i]}" "$gid" "$i")
        if [ -n "$img" ]; then
            printf '%s\n' "$img"
            shown=$((shown + 1))
        else
            echo "⚠️ Bỏ qua trang $((i + 1)) (${pages[$i]})" >&2
        fi
        # giãn cách giữa các request để không bị "Excessive pageloads"
        [ "$cached" -eq 0 ] && [ "$i" -lt $((to - 1)) ] && sleep "$delay"
    done
    printf '                                   \r' >&2
    [ "$shown" -eq 0 ] && return 1
    return 0
}

# ─── TAG / THỂ LOẠI ──────────────────────────────────────────────────────────
eh_genres() {
    printf '%s\n' \
        "🇻🇳 Tiếng Việt (language:vietnamese)|language:vietnamese" \
        "🇻🇳 Tiếng Việt · truyện dài (manga)|language:vietnamese manga" \
        "🇻🇳 Tiếng Việt · có màu (full color)|language:vietnamese full color" \
        "🇻🇳 Tiếng Việt · không H (non-h)|language:vietnamese non-h" \
        "🇻🇳 Tiếng Việt · đã dịch (translated)|language:vietnamese translated" \
        "🇺🇸 English (language:english)|language:english" \
        "🇨🇳 Trung (language:chinese)|language:chinese" \
        "🇯🇵 Nhật (language:japanese)|language:japanese"
}

eh_genre_menu() {
    local line tag name
    line=$(eh_genres | fzf --prompt="🏷 Chọn tag e-hentai > " \
        --header="Tag càng hẹp càng ít kết quả rác — ${EHENTAI_TAG:-$DEFAULT_EHENTAI_TAG} là mặc định")
    [ -z "$line" ] && return 1
    name="${line%%|*}"
    tag="${line#*|}"
    eh_browse_menu "/?f_search=$tag" "$name"
}

# ─── CHẨN ĐOÁN ───────────────────────────────────────────────────────────────
eh_diagnose() {
    local pause="${1:-}"
    local base tag
    base=$(eh_base)
    tag=$(eh_tag)
    echo "🩺 Chẩn đoán nguồn e-hentai"
    echo "──────────────────────────────────────────────────────────"
    echo "  Site    : $base"
    echo "  Tag mặc định : $tag (${#tag} ký tự)"
    echo "  Mỗi chapter  : $(eh_chunk_size) trang ảnh"
    if [ -n "${EHENTAI_COOKIE:-}" ]; then
        echo "  Cookie  : đã đặt (xem được gallery giới hạn/18+)"
    else
        echo "  Cookie  : chưa đặt (chỉ xem được gallery công khai)"
        echo "            thêm ở ⚙️ Cài đặt → 📚 Nguồn truyện → 🍪 Cookie e-hentai"
    fi
    echo
    echo "  1) Trang danh sách: $(eh_start_url)"
    local html items n
    if html=$(eh_fetch "$(eh_start_url)"); then
        items=$(printf '%s' "$html" | eh_parse_items)
        n=$(printf '%s\n' "$items" | grep -c '.')
        echo "     HTTP $(anisub_last_http) · parse được $n gallery"
        if [ "$n" -gt 0 ]; then
            echo "     ✅ danh sách OK"
            printf '%s\n' "$items" | head -3 | cut -d'|' -f1 | sed 's/^/        · /'
        else
            eh_explain_error "$html"
            echo "     ⚠️ HTTP OK nhưng không parse được gallery nào (web đổi cấu trúc?)"
        fi
    else
        echo "     ❌ không tải được $(eh_full_url "$(eh_start_url)") (HTTP $(anisub_last_http))"
        if [ "$(anisub_last_http)" = "000" ]; then
            manga_net_hint "$base" "$(anisub_last_curl_err)" | sed 's/^/     /'
        fi
        echo "        → mạng bị chặn, hoặc đổi domain ở Cài đặt."
        return 1
    fi
    echo
    echo "  2) Đọc thử 1 gallery"
    local sample s_name s_url chapters chap_url imgs nimg
    sample=$(printf '%s\n' "$items" | head -1)
    if [ -z "$sample" ]; then
        echo "     (bỏ qua: chưa có gallery mẫu)"
    else
        s_name=$(printf '%s' "$sample" | cut -d'|' -f1)
        s_url=$(printf '%s' "$sample" | cut -d'|' -f2)
        echo "     Gallery: $s_name"
        chapters=$(eh_fetch_chapter_list "$s_url" 2>/dev/null)
        if [ -z "$chapters" ]; then
            echo "     ❌ không đọc được số trang của gallery"
        else
            echo "     ✅ $(printf '%s\n' "$chapters" | grep -c '.') nhóm trang"
            chap_url=$(printf '%s\n' "$chapters" | head -1 | cut -d'|' -f2)
            imgs=$(EHENTAI_DELAY=0 eh_fetch_chapter_images "$chap_url" 2>/dev/null)
            nimg=$(printf '%s\n' "$imgs" | grep -c '.')
            echo "     → nhóm đầu: $nimg link ảnh"
            local first tmp_img
            first=$(printf '%s\n' "$imgs" | head -1)
            if [ -n "$first" ]; then
                tmp_img=$(mktemp "${TMPDIR:-/tmp}/anisub-diag.XXXXXX" 2>/dev/null) || tmp_img=""
                if [ -n "$tmp_img" ] && manga_download_image "$first" "$tmp_img"; then
                    echo "     ✅ tải thử ảnh đầu tiên: OK ($(du -h "$tmp_img" 2>/dev/null | cut -f1))"
                else
                    echo "     ❌ tải ảnh thất bại (IP có thể bị chặn, hoặc cần cookie)"
                fi
                [ -n "$tmp_img" ] && rm -f "$tmp_img"
            fi
        fi
    fi
    echo "──────────────────────────────────────────────────────────"
    if [ "$pause" != "--no-pause" ]; then
        printf 'Nhấn Enter để quay lại... '
        read -r _ || true
    fi
    return 0
}
