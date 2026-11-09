# ═══════════════════════════════════════════════════════════════════════════════
# TRUYỆN TRANH: ENGINE ĐỌC TRUYỆN (dùng chung cho mọi nguồn)
# ═══════════════════════════════════════════════════════════════════════════════
# Gồm: HTTP + cookie, cache ảnh bìa, đoán/ghép URL, tải & vẽ ảnh trong terminal
# (chafa), khung đọc (fzf preview + cuộn liên tục), lịch sử/yêu thích truyện,
# các menu duyệt/tìm/chẩn đoán và phần "định tuyến" theo nguồn đang chọn.
# Mỗi nguồn truyện nằm trong 1 file riêng (nettruyen.sh, truyenvn.sh, ehentai.sh)
# và chỉ cần cung cấp: hàm tìm kiếm, danh sách chapter, danh sách ảnh.

MANGA_BASE_URL="${MANGA_BASE_URL:-}"
# Ảnh bìa được nhớ theo slug để preview trong fzf (ghi file vì chạy trong subshell)
MANGA_COVER_CACHE="${CACHE_DIR}/manga-covers"

# Mã HTTP của lời gọi API gần nhất (đọc xuyên subshell)
anisub_last_http() {
    local s="${KKPHIM_HTTP_STATUS:-}"
    if { [ -z "$s" ] || [ "$s" = "000" ]; } && [ -r "$ANISUB_STATUS_FILE" ]; then
        s=$(head -c 3 "$ANISUB_STATUS_FILE" 2>/dev/null)
    fi
    printf '%s' "${s:-000}"
}

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
    if   manga_is_ehentai;   then printf 'e-hentai'
    elif manga_is_nettruyen; then printf 'nettruyen'
    else                          printf 'TruyenVN'
    fi
}

# Nguồn TruyenVN (Madara) - dùng cho phần cần API/CSRF riêng của nó
manga_is_truyenvn() {
    case "${MANGA_SOURCE:-$DEFAULT_MANGA_SOURCE}" in
        nettruyen|nt|nettruyen.info|ehentai|eh|e-hentai|e-hentai.org|exhentai) return 1 ;;
        *)                                                                     return 0 ;;
    esac
}

# Số chapter -> URL chương của nguồn đang dùng
manga_chapter_url() {
    local page_url="$1" num="$2"
    if manga_is_ehentai; then
        eh_chapter_url "$page_url" "$num"
        return $?
    fi
    num="${num//[^0-9.]/}"
    [ -z "$num" ] && return 1
    if manga_is_nettruyen; then
        printf '%s/chuong-%s' "${page_url%/}" "$num"
    else
        printf '%s/chapter-%s' "${page_url%/}" "${num//./-}"
    fi
}

# URL trang truyện từ slug (hoặc trả nguyên URL nếu đã là URL tuyệt đối)
manga_manga_url() {
    local base="${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
    if manga_is_ehentai; then
        eh_gallery_url "${1:-}"
        return $?
    fi
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

# "Slug" của truyện từ URL trang truyện: nguồn thường là phần cuối URL, riêng
# e-hentai cần cả <id>/<token> để mở lại từ lịch sử / yêu thích.
manga_slug_from_url() {
    local url="${1:-}"
    if manga_is_ehentai; then
        local g t
        g=$(eh_gallery_id "$url")
        t=$(eh_gallery_token "$url")
        if [ -n "$g" ] && [ -n "$t" ]; then
            printf '%s/%s' "$g" "$t"
            return 0
        fi
        [ -n "$g" ] && { printf '%s' "$g"; return 0; }
    fi
    local u="${url%/}"
    printf '%s' "${u##*/}"
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
    if   manga_is_ehentai;   then eh_parse_items
    elif manga_is_nettruyen; then nt_parse_items
    else                          manga_parse_items_pp
    fi
}

# Tải 1 danh sách của TruyenVN -> "Tên|URL|slug"
# $1 = path (bắt đầu bằng /) hoặc URL tuyệt đối, $2.. = key=value
manga_list_items() {
    local path="$1"
    shift
    if manga_is_ehentai; then
        eh_list_items "$path" "$@"
        return $?
    fi
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
    if manga_is_ehentai; then
        eh_search_items "$kw"
        return $?
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
    if manga_is_ehentai; then
        eh_fetch_chapter_list "$target"
        return $?
    fi
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

# --- FETCH CHAPTER IMAGES ---
# Lấy URL ảnh của 1 chapter. Không phụ thuộc tên class: tìm mọi URL ảnh trong
# trang (thuộc tính src/data-src của <img>, hoặc mảng JSON dạng chapterImages),
# loại ảnh phụ (logo/avatar/cover/thumb), rồi ưu tiên ảnh có chứa slug truyện.
fetch_chapter_images() {
    local chapter_url="$1"
    local prefer_slug="${2:-}"
    [ -z "$chapter_url" ] && return 1
    if manga_is_ehentai || eh_is_gallery_url "$chapter_url"; then
        eh_fetch_chapter_images "$chapter_url" "$prefer_slug"
        return $?
    fi
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
    # Dọn dẹp khi thoát, nhưng phải KHÔI PHỤC trap cũ ngay sau đó: trap EXIT toàn cục
    # giữ PID/cache cũ, lần xem sau có thể kill nhầm tiến trình khác hoặc xoá nhầm cache.
    local old_exit_trap
    old_exit_trap=$(trap -p EXIT)
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

    # 5. Dọn cache + trả lại trap cũ
    kill "$prefetch_pid" 2>/dev/null
    rm -rf "$cache_dir"
    if [ -n "$old_exit_trap" ]; then
        eval "$old_exit_trap"
    else
        trap - EXIT
    fi
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
    if manga_is_ehentai; then
        # e-hentai: mẫu = gallery đầu tiên của danh sách tag đang dùng
        target="${1:-}"
        if [ -z "$target" ]; then
            target=$(eh_list_items "$(eh_start_url)" 2>/dev/null | head -1 | cut -d'|' -f2)
            [ -z "$target" ] && { echo "❌ Không lấy được gallery mẫu từ $(eh_start_url) — dán link gallery: ./anisub.sh --manga-selftest <link>"; return 1; }
        fi
    fi
    local base="${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
    echo "🧪 KIỂM TRA ĐỌC TRUYỆN"
    echo "   anisub: $ANISUB_VERSION · nguồn: ${MANGA_SOURCE:-$DEFAULT_MANGA_SOURCE} ($base) · ảnh: ${MANGA_IMAGE_PROTOCOL:-auto}"
    echo ""

    local page_url
    page_url=$(manga_manga_url "$target")
    local slug
    slug=$(manga_slug_from_url "$page_url")
    echo "1️⃣  Trang truyện: $page_url"
    local html http
    if manga_is_ehentai; then
        html=$(eh_fetch "$page_url")
    else
        html=$(manga_http_fetch "$page_url")
    fi
    http=$(anisub_last_http)
    echo "    HTTP $http · $(printf '%s' "$html" | wc -c | tr -d ' ') byte"
    if [ -z "$html" ]; then
        echo "    ❌ Không tải được trang truyện."
        echo "       → Kiểm tra mạng, hoặc MANGA_BASE_URL đã đổi tên miền."
        return 1
    fi
    if manga_is_truyenvn; then
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
    # e-hentai: mỗi "chapter" là 1 nhóm trang ảnh -> lấy nhóm đầu cho nhanh
    manga_is_ehentai && chap_url=$(printf '%s\n' "$chapters" | head -1 | cut -d'|' -f2)
    [ -z "$chap_url" ] && chap_url=$(manga_chapter_url "$page_url" 1)
    echo "3️⃣  Trang chapter: $chap_url"
    local imgs nimg nav
    imgs=$(fetch_chapter_images "$chap_url" "$slug")
    nimg=$(printf '%s\n' "$imgs" | grep -c '.')
    nav=$(manga_saved_nav)
    # bỏ qua nav còn sót lại từ nguồn khác (đổi nguồn thì link kiểu cũ vô nghĩa)
    if manga_is_nettruyen; then
        case "$nav" in *chuong-*) : ;; *) nav="" ;; esac
    elif manga_is_truyenvn; then
        case "$nav" in *"/chapter-"*) : ;; *) nav="" ;; esac
    else
        nav=""      # e-hentai không có link chap trước/sau kiểu này
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
    local slug
    slug=$(manga_slug_from_url "$page_url")
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
    if [ "$count" -le 2 ] && ! manga_is_ehentai; then
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
    if manga_is_ehentai; then
        eh_browse_menu "$(eh_start_url)" "Truyện tiếng Việt (mới cập nhật)"
    elif manga_is_nettruyen; then
        manga_browse_menu "/" "Truyện mới cập nhật"
    else
        manga_browse_menu "/tim-kiem" "Truyện mới cập nhật" "m_orderby=latest"
    fi
}

manga_browse_hot() {
    if manga_is_ehentai; then
        eh_browse_menu "/?f_search=$(eh_tag)&f_srdd=4" "Tiếng Việt · điểm ≥ 4★"
    elif manga_is_nettruyen; then
        manga_browse_menu "/truyen-tranh-hot" "Truyện hot"
    else
        manga_browse_menu "/tim-kiem" "Truyện hot" "m_orderby=trending"
    fi
}

manga_browse_views() {
    if manga_is_ehentai; then
        eh_browse_menu "/?f_search=$(eh_tag)&f_srdd=5" "Tiếng Việt · điểm tối đa"
    elif manga_is_nettruyen; then
        manga_browse_menu "/the-loai/hot" "Truyện đọc nhiều"
    else
        manga_browse_menu "/tim-kiem" "Truyện đọc nhiều" "m_orderby=views"
    fi
}

manga_genres() {
    if manga_is_ehentai; then
        eh_genres
        return 0
    fi
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
    if manga_is_ehentai; then
        eh_genre_menu
        return $?
    fi
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
# $1 = "--no-pause" nếu gọi từ --doctor (không chờ Enter)
manga_diagnose() {
    local pause="${1:-}"
    if manga_is_ehentai; then
        eh_diagnose "$pause"
        return $?
    fi
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
    if [ "$pause" != "--no-pause" ]; then
        printf 'Nhấn Enter để quay lại... '
        read -r _ || true
    fi
    return 0
}

# Cấu hình riêng cho nguồn truyện
show_manga_settings() {
    local opt inp
    while true; do
        opt=$(echo -e "🩺 Kiểm tra nguồn truyện\n🧪 Kiểm tra đọc truyện (chẩn đoán)\n🔁 Đổi nguồn truyện (nettruyen / truyenvn / e-hentai)\n🛡 Dịch vụ đọc hộ khi bị chặn: ${MANGA_READER_PROXY:-tắt}\n🌐 Trang web nguồn: ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}\n🔎 Danh sách dùng khi tìm kiếm: ${MANGA_SEARCH_FEEDS:-$DEFAULT_MANGA_SEARCH_FEEDS}\n📄 Số trang tải cho mỗi danh sách: ${MANGA_SEARCH_PAGES:-$DEFAULT_MANGA_SEARCH_PAGES}\n🏷 Tag mặc định (e-hentai): ${EHENTAI_TAG:-$DEFAULT_EHENTAI_TAG}\n🍪 Cookie e-hentai: $([ -n "${EHENTAI_COOKIE:-}" ] && echo 'đã đặt' || echo 'chưa đặt (chỉ gallery công khai)')\n🔢 Số trang ảnh mỗi chapter (e-hentai): ${EHENTAI_CHUNK:-$DEFAULT_EHENTAI_CHUNK}\n🖼️ Kiểu hiển thị ảnh: ${MANGA_IMAGE_PROTOCOL:-$DEFAULT_MANGA_IMAGE_PROTOCOL} (đang dùng: $(manga_image_protocol))\n🔙 Quay lại" \
            | fzf --prompt="📚 Nguồn truyện ($(manga_source_label)) > " --header="$(manga_source_label): ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}")
        case "$opt" in
            *"Đổi nguồn truyện"*)
                clear
                echo "🔁 ĐỔI NGUỒN TRUYỆN TRANH"
                echo "  Đang dùng: $(manga_source_label) - ${MANGA_BASE_URL:-$DEFAULT_MANGA_BASE_URL}"
                echo ""
                echo "  1) nettruyen  (https://nettruyen.info)  - mặc định, ảnh nhanh, đủ truyện"
                echo "  2) truyenvn   (https://truyenvn.my)     - nguồn cũ (cần API chapter)"
                echo "  3) e-hentai   (https://e-hentai.org)    - gallery ảnh, mặc định xem tag"
                echo "     $(eh_tag)  (nội dung 18+, cần cookie nếu gallery giới hạn)"
                echo ""
                read -r -p "Chọn nguồn (1/2/3, Enter = giữ nguyên): " inp
                case "${inp:-}" in
                    1) MANGA_SOURCE="nettruyen"; MANGA_BASE_URL="https://nettruyen.info" ;;
                    2) MANGA_SOURCE="truyenvn";  MANGA_BASE_URL="https://truyenvn.my" ;;
                    3) MANGA_SOURCE="ehentai";   MANGA_BASE_URL="$DEFAULT_MANGA_EHENTAI_URL"
                       echo "   ⚠️ e-hentai có nội dung người lớn (18+). Bạn tự chịu trách nhiệm khi xem." ;;
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
                manga_is_ehentai && st_def="(gallery đầu tiên của tag $(eh_tag))"
                printf '🧪 Nhập slug hoặc link truyện (Enter = %s): ' "$st_def"
                manga_is_ehentai && st_def=""
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
            *"Tag mặc định (e-hentai)"*)
                echo "🏷 Tag dùng cho danh sách mặc định của e-hentai."
                echo "   Ví dụ: language:vietnamese · language:vietnamese manga · language:english"
                echo "   (xem thêm ở 🗂 Theo thể loại sau khi chọn nguồn e-hentai)"
                read -r -p "Tag (Enter = giữ nguyên ${EHENTAI_TAG:-$DEFAULT_EHENTAI_TAG}): " inp
                if [ -n "$inp" ]; then
                    EHENTAI_TAG="$(printf '%s' "$inp" | sed 's/^ *//; s/ *$//')"
                    save_config
                    echo "✅ Đã lưu: $EHENTAI_TAG"
                    sleep 1.2
                fi ;;
            *"Cookie e-hentai"*)
                clear
                echo "🍪 COOKIE E-HENTAI (chỉ cần khi gallery báo cần đăng nhập / 18+)"
                echo "   Cách lấy: đăng nhập e-hentai.org bằng trình duyệt → F12 → Network →"
                echo "   chọn 1 request → copy nguyên dòng 'cookie' (thường có ipb_member_id=...;"
                echo "   ipb_pass_hash=...; sk=...). Dán vào đây."
                echo "   Đang có: $([ -n "${EHENTAI_COOKIE:-}" ] && echo 'đã đặt' || echo 'chưa đặt')"
                read -r -p "Cookie (Enter = giữ nguyên, 'xoa' = xóa): " inp
                case "${inp:-}" in
                    "")            : ;;
                    xoa|Xoa|XOA|delete|x) EHENTAI_COOKIE="" ;;
                    *)             EHENTAI_COOKIE="$inp" ;;
                esac
                save_config
                echo "✅ Cookie: $([ -n "${EHENTAI_COOKIE:-}" ] && echo 'đã lưu' || echo 'đã xóa')"
                sleep 1.2 ;;
            *"Số trang ảnh mỗi chapter"*)
                read -r -p "Số trang ảnh gộp thành 1 chapter (5-100, Enter = $DEFAULT_EHENTAI_CHUNK): " inp
                inp="${inp:-$DEFAULT_EHENTAI_CHUNK}"
                if [[ "$inp" =~ ^[0-9]+$ ]] && [ "$inp" -ge 5 ] && [ "$inp" -le 100 ]; then
                    EHENTAI_CHUNK="$inp"
                    save_config
                    echo "✅ Đã lưu: $EHENTAI_CHUNK trang/chapter"
                    sleep 1.2
                else
                    echo "⚠️ Bỏ qua (cần số từ 5 đến 100)"; sleep 1.2
                fi ;;
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
        printf "║                    📚 MANGA READER · %-24s 📚║\n" "$(manga_source_label)"
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
                if manga_is_ehentai; then
                    printf '🔗 Dán link gallery e-hentai (vd https://e-hentai.org/g/4313400/7fcc76c845/) hoặc id/token: '
                    read -r inp
                    inp="${inp#"${inp%%[![:space:]]*}"}"
                    inp="${inp%"${inp##*[![:space:]]}"}"
                    if [ -z "$inp" ]; then
                        sleep 1
                        continue
                    fi
                    manga_read_manga "e-hentai $(printf '%s' "$inp" | cut -d/ -f1)" "$inp"
                    continue
                fi
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
                manga_is_ehentai && st_def="(gallery đầu tiên của tag $(eh_tag))"
                printf '🧪 Nhập slug hoặc link truyện (Enter = %s): ' "$st_def"
                manga_is_ehentai && st_def=""
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
