#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "Bạn phải thực thi lệnh này thông qua quyền root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    LOGE "Không thể kiểm tra phiên bản hệ điều hành, vui lòng liên hệ cho nhà phát triển！\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        LOGE "Vui lòng sử dụng hệ điều hành CentOS 7 trở lên！\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        LOGE "Vui lòng sử dụng hệ điều hành Ubuntu 16 trở lên！\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        LOGE "Vui lòng sử dụng hệ điều hành Debian 8 trở lên！\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Mặc định$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Bạn có muốn khởi động lại bảng điều khiển không? Khởi động lại bảng điều khiển cũng sẽ khởi động lại xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Nhấn Enter để quay lại Menu chính: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "Chức năng này sẽ buộc cài đặt lại phiên bản mới nhất và dữ liệu sẽ không bị mất. Bạn có muốn tiếp tục?" "n"
    if [[ $? != 0 ]]; then
        LOGE "已取消"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "Cập nhật hoàn tất, bảng điều khiển đã tự động khởi động lại"
        exit 0
    fi
}

uninstall() {
    confirm "Bạn có chắc chắn muốn gỡ cài đặt bảng điều khiển không? xray cũng sẽ được gỡ cài đặt" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "Gỡ cài đặt thành công. Nếu bạn muốn xóa script này, hãy chạy nó sau khi thoát khỏi script ${green}rm /usr/bin/x-ui -f${plain} để xóa"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Bạn có chắc chắn muốn đặt lại tên người dùng và mật khẩu cho quản trị viên không?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "Tên người dùng và mật khẩu đã được đặt lại thành ${green}admin${plain}，vui lòng khởi động lại bảng điều khiển để thay đổi có hiệu lực"
    confirm_restart
}

reset_config() {
    confirm "Bạn có chắc muốn đặt lại tất cả cài đặt bảng điều khiển không? Dữ liệu tài khoản sẽ không bị mất, tên người dùng và mật khẩu sẽ không thay đổi" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "Tất cả cài đặt bảng điều khiển đã được đặt lại về mặc định. Hãy khởi động lại bảng điều khiển và sử dụng cổng ${green}54321${plain} để truy cập bảng điều khiển"
    confirm_restart
}

check_config() {
    info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        LOGE "get current settings error,please check logs"
        show_menu
    fi
    LOGI "${info}"
}

set_port() {
    echo && echo -n -e "Nhập số Port [1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "已取消"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "Port đã được đặt. Hãy khởi động lại bảng điều khiển và sử dụng cổng mới: ${green}${port}${plain}"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "Bảng điều khiển hiện đang hoạt động, nếu muốn khởi động lại, vui lòng chọn Khởi động lại"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "x-ui đã được bật trước đó!"
        else
            LOGE "Bảng điều khiển không thể bật, có thể do thời gian khởi động vượt quá thời gian quy định (hai giây). Hãy kiểm tra thông tin nhật ký sau"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "Bảng điều khiển đã được tắt trước đó!"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "x-ui và xray đã dừng hoạt động thành công!"
        else
            LOGE "Bảng điều khiển không thể dừng, có thể do thời gian khởi động vượt quá thời gian quy định (hai giây). Hãy kiểm tra thông tin nhật ký sau"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "x-ui và xray đã khởi động lại thành công!"
    else
        LOGE "Bảng điều khiển không thể khởi động lại, có thể do thời gian khởi động vượt quá thời gian quy định (hai giây). Hãy kiểm tra thông tin nhật ký sau"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui được bật thành công!"
    else
        LOGE "không thể khởi động x-ui!"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        LOGI "Tắt tự khởi động x-ui thành công!"
    else
        LOGE "Không thể tắt quá trình tự khởi động x-ui!"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/vaxilu/x-ui/raw/master/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "Không thể tải xuống script. Hãy kiểm tra lại!"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        LOGI "Script đã được nâng cấp thành công. Hãy chạy lại script." && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "Bảng điều khiển đã được cài đặt trước đó, vui lòng không thực hiện cài đặt lại!"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "Vui lòng cài đặt bảng điều khiển trước!"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "Trạng thái bảng điều khiển: ${green}Đang hoạt động${plain}"
        show_enable_status
        ;;
    1)
        echo -e "Trạng thái bảng điều khiển: ${yellow}Đang tắt${plain}"
        show_enable_status
        ;;
    2)
        echo -e "Trạng thái bảng điều khiển: ${red}Chưa được cài đặt${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Tự động khởi động: ${green}bật${plain}"
    else
        echo -e "Tự động khởi động: ${red}tắt${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "Trạng thái xray: ${green}Đang hoạt động${plain}"
    else
        echo -e "Trạng thái xray: ${red}Đang tắt${plain}"
    fi
}

ssl_cert_issue() {
    echo -E ""
    LOGD "******Hướng dẫn******"
    LOGI "Script này sẽ sử dụng script Acme để đăng ký chứng chỉ. Khi sử dụng script này, bạn phải đảm bảo:"
    LOGI "1. Đã có địa chỉ Email đã đăng kí Cloudflare"
    LOGI "2. Đã có Cloudflare Global API Key"
    LOGI "3. Tên miền đã được trỏ tới Cloudflare"
    LOGI "4. Đường dẫn cài đặt mặc định cho tập lệnh này để đăng ký chứng chỉ là thư mục /root/cert"
    confirm "Hãy xác nhận bạn đã chuẩn bị mọi thứ được nêu trên [y/n]" "y"
    if [ $? -eq 0 ]; then
        cd ~
        LOGI "Cài đặt Acme"
        curl https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            LOGE "Không thể cài đặt script Acme"
            exit 1
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        else
            rm -rf $certPath
            mkdir $certPath
        fi
        LOGD "Vui lòng nhập tên miền:"
        read -p "Nhập tên miền của bạn ở đây:" CF_Domain
        LOGD "Tên miền của bạn đã được đặt thành:${CF_Domain}"
        LOGD "Vui lòng nhập khóa API:"
        read -p "Nhập khóa API của bạn ở đây:" CF_GlobalKey
        LOGD "Đã đặt khóa API thành:${CF_GlobalKey}"
        LOGD "Vui lòng nhập địa chỉ Email đã đăng kí Cloudflare:"
        read -p "Nhập địa chỉ Email của bạn ở đây:" CF_AccountEmail
        LOGD "Đã đặt địa chỉ Email thành:${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "Chuyển đổi CA mặc định sang Lets'Encrypt không thành công. Tiến hành thoát..."
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "Cấp chứng chỉ không thành công. Tiến hành thoát..."
            exit 1
        else
            LOGI "Đã cấp chứng chỉ thành công! Đang cài đặt..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "Cài đặt chứng chỉ không thành công. Tiến hành thoát..."
            exit 1
        else
            LOGI "Chứng chỉ đã được cài đặt thành công, đã bật tự động cập nhật"
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "Thiết lập tự động cập nhật không thành công. Tiến hành thoát..."
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "Chứng chỉ đã được cài đặt và kích hoạt tự động gia hạn chứng chỉ. Cụ thể:"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}

show_usage() {
    echo "Cách sử dụng script quản lí x-ui: "
    echo "------------------------------------------"
    echo "x-ui              - Hiển thị Menu quản trị (nhiều tính năng hơn)"
    echo "x-ui start        - Khởi động x-ui"
    echo "x-ui stop         - Tắt x-ui"
    echo "x-ui restart      - Khởi động lại x-ui"
    echo "x-ui status       - Xem trạng thái x-ui"
    echo "x-ui enable       - Bật x-ui"
    echo "x-ui disable      - Tắt x-ui"
    echo "x-ui log          - Xem nhật kí x-ui"
    echo "x-ui v2-ui        - Chuyển dữ liệu từ v2-ui trên thiết bị này sang x-ui"
    echo "x-ui update       - Cập nhật x-ui"
    echo "x-ui install      - Cài đặt x-ui"
    echo "x-ui uninstall    - Gỡ cài đặt x-ui"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}Script quản lí x-ui${plain}
  ${green}0.${plain} Thoát script
————————————————
  ${green}1.${plain} Cài đặt x-ui
  ${green}2.${plain} Cập nhật x-ui
  ${green}3.${plain} Gỡ cài đặt x-ui
————————————————
  ${green}4.${plain} Đặt lại tên người dùng và mật khẩu
  ${green}5.${plain} Đặt lại bảng điều khiển
  ${green}6.${plain} Đặt lại Port của bảng điều khiển
  ${green}7.${plain} Xem cài đặt hiện tại của bảng điều khiển
————————————————
  ${green}8.${plain} Khởi động x-ui
  ${green}9.${plain} Dừng x-ui
  ${green}10.${plain} Khởi động lại x-ui
  ${green}11.${plain} Xem trạng thái x-ui
  ${green}12.${plain} Hủy khởi động x-ui
————————————————
  ${green}13.${plain} Thiết lập tự khởi động cho x-ui
  ${green}14.${plain} Tắt thiết lập tự khởi động cho x-ui
————————————————
  ${green}15.${plain} Cài đặt bbr với một click (mới nhất)
  ${green}16.${plain} Cài đặt chứng chỉ SSL với một click (sử dụng acme)
 "
    show_status
    echo && read -p "Vui lòng chọn [0-16]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && check_config
        ;;
    8)
        check_install && start
        ;;
    9)
        check_install && stop
        ;;
    10)
        check_install && restart
        ;;
    11)
        check_install && status
        ;;
    12)
        check_install && show_log
        ;;
    13)
        check_install && enable
        ;;
    14)
        check_install && disable
        ;;
    15)
        install_bbr
        ;;
    16)
        ssl_cert_issue
        ;;
    *)
        LOGE "Vui lòng nhập lựa chọn chính xác [0-16]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "v2-ui")
        check_install 0 && migrate_v2_ui 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
