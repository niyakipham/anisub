#!/usr/bin/perl
# ═══════════════════════════════════════════════════════════════════════════════
# Lọc quảng cáo trong playlist HLS (.m3u8) — dùng bởi src/movie/kkphim.sh
# ═══════════════════════════════════════════════════════════════════════════════
# KKPhim chèn quảng cáo kiểu SSAI: khối segment quảng cáo nằm NGAY TRONG playlist,
# ngay giữa phim (hay gặp ở ~2:56 và ~14:58). Có nhiều kiểu đánh dấu:
#   • bọc bởi #EXT-X-CUE-OUT / #EXT-X-CUE-IN (hoặc CUE-OUT kèm thời lượng);
#   • chỉ có #EXT-X-DISCONTINUITY ở 2 đầu khối, không marker;
#   • segment quảng cáo ở host / thư mục / đuôi file / kiểu #EXTINF khác phim.
# Bộ lọc này xử lý ĐỦ các kiểu trên, cùng một luật cho mọi khối — nhờ vậy khối
# ở 2:56 và khối ở 14:58 được xử lý giống nhau, không phải "bắt" riêng từng chỗ.
#
# Đầu vào : playlist (stdin)
# Đầu ra  : playlist đã lọc (stdout); exit 2 = không còn segment nào
# Biến môi trường:
#   KKPHIM_BASE             URL gốc của playlist (để tuyệt đối hoá URL tương đối)
#   KKPHIM_AD_PATTERNS      mẫu nhận diện (cách nhau bằng dấu phẩy)
#   KKPHIM_AD_FOREIGN_HOST  1 = bỏ khối segment ở host/thư mục lạ (mặc định 1)
#   KKPHIM_AD_STATS         file ghi thống kê (tuỳ chọn, để chẩn đoán)
#   KKPHIM_AD_MODE          blocks = chỉ in bản đồ khối (không lọc)
use strict;
use warnings;

my $base    = $ENV{KKPHIM_BASE} // '';
my $stats_f = $ENV{KKPHIM_AD_STATS} // '';
my $mode    = $ENV{KKPHIM_AD_MODE} // 'filter';
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

sub to_sec {    # "14:58" / "1:14:58" -> giây
    my ($t) = @_;
    return undef unless defined $t && $t =~ /^(?:(\d+):)?(\d+):(\d+)$/;
    return $1 ? $1 * 3600 + $2 * 60 + $3 : $2 * 60 + $3;
}

sub hhmmss {
    my ($s) = @_;
    $s = int($s + 0.5);
    return sprintf('%d:%02d', int($s / 60), $s % 60);
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

# ─── 2. Thuộc tính từng segment: host / thư mục / đuôi / kiểu #EXTINF ─────────
my $seg_total = 0;
my @seg_idx;
for my $i (0 .. $#units) {
    my $u = $units[$i];
    next unless $u->{kind} eq 'seg';
    for my $t (@{ $u->{tags} }) {
        if ($t =~ /^#EXTINF:\s*([0-9]*\.?[0-9]+)/) {
            $u->{dur} = $1 + 0;
            $u->{prec} = ($1 =~ /\.(\d+)/) ? length($1) : 0;
        }
        $u->{disc} = 1 if $t =~ /^#EXT-X-DISCONTINUITY\b/i;
    }
    $u->{prec} = -1 unless defined $u->{prec};
    my ($host) = $u->{uri} =~ m{^[a-z][a-z0-9+.\-]*://([^/]+)}i;
    $u->{dom} = reg_domain($host);
    (my $path = $u->{uri}) =~ s{^[a-z][a-z0-9+.\-]*://[^/]*}{}i;
    $path =~ s{[?#].*$}{};
    $path = "/$path" unless $path =~ m{^/};
    my ($dir, $file) = $path =~ m{^(.*/)?([^/]*)$};
    $dir  = '/' unless defined $dir && length $dir;
    $file = '' unless defined $file;
    (my $ext = $file) =~ s/^.*\.//;
    $u->{dir} = $dir;
    $u->{ext} = lc($ext // '');
    # Kiểu tên file: 00123.ts -> ###.ts, ad_5.ts -> ad_#.ts. Quảng cáo hay đặt tên
    # file khác phim dù cùng host/thư mục -> thêm một dấu hiệu để nhận ra.
    (my $tpl = $file) =~ s/\d+/#/g;
    $tpl = '#' if $tpl =~ /^#+$/;
    $u->{tpl} = $tpl;
    $seg_total++;
    push @seg_idx, $i;
}

# ─── 3. Chia playlist thành từng KHỐI theo #EXT-X-DISCONTINUITY ───────────────
# Mỗi khối: các segment liên tiếp, bắt đầu lại khi gặp #EXT-X-DISCONTINUITY.
my @blocks;
my $cur;
my $t = 0;      # mốc thời gian (giây) của segment kế tiếp
for my $i (@seg_idx) {
    my $u = $units[$i];
    my $starts = ($u->{disc} || !defined $cur) ? 1 : 0;
    if ($starts) {
        push @blocks, $cur if defined $cur;
        $cur = { idx => [], n => 0, dur => 0, first_disc => ($u->{disc} ? 1 : 0),
                 dom => {}, dir => {}, ext => {}, prec => {}, tpl => {}, t0 => $t,
                 brk => ($u->{disc} ? 1 : 0) };
    }
    push @{ $cur->{idx} }, $i;
    $cur->{n}++;
    $cur->{dur} += $u->{dur};
    $cur->{dom}{ $u->{dom} }++;
    $cur->{dir}{ $u->{dir} }++;
    $cur->{ext}{ $u->{ext} }++;
    $cur->{prec}{ $u->{prec} }++;
    $cur->{tpl}{ $u->{tpl} }++;
    $t += $u->{dur};
    $cur->{t1} = $t;
}
push @blocks, $cur if defined $cur;

# giá trị "chủ đạo" + tỉ lệ của nó trong 1 khối
sub dominant {
    my ($h) = @_;
    my ($best, $cnt, $tot) = ('', 0, 0);
    for my $k (keys %$h) {
        $tot += $h->{$k};
        if ($h->{$k} > $cnt) { ($best, $cnt) = ($k, $h->{$k}); }
    }
    return ($best, $tot ? $cnt / $tot : 0);
}

# ─── 3b. Chế độ "blocks": in bản đồ khối để chẩn đoán ─────────────────────────
if ($mode eq 'blocks') {
    my %all = (dom => {}, dir => {}, ext => {}, prec => {}, tpl => {});
    for my $i (@seg_idx) {
        my $u = $units[$i];
        $all{$_}{ $u->{$_} }++ for qw(dom dir ext prec tpl);
    }
    my ($g_dom) = dominant($all{dom});
    my ($g_dir) = dominant($all{dir});
    my ($g_tpl) = dominant($all{tpl});
    printf "%-4s %-11s %-11s %5s %8s  %-16s %-26s %-6s %-5s %s\n",
        'KHỐI', 'TỪ', 'ĐẾN', 'SEG', 'GIÂY', 'HOST', 'THƯ MỤC', 'EXTINF', 'ĐUÔI', 'TÊN FILE';
    my $k = 0;
    for my $b (@blocks) {
        $k++;
        my ($bd) = dominant($b->{dom});
        my ($bdir) = dominant($b->{dir});
        my ($bext) = dominant($b->{ext});
        my ($bprec) = dominant($b->{prec});
        my ($btpl) = dominant($b->{tpl});
        my $flag = '';
        $flag .= ' ⚠️host-lạ'     if $bd   ne $g_dom;
        $flag .= ' ⚠️thư-mục-lạ'  if $bdir ne $g_dir;
        $flag .= ' ⚠️tên-lạ'      if $btpl ne $g_tpl;
        $flag .= ' ⚠️CUE' if grep { /^#EXT-X-CUE-(?:OUT|IN)/i } map { @{ $units[$_]{tags} } } @{ $b->{idx} };
        $flag .= ' ⚠️DATERANGE' if grep { /^#EXT-X-DATERANGE:/i && is_ad_like_daterange($_) }
            map { @{ $units[$_]{tags} } } @{ $b->{idx} };
        printf "%-4s %-11s %-11s %5s %8s  %-16s %-26s %-6s %-5s %s%s\n",
            $k, hhmmss($b->{t0}), hhmmss($b->{t1}), $b->{n}, int($b->{dur} + 0.5),
            $bd, $bdir, ($bprec < 0 ? '?' : $bprec . ' số'), $bext, $btpl, $flag;
    }
    exit 0;
}

# ─── 4. Nhận diện đoạn segment "lạ" (quảng cáo) ──────────────────────────────
# Quảng cáo là một ĐOẠN NGẮN nằm giữa phim và khác phim ở ít nhất một dấu hiệu:
#   host / thư mục / đuôi file / kiểu #EXTINF (số chữ số thập phân).
# Đoạn được tính lại mỗi khi gặp #EXT-X-DISCONTINUITY hoặc khi dấu hiệu đổi, nên
# khối quảng cáo ở 2:56 và khối ở 14:58 đều được xử lý bởi CÙNG một luật này —
# không phải "bắt" riêng từng mốc thời gian.
my %all = (dom => {}, dir => {}, ext => {}, prec => {}, tpl => {});
for my $i (@seg_idx) {
    my $u = $units[$i];
    $all{$_}{ $u->{$_} }++ for qw(dom dir ext prec tpl);
}
my ($g_dom, $g_dom_share)   = dominant($all{dom});
my ($g_dir, $g_dir_share)   = dominant($all{dir});
my ($g_ext, $g_ext_share)   = dominant($all{ext});
my ($g_prec, $g_prec_share) = dominant($all{prec});
my ($g_tpl,  $g_tpl_share)  = dominant($all{tpl});
my ($g_ext2, $g_ext_share2) = ($g_ext, $g_ext_share);

# thời lượng "chuẩn" của phim (trung vị) — quảng cáo hay dùng segment dài/ngắn khác
my @durs = sort { $a <=> $b } map { $units[$_]{dur} } @seg_idx;
my $g_med = @durs ? $durs[ int($#durs / 2) ] : 0;

my @runs;    # { idx=>[], n, dur, sig, dom, dir, ext, prec, tpl, brk }
for my $i (@seg_idx) {
    my $u = $units[$i];
    my $sig = join('|', $u->{dom}, $u->{dir}, $u->{ext},
        ($u->{prec} < 0 ? '?' : $u->{prec}), $u->{tpl});
    if (@runs && !$u->{disc} && $runs[-1]{sig} eq $sig) {
        push @{ $runs[-1]{idx} }, $i;
        $runs[-1]{n}++;
        $runs[-1]{dur} += $u->{dur};
    } else {
        push @runs, { idx => [$i], n => 1, dur => $u->{dur}, sig => $sig,
                      dom => $u->{dom}, dir => $u->{dir}, ext => $u->{ext},
                      prec => $u->{prec}, tpl => $u->{tpl}, brk => ($u->{disc} ? 1 : 0) };
    }
}
# run được "bọc" bởi #EXT-X-DISCONTINUITY ở đầu và/hoặc cuối?
for my $k (0 .. $#runs) {
    my $r = $runs[$k];
    my $last_i = $r->{idx}[-1];
    my $ends_disc = ($last_i < $#units && $units[ $last_i + 1 ]{disc}) ? 1 : 0;
    $r->{brk_after} = $ends_disc;
}

my %drop_block;
if ($foreign && $seg_total >= 4 && scalar(@runs) > 1) {
    my $max_seg = int($seg_total * 0.25) + 3;
    my ($drop_n, $drop_dur, $all_dur) = (0, 0, 0);
    $all_dur += $units[$_]{dur} for @seg_idx;
    for my $r (@runs) {
        next if $r->{n} > $max_seg;          # đoạn dài = nội dung
        next if $r->{dur} > 180;             # quảng cáo không dài quá 3 phút
        my $odd = 0;
        $odd = 1 if $g_dom_share  >= 0.7  && $r->{dom}  ne $g_dom;
        $odd = 1 if $g_dir_share  >= 0.7  && $r->{dir}  ne $g_dir;
        $odd = 1 if $g_ext_share  >= 0.7  && $r->{ext}  ne $g_ext;
        $odd = 1 if $g_prec_share >= 0.85 && $r->{prec} >= 0 && $r->{prec} ne $g_prec;
        $odd = 1 if $g_tpl_share  >= 0.8  && $r->{tpl}  ne $g_tpl;
        # thời lượng khác hẳn phim + có DISCONTINUITY ở (ít nhất) một đầu
        if (!$odd && $g_med > 0 && ($r->{brk} || $r->{brk_after}) && $r->{n} <= $max_seg) {
            my $mean = $r->{dur} / ($r->{n} || 1);
            $odd = 1 if abs($mean - $g_med) / $g_med > 0.34;
        }
        next unless $odd;
        # tổng phần bị bỏ vẫn phải "nhỏ" so với cả phim (tránh xoá nửa phim)
        next if $drop_n + $r->{n} > $seg_total * 0.35;
        next if $all_dur > 0 && $drop_dur + $r->{dur} > $all_dur * 0.35;
        $drop_block{$_} = 1 for @{ $r->{idx} };
        $drop_n   += $r->{n};
        $drop_dur += $r->{dur};
    }
}

# ─── 4b. Cắt thêm theo MỐC THỜI GIAN người dùng chỉ định ─────────────────────
# KKPHIM_AD_CUT="14:55-15:40"  ->  bỏ mọi segment nằm trong khoảng đó.
# Dùng khi quảng cáo không có dấu hiệu nào khác để nhận diện (cùng host/thư mục/
# tên file/EXTINF) mà chỉ biết nó nằm ở phút thứ mấy.
my %drop_time;
my @ranges;
for my $r (split /[,;\s]+/, ($ENV{KKPHIM_AD_CUT} // '')) {
    next unless $r =~ /^(\d+(?::\d+){1,2})-(\d+(?::\d+){1,2})$/;
    my ($a, $b) = (to_sec($1), to_sec($2));
    push @ranges, [ $a, $b ] if defined $a && defined $b && $b > $a;
}
if (@ranges) {
    my $tt = 0;
    my $hit = 0;
    for my $i (@seg_idx) {
        my $u = $units[$i];
        my ($st, $en) = ($tt, $tt + $u->{dur});
        $tt = $en;
        for my $rg (@ranges) {
            next unless $st < $rg->[1] && $en > $rg->[0];
            $drop_time{$i} = 1;
            $hit++;
            last;
        }
    }
    # chốt an toàn: không bao giờ cắt quá 60% phim dù khoảng chỉ định sai
    %drop_time = () if $hit > $seg_total * 0.6;
}

# ─── 5. Duyệt playlist: bỏ khối CUE-OUT..CUE-IN, segment khớp mẫu, khối lạ ────
my @out;
my ($kept, $dropped, $dropped_sec, $kept_dur) = (0, 0, 0, 0);
my %reasons = (cue => 0, pattern => 0, host => 0, block => 0, time => 0);
my @dropped_urls;
my $ad_left = 0;        # 0 = không trong khối quảng cáo; >0 = còn bấy nhiêu giây
my $ad_unknown = 0;     # 1 = CUE-OUT không ghi thời lượng (kết thúc ở CUE-IN/DISCONTINUITY)
my $block_drops = 0;    # số segment đã bỏ trong khối hiện tại
my $cut     = 0;        # vừa bỏ segment -> cần #EXT-X-DISCONTINUITY trước segment kế

for my $i (0 .. $#units) {
    my $u = $units[$i];

    $block_drops = 0 if $ad_left == 0;

    # Marker chèn quảng cáo đứng TRƯỚC segment mà nó áp dụng
    for my $tg (@{ $u->{tags} }) {
        if ($tg =~ /^#EXT-X-CUE-OUT-DURATION:\s*([0-9]*\.?[0-9]+)/i) {
            $ad_left = ($1 > 0) ? $1 + 0 : 90;
            $ad_unknown = 0;
        } elsif ($tg =~ /^#EXT-X-CUE-OUT-CONT(?::|\s*$)/i) {
            # Khối quảng cáo vẫn đang tiếp diễn
            $ad_left = 90 unless $ad_left > 0;
        } elsif ($tg =~ /^#EXT-X-CUE-OUT(?::(?:DURATION=)?([0-9]*\.?[0-9]+))?(?::|\s*$)/i) {
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
        } elsif ($tg =~ /^#EXT-X-CUE-IN(?::|\s*$)/i) {
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
        elsif ($drop_block{$i})  { $reason = 'block'; }
        elsif ($drop_time{$i})   { $reason = 'time'; }

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

# ─── 6. Playlist kiểu LIVE (cửa sổ trượt vài segment) thì ĐỪNG lọc ────────────
# Bản lọc là "ảnh chụp" tĩnh: nếu gốc là live thật (chỉ có vài segment mới nhất,
# không có ENDLIST/VOD) mà ta đóng lại thành VOD thì phim chỉ còn vài chục giây.
my $has_endlist  = grep { /^#EXT-X-ENDLIST/i } @out;
my $declared_vod = grep { /^#EXT-X-PLAYLIST-TYPE:\s*VOD/i } @out;
exit 3 if (!$has_endlist && !$declared_vod && $kept_dur > 0 && $kept_dur < 120);

# ─── 7. Thống kê (cho --kkphim-ad-debug / thông báo khi phát) ──────────────────
if ($stats_f ne '') {
    if (open(my $fh, '>', $stats_f)) {
        print $fh "kept=$kept\n";
        print $fh "dropped=$dropped\n";
        print $fh "dropped_sec=" . int($dropped_sec + 0.5) . "\n";
        print $fh "segments=$seg_total\n";
        print $fh "reason_cue=$reasons{cue}\n";
        print $fh "reason_pattern=$reasons{pattern}\n";
        print $fh "reason_host=$reasons{host}\n";
        print $fh "reason_block=$reasons{block}\n";
        print $fh "reason_time=$reasons{time}\n";
        print $fh "blocks=" . scalar(@blocks) . "\n";
        print $fh "url=$_\n" for @dropped_urls;
        close $fh;
    }
}

exit 2 if $kept == 0;

# ─── 8. Chốt an toàn: bỏ quá nhiều thì đừng dùng bản đã lọc ──────────────────
# Phim dài (>= 5 phút) mà "quảng cáo" chiếm > 45% thời lượng = gần như chắc chắn
# nhận diện sai (marker lạ) -> thà phát bản gốc còn hơn mất nửa phim.
my $total_dur = $kept_dur + $dropped_sec;
exit 4 if ($total_dur >= 300 && $dropped_sec > $total_dur * 0.45);

# ─── 9. Chuẩn hoá thành VOD ──────────────────────────────────────────────────
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
