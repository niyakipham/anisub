# ═══════════════════════════════════════════════════════════════════════════════
# NGUỒN TRUYỆN: NETTRUYEN (nettruyen.info)
# ═══════════════════════════════════════════════════════════════════════════════
# CMS kiểu NetTruyen: danh sách chương nằm sẵn trong HTML trang truyện (không cần
# API/CSRF), ảnh trang đọc có dạng https://net.imgchapter.store/<slug>/<chap>/page_<i>.jpg

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
