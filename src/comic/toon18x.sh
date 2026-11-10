# ═══════════════════════════════════════════════════════════════════════════════
# NGUỒN TRUYỆN: TOON18X (toon18x.com) — nội dung 18+
# ═══════════════════════════════════════════════════════════════════════════════
# Site webtoon/manhwa 18+ có bản tiếng Việt (/vi), render sẵn ở server nên đọc
# được bằng curl thường (không cần JS). Những gì anisub dùng:
#
#   Trang chủ    : /vi                     (truyện nổi bật + mới cập nhật)
#   Duyệt/tìm    : /vi/search?q=<kw>&sort=updated|newest|views|rating|followers|random&page=N
#   Trang truyện : /vi/manga/<slug>
#   Trang đọc    : /vi/manga/<slug>/chapter/<số>
#   Danh sách    : GET /api/v1/manga/<slug>/chapters?page=1&limit=200  (JSON, mới nhất trước)
#   Ảnh bìa      : https://cdn.toon18x.com/covers/<slug>.webp
#   Ảnh trang    : https://tv1.toon18x.com/series/<slug>/ch-<0000>/[scrapes/<uuid>/]<trang>.png
#
# Lưu ý khi sửa file này:
#   * URL chương suy ra được từ số chương (/chapter/<số>) nên Ctrl-G và lịch sử
#     luôn hoạt động kể cả khi danh sách chương lỗi.
#   * Danh sách chương lấy từ API (trang truyện chỉ in 20 chương mới nhất);
#     API không trả metadata phân trang -> tải tới khi số dòng < limit.
#   * Ảnh nằm trên host riêng tv1./cdn. nên tải ảnh dùng lượt thử 2 của
#     manga_download_image (kèm Referer) là đủ.

# Đánh dấu module đã nạp (menu nguồn truyện dựa vào đây để biết bộ src/ có nguồn này)
TOON18X_MODULE=1

# ─── NHẬN DIỆN NGUỒN ───────────────────────────────────────────────────────────
manga_is_toon18x() {
    case "${MANGA_SOURCE:-$DEFAULT_MANGA_SOURCE}" in
        toon18x|t18x|toon18|toon18x.com) return 0 ;;
        *)                               return 1 ;;
    esac
}

# Gốc site (không có /vi, không có "/" cuối) - dùng cho API và mọi path trang
tx_base() {
    local b="${MANGA_BASE_URL:-${DEFAULT_TOON18X_BASE_URL:-https://toon18x.com}}"
    case "$b" in
        http://*|https://*) : ;;
        "")                 b="https://toon18x.com" ;;
        *)                  b="https://$b" ;;
    esac
    b="${b%/}"
    local loc; loc=$(_tx_locale)
    case "$b" in */"$loc") b="${b%/*}" ;; esac    # người dùng dán kèm /vi thì bỏ ra
    printf '%s' "${b%/}"
}

# Mã ngôn ngữ trên URL (/vi, /en ...)
_tx_locale() {
    local l="${TOON18X_LOCALE:-${DEFAULT_TOON18X_LOCALE:-vi}}"
    case "$l" in
        ""|*[!a-z]*) l="vi" ;;
    esac
    printf '%s' "$l"
}

tx_host() {
    local h; h=$(tx_base); h="${h#*://}"
    printf '%s' "${h%%/*}"
}

# ─── NHẬN DIỆN SLUG / URL ────────────────────────────────────────────────────
# slug truyện: phần ngay sau /manga/ (bỏ /chapter/<số> nếu là link đọc)
tx_slug() {
    local v="${1:-}"
    v="${v%%\?*}"; v="${v%%#*}"; v="${v%/}"
    case "$v" in
        */manga/*)
            v="${v#*/manga/}"
            printf '%s' "${v%%/*}"
            return 0 ;;
    esac
    printf '%s' "${v##*/}"
}

# URL trang truyện từ slug / URL bất kỳ
tx_manga_url() {
    local v="${1:-}"
    case "$v" in
        http://*|https://*)
            # link đọc -> trang truyện (giữ nguyên host/ngôn ngữ người dùng dán)
            case "$v" in
                */manga/*) printf '%s/manga/%s' "${v%%/manga/*}" "$(tx_slug "$v")"; return 0 ;;
            esac
            printf '%s' "${v%%\?*}"
            return 0 ;;
    esac
    local slug
    slug=$(tx_slug "$v")
    [ -n "$slug" ] || return 1
    printf '%s/%s/manga/%s' "$(tx_base)" "$(_tx_locale)" "$slug"
}

# Số chương -> URL đọc (suy trực tiếp từ số, không cần danh sách)
tx_chapter_url() {
    local page_url="$1" num="$2"
    num="${num//[^0-9.]/}"
    [ -n "$num" ] || return 1
    page_url=$(tx_manga_url "$page_url")
    [ -n "$page_url" ] || return 1
    printf '%s/chapter/%s' "${page_url%/}" "$num"
}

# ─── PARSE DANH SÁCH TRUYỆN (HTML) ───────────────────────────────────────────
# -> "Tên|URL truyện|slug|ảnh bìa"
tx_parse_items() {
    TX_BASE="$(tx_base)" TX_LOCALE="$(_tx_locale)" perl -CS -Mutf8 -0777 -ne '
        my $base = $ENV{TX_BASE} // ""; $base =~ s{/$}{};
        my $loc  = $ENV{TX_LOCALE} // "vi";
        sub clean {
            my $t = shift // "";
            $t =~ s/<[^>]*>/ /g;
            $t =~ s/&nbsp;/ /g;
            $t =~ s/&amp;/&/g;
            $t =~ s/&quot;/"/g;
            $t =~ s/&#0?39;|&apos;/chr(39)/ge;
            $t =~ s/&lt;/</g;
            $t =~ s/&gt;/>/g;
            $t =~ s/&hellip;/.../g;
            $t =~ s/^\s+//; $t =~ s/\s+$//;
            $t =~ s/\s+/ /g;
            return $t;
        }
        # link truyện: .../[<mã ngôn ngữ>/]manga/<slug> (KHÔNG có /chapter/ phía sau)
        my @hits;
        while (m{<a\b[^>]*?href="(?:https?:)?//[^"/]+(?:/[a-z]{2})?/manga/([A-Za-z0-9._~%-]+)(?:[?#][^"]*)?"[^>]*>(.*?)</a>}gs) {
            push @hits, { slug => $1, inner => $2, stop => $+[0] };
        }
        my (@order, %item);
        my $prev = 0;
        for my $h (@hits) {
            # vùng HTML từ cuối link trước tới cuối link này: chứa cả ảnh bìa
            # (bìa thường nằm trong <a> bao ngoài, trước tên truyện)
            my $region = substr($_, $prev, $h->{stop} - $prev);
            $prev = $h->{stop};
            my $cover = "";
            while ($region =~ m{(?:https?:)?//[^"\s]*?/(?:covers|images)/[^"\s]+?[.](?:webp|jpe?g|png|avif)}gi) {
                $cover = $&;
            }
            $cover = "https:$cover" if $cover =~ m{^//};
            my $slug = $h->{slug};
            my $name = clean($h->{inner});
            if (!exists $item{$slug}) {
                push @order, $slug;
                $item{$slug} = { name => "", cover => "" };
            }
            $item{$slug}{name}  = $name  if length $name;
            $item{$slug}{cover} = $cover if length $cover;
        }
        for my $slug (@order) {
            my $name = $item{$slug}{name};
            if (!length $name) {
                ($name = $slug) =~ s/[-_]+/ /g;
                $name =~ s/\b(\w)/\u$1/g;
            }
            print "$name|$base/$loc/manga/$slug|$slug|$item{$slug}{cover}\n";
        }
    '
}


# ─── DANH SÁCH / TÌM KIẾM ────────────────────────────────────────────────────
# $1 = path (/vi hoặc /vi/search), $2.. = tham số (q=, sort=, page=)
tx_list_items() {
    local path="${1:-/vi}"
    shift 2>/dev/null || true
    local kv
    local -a params=()
    local sort="" q="" page=""
    for kv in "$@"; do
        case "$kv" in
            sort=*) sort="${kv#sort=}" ;;
            q=*)    q="${kv#q=}" ;;
            page=*) page="${kv#page=}" ;;
        esac
    done
    case "$sort" in
        ""|latest|updated|newest|views|rating|followers|random) : ;;
        trending|hot) sort="followers" ;;
        *)           sort="updated" ;;
    esac
    [ -n "$q" ]    && params+=("q=$q")
    [ -n "$sort" ] && params+=("sort=$sort")
    case "$page" in
        ""|0|1) : ;;
        *[!0-9]*) : ;;
        *) params+=("page=$page") ;;
    esac
    local html
    if ! html=$(manga_http_fetch "$path" "${params[@]}"); then
        echo "⚠️ Không tải được $path (HTTP $(anisub_last_http)) - kiểm tra mạng hoặc MANGA_BASE_URL" >&2
        return 1
    fi
    local items
    items=$(printf '%s' "$html" | tx_parse_items)
    if [ -z "$items" ]; then
        echo "⚠️ Toon18x trả trang nhưng không có truyện nào (site đổi cấu trúc HTML?)" >&2
        return 1
    fi
    printf '%s\n' "$items" | while IFS='|' read -r _n _u _s _c; do
        [ -n "${_c:-}" ] && [ -n "${_s:-}" ] && manga_cover_cache_put "$_s" "$_c"
    done
    printf '%s\n' "$items"
}

tx_search_items() {
    local kw="${1:-}"
    tx_list_items "/$(_tx_locale)/search" "q=$kw"
}

# ─── DANH SÁCH CHƯƠNG (API) ──────────────────────────────────────────────────
# GET /api/v1/manga/<slug>/chapters?page=N&limit=200 -> {"data":[{chapter_number,title,...}]}
# API không nói tổng số trang -> tải tiếp khi còn đủ `limit` dòng (tối đa 10 trang).
tx_fetch_chapter_list() {
    local target="$1"
    local slug
    slug=$(tx_slug "$target")
    if [ -z "$slug" ]; then
        echo "⚠️ Không đọc được slug truyện Toon18x từ \"$target\"." >&2
        echo "   Dán link dạng https://toon18x.com/vi/manga/<slug> để chắc chắn đúng." >&2
        return 1
    fi
    if ! command -v jq > /dev/null 2>&1; then
        echo "⚠️ Toon18x cần jq để đọc API danh sách chương (cài: sudo apt install jq)" >&2
        return 1
    fi
    local base loc page=1 limit=200 chunk rows=0 got=0 tmp
    base=$(tx_base); loc=$(_tx_locale)
    tmp=$(mktemp "${TMPDIR:-/tmp}/anisub-tx.XXXXXX" 2>/dev/null) || tmp="${TMPDIR:-/tmp}/anisub-tx.$$.list"
    : > "$tmp" 2>/dev/null || return 1
    while [ "$page" -le 10 ]; do
        if ! chunk=$(manga_http_fetch "$base/api/v1/manga/$slug/chapters?page=$page&limit=$limit"); then
            # trang 2 trở đi lỗi thì vẫn dùng phần đã có; lỗi ngay trang 1 thì báo
            if [ "$page" -eq 1 ]; then
                echo "⚠️ API Toon18x lỗi (HTTP $(anisub_last_http)) khi lấy danh sách chương." >&2
                rm -f "$tmp" 2>/dev/null
                return 1
            fi
            break
        fi
        rows=$(printf '%s' "$chunk" | jq -r '.data // [] | length' 2>/dev/null)
        case "$rows" in ''|*[!0-9]*) rows=0 ;; esac
        [ "$rows" -eq 0 ] && break
        printf '%s' "$chunk" | jq -r --arg base "$base" --arg loc "$loc" --arg slug "$slug" '
            (.data // [])[]
            | (.chapter_number | tostring) as $n
            | select($n | test("^-?[0-9]+([.][0-9]+)?$"))
            | "Chương \($n)|\($base)/\($loc)/manga/\($slug)/chapter/\($n)|\($n)"
        ' >> "$tmp" 2>/dev/null
        got=$((got + rows))
        [ "$rows" -lt "$limit" ] && break
        page=$((page + 1))
    done
    if [ ! -s "$tmp" ]; then
        echo "⚠️ API Toon18x không trả chương nào cho truyện $slug." >&2
        rm -f "$tmp" 2>/dev/null
        return 1
    fi
    awk -F'|' '!seen[$2]++' "$tmp" | sort -s -t'|' -k3,3V
    rm -f "$tmp" 2>/dev/null
    # ảnh bìa: ưu tiên ảnh đã cache khi duyệt danh sách, chưa có thì lấy từ trang truyện
    local cover
    cover=$(manga_cover_cache_get "$slug" 2>/dev/null)
    if [ -z "$cover" ]; then
        local html
        html=$(manga_http_fetch "$(tx_manga_url "$slug")" 2>/dev/null) || html=""
        [ -n "$html" ] && cover=$(printf '%s' "$html" | manga_page_cover)
        [ -z "$cover" ] && cover="https://cdn.toon18x.com/covers/${slug}.webp"
        manga_cover_cache_put "$slug" "$cover"
    fi
    MANGA_STORY_COVER="$cover"
}

# ─── ẢNH TRANG ĐỌC ──────────────────────────────────────────────────────────
# HTML trang đọc có sẵn mọi <img src="https://tv1.toon18x.com/.../<trang>.png">
tx_parse_image_urls() {
    perl -CS -Mutf8 -0777 -ne '
        my $doc = $_;
        $doc =~ s{\\+/}{/}g;                       # bỏ escape trong JSON: \/ (hoặc \\/) -> /
        my (%page, @other);
        while ($doc =~ m{((?:https?:)?//[A-Za-z0-9._-]*toon18x\.com/[^"\x27\s<>\\]+?\.(?:png|jpe?g|webp|avif))}gi) {
            my $u = $1;
            next if $u =~ m{/(?:covers|avatars|icons?)/}i;
            $u = "https:$u" if $u =~ m{^//};
            if ($u =~ m{/(\d+)\.(?:png|jpe?g|webp|avif)$}i) {
                $page{$1 + 0} = $u unless exists $page{$1 + 0};
            } elsif ($u !~ m{/(?:logo|banner|cover|thumb)}i) {
                push @other, $u;
            }
        }
        print "$page{$_}\n" for sort { $a <=> $b } keys %page;
        if (!%page) { my %s; print "$_\n" for grep { !$s{$_}++ } @other; }
    '
}

tx_fetch_chapter_images() {
    local chapter_url="${1:-}"
    [ -z "$chapter_url" ] && return 1
    rm -f "$ANISUB_MANGA_NAV_FILE" 2>/dev/null   # không dùng link chuyển chap của chapter cũ
    local html
    if ! html=$(manga_http_fetch "$chapter_url"); then
        echo "⚠️ Không tải được trang đọc Toon18x (HTTP $(anisub_last_http))." >&2
        if [ "$(anisub_last_http)" = "000" ] && declare -F manga_net_hint > /dev/null 2>&1; then
            manga_net_hint "$(tx_base)" "$(anisub_last_curl_err 2>/dev/null)" | sed 's/^/   /' >&2
        fi
        return 1
    fi
    # Nhớ "Chương trước/Chương sau" để reader chuyển chap được kể cả khi danh sách lỗi
    local nav nav_prev nav_next
    nav=$(printf '%s' "$html" | manga_parse_nav 2>/dev/null)
    if [ -n "$nav" ]; then
        nav_prev="${nav%%|*}"
        nav_next="${nav##*|}"
        [ -n "$nav_prev" ] && nav_prev=$(manga_abs_url "$nav_prev")
        [ -n "$nav_next" ] && nav_next=$(manga_abs_url "$nav_next")
        printf '%s|%s\n' "$nav_prev" "$nav_next" > "$ANISUB_MANGA_NAV_FILE" 2>/dev/null
    fi
    local found
    found=$(printf '%s' "$html" | tx_parse_image_urls)
    if [ -z "$found" ]; then
        echo "⚠️ Trang đọc không có ảnh nào - site đổi cấu trúc hoặc chương chưa có ảnh." >&2
        echo "   Mở trực tiếp: $chapter_url" >&2
        return 1
    fi
    printf '%s\n' "$found"
}

# ─── THỂ LOẠI (tìm theo từ khoá) ─────────────────────────────────────────────
# Trang lọc của site nằm trong form /search chứ không có route /the-loai/<slug>,
# nên "thể loại" = tìm theo từ khoá quen thuộc (giống cách làm với Kagane).
tx_genres() {
    printf '%s\n' \
        "💥 Hành động|action" \
        "❤️ Lãng mạn|romance" \
        "🧚 Fantasy|fantasy" \
        "🎭 Chính kịch|drama" \
        "😂 Hài hước|comedy" \
        "🏫 Học đường|school" \
        "🔍 Bí ẩn|mystery" \
        "👻 Kinh dị|horror" \
        "⚔️ Võ hiệp / Murim|murim" \
        "🌏 Isekai|isekai" \
        "🩸 Báo thù|revenge" \
        "🏢 Đời thường|slice of life" \
        "👑 Harem|harem" \
        "🧛 Siêu nhiên|supernatural" \
        "🔞 18+ (toàn bộ)|" 
}

tx_genre_menu() {
    local gline gname gkw
    gline=$(tx_genres | fzf --prompt="🗂 Chọn thể loại (Toon18x) > " \
        --header="Toon18x không có slug thể loại trên URL - anisub tìm theo từ khoá tương ứng")
    [ -z "$gline" ] && return 1
    gname=$(printf '%s' "$gline" | cut -d'|' -f1)
    gkw=$(printf '%s' "$gline" | cut -d'|' -f2)
    if [ -n "$gkw" ]; then
        manga_browse_menu "/$(_tx_locale)/search" "$gname (Toon18x)" "q=$gkw"
    else
        manga_browse_menu "/$(_tx_locale)/search" "$gname" "sort=views"
    fi
}

# ─── CHẨN ĐOÁN ───────────────────────────────────────────────────────────────
tx_diagnose() {
    local pause="${1:-}"
    local base; base=$(tx_base)
    echo "🩺 Chẩn đoán nguồn truyện tranh (toon18x)"
    echo "──────────────────────────────────────────────────────────"
    echo "  Nguồn   : $base/$(_tx_locale)  (nội dung 18+)"
    echo "  API     : $base/api/v1/manga/<slug>/chapters"
    if declare -F manga_image_protocol > /dev/null 2>&1; then
        echo "  Vẽ ảnh  : ${MANGA_IMAGE_PROTOCOL:-auto} (đang dùng: $(manga_image_protocol))"
    fi

    local html n
    html=$(manga_http_fetch "/$(_tx_locale)/search" "sort=updated" 2>/dev/null) || html=""
    if [ -n "$html" ]; then
        n=$(printf '%s' "$html" | tx_parse_items | grep -c '.')
        echo "  → /$(_tx_locale)/search: HTTP $(anisub_last_http) · parse được $n truyện"
        if [ "$n" -gt 0 ]; then
            echo "     ✅ Duyệt/tìm truyện dùng được"
        else
            echo "     ⚠️ HTTP OK nhưng không parse được mục nào - site đổi cấu trúc HTML"
        fi
    else
        echo "  ❌ không tải được $base/$(_tx_locale)/search (HTTP $(anisub_last_http))"
        if declare -F manga_net_hint > /dev/null 2>&1; then
            manga_net_hint "$base" "$(anisub_last_curl_err 2>/dev/null)" | sed 's/^/  /'
        fi
    fi

    echo ""
    local sample slug chapters
    sample=$(printf '%s' "${html:-}" | tx_parse_items 2>/dev/null | head -1)
    slug=$(printf '%s' "$sample" | cut -d'|' -f3)
    if [ -z "$slug" ]; then
        echo "  (bỏ qua phần API: chưa lấy được truyện mẫu)"
    else
        echo "  Truyện mẫu: $(printf '%s' "$sample" | cut -d'|' -f1)"
        if chapters=$(tx_fetch_chapter_list "$slug" 2>/dev/null); then
            echo "  ✓ API chương     : $(printf '%s\n' "$chapters" | grep -c '.') chương (HTTP $(anisub_last_http))"
            local first_chap
            first_chap=$(printf '%s\n' "$chapters" | head -1 | cut -d'|' -f2)
            if [ -n "$first_chap" ]; then
                local imgs
                imgs=$(tx_fetch_chapter_images "$first_chap" 2>/dev/null | head -3)
                echo "  → chapter đầu ($(printf '%s\n' "$chapters" | head -1 | cut -d'|' -f1)): $(printf '%s\n' "$imgs" | grep -c '.') ảnh (3 ảnh đầu)"
            fi
        else
            echo "  ✗ API chương     : HTTP $(anisub_last_http)"
        fi
    fi

    echo ""
    if [ -n "$pause" ] && [ "$pause" != "--no-pause" ]; then
        echo "Nhấn Enter để tiếp tục..."; read -r _
    fi
    return 0
}
