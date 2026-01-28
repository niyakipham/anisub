#!/bin/bash

# --- CONFIGURATION & DATA FILES ---
CONFIG_DIR="$HOME/.config/anisub_cli"
CONFIG_FILE="$CONFIG_DIR/config.cfg"
HISTORY_FILE="$CONFIG_DIR/history.log"
FAVORITES_FILE="$CONFIG_DIR/favorites.txt"
MANGA_HISTORY_FILE="$CONFIG_DIR/manga_history.log"
MANGA_FAVORITES_FILE="$CONFIG_DIR/manga_favorites.txt"
SCRIPT_URL="https://raw.githubusercontent.com/NiyakiPham/anisub/main/anisub.sh"

# Local Data File
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DATA_FILE="$SCRIPT_DIR/assets/aniw_export_2026-01-14.csv"

# --- DEFAULTS ---
DEFAULT_PLAYER="mpv"
DEFAULT_DOWNLOAD_DIR="$HOME/Downloads/anime"
DEFAULT_MANGA_IMAGE_SCALE=130  # Phần trăm kích thước hình ảnh (100 = full terminal, 130 = 30% lớn hơn)
PLAYER=""
DOWNLOAD_DIR=""
MANGA_IMAGE_SCALE=""

# --- UTILITY FUNCTIONS ---
ensure_config_dir() {
    mkdir -p "$CONFIG_DIR"
}

load_config() {
    ensure_config_dir
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "PLAYER=$DEFAULT_PLAYER" > "$CONFIG_FILE"
        echo "DOWNLOAD_DIR=$DEFAULT_DOWNLOAD_DIR" >> "$CONFIG_FILE"
    fi
    source "$CONFIG_FILE"
    PLAYER=${PLAYER:-$DEFAULT_PLAYER}
    DOWNLOAD_DIR=${DOWNLOAD_DIR:-$DEFAULT_DOWNLOAD_DIR}
    MANGA_IMAGE_SCALE=${MANGA_IMAGE_SCALE:-$DEFAULT_MANGA_IMAGE_SCALE}
    mkdir -p "$DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR/cut"
    mkdir -p "$DOWNLOAD_DIR/merged"
    touch "$HISTORY_FILE" "$FAVORITES_FILE" "$MANGA_HISTORY_FILE" "$MANGA_FAVORITES_FILE"
}

save_config() {
    echo "PLAYER=$PLAYER" > "$CONFIG_FILE"
    echo "DOWNLOAD_DIR=$DOWNLOAD_DIR" >> "$CONFIG_FILE"
    echo "MANGA_IMAGE_SCALE=$MANGA_IMAGE_SCALE" >> "$CONFIG_FILE"
    echo "Cấu hình đã được lưu."
    sleep 1
}

check_dependencies() {
    local missing_deps=()
    local deps=("ffmpeg" "curl" "grep" "yt-dlp" "fzf" "jq" "awk" "sed" "chafa" "perl")
    echo "Kiểm tra các phụ thuộc hệ thống..."
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "LỖI: Thiếu các phụ thuộc sau: ${missing_deps[*]}"
        echo "Vui lòng cài đặt chúng trước khi sử dụng."
        if [[ " ${missing_deps[*]} " == *"chafa"* ]]; then
            echo "Gợi ý: Cài đặt chafa để xem được hình ảnh (apt install chafa / brew install chafa / pkg install chafa)"
        fi
        exit 1
    fi
}

# --- HISTORY FUNCTIONS ---
add_to_history() {
    local anime_name="$1"
    local episode_number="$2"
    local link="$3"
    sed -i "/|${anime_name}|${episode_number}|/d" "$HISTORY_FILE"
    echo "$(date +%Y-%m-%d\ %H:%M:%S)|${anime_name}|${episode_number}|${link}" >> "$HISTORY_FILE"
}

show_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        echo "Lịch sử xem trống."
        sleep 2
        return
    fi
    selected_history=$(tac "$HISTORY_FILE" | fzf --prompt="Lịch sử xem (Enter để xem lại): " --delimiter='|' --with-nth=1,2,3)
    if [ -n "$selected_history" ]; then
        local link=$(echo "$selected_history" | cut -d'|' -f4)
        local anime_name=$(echo "$selected_history" | cut -d'|' -f2)
        local episode_number=$(echo "$selected_history" | cut -d'|' -f3)
        echo "Đang phát lại: $anime_name - Tập $episode_number..."
        play_stream "$link" "$anime_name - $episode_number"
    fi
}

# --- FAVORITES FUNCTIONS ---
add_to_favorites() {
    local name="$1"
    local slug="$2"
    if grep -q "|$slug\$" "$FAVORITES_FILE"; then
        echo "'$name' đã có trong danh sách yêu thích."
    else
        echo "$name|$slug" >> "$FAVORITES_FILE"
        echo "Đã thêm '$name' vào danh sách yêu thích."
    fi
    sleep 2
}

show_favorites() {
    if [ ! -s "$FAVORITES_FILE" ]; then
        echo "Danh sách yêu thích trống."
        sleep 2
        return 1
    fi
    selected_favorite=$(fzf --prompt="Anime yêu thích: " --delimiter='|' --with-nth=1 < "$FAVORITES_FILE")
    if [ -n "$selected_favorite" ]; then
        echo "$selected_favorite" 
        return 0
    else
        return 1
    fi
}

# --- KKPHIM API FUNCTIONS ---
api_get_episodes_kkphim() {
    local slug="$1"
    local api_url="https://phimapi.com/phim/$slug"
    local json=$(curl -s "$api_url")
    
    local status=$(echo "$json" | jq -r '.status')
    if [ "$status" = "false" ]; then 
        return 1
    fi
    
    echo "$json" | jq -r '.episodes[0].server_data[] | "\(.name)|\(.link_m3u8)"'
}

play_stream() {
    local url="$1"
    local title="$2"
    
    # Kill any existing player instance to avoid conflicts
    killall "$PLAYER" 2>/dev/null
    
    # Launch player in background
    "$PLAYER" "$url" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window --title="Anisub: $title" &
    PLAYER_PID=$!
}

# --- HELPER FOR NEXT/PREV LOGIC ---
find_adjacent_episode() {
    local current_name="$1"
    local list_raw="$2"
    local mode="$3" # "next" or "prev"
    
    # Convert list to array
    mapfile -t eps_array <<< "$list_raw"
    
    local current_index=-1
    for i in "${!eps_array[@]}"; do
        # Extract name from "Name|Link"
        local ep_name=$(echo "${eps_array[$i]}" | cut -d'|' -f1)
        if [ "$ep_name" = "$current_name" ]; then
            current_index=$i
            break
        fi
    done
    
    if [ $current_index -eq -1 ]; then
        return 1
    fi
    
    local target_index
    if [ "$mode" = "next" ]; then
        target_index=$((current_index + 1))
    else
        target_index=$((current_index - 1))
    fi
    
    if [ $target_index -ge 0 ] && [ $target_index -lt ${#eps_array[@]} ]; then
        echo "${eps_array[$target_index]}"
        return 0
    fi
    
    return 1
}

# --- CONTROL PLAYER MENU ---
manage_currently_playing() {
    local name="$1"
    local current_ep_name="$2"
    local link="$3"
    local episode_list_raw="$4"
    local anime_slug="$5"
    local user_wants_quit=0
    
    play_stream "$link" "$name - Tập $current_ep_name"
    
    # Loop while player is running
    while kill -0 "$PLAYER_PID" 2>/dev/null; do
        header="Đang phát: $name - Tập $current_ep_name"
        action=$(echo -e "⏭ Tiếp theo\n⏮ Trước đó\n📜 Chọn tập khác\n⬇ Tải tập này\n✂ Cắt Video (1 lần)\n✂✂ Cắt Video (Nhiều lần)\n🧬 Ghép Video\n❤️ Thêm vào Yêu Thích\n🔙 Quay lại Menu Chính" | fzf --prompt="$header > " --header="[Player đang chạy. Chọn tác vụ không cần tắt player]")
        
        case "$action" in
            "⏭ Tiếp theo")
                kill "$PLAYER_PID" 2>/dev/null
                sleep 0.5
                # Logic tự động chuyển tập tiếp theo
                next_data=$(find_adjacent_episode "$current_ep_name" "$episode_list_raw" "next")
                if [ -n "$next_data" ]; then
                    current_ep_name=$(echo "$next_data" | cut -d'|' -f1)
                    link=$(echo "$next_data" | cut -d'|' -f2)
                    add_to_history "$name" "$current_ep_name" "$link"
                    play_stream "$link" "$name - Tập $current_ep_name"
                else
                    echo "Đã hết tập (Tập cuối)."
                    sleep 1
                    # If end of list, maybe restart player with current ep or just stop
                    # Here we break loop to return to selection or exit
                    user_wants_quit=1
                fi
                ;;
            "⏮ Trước đó")
                kill "$PLAYER_PID" 2>/dev/null
                sleep 0.5
                # Logic tự động chuyển tập trước
                prev_data=$(find_adjacent_episode "$current_ep_name" "$episode_list_raw" "prev")
                if [ -n "$prev_data" ]; then
                    current_ep_name=$(echo "$prev_data" | cut -d'|' -f1)
                    link=$(echo "$prev_data" | cut -d'|' -f2)
                    add_to_history "$name" "$current_ep_name" "$link"
                    play_stream "$link" "$name - Tập $current_ep_name"
                else
                    echo "Đây là tập đầu tiên."
                    sleep 1
                    play_stream "$link" "$name - Tập $current_ep_name" # Resume
                fi
                ;;
            "📜 Chọn tập khác")
                kill "$PLAYER_PID" 2>/dev/null
                new_selection=$(echo "$episode_list_raw" | fzf --prompt="Chọn tập: " --delimiter='|' --with-nth=1)
                 if [ -n "$new_selection" ]; then
                     current_ep_name=$(echo "$new_selection" | cut -d'|' -f1)
                     link=$(echo "$new_selection" | cut -d'|' -f2)
                     add_to_history "$name" "$current_ep_name" "$link"
                     play_stream "$link" "$name - Tập $current_ep_name"
                 else
                     # User cancelled selection, replay current
                     play_stream "$link" "$name - Tập $current_ep_name"
                 fi
                ;;
            "⬇ Tải tập này") download_video "$link" "$name - Tap $current_ep_name" & ;;
            "✂ Cắt Video (1 lần)") cut_video_logic "$link" "single" ;;
            "✂✂ Cắt Video (Nhiều lần)") cut_video_logic "$link" "multi" ;;
            "🧬 Ghép Video") merge_video_logic ;;
            "❤️ Thêm vào Yêu Thích") add_to_favorites "$name" "$anime_slug" ;;
            "🔙 Quay lại Menu Chính") kill "$PLAYER_PID" 2>/dev/null; user_wants_quit=1; break ;;
             *) kill "$PLAYER_PID" 2>/dev/null; user_wants_quit=1; break ;;
        esac
    done

    # --- XỬ LÝ KHI VIDEO XEM HẾT (KHI PLAYER TỰ ĐỘNG TẮT) ---
    if [ $user_wants_quit -eq 0 ]; then
        clear
        echo "-----------------------------------"
        echo "  Đã xem xong: $name - $current_ep_name"
        echo "-----------------------------------"
        
        # Tìm tập tiếp theo để gợi ý
        next_ep_data=$(find_adjacent_episode "$current_ep_name" "$episode_list_raw" "next")
        local next_option=""
        if [ -n "$next_ep_data" ]; then
            local next_name=$(echo "$next_ep_data" | cut -d'|' -f1)
            next_option="▶ Phát Tập Tiếp Theo: $next_name\n"
        fi

        end_action=$(echo -e "${next_option}🔄 Xem lại tập này\n🔙 Quay lại Menu Chính" | fzf --prompt="Bạn muốn làm gì tiếp theo? > ")
        
        case "$end_action" in
            "▶ Phát Tập Tiếp Theo"*)
                # Recursive call để chơi tập tiếp theo
                local n_name=$(echo "$next_ep_data" | cut -d'|' -f1)
                local n_link=$(echo "$next_ep_data" | cut -d'|' -f2)
                manage_currently_playing "$name" "$n_name" "$n_link" "$episode_list_raw" "$anime_slug"
                ;;
            "🔄 Xem lại tập này")
                manage_currently_playing "$name" "$current_ep_name" "$link" "$episode_list_raw" "$anime_slug"
                ;;
            *)
                # Quay lại menu chính (không làm gì cả, loop sẽ thoát)
                ;;
        esac
    fi
}

# --- MEDIA PROCESSING FUNCTIONS ---
download_video() {
    local url="$1"
    local filename="$2"
    local folder="$DOWNLOAD_DIR/$(echo "$filename" | awk -F' - ' '{print $1}')"
    
    mkdir -p "$folder"
    safe_name=$(echo "$filename" | sed 's/[^a-zA-Z0-9 .-]/_/g')
    
    echo "Đang tải xuống: $safe_name..."
    if command -v yt-dlp &> /dev/null; then
        yt-dlp "$url" -o "$folder/$safe_name.mp4"
    else
        ffmpeg -i "$url" -c copy -bsf:a aac_adtstoasc "$folder/$safe_name.mp4"
    fi
    echo "Đã tải xong: $folder/$safe_name.mp4"
    sleep 2
}

cut_video_logic() {
    local input_url="$1"
    local mode="$2"
    local dest_dir="$DOWNLOAD_DIR/cut"
    mkdir -p "$dest_dir"

    echo "=== CHẾ ĐỘ CẮT VIDEO (Fix lỗi hình ảnh) ==="
    echo "Lưu ý: Nhập chính xác thời gian trên trình phát đang xem."
    
    if [ "$mode" == "single" ]; then
        read -r -p "Nhập thời gian bắt đầu (VD: 00:10:30): " start_time
        read -r -p "Nhập thời gian kết thúc (VD: 00:11:00): " end_time
        output_name="cut_$(date +%s).mp4"
        
        echo "Đang xử lý (Re-encoding)..."
        ffmpeg -i "$input_url" -ss "$start_time" -to "$end_time" \
            -c:v libx264 -preset fast -crf 23 -c:a aac \
            "$dest_dir/$output_name" -hide_banner -loglevel error
        
        echo "Xong! File lưu tại: $dest_dir/$output_name"
    
    elif [ "$mode" == "multi" ]; then
        read -r -p "Số lượng đoạn cần cắt: " count
        for ((i=1; i<=count; i++)); do
            echo "--- Đoạn $i ---"
            read -r -p "Bắt đầu (HH:MM:SS): " start_t
            read -r -p "Kết thúc (HH:MM:SS): " end_t
            output_name="cut_${i}_$(date +%s).mp4"
            
            echo "Đang xử lý đoạn $i..."
            ffmpeg -i "$input_url" -ss "$start_t" -to "$end_t" \
                -c:v libx264 -preset fast -crf 23 -c:a aac \
                "$dest_dir/$output_name" -hide_banner -loglevel error

            echo "Đã lưu đoạn $i: $output_name"
        done
        echo "Hoàn tất cắt nhiều đoạn."
    fi
    sleep 3
}

merge_video_logic() {
    local cut_dir="$DOWNLOAD_DIR/cut"
    local merge_dir="$DOWNLOAD_DIR/merged"
    mkdir -p "$merge_dir"
    
    if [ -z "$(ls -A "$cut_dir")" ]; then
        echo "Thư mục '$cut_dir' trống. Hãy cắt video trước."
        sleep 2
        return
    fi

    echo "Chọn các video để ghép (TAB để chọn nhiều, ENTER xác nhận):"
    cd "$cut_dir" || return
    selected_files=$(find . -maxdepth 1 -name "*.mp4" | sed 's|^\./||' | fzf -m --prompt="Chọn file để ghép > ")
    
    if [ -z "$selected_files" ]; then
        return
    fi

    list_txt="$cut_dir/merge_list.txt"
    > "$list_txt"
    
    echo "File đã chọn:"
    while IFS= read -r file; do
        echo "file '$file'" >> "$list_txt"
        echo " - $file"
    done <<< "$selected_files"
    
    output_name="merged_$(date +%s).mp4"
    echo "Đang ghép video..."
    ffmpeg -f concat -safe 0 -i "$list_txt" -c copy "$merge_dir/$output_name" -hide_banner -loglevel error
    
    rm "$list_txt"
    echo "Xong! Video ghép lưu tại: $merge_dir/$output_name"
    sleep 3
}

# --- LOCAL FILE HANDLER ---
play_anidata_local() {
    echo "Kiểm tra dữ liệu Local tại: $LOCAL_DATA_FILE"
    
    if [ ! -f "$LOCAL_DATA_FILE" ]; then
        echo "Đang tải dữ liệu mới..."
        local data_url="https://raw.githubusercontent.com/niyakipham/anisub/refs/heads/main/assets/aniw_export_2026-01-14.csv"
        mkdir -p "$SCRIPT_DIR/assets"
        curl -L "$data_url" -o "$LOCAL_DATA_FILE"
        if [ ! -f "$LOCAL_DATA_FILE" ]; then
            echo "Lỗi: Không tải được file dữ liệu."
            sleep 2; return
        fi
    fi

    local anime_list=$(sed '1d;s/"//g' "$LOCAL_DATA_FILE" | awk -F',' '{print $1}' | sort -u)
    local selected_anime=$(echo "$anime_list" | fzf --prompt="[Local] Chọn Anime: ")
    if [ -z "$selected_anime" ]; then return; fi

    local episodes=$(grep "^\"${selected_anime}\"," "$LOCAL_DATA_FILE" | sed 's/"//g' | awk -F',' '{print "Tập " $2 "|" $4}')
    if [ -z "$episodes" ]; then
         episodes=$(grep "^${selected_anime}," "$LOCAL_DATA_FILE" | sed 's/"//g' | awk -F',' '{print "Tập " $2 "|" $4}')
    fi

    local selected_line=$(echo "$episodes" | fzf --prompt="Chọn tập: " --delimiter='|' --with-nth=1)
    if [ -n "$selected_line" ]; then
         local ep_name=$(echo "$selected_line" | cut -d'|' -f1)
         local link=$(echo "$selected_line" | cut -d'|' -f2 | tr -d '[:space:]')
         
         add_to_history "$selected_anime (Local)" "$ep_name" "$link"
         manage_currently_playing "$selected_anime" "$ep_name" "$link" "$episodes" "local_file"
    fi
}

# --- SETTINGS & UPDATE ---
show_settings() {
    while true; do
        opt=$(echo -e "🎬 Đổi trình phát (Hiện tại: $PLAYER)\n📁 Đổi thư mục tải (Hiện tại: $DOWNLOAD_DIR)\n🖼️ Kích thước ảnh manga (Hiện tại: ${MANGA_IMAGE_SCALE}%)\n🔙 Quay lại" | fzf --prompt="⚙️ Cài đặt > ")
        case "$opt" in
            *"Đổi trình phát"*)
                read -r -p "Nhập lệnh trình phát (vd vlc): " inp
                if command -v "$inp" &> /dev/null; then PLAYER="$inp"; save_config; fi ;;
            *"Đổi thư mục tải"*)
                read -r -p "Nhập đường dẫn tuyệt đối: " inp
                DOWNLOAD_DIR="$inp"; mkdir -p "$inp"; save_config ;;
            *"Kích thước ảnh manga"*)
                echo ""
                echo "╔═══════════════════════════════════════════════════════════╗"
                echo "║  🖼️ ĐIỀU CHỈNH KÍCH THƯỚC HÌNH ẢNH MANGA                  ║"
                echo "║  Giá trị hiện tại: ${MANGA_IMAGE_SCALE}%                                     ║"
                echo "║  Phạm vi cho phép: 50% - 200%                              ║"
                echo "║  Mẹo: 100% = vừa terminal, 130% = 30% lớn hơn              ║"
                echo "╚═══════════════════════════════════════════════════════════╝"
                read -r -p "Nhập kích thước (50-200): " inp
                if [[ "$inp" =~ ^[0-9]+$ ]] && [ "$inp" -ge 50 ] && [ "$inp" -le 200 ]; then
                    MANGA_IMAGE_SCALE="$inp"
                    save_config
                    echo "✅ Đã thay đổi kích thước thành ${MANGA_IMAGE_SCALE}%"
                    sleep 1
                else
                    echo "❌ Giá trị không hợp lệ! Phải từ 50 đến 200."
                    sleep 1
                fi
                ;;
            *) break ;;
        esac
    done
}

update_script() {
    local remote=$(curl -s "$SCRIPT_URL")
    if [ -n "$remote" ]; then
         if ! diff -q "$0" <(echo "$remote") >/dev/null; then
             echo "Phát hiện bản cập nhật. Đang cài..."
             echo "$remote" > "$0"
             echo "Xong. Hãy khởi động lại."
             exit 0
         else
             echo "Phiên bản hiện tại là mới nhất."
             sleep 1
         fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# ██████╗ ██████╗ ███╗   ██╗ ██████╗  █████╗     ██████╗ ███████╗ █████╗ ██████╗ ███████╗██████╗ 
# ██╔══██╗██╔══██╗████╗  ██║██╔════╝ ██╔══██╗    ██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝██╔══██╗
# ██████╔╝██████╔╝██╔██╗ ██║██║  ███╗███████║    ██████╔╝█████╗  ███████║██║  ██║█████╗  ██████╔╝
# ██╔═══╝ ██╔══██╗██║╚██╗██║██║   ██║██╔══██║    ██╔══██╗██╔══╝  ██╔══██║██║  ██║██╔══╝  ██╔══██╗
# ██║     ██║  ██║██║ ╚████║╚██████╔╝██║  ██║    ██║  ██║███████╗██║  ██║██████╔╝███████╗██║  ██║
# ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝    ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝
# MANGA READER - TRUYENVN.SHOP
# ═══════════════════════════════════════════════════════════════════════════════

MANGA_BASE_URL="https://truyenvn.shop"

# --- MANGA HISTORY ---
add_to_manga_history() {
    local manga_name="$1"
    local chapter_name="$2"
    local manga_slug="$3"
    sed -i "/|${manga_slug}|${chapter_name}|/d" "$MANGA_HISTORY_FILE"
    echo "$(date +%Y-%m-%d\ %H:%M:%S)|${manga_name}|${chapter_name}|${manga_slug}" >> "$MANGA_HISTORY_FILE"
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

# --- FETCH CHAPTER LIST ---
fetch_chapter_list() {
    local manga_slug="$1"
    local url="${MANGA_BASE_URL}/truyen-tranh/${manga_slug}/"
    
    # Fetch HTML và extract tất cả chapter links
    # Website có nhiều format khác nhau:
    # - /truyen-tranh/soeun/chapter-1/
    # - /truyen-tranh/one-piece/one-piece-chapter-1088/
    curl -s "$url" \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" | \
        grep -oP 'href="https://truyenvn\.shop/truyen-tranh/'"$manga_slug"'/[^"]+/"' | \
        sed 's/href="//;s/"$//' | \
        grep -v "/$manga_slug/$" | \
        sort -u | \
        while read -r chap_url; do
            # Extract chapter name từ URL
            local chap_name=$(echo "$chap_url" | sed "s|.*/truyen-tranh/$manga_slug/||;s|/$||" | \
                sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
            # Format lại cho đẹp
            chap_name=$(echo "$chap_name" | sed 's/Chapter/Chapter/i')
            echo "$chap_name|$chap_url"
        done | \
        # Sắp xếp theo số chapter (extract số từ tên)
        sort -t'|' -k1 -V
}

# --- FETCH CHAPTER IMAGES ---
fetch_chapter_images() {
    local chapter_url="$1"
    local temp_html=$(mktemp /tmp/anisub_chap_XXXXXX.html)
    
    # 1. Tải HTML về file tạm để xử lý ổn định
    curl -s "$chapter_url" \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
        -H "Referer: ${MANGA_BASE_URL}/" \
        -o "$temp_html"
        
    if [ ! -s "$temp_html" ]; then
        rm -f "$temp_html"
        return 1
    fi
    
    # 2. Extract URLs - Support Lazy Loading & Scope to Content
    # Scope vào class "reading-content" để tránh ảnh thumbnail của truyện khác
    perl -0777 -ne '
    my $content = $_;
    
    # Try to find the reading content div more loosely
    if ($content =~ /(<div[^>]*class=[\"\x27][^\"\x27]*reading-content[^>]*>)/si) {
        # Start from the match
        $content = $'"'"'; # $'"'"' is post-match (using single quote hack for shell)
        
        # Stop at "comments", "related", "entry-footer" or common footer classes
        # Use a list of potential footer markers
        if ($content =~ /(class=[\"\x27][^\"\x27]*(related-reading|entry-footer|comments|footer-widgets)[^\"\x27]*[\"\x27]|id=[\"\x27]comments[\"\x27])/i) {
             $content = $` ; 
        }
    }
    
    while ($content =~ /<img\s+([^>]+)>/gi) {
        my $attrs = $1;
        my $url = "";
        # Check priority attributes
        if ($attrs =~ /data-(?:src|original|lazy-src|eco)=[\"\x27]([^\"\x27]+)[\"\x27]/i) {
            $url = $1;
        } elsif ($attrs =~ /\ssrc=[\"\x27]([^\"\x27]+)[\"\x27]/i) {
            $url = $1;
        }
        
        # Clean up URL (trim whitespace)
        $url =~ s/^\s+|\s+$//g;
        
        # Decode HTML entities if needed (basic chars)
        $url =~ s/&amp;/&/g;
        
        if ($url ne "") { print "$url\n"; }
    }' "$temp_html" | \
        grep -iE '\.(jpg|jpeg|png|webp|gif)' | \
        grep "^http" | \
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
        grep -viE 'logo|icon|avatar|thumb|banner|facebook|twitter|share|google|recaptcha|popup' | \
        grep -v '^$' | \
        awk '!seen[$0]++' > "${temp_html}.list"
        
    # Check if list is empty
    if [ ! -s "${temp_html}.list" ]; then 
        echo "" >&2 # Suppress visual error for user, handle in caller
    else
        cat "${temp_html}.list"
    fi
    rm -f "${temp_html}" "${temp_html}.list"
}

# --- PREFETCH IMAGES ---
prefetch_chapter_images() {
    local cache_dir="$1"
    shift
    local images=("$@")
    
    mkdir -p "$cache_dir"
    
    # Download in parallel (background jobs)
    local max_jobs=5
    local job_count=0
    
    local idx=0
    for url in "${images[@]}"; do
        local filename=$(printf "%03d.jpg" $((idx + 1))) # 001.jpg, 002.jpg...
        local filepath="$cache_dir/$filename"
        
        # Skip if exists
        if [ ! -f "$filepath" ]; then
            (
                curl -sL "$url" \
                     -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
                     -H "Referer: ${MANGA_BASE_URL}/" \
                     -o "$filepath.tmp" && mv "$filepath.tmp" "$filepath"
            ) &
            
            ((job_count++))
            if [ $job_count -ge $max_jobs ]; then
                wait -n
                ((job_count--))
            fi
        fi
        ((idx++))
    done
    wait # Wait for all remaining jobs
}

# --- DISPLAY FULL CHAPTER (FZF "Smart Mode") ---
# --- DISPLAY FULL CHAPTER (FZF "Smart Mode" + Fallback) ---
display_full_chapter() {
    local manga_name="$1"
    local chapter_name="$2"
    shift 2
    local images=("$@")
    local total_pages=${#images[@]}
    
    # Cache Directory Setup
    local session_id=$(date +%s)
    local cache_dir="/tmp/anisub_cache_$session_id"
    mkdir -p "$cache_dir"
    
    # 1. Create URL Map for Fallback (lines 1..N)
    local url_file="$cache_dir/urls.txt"
    printf "%s\n" "${images[@]}" > "$url_file"
    
    # 2. Create Open Helper
    cat <<EOF > "$cache_dir/open.sh"
#!/bin/bash
current_line="\$1"
page_num=\$(echo "\$current_line" | awk '{print \$2}' | cut -d'/' -f1)
target_file="$cache_dir/\${page_num}.jpg"
# Try downloading if missing (using curl line from url file)
if [ ! -f "\$target_file" ]; then
    idx=\$(echo "\$page_num" | sed 's/^0*//')
    url=\$(sed -n "\${idx}p" "$url_file")
    curl -sL "\$url" \
         -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
         -H "Referer: ${MANGA_BASE_URL}/" \
         -o "\$target_file.tmp" && mv "\$target_file.tmp" "\$target_file"
fi
if [ -f "\$target_file" ]; then
    xdg-open "\$target_file" >/dev/null 2>&1 &
fi
EOF
    chmod +x "$cache_dir/open.sh"

    # Create Preview Script Helper
    cat <<EOF > "$cache_dir/preview.sh"
#!/bin/bash
current_line="\$1"
page_num=\$(echo "\$current_line" | awk '{print \$2}' | cut -d'/' -f1)
target_file="$cache_dir/\${page_num}.jpg"

# DEBOUNCE
sleep 0.15

# [ CLEANUP ] Force clear previous graphics (Crucial for Kitty)
if [[ "\$TERM" == "xterm-kitty" ]]; then
    printf '\x1b_Ga=d,d=A\x1b\\'
fi

# [ FALLBACK ] Check Cache or Download
if [ ! -s "\$target_file" ]; then
    idx=\$(echo "\$page_num" | sed 's/^0*//'); [ -z "\$idx" ] && idx=0 
    url=\$(sed -n "\${idx}p" "$url_file")
    
    if [ -n "\$url" ]; then
        # Try download silently
        curl -fsL "\$url" -H "Referer: ${MANGA_BASE_URL}/" -H "User-Agent: Mozilla/5.0" -o "\$target_file.tmp" >/dev/null 2>&1
        
        if [ -s "\$target_file.tmp" ]; then
            mv "\$target_file.tmp" "\$target_file" >/dev/null 2>&1
        else
            rm -f "\$target_file.tmp" >/dev/null 2>&1
        fi
    fi
fi

if [ ! -s "\$target_file" ]; then
    echo "❌ Tải lỗi. (Mạng kém?)"
    exit 1
fi

# [ INFO ]
fsize=\$(du -h "\$target_file" | cut -f1)

# [ DIMENSION CHECK ]
width=0
height=0

if command -v identify &>/dev/null; then
    dims=\$(identify -format "%w %h" "\$target_file" 2>/dev/null)
    width=\$(echo "\$dims" | awk '{print \$1}')
    height=\$(echo "\$dims" | awk '{print \$2}')
elif command -v file &>/dev/null; then
    res=\$(file "\$target_file")
    if [[ \$res =~ ([0-9]+)x([0-9]+) ]]; then
        width=\${BASH_REMATCH[1]}
        height=\${BASH_REMATCH[2]}
    fi
fi

if [ -z "\$width" ] || [ "\$width" -eq 0 ]; then width=1; height=1; fi
ratio=\$((height / width))

echo "📁 \${page_num} [\$fsize]"

# [ RENDER ] Logic
# 1. Webtoon Strip (Ratio >= 3) -> Text Mode for Scrolling
if [ \$ratio -ge 3 ]; then
     safe_cols=\$((FZF_PREVIEW_COLUMNS - 4))
     if [ \$safe_cols -lt 10 ]; then safe_cols=10; fi
     chafa -f symbols --symbols=all --size="\${safe_cols}x" --animate=off "\$target_file"

# 2. Normal Page -> Graphic Mode (Kitty/Sixel)
else
    safe_cols=\$((FZF_PREVIEW_COLUMNS - 4))
    safe_lines=\$((FZF_PREVIEW_LINES - 3))
    if [ \$safe_cols -lt 10 ]; then safe_cols=10; fi

    if [[ "\$TERM" == "xterm-kitty" ]]; then
        # Force Kitty Protocol
        chafa -f kitty --size="\${safe_cols}x\${safe_lines}" --animate=off "\$target_file"
    else
        # Force Sixel Protocol (Assuming terminal supports it if not Kitty)
        # We REMOVE the fallback to symbols to force HD or nothing.
        # If chafa fails (exit code), FZF will just show nothing or error, better than blurry symbols.
        chafa -f sixels --size="\${safe_cols}x\${safe_lines}" --animate=off "\$target_file"
    fi
fi
EOF
    chmod +x "$cache_dir/preview.sh"

    # Start Prefetching in Background
    prefetch_chapter_images "$cache_dir" "${images[@]}" >/dev/null 2>&1 &
    local prefetch_pid=$!
    
    # Cleanup Trap (ensure cache is deleted on exit)
    trap "rm -rf '$cache_dir'; kill $prefetch_pid 2>/dev/null" EXIT
    
    # Prepare Input list for FZF
    list_input=""
    for ((i=1; i<=total_pages; i++)); do
        p_str=$(printf "%03d" $i)
        list_input+="Trang ${p_str}/${total_pages}"$'\n'
    done
    
    # FZF Execution
    echo -n "$list_input" | fzf \
        --layout=reverse \
        --ansi \
        --header="📖 $manga_name - $chapter_name" \
        --prompt="Xem ảnh HD | Enter: Mở ngoài > " \
        --preview "$cache_dir/preview.sh {}" \
        --preview-window="right:75%" \
        --bind "enter:execute-silent($cache_dir/open.sh {})" \
        --bind "ctrl-c:abort"
        
    # Clean up at end of chapter
    rm -rf "$cache_dir"
}

# --- READ MANGA CHAPTER (Continuous Scroll) ---
read_manga_chapter() {
    local manga_name="$1"
    local manga_slug="$2"
    local chapter_name="$3"
    local chapter_url="$4"
    local chapter_list_raw="$5"
    
    while true; do
        clear
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║  ⏳ ĐANG TẢI CHAPTER...                                                      ║"
        printf "║  📖 %-70s ║\n" "$manga_name"
        printf "║  📑 %-70s ║\n" "$chapter_name"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        
        # Lấy danh sách ảnh
        mapfile -t images < <(fetch_chapter_images "$chapter_url")
        
        if [ ${#images[@]} -eq 0 ]; then
            echo ""
            echo "❌ Không tìm thấy hình ảnh trong chapter này!"
            echo "Nhấn [r] để thử lại, [c] để chọn chapter khác, hoặc [q] để thoát."
            read -rsn1 key
            case "$key" in
                'r') continue ;;
                'c') return 0 ;;
                'q') return 1 ;;
            esac
            continue
        fi
        
        add_to_manga_history "$manga_name" "$chapter_name" "$manga_slug"
        
        # Clear và hiển thị toàn bộ chapter (continuous scroll)
        clear
        display_full_chapter "$manga_name" "$chapter_name" "${images[@]}"
        
        # Input Loop to prevent re-rendering on invalid key
        while true; do
            read -rsn1 key < /dev/tty
            case "$key" in
                'n')  # Next chapter
                    next_chap=$(echo "$chapter_list_raw" | grep -A1 "^${chapter_name}|" | tail -1)
                    if [ -n "$next_chap" ] && [ "$next_chap" != "${chapter_name}|"* ]; then
                        chapter_name=$(echo "$next_chap" | cut -d'|' -f1)
                        chapter_url=$(echo "$next_chap" | cut -d'|' -f2)
                        break 2 # Break inner loop, continue outer (reload new chap)
                    else
                        echo ""
                        echo "📚 Đây là chapter mới nhất! (Phím bất kỳ để tiếp tục)"
                        # Stay in inner loop
                    fi
                    ;;
                'p')  # Previous chapter
                    prev_chap=$(echo "$chapter_list_raw" | grep -B1 "^${chapter_name}|" | head -1)
                    if [ -n "$prev_chap" ] && [ "$prev_chap" != "${chapter_name}|"* ]; then
                        chapter_name=$(echo "$prev_chap" | cut -d'|' -f1)
                        chapter_url=$(echo "$prev_chap" | cut -d'|' -f2)
                        break 2 # Break inner loop, continue outer (reload new chap)
                    else
                        echo ""
                        echo "📚 Đây là chapter đầu tiên! (Phím bất kỳ để tiếp tục)"
                        # Stay in inner loop
                    fi
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
        echo "║                        📚 MANGA READER 📚                                    ║"
        echo "║                                                                              ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        
        main_opt=$(echo -e "🔍 Tìm kiếm truyện tranh\n📖 Truyện mới cập nhật\n📜 Lịch sử đọc\n⭐ Truyện yêu thích\n🔙 Quay lại Menu Chính" | \
            fzf --prompt="📚 Menu > " --height=40% --reverse)
        
        case "$main_opt" in
            "🔍 Tìm kiếm truyện tranh")
                # Search với fzf dynamic
                sel=$(fzf --disabled \
                    --prompt="🔍 Gõ tên truyện: " \
                    --header="╔══════════════════════════════════════════╗
║  Nhập >= 2 ký tự để tìm kiếm             ║
╚══════════════════════════════════════════╝" \
                    --bind "change:reload:
                        query={q};
                        if [ \${#query} -ge 2 ]; then
                            encoded_q=\$(echo \"\$query\" | sed 's/ /%20/g');
                            curl -s \"https://truyenvn.shop/?s=\$encoded_q&post_type=wp-manga\" | \
                            grep -oP '<a href=\"https://truyenvn.shop/truyen-tranh/[^\"]+\"[^>]*title=\"[^\"]+\"' | \
                            sed 's/<a href=\"\([^\"]*\)\"[^>]*title=\"\([^\"]*\)\"/\2|\1/' | \
                            head -20;
                        else
                            echo 'Vui lòng nhập tên truyện...';
                        fi" \
                    --delimiter='|' \
                    --with-nth=1)
                
                if [ -n "$sel" ] && [[ "$sel" != "Vui lòng"* ]]; then
                    manga_name=$(echo "$sel" | cut -d'|' -f1)
                    manga_url=$(echo "$sel" | cut -d'|' -f2)
                    manga_slug=$(echo "$manga_url" | sed 's|.*/truyen-tranh/\([^/]*\)/.*|\1|')
                    
                    # Lấy danh sách chapter
                    echo "⏳ Đang tải danh sách chapter..."
                    chapter_list=$(fetch_chapter_list "$manga_slug")
                    
                    if [ -z "$chapter_list" ]; then
                        echo "❌ Không tìm thấy chapter!"
                        sleep 2
                        continue
                    fi
                    
                    # Chọn chapter
                    sel_chap=$(echo "$chapter_list" | fzf --prompt="📑 Chọn chapter > " --delimiter='|' --with-nth=1 --tac \
                        --header="╔══════════════════════════════════════════╗
║  📖 $manga_name
╚══════════════════════════════════════════╝")
                    
                    if [ -n "$sel_chap" ]; then
                        chap_name=$(echo "$sel_chap" | cut -d'|' -f1)
                        chap_url=$(echo "$sel_chap" | cut -d'|' -f2)
                        
                        while true; do
                            read_manga_chapter "$manga_name" "$manga_slug" "$chap_name" "$chap_url" "$chapter_list"
                            result=$?
                            if [ $result -eq 1 ]; then
                                break  # User quit
                            fi
                            # User wants to change chapter
                            sel_chap=$(echo "$chapter_list" | fzf --prompt="📑 Chọn chapter > " --delimiter='|' --with-nth=1 --tac)
                            if [ -z "$sel_chap" ]; then
                                break
                            fi
                            chap_name=$(echo "$sel_chap" | cut -d'|' -f1)
                            chap_url=$(echo "$sel_chap" | cut -d'|' -f2)
                        done
                    fi
                fi
                ;;
                
            "📖 Truyện mới cập nhật")
                echo "⏳ Đang tải danh sách truyện mới..."
                manga_list=$(curl -s "${MANGA_BASE_URL}/truyen-tranh/" | \
                    grep -oP '<a href="https://truyenvn.shop/truyen-tranh/[^"]+/"[^>]*title="[^"]+"' | \
                    sed 's/<a href="\([^"]*\)"[^>]*title="\([^"]*\)"/\2|\1/' | \
                    head -30)
                
                sel=$(echo "$manga_list" | fzf --prompt="📖 Chọn truyện > " --delimiter='|' --with-nth=1 \
                    --header="╔══════════════════════════════════════════╗
║  📖 TRUYỆN MỚI CẬP NHẬT                  ║
╚══════════════════════════════════════════╝")
                
                if [ -n "$sel" ]; then
                    manga_name=$(echo "$sel" | cut -d'|' -f1)
                    manga_url=$(echo "$sel" | cut -d'|' -f2)
                    manga_slug=$(echo "$manga_url" | sed 's|.*/truyen-tranh/\([^/]*\)/.*|\1|')
                    
                    chapter_list=$(fetch_chapter_list "$manga_slug")
                    
                    if [ -z "$chapter_list" ]; then
                        echo "❌ Không tìm thấy chapter!"
                        sleep 2
                        continue
                    fi
                    
                    sel_chap=$(echo "$chapter_list" | fzf --prompt="📑 Chọn chapter > " --delimiter='|' --with-nth=1 --tac \
                        --header="📖 $manga_name")
                    
                    if [ -n "$sel_chap" ]; then
                        chap_name=$(echo "$sel_chap" | cut -d'|' -f1)
                        chap_url=$(echo "$sel_chap" | cut -d'|' -f2)
                        
                        while true; do
                            read_manga_chapter "$manga_name" "$manga_slug" "$chap_name" "$chap_url" "$chapter_list"
                            result=$?
                            if [ $result -eq 1 ]; then break; fi
                            sel_chap=$(echo "$chapter_list" | fzf --prompt="📑 Chọn chapter > " --delimiter='|' --with-nth=1 --tac)
                            if [ -z "$sel_chap" ]; then break; fi
                            chap_name=$(echo "$sel_chap" | cut -d'|' -f1)
                            chap_url=$(echo "$sel_chap" | cut -d'|' -f2)
                        done
                    fi
                fi
                ;;
                
            "📜 Lịch sử đọc")
                history_result=$(show_manga_history)
                if [ $? -eq 0 ]; then
                    manga_name=$(echo "$history_result" | cut -d'|' -f1)
                    manga_slug=$(echo "$history_result" | cut -d'|' -f2)
                    chapter_name=$(echo "$history_result" | cut -d'|' -f3)
                    
                    chapter_list=$(fetch_chapter_list "$manga_slug")
                    chap_url="${MANGA_BASE_URL}/truyen-tranh/${manga_slug}/${chapter_name}/"
                    
                    # Chuẩn hóa chapter name
                    chap_name_display=$(echo "$chapter_name" | sed 's/chapter-/Chapter /')
                    
                    while true; do
                        read_manga_chapter "$manga_name" "$manga_slug" "$chap_name_display" "$chap_url" "$chapter_list"
                        result=$?
                        if [ $result -eq 1 ]; then break; fi
                        sel_chap=$(echo "$chapter_list" | fzf --prompt="📑 Chọn chapter > " --delimiter='|' --with-nth=1 --tac)
                        if [ -z "$sel_chap" ]; then break; fi
                        chap_name_display=$(echo "$sel_chap" | cut -d'|' -f1)
                        chap_url=$(echo "$sel_chap" | cut -d'|' -f2)
                    done
                fi
                ;;
                
            "⭐ Truyện yêu thích")
                fav_result=$(show_manga_favorites)
                if [ $? -eq 0 ]; then
                    manga_name=$(echo "$fav_result" | cut -d'|' -f1)
                    manga_slug=$(echo "$fav_result" | cut -d'|' -f2)
                    
                    chapter_list=$(fetch_chapter_list "$manga_slug")
                    
                    if [ -z "$chapter_list" ]; then
                        echo "❌ Không tìm thấy chapter!"
                        sleep 2
                        continue
                    fi
                    
                    sel_chap=$(echo "$chapter_list" | fzf --prompt="📑 Chọn chapter > " --delimiter='|' --with-nth=1 --tac \
                        --header="⭐ $manga_name")
                    
                    if [ -n "$sel_chap" ]; then
                        chap_name=$(echo "$sel_chap" | cut -d'|' -f1)
                        chap_url=$(echo "$sel_chap" | cut -d'|' -f2)
                        
                        while true; do
                            read_manga_chapter "$manga_name" "$manga_slug" "$chap_name" "$chap_url" "$chapter_list"
                            result=$?
                            if [ $result -eq 1 ]; then break; fi
                            sel_chap=$(echo "$chapter_list" | fzf --prompt="📑 Chọn chapter > " --delimiter='|' --with-nth=1 --tac)
                            if [ -z "$sel_chap" ]; then break; fi
                            chap_name=$(echo "$sel_chap" | cut -d'|' -f1)
                            chap_url=$(echo "$sel_chap" | cut -d'|' -f2)
                        done
                    fi
                fi
                ;;
                
            "🔙 Quay lại Menu Chính"|*)
                return
                ;;
        esac
    done
}

# --- MAIN LOGIC ---
main() {
    trap 'kill $(jobs -p) 2>/dev/null' EXIT
    check_dependencies
    load_config

    while true; do
        clear
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║     █████╗ ███╗   ██╗██╗███████╗██╗   ██╗██████╗      ██████╗██╗     ██╗     ║"
        echo "║    ██╔══██╗████╗  ██║██║██╔════╝██║   ██║██╔══██╗    ██╔════╝██║     ██║     ║"
        echo "║    ███████║██╔██╗ ██║██║███████╗██║   ██║██████╔╝    ██║     ██║     ██║     ║"
        echo "║    ██╔══██║██║╚██╗██║██║╚════██║██║   ██║██╔══██╗    ██║     ██║     ██║     ║"
        echo "║    ██║  ██║██║ ╚████║██║███████║╚██████╔╝██████╔╝    ╚██████╗███████╗██║     ║"
        echo "║    ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚══════╝ ╚═════╝ ╚═════╝      ╚═════╝╚══════╝╚═╝     ║"
        echo "║                   🎬 Anime & 📚 Manga All-in-One CLI 🎬                      ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        main_opt=$(echo -e "🎬 Xem Anime (KKPhim)\n📚 Đọc Truyện Tranh (TruyenVN)\n📂 Xem từ Local Anidata\n📜 Lịch sử xem Anime\n⭐ Anime yêu thích\n⚙️ Cài đặt\n🔄 Cập nhật\n🚪 Thoát" | fzf --prompt="🎯 Menu > " --height=50% --reverse)

        case "$main_opt" in
            "🎬 Xem Anime (KKPhim)")
                sel=$(fzf --disabled \
                    --prompt="Gõ tên Anime: " \
                    --header="vui lòng gõ (Nhập >= 2 ký tự) để gợi ý từ khóa" \
                    --bind "change:reload:
                        query={q};
                        if [ \${#query} -ge 2 ]; then
                            encoded_q=\$(echo \"\$query\" | sed 's/ /%20/g');
                            curl -s \"https://phimapi.com/v1/api/tim-kiem?keyword=\$encoded_q&limit=20\" | 
                            jq -r 'if .status == \"success\" then .data.APP_DOMAIN_CDN_IMAGE as \$dom | .data.items[] | \"\(.name) (\(.year))|\(.slug)|\(\$dom)/\(.poster_url)\" else \"Không có dữ liệu...\" end';
                        else
                            echo 'Vui lòng nhập tên anime...';
                        fi" \
                    --delimiter='|' \
                    --with-nth=1 \
                    --preview "echo {} | cut -d'|' -f3 | xargs -I {} curl -s {} | chafa -s 40x20 - 2>/dev/null" \
                    --preview-window=right:40%:wrap)
                
                if [ -n "$sel" ]; then
                    name=$(echo "$sel" | cut -d'|' -f1)
                    slug=$(echo "$sel" | cut -d'|' -f2)
                    
                    if [ "$slug" == "" ] || [[ "$sel" == *"Không có dữ liệu"* ]]; then
                        continue
                    fi

                    eps=$(api_get_episodes_kkphim "$slug")
                    if [ -z "$eps" ]; then echo "Lỗi lấy danh sách tập."; sleep 1; continue; fi
                    
                    sel_ep=$(echo "$eps" | fzf --prompt="[$name] Chọn tập > " --delimiter='|' --with-nth=1)
                    if [ -n "$sel_ep" ]; then
                         ename=$(echo "$sel_ep" | cut -d'|' -f1)
                         elink=$(echo "$sel_ep" | cut -d'|' -f2)
                         add_to_history "$name" "$ename" "$elink"
                         
                         manage_currently_playing "$name" "$ename" "$elink" "$eps" "$slug"
                    fi
                fi
                ;;
            "📚 Đọc Truyện Tranh (TruyenVN)") manga_main_menu ;;
            "📂 Xem từ Local Anidata") play_anidata_local ;;
            "📜 Lịch sử xem Anime") show_history ;;
            "⭐ Anime yêu thích")
                fav_line=$(show_favorites)
                if [ $? -eq 0 ]; then
                     fname=$(echo "$fav_line" | cut -d'|' -f1)
                     fslug=$(echo "$fav_line" | cut -d'|' -f2)
                     eps=$(api_get_episodes_kkphim "$fslug")
                     if [ -n "$eps" ]; then
                         sel_ep=$(echo "$eps" | fzf --prompt="[$fname] Chọn tập > " --delimiter='|' --with-nth=1)
                         if [ -n "$sel_ep" ]; then
                              ename=$(echo "$sel_ep" | cut -d'|' -f1)
                              elink=$(echo "$sel_ep" | cut -d'|' -f2)
                              manage_currently_playing "$fname" "$ename" "$elink" "$eps" "$fslug"
                         fi
                     else
                         echo "Lỗi: Không tìm thấy link tập."
                         sleep 2
                     fi
                fi
                ;;
            "⚙️ Cài đặt") show_settings ;;
            "🔄 Cập nhật") update_script ;;
            "🚪 Thoát"*) exit 0 ;;
        esac
    done
}

main
