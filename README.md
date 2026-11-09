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
《📺》- Thêm gợi ý từ khóa<br>
《📺》- Thêm data từ kkphim, nguồn ophim sang dạng cào<br>
《📖》- Tích hợp truyenvn ( manga thì đọc oke còn webtoon thì như hạch ) <br>
《📖》- Đổi nguồn truyện sang `truyenvn.my`, sửa lỗi không tải được danh sách chapter / ảnh trang đọc<br>
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
《📚》- **TruyenVN** — `https://truyenvn.my` : đọc truyện tranh (cào HTML + API nội bộ `list-chapter`, không cần API key) <br>
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
```

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

### 📚 Đọc truyện tranh (TruyenVN)

Nguồn truyện mới là `https://truyenvn.my` (trang cũ `truyenvn.shop` đã đổi nên không đọc được nữa).
Danh sách truyện và ảnh trang đọc cào thẳng HTML; riêng **danh sách chương** phải gọi API
nội bộ của web (xem ghi chú bên dưới).

```shell
MANGA_BASE_URL="https://truyenvn.my"           # nguồn truyện (đổi được khi site đổi domain)
MANGA_SEARCH_FEEDS="latest,trending,views"     # các bảng sẽ quét khi tìm
MANGA_SEARCH_PAGES="1"                         # số trang của mỗi bảng (1-5)
MANGA_IMAGE_SCALE="130"                        # % độ rộng ảnh so với terminal (100 = full)
MANGA_IMAGE_PROTOCOL="auto"                    # auto | symbols | kitty | sixel | iterm
```

**Ba chỗ hay hỏng và cách anisub xử lý**

1. **Ảnh bìa khi chọn truyện** — mỗi dòng danh sách là `Tên|URL|slug|ảnh bìa`; fzf hiện
   khung preview bên phải (ảnh được cache ở `~/.config/anisub_cli/cache/manga-covers/`).
2. **Danh sách chương** — trang truyện chỉ nhúng 2 link `Đọc từ đầu` + `Chap mới nhất`, còn
   danh sách thật do JavaScript lấy từ `POST /webapi/stories/list-chapter`
   (body `story_id=…&routeName=story.detail`, header `X-CSRF-TOKEN` lấy từ
   `<meta name="csrf-token">`, có cookie phiên). anisub gọi đúng API đó, tự tải lại trang khi
   gặp `HTTP 419` (phiên của web chỉ sống 60 giây), API lỗi thì mới fallback về 2 chapter và
   cảnh báo rõ ra màn hình.
3. **Ảnh trang đọc không hiện** — CDN ảnh (`*.imggo.net`) trả **403 với mọi request có
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

Bộ thử nghiệm chạy offline (mock `curl`/`fzf` + HTML mẫu của TruyenVN, không cần mạng):

```shell
bash tests/run_tests.sh     # parse danh sách + ảnh bìa, API chapter (419/500), tải ảnh không Referer,
                           # giao thức vẽ ảnh, script preview bìa, tìm kiếm, lịch sử / yêu thích
```

> **Tìm kiếm dùng tham số nào?** `/tim-kiem` của `truyenvn.my` lọc thật ở server bằng
> **`?search=<từ khóa>`** (`?q=` / `?keyword=` bị bỏ qua, trả về cả 49k truyện).
> anisub gửi `?search=` trước; chỉ khi server không trả mục nào khớp mới quét thêm các bảng
> `m_orderby=latest|trending|views` rồi lọc **tại máy**; gõ dấu cách vẫn khớp
> (`bo chi` → `Bocchi`), không cần gõ dấu.
> Không thấy gì? vào `🔗 Mở bằng link / slug` và dán thẳng link truyện
> (`https://truyenvn.my/truyen-tranh/bocchi-the-rock`) là đọc được ngay; hoặc duyệt theo
> `🗂️ Thể loại`. Muốn tìm phủ nhiều truyện hơn thì tăng `MANGA_SEARCH_PAGES` lên `3`–`5`.

| Kết quả | Nguyên nhân | Cách xử lý |
| --- | --- | --- |
| `HTTP 000` | không với được `truyenvn.my` | kiểm tra mạng / DNS / VPN, hoặc `curl -I https://truyenvn.my` |
| `HTTP 403` / Cloudflare challenge | trang chặn client không phải trình duyệt | anisub đã gửi User-Agent trình duyệt; thử lại sau, hoặc đổi `MANGA_BASE_URL` sang domain mirror của TruyenVN |
| `❌ Không lấy được danh sách chapter` | slug sai hoặc trang đổi layout | dùng `🔗 Mở bằng link / slug` dán link thật từ trình duyệt |
| Chỉ có ~2 chapter (đầu + cuối) | API `list-chapter` đổi đường dẫn / chặn | chạy `🩺 Kiểm tra nguồn truyện` để xem HTTP của API, rồi báo lên repo |
| Chọn truyện không thấy ảnh bìa | thiếu `chafa`, hoặc terminal không vẽ được ảnh | `sudo apt install chafa`; đổi `MANGA_IMAGE_PROTOCOL` sang `symbols` |
| Danh sách rỗng khi tìm | từ khóa quá ngắn / nằm ngoài các bảng đang quét | gõ ≥ 2 ký tự, tăng `MANGA_SEARCH_PAGES`, hoặc lọc theo `🗂️ Thể loại` |
| Ảnh đen / không hiện | thiếu `chafa`, hoặc giao thức vẽ ảnh không khớp terminal | `sudo apt install chafa` (hoặc `yay -S chafa`); đặt `MANGA_IMAGE_PROTOCOL=symbols` để chắc chắn thấy hình; `Enter` luôn mở ảnh bằng ứng dụng ngoài |

<br>

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
