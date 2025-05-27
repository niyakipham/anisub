#!/bin/bash

# --- CONFIGURATION & DATA FILES ---
CONFIG_DIR="$HOME/.config/anisub_cli"
CONFIG_FILE="$CONFIG_DIR/config.cfg"
HISTORY_FILE="$CONFIG_DIR/history.log"
FAVORITES_FILE="$CONFIG_DIR/favorites.txt"
SCRIPT_URL="https://raw.githubusercontent.com/NiyakiPham/anisub/main/anisub.sh" # Replace with actual URL if hosted

# --- DEFAULTS ---
DEFAULT_PLAYER="mpv"
DEFAULT_DOWNLOAD_DIR="$HOME/Downloads/anime"
PLAYER=""
DOWNLOAD_DIR=""

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
    mkdir -p "$DOWNLOAD_DIR" # Ensure download dir exists
    touch "$HISTORY_FILE" "$FAVORITES_FILE"
}

save_config() {
    echo "PLAYER=$PLAYER" > "$CONFIG_FILE"
    echo "DOWNLOAD_DIR=$DOWNLOAD_DIR" >> "$CONFIG_FILE"
    echo "Cấu hình đã được lưu."
    sleep 1
}

check_dependencies() {
    local missing_deps=()
    local deps=("ffmpeg" "curl" "grep" "yt-dlp" "fzf" "pup" "manga-tui" "jq" "awk" "cut")
    echo "Kiểm tra các phụ thuộc..."
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "LỖI: Thiếu các phụ thuộc sau: ${missing_deps[*]}"
        echo "Vui lòng cài đặt chúng."
        echo "Ví dụ trên Ubuntu: sudo apt install ${missing_deps[*]}"
        echo "Ví dụ trên Arch: yay -S ${missing_deps[*]}"
        exit 1
    fi
    echo "Tất cả phụ thuộc đã được cài đặt."
}

# --- HISTORY FUNCTIONS ---
add_to_history() {
    local anime_name="$1"
    local episode_number="$2"
    local link="$3"
    # Remove duplicates before adding
    sed -i "/|${anime_name}|${episode_number}|/d" "$HISTORY_FILE"
    echo "$(date +%Y-%m-%d\ %H:%M:%S)|${anime_name}|${episode_number}|${link}" >> "$HISTORY_FILE"
}

show_history() {
    if [ ! -s "$HISTORY_FILE" ]; then
        echo "Lịch sử xem trống."
        sleep 2
        return
    fi
    selected_history=$(tac "$HISTORY_FILE" | fzf --prompt="Lịch sử xem (Chọn để xem lại): " --delimiter='|' --with-nth=1,2,3)
    if [ -n "$selected_history" ]; then
        local link=$(echo "$selected_history" | cut -d'|' -f4)
        local anime_name=$(echo "$selected_history" | cut -d'|' -f2)
        local episode_number=$(echo "$selected_history" | cut -d'|' -f3)
        echo "Đang phát lại: $anime_name - Tập $episode_number..."
        "$PLAYER" "$link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window
    fi
}

# --- FAVORITES FUNCTIONS ---
add_to_favorites() {
    local anime_name="$1"
    local anime_url="$2"
    if grep -q "|$anime_url\$" "$FAVORITES_FILE"; then
        echo "'$anime_name' đã có trong danh sách yêu thích."
    else
        echo "$anime_name|$anime_url" >> "$FAVORITES_FILE"
        echo "'$anime_name' đã được thêm vào danh sách yêu thích."
    fi
    sleep 2
}

show_favorites() {
    if [ ! -s "$FAVORITES_FILE" ]; then
        echo "Danh sách yêu thích trống."
        sleep 2
        return 1 # Return 1 to indicate no selection
    fi
    selected_favorite=$(fzf --prompt="Chọn anime yêu thích: " < "$FAVORITES_FILE")
    if [ -n "$selected_favorite" ]; then
        echo "$selected_favorite" | cut -d'|' -f2
        return 0 # Return 0 to indicate selection
    else
        return 1 # Return 1 if nothing selected
    fi
}

# --- SETTINGS FUNCTION ---
show_settings() {
    while true; do
        setting_option=$(echo -e "Trình phát hiện tại: $PLAYER\nThư mục tải xuống: $DOWNLOAD_DIR\nĐặt lại trình phát\nĐặt lại thư mục tải xuống\nQuay lại" | fzf --prompt="Cài đặt: ")
        case "$setting_option" in
            "Đặt lại trình phát")
                read -r -p "Nhập trình phát mới (ví dụ: mpv, vlc): " new_player
                if command -v "$new_player" &> /dev/null; then
                    PLAYER="$new_player"
                    save_config
                else
                    echo "Lỗi: Trình phát '$new_player' không tồn tại."
                    sleep 2
                fi
                ;;
            "Đặt lại thư mục tải xuống")
                read -r -p "Nhập đường dẫn thư mục tải xuống mới: " new_dir
                DOWNLOAD_DIR="$new_dir"
                mkdir -p "$DOWNLOAD_DIR"
                save_config
                ;;
            "Quay lại")
                break
                ;;
            *)
                ;;
        esac
    done
}

# --- UPDATE FUNCTION ---
update_script() {
    echo "Đang kiểm tra cập nhật từ $SCRIPT_URL..."
    local latest_script=$(curl -s "$SCRIPT_URL")
    local current_script_path="$0"

    if [ -z "$latest_script" ]; then
        echo "Không thể tải phiên bản mới nhất. Vui lòng kiểm tra lại URL hoặc kết nối mạng."
        sleep 2
        return
    fi

    if ! diff -q "$current_script_path" <(echo "$latest_script") >/dev/null; then
        echo "Có phiên bản mới! Bạn có muốn cập nhật không? (y/n)"
        read -r confirm_update
        if [[ "$confirm_update" == "y" || "$confirm_update" == "Y" ]]; then
            echo "$latest_script" > "$current_script_path"
            echo "Script đã được cập nhật. Vui lòng chạy lại."
            exit 0
        else
            echo "Đã hủy cập nhật."
        fi
    else
        echo "Bạn đang sử dụng phiên bản mới nhất."
    fi
    sleep 2
}

# --- CORE ANIME FUNCTIONS ---
play_anime() {

    select_anime() {
        local keyword="$1"
        local anime_list

        anime_list=$(
            curl -s "https://ophim17.cc/tim-kiem?keyword=$keyword" |
            pup '.ml-4 > a attr{href}' |
            awk '{print "https://ophim17.cc" $0}' |
            while IFS= read -r link; do
                title=$(curl -s "$link" | pup 'h1 text{}')
                printf '%s\n' "$link@@@$title"
            done |
            awk -F '@@@' '{print NR ". " $2 " (" $1 ")"}'
        )

        if [[ -z "$anime_list" ]] || [[ "$anime_list" == "Not Found" ]]; then
            echo "Không tìm thấy anime nào với từ khóa '$keyword'."
            return 1
        fi

        selected_anime=$(echo "$anime_list" | fzf --prompt="Chọn anime: ")
        if [[ -z "$selected_anime" ]]; then
            echo "Không có anime nào được chọn."
            return 1
        fi

        echo "$selected_anime" | sed 's/.*(\(.*\))/\1/'
    }

    get_episode_list_from_url() {
        local url="$1"
        local html_content
        local episode_data

        html_content=$(curl -s "$url")
        if [[ -z "$html_content" ]]; then
            echo "Không thể tải nội dung từ URL: $url" >&2
            return 1
        fi

        episode_data=$(echo "$html_content" | pup 'script json{}' | jq -r '.[].text | @text' | grep -oE '"(http|https)://[^"]*index.m3u8"' | sed 's/"//g')

        if [[ -z "$episode_data" ]]; then
            echo "Không tìm thấy danh sách tập phim cho URL: $url" >&2
            return 1
        fi

        local i=1
        while IFS= read -r link; do
            printf "%s|%s\n" "$i" "$link"
            i=$((i + 1))
        done <<< "$episode_data"
    }

    get_episode_list() {
        get_episode_list_from_url "$1"
    }

    get_episode_title() {
        local episode_url="$1"
        local episode_number="$2"
        local episode_title

        # Try to get the title, fallback to Episode N
        episode_title=$(curl -s "$episode_url" | pup ".ep-name text{}" | sed -n "${episode_number}p" | tr -d '[:space:]')

        if [[ -z "$episode_title" ]]; then
            episode_title="Tap_$episode_number"
        fi

        echo "$episode_title" | tr -d '/\:*?"<>|' # Sanitize filename
    }

    play_video() {
        local selected_anime_line="$1"
        local anime_url
        local episode_data
        local anime_name

        anime_url=$(echo "$selected_anime_line" | sed 's/.*(\(.*\))/\1/')
        anime_name=$(echo "$selected_anime_line" | sed 's/^[^(]*(\([^)]*\)) \+//;s/ ([^ ]*)$//')

        episode_data=$(get_episode_list "$anime_url")
        if [[ -z "$episode_data" ]]; then
            echo "Không tìm thấy danh sách tập phim." >&2
            return 1
        fi

        play_video_with_menu "$anime_name" "$anime_url" "$episode_data"
    }

    play_video_with_menu() {
        local anime_name="$1"
        local anime_url="$2"
        local episode_data="$3"
        local selected_episode
        local current_episode_number
        local current_link
        local action
        local mpv_pid
        local download_status=""
        local anime_dir

        selected_episode=$(echo "$episode_data" | fzf --prompt="Chọn tập phim: " --preview 'echo {2}')
        if [[ -z "$selected_episode" ]]; then
            echo "Không có tập nào được chọn." >&2
            return 1
        fi

        current_episode_number=$(echo "$selected_episode" | cut -d'|' -f1)
        current_link=$(echo "$selected_episode" | cut -d'|' -f2)

        while true; do
            echo "Đang phát $anime_name - Tập $current_episode_number..."
            add_to_history "$anime_name" "$current_episode_number" "$current_link"
            "$PLAYER" "$current_link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window &
            mpv_pid=$!

            while kill -0 "$mpv_pid" 2> /dev/null; do
                action=$(echo -e "Next\nPrevious\nSelect\nDownloads\nCut Video\nGrafting\nAdd to Favorites\nBack to Menu" | fzf --prompt="Đang phát: $anime_name - Tập $current_episode_number $download_status: ")
                download_status=""

                case "$action" in
                    "Next")
                        kill "$mpv_pid"
                        local next_episode_number=$((current_episode_number + 1))
                        local next_link=$(echo "$episode_data" | grep "^$next_episode_number|" | cut -d'|' -f2)
                        if [[ -z "$next_link" ]]; then
                            echo "Không có tập tiếp theo." >&2; sleep 1;
                        else
                            current_episode_number=$next_episode_number
                            current_link=$next_link
                        fi
                        break # Break inner loop to restart play
                        ;;
                    "Previous")
                        kill "$mpv_pid"
                        local previous_episode_number=$((current_episode_number - 1))
                        local previous_link=$(echo "$episode_data" | grep "^$previous_episode_number|" | cut -d'|' -f2)
                        if [[ -z "$previous_link" || "$previous_episode_number" -lt 1 ]]; then
                            echo "Không có tập trước đó." >&2; sleep 1;
                        else
                            current_episode_number=$previous_episode_number
                            current_link=$previous_link
                        fi
                        break # Break inner loop to restart play
                        ;;
                    "Select")
                        kill "$mpv_pid"
                        selected_episode=$(echo "$episode_data" | fzf --prompt="Chọn tập phim: " --preview 'echo {2}')
                        if [[ -n "$selected_episode" ]]; then
                            current_episode_number=$(echo "$selected_episode" | cut -d'|' -f1)
                            current_link=$(echo "$selected_episode" | cut -d'|' -f2)
                            break # Break inner loop to restart play
                        fi
                        # If no selection, continue current play
                        "$PLAYER" "$current_link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window &
                        mpv_pid=$!
                        ;;
                    "Downloads")
                        kill "$mpv_pid"
                        anime_dir_sanitized=$(echo "$anime_name" | tr -d '/\:*?"<>|' | tr ' ' '_') # Sanitize dir name
                        episode_title=$(get_episode_title "$anime_url" "$current_episode_number")
                        local full_download_path="$DOWNLOAD_DIR/$anime_dir_sanitized"
                        mkdir -p "$full_download_path"
                        download_status="(Đang tải...)"
                        echo "Đang tải tập $current_episode_number - $episode_title vào thư mục $full_download_path..."
                        yt-dlp -o "$full_download_path/$episode_title.%(ext)s" "$current_link" &
                        echo "Đã bắt đầu tải xuống dưới nền."
                        sleep 1
                        "$PLAYER" "$current_link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window &
                        mpv_pid=$!
                        ;;
                    "Cut Video")
                        kill "$mpv_pid"
                        cut_option=$(echo -e "Cắt 1 lần\nCắt nhiều lần\nQuay lại" | fzf --prompt="Chọn chế độ cắt: ")
                        local cut_dir="$DOWNLOAD_DIR/cut"
                        mkdir -p "$cut_dir"
                        case "$cut_option" in
                            "Cắt 1 lần")
                                read -r -p "Nhập thời gian bắt đầu (HH:MM:SS): " start_time
                                read -r -p "Nhập thời gian kết thúc (HH:MM:SS): " end_time
                                output_file="$cut_dir/cut_$(date +%s).mp4"
                                echo "Đang cắt video từ $start_time đến $end_time..."
                                ffmpeg -i "$current_link" -ss "$start_time" -to "$end_time" -c copy "$output_file"
                                echo "Video đã được cắt và lưu tại: $output_file"
                                sleep 2
                                ;;
                            "Cắt nhiều lần")
                                read -r -p "Nhập số lượng phân đoạn muốn cắt: " num_segments
                                for ((i=1; i<=num_segments; i++)); do
                                    echo "Phân đoạn $i:"
                                    read -r -p "Nhập thời gian bắt đầu (HH:MM:SS): " start_time
                                    read -r -p "Nhập thời gian kết thúc (HH:MM:SS): " end_time
                                    output_file="$cut_dir/cut_${i}_$(date +%s).mp4"
                                    echo "Đang cắt video từ $start_time đến $end_time..."
                                    ffmpeg -i "$current_link" -ss "$start_time" -to "$end_time" -c copy "$output_file"
                                    echo "Phân đoạn $i đã được cắt và lưu tại: $output_file"
                                done
                                sleep 2
                                ;;
                            *) ;;
                        esac
                        "$PLAYER" "$current_link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window &
                        mpv_pid=$!
                        ;;
                    "Grafting")
                         kill "$mpv_pid"
                         local cut_dir="$DOWNLOAD_DIR/cut"
                         local graft_dir="$DOWNLOAD_DIR/grafting"
                         mkdir -p "$graft_dir"
                         if [ -z "$(ls -A $cut_dir/*.mp4 2>/dev/null)" ]; then
                             echo "Thư mục '$cut_dir' trống. Vui lòng cắt video trước."
                             sleep 2
                         else
                             grafting_option=$(echo -e "Ghép nhiều video\nQuay lại" | fzf --prompt="Chọn chế độ ghép: ")
                             case "$grafting_option" in
                                 "Ghép nhiều video")
                                     echo "Chọn các video muốn ghép (Sử dụng Tab để chọn, Enter để xác nhận):"
                                     video_files=($(find "$cut_dir" -type f -name "*.mp4" | fzf --multi --prompt="Chọn video: "))
                                     if [ ${#video_files[@]} -gt 1 ]; then
                                         output_file="$graft_dir/grafted_$(date +%s).mp4"
                                         echo "Đang ghép video..."
                                         list_file=$(mktemp)
                                         for f in "${video_files[@]}"; do echo "file '$f'"; done > "$list_file"
                                         ffmpeg -f concat -safe 0 -i "$list_file" -c copy "$output_file"
                                         rm "$list_file"
                                         echo "Video đã được ghép và lưu tại: $output_file"
                                         sleep 2
                                     else
                                        echo "Cần chọn ít nhất 2 video để ghép."
                                        sleep 2
                                     fi
                                     ;;
                                 *) ;;
                             esac
                         fi
                         "$PLAYER" "$current_link" --no-terminal --profile=sw-fast --audio-display=no --no-keepaspect-window &
                         mpv_pid=$!
                        ;;
                    "Add to Favorites")
                        add_to_favorites "$anime_name" "$anime_url"
                        # Don't kill mpv, just show message and continue
                        ;;
                    "Back to Menu")
                        kill "$mpv_pid"
                        return 0 # Return to main menu
                        ;;
                    "") # Exit on empty input (Ctrl+C or Esc)
                        kill "$mpv_pid"
                        echo "Thoát"
                        exit 0
                        ;;
                    *)
                        echo "Lựa chọn không hợp lệ." >&2
                        sleep 1
                        ;;
                esac
            done # End of inner while loop (action selection)

            # Wait for mpv to finish if it wasn't killed by an action
            wait "$mpv_pid" 2>/dev/null
        done # End of outer while loop (video playing)
    }

    play_video_from_url() {
        local url="$1"
        local episode_data
        local anime_name

        html_content=$(curl -s "$url")
        anime_name=$(echo "$html_content" | pup 'h1 text{}')
        if [[ -z "$anime_name" ]]; then
            anime_name=$(echo "$url" | awk -F'/' '{print $5}') # Fallback
        fi

        episode_data=$(get_episode_list_from_url "$url")
        if [[ -z "$episode_data" ]]; then
            echo "Không tìm thấy danh sách tập phim." >&2
            return 1
        fi

        play_video_with_menu "$anime_name" "$url" "$episode_data"
    }

    play_anidata() {
        local CSV_URL="https://raw.githubusercontent.com/toilamsao/anidata/refs/heads/main/data.csv"
        echo "Đang tải dữ liệu từ Anidata..."
        local CSV_CONTENT=$(curl -s "$CSV_URL" | sed 's/"//g')

        if [ -z "$CSV_CONTENT" ]; then
            echo "Không thể tải dữ liệu Anidata."
            sleep 2
            return
        fi

        local ANIME_NAMES=$(echo "$CSV_CONTENT" | sed '1d' | cut -d',' -f1 | sort -u)
        local SELECTED_ANIME=$(echo "$ANIME_NAMES" | fzf --prompt="Chọn anime (Anidata): ")

        if [ -z "$SELECTED_ANIME" ]; then
            echo "Không có anime nào được chọn."
            return
        fi

        local EPISODES=$(echo "$CSV_CONTENT" | awk -F',' -v anime="$SELECTED_ANIME" '$1 == anime {print $2 " | " $3}')
        local SELECTED_EPISODE=$(echo "$EPISODES" | fzf --prompt="Chọn tập: ")

        if [ -z "$SELECTED_EPISODE" ]; then
            echo "Không có tập nào được chọn."
            return
        fi

        local LINK=$(echo "$SELECTED_EPISODE" | awk -F' \\| ' '{print $2}')
        local ANIME_NAME=$(echo "$SELECTED_ANIME")
        local EPISODE_NAME=$(echo "$SELECTED_EPISODE" | awk -F' \\| ' '{print $1}')

        echo "Đang phát $ANIME_NAME - $EPISODE_NAME..."
        add_to_history "$ANIME_NAME (Anidata)" "$EPISODE_NAME" "$LINK"
        "$PLAYER" "$LINK"
    }

    # --- MAIN MENU LOOP ---
    while true; do
        selected_option=$(echo -e "Tìm kiếm Anime (OPhim)\nXem từ Anidata\nĐọc Manga\nLịch sử xem\nDanh sách yêu thích\nCài đặt\nCập nhật Script\nThoát" | fzf --prompt="✨ ANISUB-CLI - CHỌN CHỨC NĂNG ✨: ")

        case "$selected_option" in
            "Tìm kiếm Anime (OPhim)")
                while true; do
                    read -r -p "Tìm kiếm anime hoặc nhập URL: " input
                    if [[ -n "$input" ]]; then
                        break
                    fi
                done

                if [[ "$input" =~ ^https?:// ]]; then
                    play_video_from_url "$input"
                else
                    anime_name_encoded=$(echo "$input" | sed 's/ /+/g')
                    selected_anime_line=$(select_anime "$anime_name_encoded")
                    if [[ $? -ne 0 ]]; then
                        continue # Go back to main menu
                    fi
                    play_video "$selected_anime_line"
                fi
                ;;
            "Xem từ Anidata")
                play_anidata
                ;;
            "Đọc Manga")
                echo "Đang khởi chạy manga-tui (Thiết lập tiếng Việt)..."
                manga-tui lang --set 'vi' > /dev/null 2>&1
                manga-tui
                ;;
            "Lịch sử xem")
                show_history
                ;;
            "Danh sách yêu thích")
                 fav_url=$(show_favorites)
                 if [ $? -eq 0 ]; then
                     play_video_from_url "$fav_url"
                 fi
                 ;;
            "Cài đặt")
                show_settings
                ;;
            "Cập nhật Script")
                update_script
                ;;
            "Thoát" | "")
                echo "Tạm biệt Bạn"
                exit 0
                ;;
            *)
                echo "Lựa chọn không hợp lệ." >&2
                sleep 1
                ;;
        esac
    done
}

# --- SCRIPT START ---
clear
echo "Khởi động Anisub-CLI..."
check_dependencies
load_config
play_anime
