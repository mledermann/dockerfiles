firewall-cmd --permanent --new-service=homeassistant 
firewall-cmd --permanent --service=homeassistant --add-port=8123/tcp
firewall-cmd --permanent --service=homeassistant --set-destination=ipv4:192.168.0.0/24
firewall-cmd --permanent --zone=public --add-service=homeassistant
firewall-cmd --reload
