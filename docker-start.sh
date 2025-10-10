#!/bin/bash

# SSH 설정 적용
echo "Configuring SSH settings..."
echo 'root:'$ROOT_PASSWORD | chpasswd
sed -i 's/^#Port .*/Port '$SSH_PORT'/' /etc/ssh/sshd_config
sed -i 's/^Port .*/Port '$SSH_PORT'/' /etc/ssh/sshd_config
service ssh start
echo "SSH service started on port $SSH_PORT"

# crontab 설정 적용 (파일이 volume으로 마운트됨)
if [ -f "/etc/cron.d/app-crontab" ]; then
    echo "Loading crontab configuration from mounted file..."
    chmod 0644 /etc/cron.d/app-crontab
    # 파일 끝에 빈 줄 추가 (필수)
    sed -i -e '$a\' /etc/cron.d/app-crontab
    # crontab 설치
    echo "Installing crontab from /etc/cron.d/app-crontab"
    crontab /etc/cron.d/app-crontab

    # crontab 설정 확인
    echo "Current crontab configuration:"
    crontab -l
    
    # cron 서비스 시작
    echo "Starting cron service..."
    service rsyslog start
    service cron start
    
    # cron 로그를 별도 파일로 복사
    echo "Setting up cron logging to /exposed/logs/cron.log..."
    mkdir -p /exposed/logs
    (tail -f /var/log/syslog | grep CRON >> /exposed/logs/cron.log) &
    
    echo "Cron setup completed!"
else
    echo "No cron jobs to set up. Crontab file not found."
fi

# bashrc 설정 적용 (파일이 volume으로 마운트됨)
if [ -f "/root/.bashrc" ]; then
    echo "Loading bashrc configuration from mounted file..."
    source /root/.bashrc
    echo "Bashrc configuration loaded!"
else
    echo "No bashrc configuration found."
fi

## chrome 설치
# 1. 키 추가 (최신 방식)
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/google-chrome.gpg > /dev/null &&

# 2. 저장소 추가
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list &&

# 3. 패키지 목록 업데이트
sudo apt-get update &&

# 4. Chrome 설치
sudo apt-get install -y google-chrome-stable
