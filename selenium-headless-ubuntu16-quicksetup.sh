#!/bin/bash

# OS Setup
sudo apt-get install -y aptitude ubuntu-minimal
sudo aptitude markauto -y '~i!~nubuntu-minimal'
sudo apt-get update --fix-missing
sudo apt-get install -y linux-image-virtual openssh-server
sudo apt-get upgrade -y

# Supporting Software
sudo apt-get install -y xvfb x11vnc unzip default-jre openbox

# Fix hostname
sudo hostname selenium.head
sudo sh -c 'echo $(hostname) > /etc/hostname'
sudo sh -c 'FQDN=$(hostname); sed -i "s/^127.0.0.1.*/127.0.0.1 localhost localhost.localdomain $FQDN/" /etc/hosts'

# Setup a swap
sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Create selenium user
sudo useradd -m selenium

# Firefox & Chrome
sudo apt-get install -y firefox chromium-browser libgconf2-4

# Chromedriver
wget https://chromedriver.storage.googleapis.com/$(curl -f -s https://chromedriver.storage.googleapis.com/LATEST_RELEASE || printf 2.37)/chromedriver_linux64.zip
unzip chromedriver_linux64.zip
chmod +x chromedriver
sudo mv -f chromedriver /usr/local/share/chromedriver
sudo ln -f -s /usr/local/share/chromedriver /usr/local/bin/chromedriver
sudo ln -f -s /usr/local/share/chromedriver /usr/bin/chromedriver

# Geckodriver
wget https://github.com/mozilla/geckodriver/releases/download/v0.24.0/geckodriver-v0.24.0-linux64.tar.gz
tar -zxf geckodriver-v0.19.1-linux64.tar.gz
chmod +x geckodriver
sudo mv -f geckodriver /usr/local/share/geckodriver
sudo ln -f -s /usr/local/share/geckodriver /usr/local/bin/geckodriver
sudo ln -f -s /usr/local/share/geckodriver /usr/bin/geckodriver

# xvfb
sudo sh -c 'cat > /etc/systemd/system/xvfb.service << ENDOFPASTA
[Unit]
Description=X Virtual Frame Buffer Service
After=network.target

[Service]
User=selenium
ExecStart=/usr/bin/Xvfb :90 -screen 0 1024x768x24
ExecStop=/usr/bin/killall Xvfb

[Install]
WantedBy=multi-user.target
ENDOFPASTA'
sudo systemctl enable xvfb.service
sudo systemctl start xvfb

# openbox
sudo sh -c 'cat > /etc/systemd/system/openbox.service << ENDOFPASTA
[Unit]
Description=Openbox Window Manager
After=xvfb.service

[Service]
User=selenium
Environment=DISPLAY=:90
ExecStart=/usr/bin/openbox-session
ExecStop=/usr/bin/killall openbox

[Install]
WantedBy=multi-user.target
ENDOFPASTA'
sudo systemctl enable openbox.service
sudo systemctl start openbox

# x11vnc
sudo sh -c 'cat > /etc/systemd/system/x11vnc.service << ENDOFPASTA
[Unit]
Description=x11vnc VNC Server
After=xvfb.service

[Service]
User=selenium
ExecStart=/usr/bin/x11vnc -ncache_cr -forever -display :90 -passwd cpanel1
ExecStop=/usr/bin/killall x11vnc

[Install]
WantedBy=multi-user.target
ENDOFPASTA'
sudo systemctl enable x11vnc.service
sudo systemctl start x11vnc

# Selenium
sudo mkdir -p /var/log/selenium /var/lib/selenium
sudo chmod 777 /var/log/selenium
sudo wget http://selenium-release.storage.googleapis.com/3.9/selenium-server-standalone-3.9.1.jar -P /var/lib/selenium/
sudo ln -s /var/lib/selenium/selenium-server-standalone-3.9.1.jar /var/lib/selenium/selenium-server.jar
sudo sh -c 'cat > /etc/systemd/system/selenium.service << ENDOFPASTA
[Unit]
Description=Selenium Standalone Server
After=xvfb.service

[Service]
Environment=DISPLAY=:90
Environment=DBUS_SESSION_BUS_ADDRESS=/dev/null
ExecStart=/sbin/start-stop-daemon -c selenium --start --background --pidfile /var/run/selenium.pid --make-pidfile --exec /usr/bin/java -- -Dwebdriver.chrome.driver=/usr/local/share/chromedriver -Dwebdriver.gecko.driver=/usr/local/share/geckodriver -Djava.security.egd=file:/dev/./urandom -jar /var/lib/selenium/selenium-server.jar -log /var/log/selenium/selenium.log -port 4444
Type=forking
PIDFile=/var/run/selenium.pid

[Install]
WantedBy=default.target
ENDOFPASTA'
sudo systemctl enable selenium.service
sudo systemctl start selenium

# Corn jobs
sudo sh -c 'crontab - << ENDOFPASTA
5 * * * * killall -o 2h firefox
15 * * * * killall -o 2h chromium-browser
*/5 * * * * service xvfb status >/dev/null || service xvfb start >/dev/null
*/5 * * * * service x11vnc status >/dev/null || service x11vnc start >/dev/null
*/5 * * * * service selenium status >/dev/null || service selenium start >/dev/null
ENDOFPASTA'

# All done.
echo "SETUP COMPLETE"
