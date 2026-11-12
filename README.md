<div align = center>
    <a href="https://discord.gg/AYbJ9MJez7">
<img alt="Dynamic JSON Badge" src="https://i.pinimg.com/736x/07/9d/5f/079d5fb88985798fe0f88d1731c1fa6d.jpg">
    </a>
</div>

<br>
<div align = center>
  <a href="#FEARTURE"><kbd> <br> FEARTURE <br> </kbd></a>&ensp;&ensp;
  <a href="#INSTALL"><kbd> <br> INSTALL <br> </kbd></a>&ensp;&ensp;
  <a href="#RUN"><kbd> <br> RUN <br> </kbd></a>&ensp;&ensp;
  <a href="#CONTACT"><kbd> <br> CONTACT <br> </kbd></a>&ensp;&ensp;
</div>
<br>

## Hi Everyone 👋

[![Anisub on J2TEAM Launch](https://launch.j2team.dev/badge/anisub/light)](https://launch.j2team.dev/products/anisub) <br>

### DONATE
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://buymeacoffee.com/niyakiphamn)
<br>

## DỰ KIẾN
《🔝》- Thêm level để leo rank<br>
《🪟》- Chạy trên windows<br>
## UPDATE
《🚫》- **Sửa lỗi quảng cáo hiện giữa phim (chỗ ~phút 14:58–15:00)**: KKPhim nhét **khối segment quảng cáo ngay trong playlist `.m3u8`** (kiểu SSAI, bọc bởi `#EXT-X-CUE-OUT` / `#EXT-X-CUE-IN`). Bản lọc cũ chỉ bỏ segment có URL khớp mẫu quảng cáo nên quảng cáo **cùng host với phim** vẫn lọt; bản này **bỏ cả khối giữa 2 marker** (hoặc đúng thời lượng ghi trong `CUE-OUT`), bỏ segment khớp `KKPHIM_AD_PATTERNS`, bỏ khối ngắn nằm ở **tên miền lạ** (adserver), rồi mới đưa playlist cho mpv/vlc — tua qua chỗ cắt không còn khựng vì có `#EXT-X-DISCONTINUITY`, playlist được chuẩn hoá thành VOD. Tải/cắt video cũng dùng chung bản đã lọc nên mốc thời gian khớp với lúc xem. Không lọc được (mạng lỗi, AES-128 thiếu IV, playlist lạ) thì **phát đúng link gốc**. Chẩn đoán: `./anisub.sh --kkphim-ad-debug "<link .m3u8>"`; bật/tắt ở `⚙️ Cài đặt → 🎞 Nguồn phim`<br>
《🔧》- **Sửa lỗi “không thấy nguồn toon18x trong Cài đặt”**: anisub giờ **tự kiểm tra bộ `src/`** khi khởi động; thiếu module nguồn nào (ví dụ `toon18x.sh`) là **tự tải lại bộ nguồn** (bản cài git thì `git pull`), rồi mới mở menu — không còn cảnh bộ nguồn cũ nằm im. Không tải được (mất mạng) thì nói rõ đang thiếu nguồn nào và cách sửa; dòng `📚 Nguồn truyện` trong ⚙️ Cài đặt cũng gắn `⚠️ thiếu nguồn: …`. `🔄 Cập nhật` không còn bỏ qua khi “đã là bản mới nhất” mà `src/` vẫn thiếu module<br>
《📚》- Thêm nguồn truyện **toon18x** (`https://toon18x.com/vi`): webtoon/manhwa 18+ bản tiếng Việt, duyệt/tìm trên `/vi/search`, danh sách chương đầy đủ qua `GET /api/v1/manga/<slug>/chapters`, ảnh trang đọc nằm trên `tv1.toon18x.com`; URL chương suy trực tiếp từ số chương nên `Ctrl-G` và lịch sử luôn chạy<br>
《🎛》- **Đổi nguồn truyện** trong Cài đặt giờ là **menu chọn bằng fzf** (đánh dấu ✅ nguồn đang dùng, thấy đủ 5 nguồn: nettruyen / truyenvn / e-hentai / kagane / toon18x) thay vì phải gõ số; nếu bộ `src/` trên máy còn là bản cũ (chưa có nguồn kagane) thì anisub **nói rõ “chạy 🔄 Cập nhật”** thay vì im lặng<br>
《📚》- Thêm nguồn truyện **kagane** (`https://kagane.moe`): duyệt/tìm truyện, danh sách chương lấy từ API riêng của site, ảnh trang đọc dùng **token ngắn hạn** (anisub tự xin + tự làm mới khi hết hạn); đổi nguồn ở `⚙️ Cài đặt → 📚 Nguồn truyện`, lọc ngôn ngữ bằng `KAGANE_LANG`<br>
《🔒》- **DNS nhà mạng chặn e-hentai**: anisub tự hỏi IP qua **DNS-over-HTTPS** (cloudflare-dns.com → dns.google) rồi nối thẳng bằng `--resolve`, nhớ IP cho lần sau; tắt bằng `MANGA_DOH="off"`<br>
《🩺》- Thêm `./anisub.sh --netcheck [host]`: kiểm tra **từng lớp** DNS hệ thống → DoH → HTTPS/TLS để biết bị chặn ở đâu (DNS / IP / SNI), kèm cách sửa (`resolvectl`, VPN, proxy)<br>
《🧦》- Thêm `MANGA_PROXY` cho phần truyện (vd `socks5h://127.0.0.1:1080`); vẫn dùng được `export https_proxy=...` như curl<br>
《🌐》- **e-hentai không tải được (HTTP 000)** giờ nói rõ nguyên nhân theo mã lỗi curl (DNS / không kết nối / timeout / TLS) và cảnh báo e-hentai hay bị nhà mạng VN chặn; in **URL đầy đủ** thay vì `/?f_search=…`, và cho **bấm `1` để chuyển ngay sang nettruyen**; kết nối bị chặn giờ báo lỗi sau ~10s thay vì treo 30s<br>
《💾》- Sửa `save_config`: tự tạo `~/.config/anisub_cli` (trước đây lưu cài đặt **mất im lặng** nếu thư mục chưa có) và báo lỗi nếu không ghi được<br>
《🧾》- **📚 Đọc Truyện Tranh** giờ không im lặng nữa: nếu menu truyện không mở được, anisub nói rõ (đã vẽ menu chưa, fzf trả về gì), tự thử nạp/tải lại bộ nguồn ngay tại chỗ, và ghi lại dấu vết vào `~/.config/anisub_cli/cache/anisub-debug.log`<br>
《🩺》- `--doctor` in thêm môi trường (bash/fzf/TERM), commit git đang chạy + nhắc `git pull` khi chậm bản, và tình trạng các hàm chính (`manga_main_menu`, `fetch_chapter_list`, …)<br>
《🩺》- Sửa lỗi **không đọc được truyện tranh**: nếu máy chỉ có `anisub.sh` (thiếu `src/`) thì anisub **tự tải `src/` về** khi chạy, báo lỗi kèm cách sửa nếu không tải được, và có thêm `./anisub.sh --doctor` để chẩn đoán toàn bộ (module · phụ thuộc · nguồn truyện)<br>
《🔄》- Sửa **🔄 Cập nhật**: trước đây luôn báo "thiếu anisub.sh hoặc src/" (giải nén nhầm thư mục tạm) — giờ cập nhật đúng cả `anisub.sh` + `src/`<br>
《🔐》- `anisub.sh` được đặt quyền chạy (`chmod +x`) nên `./anisub.sh` chạy được ngay sau khi clone<br>
《📺》- Thêm gợi ý từ khóa<br>
《🧩》- Tách mã nguồn: `src/movie/` (nguồn phim) và `src/comic/` (nguồn truyện) — thêm nguồn mới chỉ cần thêm 1 file, code chính gọn còn ~1/6<br>
《🔞》- Thêm nguồn truyện **e-hentai** (`https://e-hentai.org`), mặc định xem tag `language:vietnamese`<br>
《📺》- Thêm data từ kkphim, nguồn ophim sang dạng cào<br>
《📖》- Tích hợp truyenvn ( manga thì đọc oke còn webtoon thì như hạch ) <br>
《📖》- Đổi nguồn truyện sang `truyenvn.my`, sửa lỗi không tải được danh sách chapter / ảnh trang đọc<br>
《📖》- Sửa lỗi bấm **📚 Đọc Truyện Tranh** ở menu chính không mở được menu truyện (nhãn nguồn trong menu đổi thành động)<br>
《📖》- Chuyển nguồn truyện mặc định sang **nettruyen** (`nettruyen.info`): danh sách chapter đọc thẳng từ HTML, ảnh trang đọc trên `net.imgchapter.store`, có thêm `🔁 Đổi nguồn truyện` (nettruyen ⇄ truyenvn)<br>
《📖》- Truyện tranh: xem trước **ảnh bìa** khi chọn truyện, lấy **đủ danh sách chapter** (API `list-chapter`) và **ảnh trang đọc hiện ở mọi terminal**<br>
《✂》- Bổ sung cắt video 1 lần và cắt video nhiều lần<br>
《﬚》- Bổ sung tính năng ghép nhiều video với nhau <br>
#### Và còn nhiều tính năng khác!!! <br>
## FEARTURE

《👀》- Tìm kiếm Anime, hiển thị các bộ anime có cùng tư khóa liên quan <br>
《📺》- Ngoài ra bạn có thể xem được cả phim truyền hình từ Scripts này <br>
《✂》- Cắt video từ phút bao nhiêu đến phút bao nhiêu <br>
《🔗》- Tải video về thư mục tên Anime <br>
《👈》- Phát tập trước <br>
《👉》- Phát tập sau<br>

## NGUỒN PHIM

《🎬》- **KKPhim** — `https://kkphim.com` : tìm kiếm, danh mục, thông tin phim, server phụ đề và link `.m3u8` đều lấy từ API chính thức mà KKPhim công bố tại https://kkphim.com/api-document (base `https://phimapi.com`) <br>
《📚》- **nettruyen** — `https://nettruyen.info` : đọc truyện tranh (mặc định; cào HTML, danh sách chapter nằm sẵn trong trang, không cần API key) <br>
《📚》- **TruyenVN** — `https://truyenvn.my` : nguồn cũ, đổi lại được bằng `🔁 Đổi nguồn truyện` (cần API nội bộ `list-chapter`) <br>
《🔞》- **e-hentai** — `https://e-hentai.org` : gallery ảnh (18+), mặc định duyệt tag `language:vietnamese` <br>
《📚》- **kagane** — `https://kagane.moe` : manga/manhwa/manhua đa ngôn ngữ (60+), duyệt/tìm trên trang `/search`, chương + ảnh trang qua API `/api/v2` của site <br>
《🔞》- **toon18x** — `https://toon18x.com/vi` : webtoon/manhwa **18+** bản tiếng Việt, duyệt/tìm trên `/vi/search`, danh sách chương qua `GET /api/v1/manga/<slug>/chapters`, ảnh trang trên `tv1.toon18x.com` <br>
《📂》- **Local Anidata** — `assets/aniw_export_2026-01-14.csv` : xem offline không cần mạng <br>

<br>

KKPhim đôi khi đổi domain frontend (`kkphim.com` ↔ `kkphim2.com`), khi đó chỉ cần sửa trong `~/.config/anisub_cli/config.cfg` (hoặc vào `⚙️ Cài đặt → 🎞 Nguồn phim`):

```shell
KKPHIM_SITE_URL="https://kkphim.com"   # trang web: poster, mở trình duyệt, Referer
KKPHIM_API_URL="https://phimapi.com"   # API RESTful của KKPhim
KKPHIM_CDN_URL="https://phimimg.com"   # CDN ảnh (dùng cho đường dẫn ảnh tương đối)
KKPHIM_REFERER="https://kkphim.com/"   # Referer gửi kèm khi phát / tải
KKPHIM_SEARCH_LIMIT="24"               # số kết quả mỗi trang
KKPHIM_DETAIL_TTL="600"                # giây cache thông tin phim
KKPHIM_SERVER_PREF="auto"              # auto | vietsub | long-tieng | thuyet-minh
KKPHIM_AD_BLOCK="1"                    # 1 = bỏ quảng cáo chèn trong playlist .m3u8
KKPHIM_AD_VARIANT="first"              # first (mượt) | max (nét) | 1..9
KKPHIM_AD_FOREIGN_HOST="1"             # 1 = bỏ khối segment ở tên miền lạ (adserver)
KKPHIM_AD_PATTERNS="ad,ads,advert,adserver,adtag,adslot,preroll,midroll,postroll,quangcao,promo,sponsor,vast,vmap,scte,banner"
```

**▶️ Phát phim & 🚫 chặn quảng cáo.** Quảng cáo của KKPhim **nằm ngay trong playlist `.m3u8`**
(SSAI): một khối segment quảng cáo được chèn vào giữa phim — thường gặp ở **~phút 14:58–15:00** —
bọc bởi `#EXT-X-CUE-OUT` / `#EXT-X-CUE-IN`. Trình phát phát đúng những gì playlist ghi, nên anisub
tải playlist (kèm `Referer` / `User-Agent`) rồi lọc **trước khi phát**:

1. nếu là **master playlist** thì chọn 1 variant (`KKPHIM_AD_VARIANT`, mặc định `first` — giống cách
   trình phát vẫn chọn, nên không bị "phát 3 giây đệm 3 giây" vì chọn nhầm bản quá nặng);
2. **bỏ toàn bộ khối giữa `CUE-OUT` và `CUE-IN`**, kể cả khi segment quảng cáo nằm **cùng host**
   với phim (đây chính là chỗ bản lọc cũ để lọt quảng cáo); `CUE-OUT` có ghi thời lượng thì bỏ đúng
   chừng ấy giây;
3. bỏ segment có host/đường dẫn khớp `KKPHIM_AD_PATTERNS` (so khớp **nguyên một thành phần**, nên
   `media`, `shadow`, `load`, `segment_1`… không bị xoá nhầm; query được bỏ qua nên `?ad=0` không tính);
4. bỏ **khối ngắn nằm ở tên miền khác** với CDN của phim (adserver) khi CDN phim chiếm >=70% segment
   — tắt bằng `KKPHIM_AD_FOREIGN_HOST="0"`;
5. đổi URL tương đối (`segment`, `#EXT-X-KEY`, `#EXT-X-MAP`) sang tuyệt đối để file local vẫn tải
   được, **giữ nguyên** `#EXT-X-MEDIA-SEQUENCE` / `#EXT-X-DISCONTINUITY-SEQUENCE` (IV mặc định của
   AES-128 + mốc `BYTERANGE`), và **chèn `#EXT-X-DISCONTINUITY` đúng chỗ cắt** để trình phát nối
   tiếp tức thì (không khựng, tua qua chỗ cắt vẫn đúng);
6. **chuẩn hoá thành VOD** (`#EXT-X-PLAYLIST-TYPE:VOD` + `#EXT-X-ENDLIST`) — playlist kiểu live mà
   để nguyên thì trình phát tải lại mỗi `TARGETDURATION` giây, đó là nguồn gốc của "phát vài giây
   lại khựng vài giây" ở bản cũ;
7. ghi ra `$TMPDIR/anisub-adfree-<pid>.m3u8`, phát file đó (tự xoá khi thoát).

**Tải tập** và **✂ cắt video** dùng chung bản đã lọc → bản tải về không còn quảng cáo và mốc thời
gian cắt khớp đúng với lúc xem. Playlist mã hoá AES-128 **không kèm `IV=`** thì anisub **không lọc**
(phát bản gốc) vì bỏ segment sẽ làm lệch IV → giải mã hỏng cả phim; tải/lọc lỗi cũng phát đúng link
gốc — không bao giờ làm bạn không xem được phim.

Chẩn đoán nhanh (in số segment giữ/bỏ, lý do bỏ, lưu playlist đã lọc):

```shell
./anisub.sh --kkphim-ad-debug "https://.../index.m3u8"
```

Bật/tắt và chỉnh trong `⚙️ Cài đặt → 🎞 Nguồn phim`:
**🚫 Chặn quảng cáo trong m3u8: bật/tắt**, **🎚️ Chất lượng khi lọc quảng cáo** (`first` / `max` /
`1..3`), **🏷️ Mẫu nhận diện quảng cáo**.

> Nếu **vẫn** thấy quảng cáo: chạy `--kkphim-ad-debug` với link m3u8 của tập đó rồi gửi mình file
> playlist in ra — quảng cáo chèn server-side hoàn toàn có thể nhận diện thêm bằng mẫu URL hoặc
> marker mới. Nếu phim **khựng** khi phát: đặt `🎚️ Chất lượng khi lọc quảng cáo` = `first`, hoặc tắt
> tạm `🚫 Chặn quảng cáo trong m3u8` để so sánh rồi báo lại.


> **Lưu ý:** link `.m3u8` của KKPhim được cấp theo từng lần gọi API và hết hạn sau vài phút,
> nên anisub luôn xin lại link khi bạn xem lại từ lịch sử, đổi server, hoặc khi trình phát
> chết ngay sau khi mở (sẽ có menu gợi ý "🔄 Lấy link mới").

<br>

### 🔍 Tìm kiếm không ra phim?

Vào `⚙️ Cài đặt → 🎞 Nguồn phim (KKPhim) → 🩺 Kiểm tra kết nối & phụ thuộc`: anisub sẽ kiểm tra
`curl / grep / jq / fzf / awk / sed / chafa / perl`, thử gọi thật `phimapi.com/v1/api/tim-kiem`
và in mã HTTP + số kết quả nhận được (bản này chính là thứ bạn cần gửi kèm khi báo bug).

| Kết quả chẩn đoán | Nguyên nhân | Cách xử lý |
| --- | --- | --- |
| `HTTP 000` | máy không với được `phimapi.com` | kiểm tra mạng / DNS / proxy / VPN, thử mạng khác |
| `HTTP 403`, `429`, `5xx` | KKPhim chặn theo khu vực hoặc đang bảo trì | thử lại sau; nếu họ đổi host thì sửa `KKPHIM_API_URL` / `KKPHIM_SITE_URL` |
| `HTTP 200 · 0 kết quả` | từ khóa không khớp | thử gõ không dấu, hoặc tên tiếng Việt đầy đủ có dấu |
| fzf quá cũ (không có action `reload:`, cần `>= 0.19`) | `--bind` bị báo lỗi, cửa sổ tìm không mở | anisub **tự chuyển** sang chế độ nhập từ khóa 1 lần (Enter để tải danh sách, vẫn gõ để lọc trong kết quả) |

<br>

### 📚 Đọc truyện tranh (nettruyen)

Nguồn mặc định là **`https://nettruyen.info`** (banner của site tự ghi tên miền chính thức là
`nettruyenn.org`, đây là mirror — cứ `MANGA_BASE_URL` mà đổi khi domain thay đổi). Truyện nằm ở
`/truyen-<slug>`, chương ở `/truyen-<slug>/chuong-<n>` (`chuong-0`, `chuong-1.5` có thật), ảnh trang
đọc trên `https://net.imgchapter.store/<slug>/<chap>/page_<i>.jpg`.

Danh sách chương **nằm sẵn trong HTML** trang truyện (`#nt_listchapter`) nên không cần API/CSRF;
tìm kiếm dùng `/tim-kiem?keyword=…`, thể loại dùng `/the-loai/<slug>`.

```shell
MANGA_SOURCE="nettruyen"                       # nettruyen (mặc định) | truyenvn
MANGA_BASE_URL="https://nettruyen.info"        # nguồn truyện (đổi được khi site đổi domain)
MANGA_SEARCH_FEEDS="latest,trending,views"     # chỉ dùng cho nguồn truyenvn khi tìm
MANGA_SEARCH_PAGES="1"                         # số trang của mỗi bảng (1-5)
MANGA_IMAGE_SCALE="130"                        # % độ rộng ảnh so với terminal (100 = full)
MANGA_IMAGE_PROTOCOL="auto"                    # auto | symbols | kitty | sixel | iterm
MANGA_READER_PROXY="https://r.jina.ai"         # "" hoặc "off" để tắt (xem bên dưới)
MANGA_DOH="auto"                               # auto | off — tự hỏi IP qua DNS-over-HTTPS khi DNS nhà mạng chặn
MANGA_PROXY=""                                 # vd socks5h://127.0.0.1:1080 (v2rayN/clash/ssh -D); "" = dùng https_proxy
EHENTAI_TAG="language:vietnamese"              # tag mở ra đầu tiên của nguồn e-hentai
EHENTAI_CHUNK="20"                             # số trang ảnh gộp thành 1 "chapter" (5-100)
EHENTAI_COOKIE=""                              # cookie đăng nhập e-hentai (chỉ khi gallery cần)
KAGANE_LANG=""                                 # lọc ngôn ngữ của kagane: "" = mọi ngôn ngữ, vd "vi" / "en"
KAGANE_COOKIE=""                               # cookie kagane.moe (chỉ cần cho truyện 18+)
TOON18X_LOCALE="vi"                            # mã ngôn ngữ trên URL toon18x: vi (mặc định), en...
```

Đổi nguồn không cần sửa file:
`⚙️ Cài đặt → 📚 Nguồn truyện → 🔁 Đổi nguồn truyện` — chọn trong menu fzf (✅ = nguồn đang dùng;
máy không có fzf thì vẫn gõ số 1/2/3/4/5). Nếu bộ `src/` là bản cũ (thiếu nguồn kagane / toon18x),
anisub **tự tải lại bộ nguồn khi khởi động**; không có mạng thì menu nguồn truyện nhắc rõ đang thiếu
nguồn nào và **chạy 🔄 Cập nhật** — cập nhật xong là thấy nguồn mới.
(máy đang dùng config cũ chưa có `MANGA_SOURCE` sẽ tự chuyển sang nettruyen một lần).

### 📚 Nguồn Kagane (`kagane.moe`)

Kagane là site tổng hợp manga/manhwa/manhua **đa ngôn ngữ** (60+), chạy SPA sau Cloudflare và
có API JSON riêng. anisub dùng:

| Việc | Cách anisub lấy |
| --- | --- |
| Duyệt truyện | `/search?sort=now` (đang hot) · `sort=updated_at,desc` (mới cập nhật) · `sort=avg_views_week,desc` (đọc nhiều tuần) |
| Tìm kiếm | `/search?q=<từ khoá>` + `languages=<KAGANE_LANG>` nếu bạn đặt ngôn ngữ |
| Danh sách chương | `GET /api/v2/series/<series_id>/books/index?fields=List` (bảng nén: `fields[]` + từng dòng) |
| Ảnh bìa | `<base>/api/v2/image/<image_id>/compressed` |
| Ảnh trang đọc | `POST /api/integrity` → `POST /api/v2/books/<book_id>?intent=Read` (kèm `x-integrity-token`) → `manifest.pages[]` → `<cache_url>/api/v2/books/page/original/<book_id>/<page_id>.<ext>?token=…` |

Vài điểm cần biết:

* **Token đọc chỉ sống vài phút**, anisub cache lại tới lúc hết hạn; ảnh trả `401/403/507` thì
  tự xin token mới rồi thử lại 1 lần. Hết cách vẫn lỗi thì báo rõ và in link để mở bằng trình duyệt.
* **Host ảnh đòi header `Origin`** của site (thiếu là 404), nên mọi request ảnh đều gửi kèm
  `Origin` + `Referer` của `MANGA_BASE_URL`.
* **Trang `/search` chỉ render server trang đầu** — tham số `page` lạ làm site trả danh sách rỗng,
  nên anisub duyệt trang đầu rồi lọc bằng 🔍 Tìm kiếm (bấm `__next__` sẽ có nhắc, không treo).
* **Thể loại** của Kagane nằm trong bộ lọc của SPA (không có route cố định), nên mục
  🗂 Theo thể loại tìm theo từ khoá tương ứng (action / romance / murim / isekai…).
* Truyện **18+** có thể cần `KAGANE_COOKIE` (cookie trình duyệt sau khi đã bấm xác nhận 18+).

### 📚 Nguồn Toon18x (`toon18x.com`)

Toon18x là site webtoon/manhwa **18+** có bản tiếng Việt ở `/vi`, render sẵn phía server nên đọc
được bằng `curl` thường. anisub dùng:

| Việc | Cách anisub lấy |
| --- | --- |
| Duyệt truyện | `/vi/search?sort=updated` (mới cập nhật) · `sort=followers` (theo dõi nhiều) · `sort=views` (đọc nhiều) |
| Tìm kiếm | `/vi/search?q=<từ khoá>` (`?keyword=` bị site bỏ qua) |
| Danh sách chương | `GET /api/v1/manga/<slug>/chapters?page=1&limit=200` (JSON; trang truyện chỉ in 20 chương mới nhất) |
| Ảnh bìa | `https://cdn.toon18x.com/covers/<slug>.webp` (thiếu thì về `default-cover.svg`) |
| Ảnh trang đọc | `<img>` trong `/vi/manga/<slug>/chapter/<số>` → `https://tv1.toon18x.com/series/<slug>/ch-<0000>/…` |

Vài điểm cần biết:

* **URL chương suy trực tiếp từ số chương** (`/chapter/<số>`) nên `Ctrl-G`, `n`/`p` và mở lại từ
  lịch sử luôn chạy, kể cả khi API danh sách chương lỗi. Chương lẻ như `11.5` được giữ nguyên.
* **Danh sách chương lấy từ API** vì trang truyện chỉ in 20 chương mới nhất; API trả mới-nhất-trước
  nên anisub sắp lại **tăng dần**. API không nói tổng số trang → anisub tải tiếp khi còn đủ 200 dòng
  (tối đa 10 lượt).
* **Ảnh trang không theo một mẫu cố định** (`ch-0001/001.png` hoặc `ch-0135/scrapes/<uuid>/001.png`),
  nên anisub **đọc URL từ HTML** rồi xếp theo số trang, không tự ghép URL.
* **Ngôn ngữ** đổi bằng `TOON18X_LOCALE` (mặc định `vi`) hoặc `⚙️ Cài đặt → 📚 Nguồn truyện →
  🌏 Ngôn ngữ Toon18x`; URL sẽ thành `https://toon18x.com/<mã>/manga/...`.
* **18+**: nguồn này chỉ chọn được khi bạn tự vào `📚 Nguồn truyện → 🔁 Đổi nguồn truyện` (anisub
  in cảnh báo 18+ mỗi lần đổi). Nội dung công khai, không cần cookie.

**Ba chỗ hay hỏng và cách anisub xử lý** (áp dụng cho cả hai nguồn)

1. **Ảnh bìa khi chọn truyện** — mỗi dòng danh sách là `Tên|URL|slug|ảnh bìa`; fzf hiện
   khung preview bên phải (ảnh được cache ở `~/.config/anisub_cli/cache/manga-covers/`).
   Với nettruyen, bìa lấy từ `data-src` / `data-lazy-src` / `src` (`/images/<slug>.jpg`,
   `/storage/thumbnails/<slug>.jpg`) và được nhớ lại để bước chọn chapter cũng preview được.
2. **Danh sách chương trên nettruyen** — đọc thẳng HTML: mọi link `/truyen-<slug>/chuong-<n>`
   trong trang, gỡ trùng, sắp xếp tăng dần theo số chương (`1 < 1.5 < 2 < 10`), bỏ chapter của
   truyện khác lẫn trong sidebar. Trang đổi cấu trúc thì vẫn đọc được bằng `n`/`p` (link
   `Chap trước/Chap sau` ngay trên trang chapter) hoặc `Ctrl-G` để nhập số chapter.
   *(Nguồn truyenvn thì khác: trang chỉ nhúng 2 link `Đọc từ đầu` + `Chap mới nhất`, còn
   danh sách thật do JavaScript lấy từ `POST /webapi/stories/list-chapter`
   (body `story_id=…&routeName=story.detail`, header `X-CSRF-TOKEN` lấy từ
   `<meta name="csrf-token">`, có cookie phiên). anisub gọi đúng API đó, tự tải lại trang khi
   gặp `HTTP 419` (phiên của web chỉ sống 60 giây), API lỗi thì mới fallback về 2 chapter và
   cảnh báo rõ ra màn hình. Nếu trang không còn `"story_id"`, anisub suy id từ URL ảnh bìa
   (`/books/<id>/cover_*.jpg`); nếu slug trên URL khác slug trong link chapter thì tự dò slug
   xuất hiện nhiều nhất trong danh sách để không lẫn chapter của truyện khác.)*
3. **Ảnh trang đọc không hiện** — với nettruyen, anisub lấy mọi URL `/page_<i>.(jpg|png|webp)`
   trong trang đọc (ưu tiên `data-src`, rồi `data-lazy-src`, rồi `src`), sắp theo đúng số trang và
   bỏ logo/banner. Trang không trả ảnh thì thử **dịch vụ đọc hộ**, cuối cùng tự dò theo mẫu URL
   (`HEAD` từng `page_0..` và dừng sau 3 lần trượt).
   Với truyenvn, CDN ảnh (`*.imggo.net`) trả **403 với mọi request có
   `Referer`**, nên anisub tải ảnh **không kèm Referer** và kiểm tra magic bytes trước khi vẽ.
   Ngoài ra anisub không còn ép `sixel` cho mọi terminal: `MANGA_IMAGE_PROTOCOL=auto` tự nhận
   `kitty`/`sixel`/`iterm`, terminal lạ thì vẽ bằng ký tự (`symbols`) nên **luôn thấy hình**.

```shell
# xem nhanh mình đang ở giao thức nào
⚙️ Cài đặt → 📚 Nguồn truyện → 🖼️ Kiểu hiển thị ảnh     # hoặc sửa MANGA_IMAGE_PROTOCOL trong config.cfg
```

Sửa nhanh: `⚙️ Cài đặt → 📚 Nguồn truyện` (đổi domain / số bảng / số trang) hoặc
`🩺 Kiểm tra nhanh nguồn truyện` trong cùng menu — chẩn đoán sẽ in mã HTTP và số truyện
parse được từ trang thật.

Bộ thử nghiệm chạy offline (mock `curl`/`fzf` + HTML mẫu của cả hai nguồn, không cần mạng):

```shell
bash tests/run_tests.sh     # 430+ check: nettruyen (URL, tìm kiếm, chapter, ảnh page_N, tự dò ảnh, menu),
                           # truyenvn (API chapter 419/500, 4 kiểu tải, proxy), kagane (parse /search,
                           # API chapter, token ảnh + tự làm mới, header Origin),
                           # toon18x (parse /vi/search, API /api/v1 chapters + phân trang,
                           # ảnh tv1. nhiều dạng URL, cảnh báo 18+), DoH/netcheck,
                           # ảnh bìa, tìm kiếm, lịch sử / yêu thích, giao thức vẽ ảnh
```

> **Tìm kiếm dùng tham số nào?** Với nettruyen: `/tim-kiem?keyword=<từ khóa>` rồi lọc lại
> tại máy (site có lúc trả danh sách chung). Với `truyenvn.my`, `/tim-kiem` lọc thật ở server bằng
> **`?search=<từ khóa>`** (`?q=` / `?keyword=` bị bỏ qua, trả về cả 49k truyện).
> anisub gửi `?search=` trước; chỉ khi server không trả mục nào khớp mới quét thêm các bảng
> `m_orderby=latest|trending|views` rồi lọc **tại máy**; gõ dấu cách vẫn khớp
> (`bo chi` → `Bocchi`), không cần gõ dấu.
> Không thấy gì? vào `🔗 Mở bằng link / slug` và dán thẳng link truyện
> (`https://nettruyen.info/truyen-one-piece-dao-hai-tac`) là đọc được ngay; hoặc duyệt theo
> `🗂️ Thể loại`. Muốn tìm phủ nhiều truyện hơn thì tăng `MANGA_SEARCH_PAGES` lên `3`–`5`.
>
> Trong lúc đọc: `n` chap sau · `p` chap trước · `c` chọn chap khác · `r` tải lại ·
> `f` ⭐ · `q` thoát. Việc chuyển chap dựa vào link "Chap trước/Chap sau" của chính
> trang chapter, nên **không phụ thuộc** API danh sách chapter; `Ctrl-G` ở màn chọn
> chapter cho phép nhập thẳng số chapter muốn đọc (vd `120`, `9.5`).

**Bị chặn khi tải trang chapter?** Với nettruyen, anisub thử theo thứ tự: tải trực tiếp → dịch vụ
đọc hộ → tự dò mẫu URL ảnh, nên chỉ cần trang chapter còn mở được là sẽ ra ảnh.
Với TruyenVN, trang có lúc trả bản HTML rút gọn (không có `<img>`)
cho request "không giống trình duyệt". anisub tự thử lần lượt 4 kiểu tải:
`normal` → `minimal` (không cookie/referer) → `bot` (UA Googlebot) → **`proxy`**
(mặc định `https://r.jina.ai` đọc hộ bằng trình duyệt thật rồi trả markdown). Chỉ khi
kiểu trước không ra ảnh mới dùng kiểu sau. Tắt dịch vụ đọc hộ (không gửi link truyện ra
bên thứ ba): `⚙️ Cài đặt → 📚 Nguồn truyện → 🛡 Dịch vụ đọc hộ` hoặc đặt
`MANGA_READER_PROXY="off"` trong `~/.config/anisub_cli/config.cfg`.

**Bấm `📚 Đọc Truyện Tranh` mà không có gì xảy ra / menu truyện trống?** Gần như chắc là máy
đang thiếu thư mục `src/` (bản cài cũ chỉ có 1 file `anisub.sh`, hoặc `src/` bị xoá/di chuyển).
anisub sẽ tự tải `src/` về khi chạy; nếu mạng đang tắt thì chép lại cả repo. Kiểm tra bằng:

```shell
./anisub.sh --doctor        # in ra: script ở đâu · nạp module nào · thiếu gói gì · nguồn truyện nào
```

Chạy xong mà vẫn lỗi thì gửi nguyên kết quả:

```shell
./anisub.sh --doctor 2>&1 | tee anisub-doctor.txt
```

Kiểm tra nhanh toàn bộ luồng đọc: vào `📚 Truyện tranh` → **`🧪 Kiểm tra đọc truyện (chẩn đoán)`**
(kết quả được lưu vào `~/.config/anisub_cli/cache/manga-selftest.txt`), hoặc bằng **một lệnh**:

```shell
./anisub.sh --version                          # xem đang chạy bản nào
./anisub.sh --doctor                           # 🩺 kiểm tra module src/, phụ thuộc, nguồn truyện (tự tải src/ nếu thiếu)
./anisub.sh --netcheck e-hentai.org            # 🔒 bị chặn ở đâu: DNS hệ thống / DoH / IP / TLS — kèm cách sửa
tail -n 20 ~/.config/anisub_cli/cache/anisub-debug.log   # log mở menu truyện / lựa chọn của fzf
./anisub.sh --manga-selftest                   # tự chọn truyện mẫu theo nguồn đang dùng
./anisub.sh --manga-selftest one-piece-dao-hai-tac
# 1️⃣ trang truyện (HTTP + kích thước)  2️⃣ danh sách chapter (HTTP + số chapter)
# 3️⃣ trang chapter (số ảnh + link chap trước/sau)  4️⃣ tải thử 1 ảnh  5️⃣ chafa
```

| Kết quả | Nguyên nhân | Cách xử lý |
| --- | --- | --- |
| Bấm **📚 Đọc Truyện Tranh** nháy một cái rồi quay lại menu chính | fzf trả về rỗng (Esc, terminal quá thấp, hoặc fzf lỗi) | anisub đã báo rõ số lần fzf trả về; xem `~/.config/anisub_cli/cache/anisub-debug.log` (dòng `comic-menu:`) rồi gửi kèm khi báo lỗi |
| Bấm **📚 Đọc Truyện Tranh** không có gì xảy ra / menu truyện trống | thiếu thư mục `src/` (chỉ có `anisub.sh`, hoặc cập nhật dở) | chạy `./anisub.sh --doctor` (tự tải `src/` về); không có mạng thì `git clone https://github.com/NiyakiPham/anisub.git` |
| Trong Cài đặt **không thấy nguồn kagane** | bộ `src/` trên máy là bản cũ (chưa cập nhật) | chạy `🔄 Cập nhật` ở menu chính hoặc `./anisub.sh --update` rồi mở lại; menu nguồn truyện có dòng nhắc khi phát hiện bản cũ |
| Trong Cài đặt **không thấy nguồn toon18x** (hoặc nguồn mới bất kỳ) | bộ `src/` trên máy là bản cũ — thiếu module nguồn | **Từ `2026.11.12b` anisub tự xử lý**: khi khởi động thấy thiếu module là tự tải lại bộ nguồn (bản cài git thì `git pull`), xong mới mở menu. Mất mạng thì nó in rõ `Đang dùng bộ nguồn cũ … Thiếu nguồn: toon18x` + nhắc `./anisub.sh --update`; dòng `📚 Nguồn truyện` trong ⚙️ Cài đặt gắn `⚠️ thiếu nguồn: toon18x`. Kiểm tra bằng `./anisub.sh --doctor` (mục `⚠️ Thiếu module nguồn`) |
| Toon18x: `API Toon18x lỗi (HTTP 404)` | sai slug / site đổi route | dán link thật dạng `https://toon18x.com/vi/manga/<slug>`; nghi bị chặn thì `./anisub.sh --netcheck toon18x.com` |
| Toon18x: `Trang đọc không có ảnh nào` | chương chưa có ảnh hoặc site đổi cấu trúc | mở link in kèm bằng trình duyệt; gửi kèm URL chương khi báo lỗi |
| Kagane: ảnh trang `401/403/507` | token đọc hết hạn hoặc truyện 18+ chưa xác nhận | anisub tự xin token mới 1 lần; vẫn lỗi thì đặt `KAGANE_COOKIE` hoặc `./anisub.sh --netcheck kagane.moe` |
| Đổi DNS rồi **vẫn** `HTTP 000` | nhà mạng chặn theo IP/SNI, không chỉ DNS | `./anisub.sh --netcheck e-hentai.org` để xem lớp nào bị chặn; DNS chặn thì anisub tự đi DoH, còn IP/SNI chặn thì cần VPN/proxy (`MANGA_PROXY`, `https_proxy`) |
| `HTTP 000` | không với được trang nguồn | anisub in kèm mã lỗi curl: `6` DNS (đổi DNS 1.1.1.1), `7` bị chặn/không kết nối, `28` timeout, `35/60` TLS. Với **e-hentai**: site hay bị nhà mạng VN chặn → bật VPN, hoặc bấm `1` để đổi sang nettruyen |
| `HTTP 403` / Cloudflare challenge | trang chặn client không phải trình duyệt | anisub đã gửi User-Agent trình duyệt; thử lại sau, hoặc đổi `MANGA_BASE_URL` sang domain mirror (nettruyen: `nettruyenn.org`, truyenvn: domain mới) |
| `❌ Không tìm thấy hình ảnh` khi đọc chapter nettruyen | trang đọc không trả `<img>` hoặc đổi host ảnh | chạy `./anisub.sh --manga-selftest <slug>`; xem `~/.config/anisub_cli/cache/manga-debug.txt`; bấm `o` để mở chapter bằng trình duyệt |
| `❌ Không lấy được danh sách chapter` | slug sai hoặc trang đổi layout | dùng `🔗 Mở bằng link / slug` dán link thật từ trình duyệt |
| Chỉ có ~2 chapter (đầu + cuối) | API `list-chapter` đổi đường dẫn / chặn | vẫn đọc được: chọn 1 chapter rồi dùng `n`/`p`, hoặc `Ctrl-G` để nhảy tới số chapter bất kỳ; chạy `./anisub.sh --manga-selftest <slug>` để xem HTTP của API |
| Trong chapter báo "Không tìm thấy hình ảnh" (anisub tự thử 4 kiểu: normal → minimal → bot → **dịch vụ đọc hộ**) | trang chapter trả bản không có `<img>` (Cloudflare / chỉ render bằng JS), hoặc site đổi markup | xem `~/.config/anisub_cli/cache/manga-debug.txt` (dòng `challenge:` và `img tags:`) — file này ghi HTTP, số thẻ `img`, số URL ảnh; gửi kèm khi báo lỗi. Trong lúc chờ, bấm `o` để mở chapter bằng trình duyệt |
| Không đọc được chapter / ảnh không hiện | chưa rõ bước hỏng | chạy `./anisub.sh --manga-selftest <slug>`: in ra HTTP + số chapter + số ảnh + tải thử 1 ảnh, chỉ đúng bước lỗi |
| Chọn truyện không thấy ảnh bìa | thiếu `chafa`, hoặc terminal không vẽ được ảnh | `sudo apt install chafa`; đổi `MANGA_IMAGE_PROTOCOL` sang `symbols` |
| Danh sách rỗng khi tìm | từ khóa quá ngắn / nằm ngoài các bảng đang quét | gõ ≥ 2 ký tự, tăng `MANGA_SEARCH_PAGES`, hoặc lọc theo `🗂️ Thể loại` |
| Ảnh đen / không hiện | thiếu `chafa`, hoặc giao thức vẽ ảnh không khớp terminal | `sudo apt install chafa` (hoặc `yay -S chafa`); đặt `MANGA_IMAGE_PROTOCOL=symbols` để chắc chắn thấy hình; `Enter` luôn mở ảnh bằng ứng dụng ngoài |

<br>


### 🔞 Đọc truyện trên e-hentai

Nguồn **`https://e-hentai.org`** (nội dung người lớn — 18+, bạn tự chịu trách nhiệm khi bật).
e-hentai là hệ **gallery ảnh**, nên anisub quy ước:

| Trên anisub | Trên e-hentai |
| --- | --- |
| 1 "truyện" | 1 gallery `https://e-hentai.org/g/<id>/<token>/` |
| 1 "chapter" | 1 nhóm trang ảnh (mặc định **20 trang**: `Trang 1–20/123`) |
| thể loại | tag (`language:vietnamese`, `language:vietnamese manga`, …) |

- **Danh sách mặc định** = tag `EHENTAI_TAG` (mặc định `language:vietnamese`) →
  `https://e-hentai.org/tag/language:vietnamese`. Đổi tag bằng
  `⚙️ Cài đặt → 📚 Nguồn truyện → 🏷 Tag mặc định (e-hentai)` hoặc chọn `🗂 Theo thể loại`.
- **Phân trang**: e-hentai dùng link `Next >` (`?next=<id>`) chứ không phải `?page=N`,
  nên menu duyệt của e-hentai tự đọc link "Next" từ trang vừa tải.
- **Đọc ảnh**: link ảnh thật chỉ có trong trang xem từng ảnh (`/s/<token>/<id>-<i>`, thẻ
  `<img id="img">`). Đọc 1 nhóm 20 trang = 20 request, anisub **cache** link ảnh ở
  `~/.config/anisub_cli/cache/ehentai/` nên lần sau mở lại gần như tức thì. Có delay
  `EHENTAI_DELAY` (mặc định 0.4s) giữa các request để không bị chặn "Excessive pageloads".
- **Gallery giới hạn/18+**: dán cookie đăng nhập vào
  `⚙️ Cài đặt → 📚 Nguồn truyện → 🍪 Cookie e-hentai` (F12 → Network → copy header `cookie`,
  thường có `ipb_member_id=…; ipb_pass_hash=…; sk=…`). Không có cookie vẫn xem được gallery
  công khai.
- **Lỗi hay gặp**: `Excessive pageloads` / IP bị khoá tạm → chờ 2-5 phút; trang báo cần đăng
  nhập → thêm cookie; `Không đọc được số trang của gallery` → kiểm tra lại link `/g/<id>/<token>/`.
- **Lịch sử / yêu thích** lưu gallery dạng `id/token` nên mở lại đúng gallery, đúng nhóm trang.

Gõ tay từ dòng lệnh:

```shell
MANGA_SOURCE=ehentai MANGA_BASE_URL=https://e-hentai.org ./anisub.sh --manga-selftest "https://e-hentai.org/g/4313400/7fcc76c845/"
```

### 🧩 Cấu trúc mã nguồn (src/)

Code đã tách khỏi 1 file duy nhất để dễ bảo trì. `anisub.sh` chỉ còn phần cấu hình, tiện ích,
lịch sử/yêu thích, cài đặt, menu chính và **bộ nạp module**:

```text
anisub.sh                 # khởi động + menu chính + nạp src/ (anisub_load_sources)
src/movie/kkphim.sh       # nguồn phim KKPhim: API, danh mục, server, tập, phát phim
src/movie/media.sh        # tải / cắt / ghép video, mở link, xem file local
src/comic/core.sh         # engine đọc truyện dùng chung (HTTP, ảnh, fzf, khung đọc, menu)
src/comic/nettruyen.sh    # nguồn nettruyen.info
src/comic/truyenvn.sh     # nguồn truyenvn.my
src/comic/ehentai.sh      # nguồn e-hentai.org
```

- Mọi file `src/movie/*.sh` và `src/comic/*.sh` được nạp tự động (theo tên file) —
  **thêm nguồn mới chỉ cần thêm 1 file**, không sửa `anisub.sh`.
- Chạy ở nơi khác (hoặc nhúng vào script khác): đặt `ANISUB_SRC_DIR=/duong/dan/src`.
- Nếu thiếu `src/` (ví dụ chỉ tải mỗi `anisub.sh`), anisub báo rõ và dừng — hãy clone cả repo.
- `🔄 Cập nhật` tải archive `main` của GitHub rồi cập nhật **cả** `anisub.sh` và `src/`.
- Test offline: `bash tests/run_tests.sh` (không cần mạng, mọi request đi qua `tests/mockbin`).

## INSTALL

UBUNTU
```shell
sudo apt install ffmpeg curl grep yt-dlp fzf pup jq mawk cut chafa mpv
```
Nếu có gói nào chưa đưọc cài đặt thì bạn cài riêng ra nhé <br>

ARCH LINUX
```shell
yay -S ffmpeg curl grep yt-dlp fzf pup manga-tui jq awk cutafa chafa mpv
```

## RUN

> ⚠️ Anisub giờ gồm nhiều file (`anisub.sh` + `src/`). Hãy **clone cả repo**, đừng tải mỗi
> `anisub.sh`: `git clone https://github.com/NiyakiPham/anisub.git && cd anisub`

Cấp quyền cho file
```shell
chmod +x anisub.sh
```

Chạy File
```shell
./anisub.sh
```

<br>

Nếu bạn đang dùng bashrc thì vào file bashrc, ở đây mình dùng zshrc các ví dụ bạn đang dùng bashrc thì nano bash hay vim,... sau đó gán lệnh này vô

```shell
alias anisub='bash $HOME/anilink/anisub.sh'
```
<br>

- Các bạn lưu File anisub.sh ở đâu thì trỏ nó đến đường dẫn đó nhé
- Lệnh alias cho phép ngụy trang câu lệnh ( do mình lười viết file install )
- Sau khi các bạn gán lệnh này vô bashrc hay zshrc thì khởi động lại máy cho chắc ăn
- Bạn mở terminal rồi gõ anisub
<br>
CHÚC CÁC BẠN THÀNH CÔNG

## CONTACT
Nếu trong quá trình thực hiện mà bạn gặp lỗi gì hãy liên hệ với mình qua FB. Cảm ơn các bạn đã đọc bài viết này, nếu thấy project này thú vị đừng quên cho mình xin một sao trên github để mình có động lực ra nhiều tính năng hay cho project này nha. CẢM ƠN CÁC CẬU

## LƯU Ý
WEB MÀ MÌNH ĐANG SỬ DỤNG CÓ CHỨA QC BỌN LÀM WEB TÍNH CẢ RỒI NÓ SẼ CHÈN MỘT SRC NHÚNG VÀO TỆP M3U8 KHI ĐẾN MỘT KHOẢNG TIME NÀO ĐÓ NÓ SẼ HIỆN QC NÊN NẾU BẠN CỐ TÌNH SKIP THÌ NÓ SẼ CHO CÁC BẠN XEM LẠI TỪ ĐÂU
