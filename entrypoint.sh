#!/bin/bash
set -e

ROOT_PASSWORD=${ROOT_PASSWORD:-password}
BIND_DATA_DIR=${DATA_DIR}/bind
DHCP_DATA_DIR=${DATA_DIR}/dhcp
WEBMIN_DATA_DIR=${DATA_DIR}/webmin

get_dhcp_interfaces() {
IFACE="`ls -1 /sys/class/net | grep -v docker0 | grep -v lo`"
IP="`ifconfig $INTERFACES | awk '/inet addr/{print substr($2,6)}'`"
MASK="`ifconfig $INTERFACES | grep Mask | cut -d":" -f4`"

sed -i '/INTERFACES*/c\INTERFACES="'$INTERFACES'"' /etc/default/isc-dhcp-server
}

for SRV_DIR in "bind" "dhcp" "webmin"
do
  mkdir -p ${DATA_DIR}/${SRV_DIR}

  # populate default configuration if it does not exist
  if [ ! -d ${DATA_DIR}/${SRV_DIR}/etc ]; then
    mv /etc/${SRV_DIR} ${DATA_DIR}/${SRV_DIR}/etc
  fi
  rm -rf /etc/${SRV_DIR}
  ln -sf ${DATA_DIR}/${SRV_DIR}/etc /etc/${SRV_DIR}
  echo "criando links para " ${SRV_DIR}
  chmod -R 0775 ${DATA_DIR}/${SRV_DIR}
  
  # bind config
  if [ ${SRV_DIR} = bind ]; then 
    chown -R ${BIND_USER}:${BIND_USER} ${BIND_DATA_DIR}
	if [ ! -d ${BIND_DATA_DIR}/lib ]; then
	  mkdir -p ${BIND_DATA_DIR}/lib
	  chown ${BIND_USER}:${BIND_USER} ${BIND_DATA_DIR}/lib
	fi
	  rm -rf /var/lib/bind
	  ln -sf ${BIND_DATA_DIR}/lib /var/lib/bind
	  
	  mkdir -m 0775 -p /var/run/named
	  mkdir -m 0775 -p /var/cache/bind
	  chown root:${BIND_USER} /var/run/named
	  chown root:${BIND_USER} /var/cache/bind
  fi


  if [ ${SRV_DIR} = webmin ]; then
	if [ ! "${WEBMIN_ENABLED}" == "true" ]; then
	  rm -f ${DATA_DIR}/${SRV_DIR}
	else
	  ln -sf ${WEBMIN_DATA_DIR}/etc /etc/webmin
	fi
  fi
  
  # dhcp config
  if [ ${SRV_DIR} = dhcp ]; then
    if [ "${INTERFACES}" == "" ]; then
      DHCP_ENABLED="false"
      echo "Informe a(s) interface(s) para dhcp, serviço será desativado!"
    fi
	if [ ! "${DHCP_ENABLED}" == "true" ]; then
	  rm -rf ${DATA_DIR}/${SRV_DIR}
	else
	  touch ${DHCP_DATA_DIR}/dhcpd.leases
	  touch /var/run/dhcpd.pid
	  chown root:dhcpd ${DHCP_DATA_DIR}/dhcpd.leases
	  IP="`ifconfig $INTERFACES | awk '/inet addr/{print substr($2,6)}'`"
	  MASK="`ifconfig $INTERFACES | grep Mask | cut -d":" -f4`"
	  
	  sed -i '/INTERFACES*/c\INTERFACES="'$INTERFACES'"' /etc/default/isc-dhcp-server
	  
	  if ! grep -q 'subnet' /etc/dhcp/dhcpd.conf; then
		IFS=. read -r i1 i2 i3 i4 <<< "`ifconfig $INTERFACES | awk '/inet addr/{print substr($2,6)}'`"
		IFS=. read -r m1 m2 m3 m4 <<< "`ifconfig $INTERFACES | grep Mask | cut -d":" -f4`"
		SUBNET="`printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))"`"

		RANGES="`ifconfig $INTERFACES | grep -i 'inet addr' | awk '{print $2}' | cut -d':' -f2 | cut -d'.' -f1,2,3`"
		echo "subnet $SUBNET netmask $MASK {" >> /etc/dhcp/dhcpd.conf
		echo "  range $RANGES.10 $RANGES.20;" >> /etc/dhcp/dhcpd.conf
		echo "}" >> /etc/dhcp/dhcpd.conf
	  fi
	fi
  fi
done

set_root_passwd() {
  echo "root:$ROOT_PASSWORD" | chpasswd
}

# allow arguments to be passed to named
if [[ ${1:0:1} = '-' ]]; then
  EXTRA_ARGS="$@"
  set --
elif [[ ${1} == named || ${1} == $(which named) ]]; then
  EXTRA_ARGS="${@:2}"
  set --
fi

# default behaviour is to launch named
if [[ -z ${1} ]]; then
  if [ "${WEBMIN_ENABLED}" == "true" ]; then
    set_root_passwd
    echo "Starting webmin..."
    /etc/init.d/webmin start
  fi
  if [ "${DHCP_ENABLED}" == "true" ]; then
      sed -i "/autostart=false/c\autostart=true" /etc/supervisord.conf
      DHCPD_ORIG="command=DHCPD"
      DHCPD="command=/usr/sbin/dhcpd "$INTERFACES" -pf /var/run/dhcpd.pid -f"
	  sed -i "s|$DHCPD_ORIG|$DHCPD|g" /etc/supervisord.conf
  fi
  exec /usr/bin/supervisord -c /etc/supervisord.conf
else
  exec "$@"
fi
