# ═══════════════════════════════════════════════════════════════════════════════
# NGUỒN TRUYỆN: TRUYENVN (truyenvn.my)
# ═══════════════════════════════════════════════════════════════════════════════
# TruyenVN đã bỏ WordPress nên không còn /?s=tu-khoa&post_type=wp-manga; trang
# /tim-kiem cũng KHÔNG lọc theo ?q=. Vì vậy anisub tải danh sách của site rồi tự
# lọc theo từ khóa. Danh sách chapter lấy qua /webapi/stories/list-chapter (cần
# story_id + CSRF token lấy từ trang truyện).

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
