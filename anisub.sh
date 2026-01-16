#!/bin/bash

# --- CONFIGURATION & DATA FILES ---
CONFIG_DIR="$HOME/.config/anisub_cli"
CONFIG_FILE="$CONFIG_DIR/config.cfg"
HISTORY_FILE="$CONFIG_DIR/history.log"
FAVORITES_FILE="$CONFIG_DIR/favorites.txt"
SCRIPT_URL="https://raw.githubusercontent.com/NiyakiPham/anisub/main/anisub.sh"

# Image Cache Dir (Để ảnh load nhanh hơn khi lướt lại)
CACHE_DIR="$HOME/.cache/anisub_thumbs"

# Local Data File
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DATA_FILE="$SCRIPT_DIR/assets/aniw_export_2026-01-14.csv"

# --- DEFAULTS ---
DEFAULT_PLAYER="mpv"
DEFAULT_DOWNLOAD_DIR="$HOME/Downloads/anime"
PLAYER=""
DOWNLOAD_DIR=""
IMG_VIEWER=""

# --- UTILITY FUNCTIONS ---
ensure_config_dir() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CACHE_DIR"
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
    mkdir -p "$DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR/cut" 
    mkdir -p "$DOWNLOAD_DIR/merged" 
    touch "$HISTORY_FILE" "$FAVORITES_FILE"
    
    # Kiểm tra xem có chafa không để hiện ảnh
    if command -v chafa &> /dev/null; then
        IMG_VIEWER="chafa"
    else
        IMG_VIEWER=""
    fi
}

save_config() {
    echo "PLAYER=$PLAYER" > "$CONFIG_FILE"
    echo "DOWNLOAD_DIR=$DOWNLOAD_DIR" >> "$CONFIG_FILE"
    echo "Cấu hình đã được lưu."
    sleep 1
}

check_dependencies() {
    local missing_deps=()
    local deps=("ffmpeg" "curl" "grep" "yt-dlp" "fzf" "jq" "awk" "sed")
    # Kiểm tra chafa (optional nhưng cần cho ảnh)
    
    echo "Kiểm tra các phụ thuộc hệ thống..."
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "LỖI: Thiếu các phụ thuộc sau: ${missing_deps[*]}"
        echo "Vui lòng cài đặt chúng trước khi sử dụng."
        exit 1
    fi
    
    if ! command -v chafa &> /dev/null; then
        echo "LƯU Ý: 'chafa' chưa được cài đặt. Sẽ không hiển thị được hình ảnh poster."
        echo "Bạn có thể cài đặt bằng lệnh: sudo apt install chafa (Ubuntu) hoặc brew install chafa (Mac)"
        sleep 3
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

api_search_kkphim() {
    local keyword="$1"
    keyword=$(echo "$keyword" | sed 's/ /%20/g')
    
    local api_url="https://phimapi.com/v1/api/tim-kiem?keyword=$keyword&limit=20"
    local json=$(curl -s "$api_url")
    
    local status=$(echo "$json" | jq -r '.status')
    if [ "$status" != "success" ]; then
        return 1
    fi
    
    local domain_img=$(echo "$json" | jq -r '.data.APP_DOMAIN_CDN_IMAGE')

    # Output Format: "Name (Year) | Slug | FullPosterUrl"
    # Dùng APP_DOMAIN_CDN_IMAGE ghép với poster_url để có link ảnh full
    echo "$json" | jq -r --arg domain "$domain_img" '.data.items[] | "\(.name) (\(.year))|\(.slug)|\($domain)/\(.poster_url)"'
}

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
    "$PLAYER" "$url" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window --title="Anisub: $title" &
    PLAYER_PID=$!
}

# --- PREVIEW HELPER (EXPORTED FOR FZF) ---
export CACHE_DIR
preview_handler() {
    local line="$1"
    local img_url=$(echo "$line" | awk -F'|' '{print $3}')
    local name=$(echo "$line" | awk -F'|' '{print $1}')
    local filename=$(echo "$img_url" | md5sum | awk '{print $1}')
    local cache_path="$CACHE_DIR/$filename.jpg"
    
    # Header Info
    echo -e "\033[1;33m$name\033[0m"
    echo "------------------------"
    
    if [ -n "$img_url" ] && [[ "$img_url" == http* ]]; then
        # Check cache
        if [ ! -f "$cache_path" ]; then
            curl -s -L "$img_url" -o "$cache_path"
        fi
        
        # Display image if chafa exists
        if command -v chafa &> /dev/null; then
            # Resize image to fit width, preserve aspect
            chafa -s 40x40 "$cache_path"
        else
            echo "[Chưa cài 'chafa', không thể xem ảnh]"
            echo "URL ảnh: $img_url"
        fi
    else
        echo "Không có hình ảnh."
    fi
}
export -f preview_handler

# --- MEDIA PROCESSING ---
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

    echo "=== CHẾ ĐỘ CẮT VIDEO ==="
    echo "Lưu ý: Nhập chính xác thời gian trên trình phát."
    
    if [ "$mode" == "single" ]; then
        read -r -p "Nhập thời gian bắt đầu (VD: 00:10:30): " start_time
        read -r -p "Nhập thời gian kết thúc (VD: 00:11:00): " end_time
        output_name="cut_$(date +%s).mp4"
        
        echo "Đang xử lý (Re-encoding)..."
        # Re-encode để fix lỗi keyframe gây đen hình
        ffmpeg -i "$input_url" -ss "$start_time" -to "$end_time" \
            -c:v libx264 -preset fast -crf 23 -c:a aac \
            "$dest_dir/$output_name" -hide_banner -loglevel error
        
        echo "Xong! File: $dest_dir/$output_name"
    
    elif [ "$mode" == "multi" ]; then
        read -r -p "Số đoạn cần cắt: " count
        for ((i=1; i<=count; i++)); do
            echo "--- Đoạn $i ---"
            read -r -p "Bắt đầu: " start_t
            read -r -p "Kết thúc: " end_t
            output_name="cut_${i}_$(date +%s).mp4"
            echo "Đang xử lý đoạn $i..."
            ffmpeg -i "$input_url" -ss "$start_t" -to "$end_t" \
                -c:v libx264 -preset fast -crf 23 -c:a aac \
                "$dest_dir/$output_name" -hide_banner -loglevel error
            echo "Lưu đoạn $i: $output_name"
        done
        echo "Hoàn tất."
    fi
    sleep 3
}

merge_video_logic() {
    local cut_dir="$DOWNLOAD_DIR/cut"
    local merge_dir="$DOWNLOAD_DIR/merged"
    mkdir -p "$merge_dir"
    
    if [ -z "$(ls -A "$cut_dir")" ]; then
        echo "Thư mục '$cut_dir' trống."
        sleep 2
        return
    fi

    echo "Chọn video để ghép (TAB chọn nhiều, ENTER chốt):"
    cd "$cut_dir" || return
    selected_files=$(find . -maxdepth 1 -name "*.mp4" | sed 's|^\./||' | fzf -m --prompt="Ghép > ")
    
    if [ -z "$selected_files" ]; then return; fi

    list_txt="$cut_dir/merge_list.txt"
    > "$list_txt"
    
    echo "File đã chọn:"
    while IFS= read -r file; do
        echo "file '$file'" >> "$list_txt"
        echo " - $file"
    done <<< "$selected_files"
    
    output_name="merged_$(date +%s).mp4"
    echo "Đang ghép..."
    ffmpeg -f concat -safe 0 -i "$list_txt" -c copy "$merge_dir/$output_name" -hide_banner -loglevel error
    rm "$list_txt"
    echo "Xong! Video ghép: $merge_dir/$output_name"
    sleep 3
}

manage_currently_playing() {
    local name="$1"
    local current_ep_name="$2"
    local link="$3"
    local episode_list_raw="$4"
    local anime_slug="$5"
    
    play_stream "$link" "$name - Tập $current_ep_name"
    
    while kill -0 "$PLAYER_PID" 2>/dev/null; do
        header="Đang phát: $name - Tập $current_ep_name"
        action=$(echo -e "⏭ Tiếp theo\n⏮ Trước đó\n📜 Chọn tập khác\n⬇ Tải tập này\n✂ Cắt Video (1 lần)\n✂✂ Cắt Video (Nhiều lần)\n🧬 Ghép Video (Grafting)\n❤️ Thêm vào Yêu Thích\n🔙 Menu Chính" | fzf --prompt="$header > " --header="[Player đang chạy nền]")
        
        case "$action" in
            "⏭ Tiếp theo")
                kill "$PLAYER_PID" 2>/dev/null
                new_selection=$(echo "$episode_list_raw" | fzf --prompt="Chọn tập tiếp theo: " --delimiter='|' --with-nth=1)
                if [ -n "$new_selection" ]; then
                     current_ep_name=$(echo "$new_selection" | cut -d'|' -f1)
                     link=$(echo "$new_selection" | cut -d'|' -f2)
                     add_to_history "$name" "$current_ep_name" "$link"
                     play_stream "$link" "$name - Tập $current_ep_name"
                fi
                ;;
            "⏮ Trước đó"|"📜 Chọn tập khác")
                kill "$PLAYER_PID" 2>/dev/null
                new_selection=$(echo "$episode_list_raw" | fzf --prompt="Chọn tập: " --delimiter='|' --with-nth=1)
                 if [ -n "$new_selection" ]; then
                     current_ep_name=$(echo "$new_selection" | cut -d'|' -f1)
                     link=$(echo "$new_selection" | cut -d'|' -f2)
                     add_to_history "$name" "$current_ep_name" "$link"
                     play_stream "$link" "$name - Tập $current_ep_name"
                 fi
                ;;
            "⬇ Tải tập này") download_video "$link" "$name - Tap $current_ep_name" & ;;
            "✂ Cắt Video (1 lần)") cut_video_logic "$link" "single" ;;
            "✂✂ Cắt Video (Nhiều lần)") cut_video_logic "$link" "multi" ;;
            "🧬 Ghép Video (Grafting)") merge_video_logic ;;
            "❤️ Thêm vào Yêu Thích") add_to_favorites "$name" "$anime_slug" ;;
            "🔙 Menu Chính"|*) kill "$PLAYER_PID" 2>/dev/null; return 0 ;;
        esac
    done
}

play_anidata_local() {
    if [ ! -f "$LOCAL_DATA_FILE" ]; then
        echo "Tải data..."
        local data_url="https://raw.githubusercontent.com/niyakipham/anisub/refs/heads/main/assets/aniw_export_2026-01-14.csv"
        mkdir -p "$SCRIPT_DIR/assets"
        curl -L "$data_url" -o "$LOCAL_DATA_FILE"
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

show_settings() {
    while true; do
        opt=$(echo -e "Đổi trình phát (Hiện tại: $PLAYER)\nĐổi thư mục tải (Hiện tại: $DOWNLOAD_DIR)\nQuay lại" | fzf --prompt="Cài đặt > ")
        case "$opt" in
            "Đổi trình phát"*) read -r -p "Nhập tên lệnh trình phát: " inp; [ -n "$inp" ] && { PLAYER="$inp"; save_config; } ;;
            "Đổi thư mục tải"*) read -r -p "Nhập đường dẫn tuyệt đối: " inp; [ -n "$inp" ] && { DOWNLOAD_DIR="$inp"; mkdir -p "$inp"; save_config; } ;;
            *) break ;;
        esac
    done
}

update_script() {
    local remote=$(curl -s "$SCRIPT_URL")
    if [ -n "$remote" ]; then
         if ! diff -q "$0" <(echo "$remote") >/dev/null; then
             echo "$remote" > "$0"
             echo "Đã cập nhật. Hãy khởi động lại."
             exit 0
         else
             echo "Bạn đang ở phiên bản mới nhất."
             sleep 1
         fi
    else
        echo "Lỗi kết nối."
        sleep 2
    fi
}

main() {
    trap 'kill $(jobs -p) 2>/dev/null' EXIT
    check_dependencies
    load_config

    while true; do
        clear
        echo "=== ANISUB CLI ULTIMATE ==="
        main_opt=$(echo -e "🔎 Tìm kiếm Anime (Có Ảnh)\n📂 Xem từ Local Anidata\n📜 Lịch sử xem\n⭐ Danh sách yêu thích\n⚙️ Cài đặt\n🔄 Cập nhật\n🚪 Thoát" | fzf --prompt="Menu > ")

        case "$main_opt" in
            "🔎 Tìm kiếm Anime")
                read -r -p "Nhập tên anime: " k
                if [ -n "$k" ]; then
                    # API call now returns poster url in 3rd field
                    res=$(api_search_kkphim "$k")
                    
                    if [ -z "$res" ] || [ "$res" == "null" ]; then echo "Không tìm thấy phim."; sleep 1; continue; fi
                    
                    # FZF With Preview Image!
                    # --with-nth=1 : Only show Name column in list
                    # --preview: Calls the handler function with the selected line
                    sel=$(echo "$res" | fzf --delimiter='|' --with-nth=1 --preview 'bash -c "preview_handler {}"' --preview-window=right:40%)
                    
                    if [ -n "$sel" ]; then
                        name=$(echo "$sel" | cut -d'|' -f1)
                        slug=$(echo "$sel" | cut -d'|' -f2)
                        
                        eps=$(api_get_episodes_kkphim "$slug")
                        if [ -z "$eps" ]; then echo "Lỗi lấy tập."; sleep 1; continue; fi
                        
                        sel_ep=$(echo "$eps" | fzf --prompt="Chọn tập > " --delimiter='|' --with-nth=1)
                        if [ -n "$sel_ep" ]; then
                             ename=$(echo "$sel_ep" | cut -d'|' -f1)
                             elink=$(echo "$sel_ep" | cut -d'|' -f2)
                             add_to_history "$name" "$ename" "$elink"
                             manage_currently_playing "$name" "$ename" "$elink" "$eps" "$slug"
                        fi
                    fi
                fi
                ;;
            "📂 Xem từ Local Anidata") play_anidata_local ;;
            "📜 Lịch sử xem") show_history ;;
            "⭐ Danh sách yêu thích")
                fav_line=$(show_favorites)
                if [ $? -eq 0 ]; then
                     fname=$(echo "$fav_line" | cut -d'|' -f1)
                     fslug=$(echo "$fav_line" | cut -d'|' -f2)
                     eps=$(api_get_episodes_kkphim "$fslug")
                     if [ -n "$eps" ]; then
                         sel_ep=$(echo "$eps" | fzf --prompt="[$fname] Chọn tập > " --delimiter='|' --with-nth=1)
                         [ -n "$sel_ep" ] && manage_currently_playing "$fname" "$(echo "$sel_ep" | cut -d'|' -f1)" "$(echo "$sel_ep" | cut -d'|' -f2)" "$eps" "$fslug"
                     else
                         echo "Không tải được phim."; sleep 2
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
