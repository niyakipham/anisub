#!/usr/bin/perl
# ═══════════════════════════════════════════════════════════════════════════════
# Lọc quảng cáo trong playlist HLS (.m3u8) — dùng bởi src/movie/kkphim.sh
# ═══════════════════════════════════════════════════════════════════════════════
# KKPhim chèn quảng cáo kiểu SSAI: khối segment quảng cáo nằm NGAY TRONG playlist,
# thường bọc bởi #EXT-X-CUE-OUT / #EXT-X-CUE-IN (hoặc chỉ CUE-OUT kèm thời lượng).
# Vì quảng cáo hay nằm CÙNG host với phim, lọc theo tên miền/tên file là không đủ:
# ở đây bỏ cả KHỐI nằm giữa 2 marker, kể cả khi URL giống hệt segment phim.
#
# Đầu vào : playlist (stdin)
# Đầu ra  : playlist đã lọc (stdout); exit 2 nếu không còn segment nào
# Biến môi trường:
#   KKPHIM_BASE             URL gốc của playlist (để tuyệt đối hoá URL tương đối)
#   KKPHIM_AD_PATTERNS      mẫu nhận diện (cách nhau bằng dấu phẩy)
#   KKPHIM_AD_FOREIGN_HOST  1 = bỏ khối segment nằm ở tên miền khác với phim
#   KKPHIM_AD_STATS         file ghi thống kê (tuỳ chọn, để chẩn đoán)
use strict;
use warnings;

my $base    = $ENV{KKPHIM_BASE} // '';
my $stats_f = $ENV{KKPHIM_AD_STATS} // '';
my @pats    = grep { length } map { lc } split /[,\s]+/, ($ENV{KKPHIM_AD_PATTERNS} // '');
my $foreign = (($ENV{KKPHIM_AD_FOREIGN_HOST} // '1') =~ /^(?:1|on|yes|true|bat|bật)$/i) ? 1 : 0;

my ($origin) = $base =~ m{^(https?://[^/]+)}i;
$origin //= '';

sub abs_url {
    my ($u) = @_;
    return '' if !defined $u || $u eq '';
    return $u if $u =~ m{^[a-z][a-z0-9+.\-]*://}i;
    return "https:$u" if $u =~ m{^//};
    return $origin . $u if $u =~ m{^/};
    my $p = $base;
    $p =~ s{[?#].*$}{};
    $p =~ s{/[^/]*$}{};
    return "$p/$u";
}

# Tên miền gốc gần đúng: s1.phimapi.com -> phimapi.com
# (ads.adtag.vn -> adtag.vn; a.b.example.co.uk -> example.co.uk)
sub reg_domain {
    my ($host) = @_;
    $host = lc($host // '');
    $host =~ s/:\d+$//;
    my @l = split /\./, $host;
    return $host if @l <= 2;
    my %sl = map { $_ => 1 } qw(com net org co gov edu ac biz info);
    if (@l >= 3 && $sl{ $l[-2] } && length($l[-1]) == 2) {
        return join('.', @l[ -3 .. -1 ]);
    }
    return join('.', @l[ -2 .. -1 ]);
}

# #EXT-X-DATERANGE mô tả một đoạn quảng cáo (interstitial / SSAI)? Trình phát
# hiện tại (mpv/vlc) bỏ qua tag này, nhưng để nguyên thì vài trình phát khác có
# thể chèn quảng cáo -> bỏ luôn những tag "mang tiếng" quảng cáo.
sub is_ad_like_daterange {
    my ($t) = @_;
    return 1 if $t =~ /(?:^|[,:\s"])(?:CLASS|ID|X-ASSET-URI|X-ASSET-LIST)[^,]*?(?:interstitial|\bad(s|vert\w*)?\b|promo|sponsor|ssai|vast|vmap|quang[-_]?cao)/i;
    return 0;
}

# URL này là segment quảng cáo? (so khớp NGUYÊN một thành phần host/đường dẫn,
# nên media / shadow / load / segment_1 không bị xoá nhầm; query được bỏ đi nên
# ?ad=0 cũng không bị coi là quảng cáo)
sub is_ad {
    my ($u) = @_;
    my $s = $u;
    $s =~ s{[?#].*$}{};
    return 1 if $s =~ /quang[-_.]?cao/i;
    my @parts = grep { length } split m{[/.\-_\s=&]+}, lc($s);
    for my $p (@parts) {
        for my $pat (@pats) {
            return 1 if $p =~ /^\Q$pat\E[0-9]*$/;
        }
    }
    return 0;
}

# ─── 1. Đọc playlist thành các "đơn vị" (tag + segment) ───────────────────────
my @units;      # { kind => 'seg'|'tag', tags => [...], uri => '...', dur => n }
my @pending;
while (my $raw = <STDIN>) {
    my $l = $raw;
    $l =~ s/\r?\n$//;
    $l =~ s/^\s+|\s+$//g;
    next if $l eq '';
    if (substr($l, 0, 1) eq '#') {
        # URI="..." trong tag (#EXT-X-KEY, #EXT-X-MAP, ...) -> tuyệt đối hoá
        $l =~ s{(URI=")([^"]*)(")}{$1 . abs_url($2) . $3}ge;
        push @pending, $l;
        next;
    }
    push @units, { kind => 'seg', tags => [@pending], uri => abs_url($l), dur => 0, dom => '' };
    @pending = ();
}
push @units, { kind => 'tag', tags => [@pending], dur => 0, dom => '' } if @pending;

# ─── 2. Thời lượng từng segment + tên miền ────────────────────────────────────
my $seg_total = 0;
my %dom_count;
my @seg_idx;
for my $i (0 .. $#units) {
    my $u = $units[$i];
    next unless $u->{kind} eq 'seg';
    for my $t (@{ $u->{tags} }) {
        if ($t =~ /^#EXTINF:\s*([0-9]*\.?[0-9]+)/) { $u->{dur} = $1 + 0; }
    }
    my ($h) = $u->{uri} =~ m{^[a-z][a-z0-9+.\-]*://([^/]+)}i;
    $u->{dom} = reg_domain($h);
    $dom_count{ $u->{dom} }++;
    $seg_total++;
    push @seg_idx, $i;
}

# ─── 3. Nhận diện khối segment ở tên miền "lạ" (thường là adserver) ───────────
# Chỉ bỏ khi: có 1 tên miền chiếm >=70% segment (CDN của phim) và khối lạ ngắn
# (<= 20% + 2 segment, <= 5 phút) — tránh xoá nhầm phim chia nhiều CDN.
my %drop_host;
if ($foreign && $seg_total >= 4) {
    my ($dom, $cnt) = ('', 0);
    for my $d (keys %dom_count) {
        if ($dom_count{$d} > $cnt) { ($dom, $cnt) = ($d, $dom_count{$d}); }
    }
    if ($dom ne '' && $cnt < $seg_total && ($cnt / $seg_total) >= 0.7) {
        my $max_len = int($seg_total * 0.2) + 2;
        my $n = @seg_idx;
        for (my $p = 0; $p < $n; $p++) {
            next if $units[ $seg_idx[$p] ]{dom} eq $dom;
            my ($q, $dur, $len) = ($p, 0, 0);
            while ($q < $n && $units[ $seg_idx[$q] ]{dom} ne $dom) {
                $dur += $units[ $seg_idx[$q] ]{dur};
                $len++;
                $q++;
            }
            if ($len <= $max_len && $dur <= 300) {
                $drop_host{ $seg_idx[$_] } = 1 for ($p .. $q - 1);
            }
            $p = $q;
        }
    }
}

# ─── 4. Duyệt playlist: bỏ khối CUE-OUT..CUE-IN, segment khớp mẫu, host lạ ────
my @out;
my ($kept, $dropped, $dropped_sec, $kept_dur) = (0, 0, 0, 0);
my %reasons = (cue => 0, pattern => 0, host => 0);
my @dropped_urls;
my $ad_left = 0;        # 0 = không trong khối quảng cáo; >0 = còn bấy nhiêu giây
my $ad_unknown = 0;     # 1 = CUE-OUT không ghi thời lượng (kết thúc ở CUE-IN/DISCONTINUITY)
my $block_drops = 0;    # số segment đã bỏ trong khối hiện tại
my $cut     = 0;        # vừa bỏ segment -> cần #EXT-X-DISCONTINUITY trước segment kế

for my $i (0 .. $#units) {
    my $u = $units[$i];

    $block_drops = 0 if $ad_left == 0;

    # Marker chèn quảng cáo đứng TRƯỚC segment mà nó áp dụng
    for my $t (@{ $u->{tags} }) {
        if ($t =~ /^#EXT-X-CUE-OUT-DURATION:\s*([0-9]*\.?[0-9]+)/i) {
            $ad_left = ($1 > 0) ? $1 + 0 : 90;
            $ad_unknown = 0;
        } elsif ($t =~ /^#EXT-X-CUE-OUT-CONT(?::|\s*$)/i) {
            # Khối quảng cáo vẫn đang tiếp diễn
            $ad_left = 90 unless $ad_left > 0;
        } elsif ($t =~ /^#EXT-X-CUE-OUT(?::(?:DURATION=)?([0-9]*\.?[0-9]+))?(?::|\s*$)/i) {
            if (defined $1 && $1 > 0) {
                $ad_left = $1 + 0;
                $ad_unknown = 0;
            } else {
                # Không ghi thời lượng (hoặc ghi kiểu :ID=…): bỏ tối đa 90s và
                # dừng ngay khi gặp #EXT-X-DISCONTINUITY — nếu playlist thiếu
                # CUE-IN mà bỏ "tới hết playlist" thì sẽ mất cả phần sau phim.
                $ad_left = 90;
                $ad_unknown = 1;
            }
        } elsif ($t =~ /^#EXT-X-CUE-IN(?::|\s*$)/i) {
            $ad_left = 0;
            $ad_unknown = 0;
        }
    }
    # CUE-OUT không thời lượng + đã bỏ được segment + gặp DISCONTINUITY -> hết khối
    if ($ad_unknown && $ad_left > 0 && $block_drops > 0
            && grep { /^#EXT-X-DISCONTINUITY\b/i } @{ $u->{tags} }) {
        $ad_left = 0;
        $ad_unknown = 0;
    }
    my @keep_tags = grep {
        !/^#EXT-X-CUE-(?:OUT|IN)\b/i
            && !/^#EXT-(?:OATCLS-)?SCTE35\b/i
            && !/^#EXT-X-ASSET\b/i
            && !/^#EXT-X-SPLICE(?:POINT|INFO)?\b/i
            && !/^#EXT-X-SOFA-AD\b/i                       # marker quảng cáo của một số CDN
            && !(/^#EXT-X-DATERANGE:/i && is_ad_like_daterange($_))
    } @{ $u->{tags} };

    if ($u->{kind} eq 'seg') {
        my $reason = '';
        if    ($ad_left != 0)    { $reason = 'cue'; }
        elsif (is_ad($u->{uri})) { $reason = 'pattern'; }
        elsif ($drop_host{$i})   { $reason = 'host'; }

        if ($reason) {
            $dropped++;
            $dropped_sec += $u->{dur};
            $reasons{$reason}++;
            push @dropped_urls, $u->{uri} if @dropped_urls < 25;
            $block_drops++;
            if ($ad_left > 0) {
                $ad_left -= $u->{dur};
                $ad_left = 0 if $ad_left <= 0.001;
            }
            $cut = 1;
            next;
        }

        # Giữ segment: chèn DISCONTINUITY ngay chỗ vừa cắt để trình phát nối
        # tiếp tức thì (mốc thời gian nhảy mà không báo -> khựng/đứng hình).
        if ($cut) {
            my $has = grep { /^#EXT-X-DISCONTINUITY\b/i } @keep_tags;
            my $last = (@out && $out[-1] =~ /^#EXT-X-DISCONTINUITY\b/i) ? 1 : 0;
            unshift @keep_tags, '#EXT-X-DISCONTINUITY' unless $has || $last;
            $cut = 0;
        }
        # Bỏ DISCONTINUITY thừa (2 dòng liền nhau)
        if (@out && $out[-1] =~ /^#EXT-X-DISCONTINUITY\b/i && @keep_tags
                && $keep_tags[0] =~ /^#EXT-X-DISCONTINUITY\b/i) {
            shift @keep_tags;
        }
        $kept++;
        $kept_dur += $u->{dur};
        push @out, @keep_tags;
        push @out, $u->{uri};
        next;
    }

    push @out, @keep_tags if @keep_tags;
}

# ─── 5. Playlist kiểu LIVE (cửa sổ trượt vài segment) thì ĐỪNG lọc ────────────
# Bản lọc là "ảnh chụp" tĩnh: nếu gốc là live thật (chỉ có vài segment mới nhất,
# không có ENDLIST/VOD) mà ta đóng lại thành VOD thì phim chỉ còn vài chục giây.
# Chỉ chuẩn hoá VOD khi playlist đã chứa cả bộ phim (>= 120s nội dung).
my $has_endlist = grep { /^#EXT-X-ENDLIST/i } @out;
my $declared_vod = grep { /^#EXT-X-PLAYLIST-TYPE:\s*VOD/i } @out;
if (!$has_endlist && !$declared_vod && $kept_dur > 0 && $kept_dur < 120) {
    exit 3;    # live window -> để anisub phát đúng link gốc
}

# ─── 5b. Thống kê (cho --kkphim-ad-debug / thông báo khi phát) ────────────────
if ($stats_f ne '') {
    if (open(my $fh, '>', $stats_f)) {
        print $fh "kept=$kept\n";
        print $fh "dropped=$dropped\n";
        print $fh "dropped_sec=" . int($dropped_sec + 0.5) . "\n";
        print $fh "segments=$seg_total\n";
        print $fh "reason_cue=$reasons{cue}\n";
        print $fh "reason_pattern=$reasons{pattern}\n";
        print $fh "reason_host=$reasons{host}\n";
        print $fh "url=$_\n" for @dropped_urls;
        close $fh;
    }
}

exit 2 if $kept == 0;

# ─── 4b. Chốt an toàn: bỏ quá nhiều thì đừng dùng bản đã lọc ──────────────────
# Phim dài (>= 5 phút) mà "quảng cáo" chiếm > 45% thời lượng = gần như chắc chắn
# nhận diện sai (marker lạ) -> thà phát bản gốc còn hơn mất nửa phim.
my $total_dur = $kept_dur + $dropped_sec;
if ($total_dur >= 300 && $dropped_sec > $total_dur * 0.45) {
    exit 4;
}

# ─── 6. Chuẩn hoá thành VOD ──────────────────────────────────────────────────
# Playlist kiểu live (thiếu #EXT-X-ENDLIST) bị trình phát tải lại mỗi
# TARGETDURATION giây; bản đã lọc là ảnh chụp tĩnh nên nếu để nguyên kiểu live
# sẽ "phát vài giây lại khựng vài giây". GIỮ NGUYÊN #EXT-X-MEDIA-SEQUENCE và
# #EXT-X-DISCONTINUITY-SEQUENCE (đó là IV mặc định của AES-128 + mốc BYTERANGE).
my ($has_end, $has_type) = (0, 0);
for my $l (@out) {
    $has_end  = 1 if $l =~ /^#EXT-X-ENDLIST/i;
    $has_type = 1 if $l =~ /^#EXT-X-PLAYLIST-TYPE:/i;
}
my @final;
my $type_done = 0;
for my $l (@out) {
    push @final, $l;
    if (!$has_type && !$type_done && $l =~ /^#EXT-X-TARGETDURATION:/i) {
        push @final, '#EXT-X-PLAYLIST-TYPE:VOD';
        $type_done = 1;
    }
}
if (!$has_type && !$type_done) {
    if (@final > 1) { splice @final, 1, 0, '#EXT-X-PLAYLIST-TYPE:VOD'; }
    else            { unshift @final, '#EXT-X-PLAYLIST-TYPE:VOD'; }
}
push @final, '#EXT-X-ENDLIST' unless $has_end;

print join("\n", @final), "\n";
exit 0;
