#!/bin/bash

## COLOR
GREEN="\\033[1;32m"
RED="\\033[1;31m"
BLUE="\\033[1;34m"
NC='\033[0m'
YEL="\\033[1;33m"

#DIR CREATE FILE
file_conf='/var/opt/nagios'
file_nrpe='/etc/nagios'
dir_pluggin='/etc/nagios-plugins'


## HEADER
head()
{
	echo    ""
	echo -e "$GREEN" "    ------- ""$YEL""NAGIOS:""$RED"" Installation automatique du client (DEBIAN)""$GREEN"" ------ " "$NC"
	echo            "    |              Written By H4wk3r(vdbnicolas@gmail.com)             |  "
	echo -e "$GREEN" "    ------------------------------------------------------------------     " "$NC"
	echo " "
}

## MENU
menu()
{
        echo  "	--------------------"
        echo -e "	|       ${GREEN}MENU${NC}       |"
        echo  "	--------------------"

	echo ''
	echo -e "${BLUE}0 - ${NC}"'COMPLET : Installer le client NAGIOS + Configuration Serveur Nagios'
	echo -e "${BLUE}1 - ${NC}"'CLIENT  : Installer le Nagios Agent'
	echo -e "${BLUE}2 - ${NC}"'SERVEUR : Configuration Serveur Nagios'
	echo ''
	echo -e "${BLUE}q - ${NC}"'Quittez'
	echo ''
}

## VERIFICATION DES DEPENDANCES AVANT INSTALLATION
check_base()
{
    echo " "
    echo -e "${BLUE}Analyses système : ${NC}"
    # Check OS Type
    os=$(uname -o)
    echo -e '\E[32m'"Operating System Type : \033[0m"$os

    # Check OS Release Version and Name
    os_name=$(uname -n)
    echo -e '\E[32m'"OS Name : \033[0m"$os_name

    os_version=$(uname -v)
    echo -e '\E[32m'"OS Version : \033[0m" $os_version

    # Check Architecture
    architecture=$(uname -m)
    echo -e '\E[32m'"Architecture : \033[0m"$architecture

    # Check Kernel Release
    kernelrelease=$(uname -r)
    echo -e '\E[32m'"Kernel Release : \033[0m"$kernelrelease

    # Check hostname
    echo -e '\E[32m'"Hostname : \033[0m"$HOSTNAME

    #Check root
    user_actif=$(whoami)
    echo -e '\E[32m'"Utilisateur actif : \033[0m"$user_actif
    if [ $EUID -ne 0 ]
    then
     	user_exe="Le script doit être executé en root"
       	echo -e  "${RED}Le script doit être executé en root${NC}"
       	echo -e '\E[32m'"Votre userID est : \033[0m$EUID"; exit
    else
       	user_exe="Le script est executé en root"
       	echo -e '\E[32m'"Le script est executé en super_admin${NC}"
       	echo -e '\E[32m'"Votre userID est : \033[0m$EUID"
    fi

    #Check internet
    externe=$(wget -T 5 -O - -o /dev/null http://www.google.fr)
    if [ $? -ne 0 ]
    then
      	echo -e "${RED}Connexion Internet : \033[0mDeconnecte"
       	exit;
    else
       	echo -e '\E[32m'"Connexion Internet : \033[0mConnecte"
    fi
    echo " "
}

## REDEMARRER LE SERVICE NAGIOS
restart_nagios()
{
        ssh root@$ip_server 'service nagios3 restart'
				echo -e "Service NAGIOS3 is : ----------------- : "$GREEN"RESTART" "$NORMAL"
}

## INSTALLATION DU CLIENT NAGIOS AVEC APT-GET
install_agent()
{
  echo ""
	echo "########## ETAPE INSTALLATION CLIENT NAGIOS #############"
	echo "Installer et configurer Nagios Agent."
  echo ""
	if [ -d $dir_pluggin ] && [ -f $file_nrpe/nrpe.cfg ]
	then
		echo -e "${GREEN}Les services NAGIOS-PLUGINS & NAGIOS-NRPE-SERVEUR sont déjà installés.${NC}"
	else
		 apt-get update
		 apt-get -y install nagios-plugins nagios-nrpe-server
		 cp /etc/nagios/nrpe.cfg /etc/nagios/nrpe.cfg.backup
		 sed -i "/server_address/cserver_address=$privateip" /etc/nagios/nrpe.cfg
		 sed -i "s|allowed_hosts=127.0.0.1|allowed_hosts=127.0.0.1,$ip_server|" /etc/nagios/nrpe.cfg
		 sed -i 's|^command*|#command|' /etc/nagios/nrpe.cfg
		 service nagios-nrpe-server restart
		 echo -e "${GREEN}Installation et configuration terminée.${NC}"
	fi
}

## CREATION DU FICHIER DE CONFIGURATION POUR LE NAGIOS SERVEUR
conf_server()
{
	newip=$privateip
	echo "########## ETAPE CONF SERVEUR #############"
	echo "Configuration du serveur NAGIOS."
	echo ""
	echo  -e "${BLUE}Entrer le nom du nouvel hôte : ${NC}"
	read -p "	> " newhost
	echo  -e "${BLUE}Entrer l'alias du nouvel hôte : ${NC}"
	read -p "	> " newalias

	if [ -f $file_conf/$newhost.cfg ]
	then
		echo ""
		echo -e "${GREEN}La configuration pour le hôte $newhost existe déjà.${NC}"
		echo ""
	else
		mkdir -p $file_conf
		echo "define host {" > $file_conf/$newhost.cfg
		echo "        use                             generic-host" >> $file_conf/$newhost.cfg
		echo "        host_name                       $newhost" >> $file_conf/$newhost.cfg
		echo "        alias                           $newalias" >> $file_conf/$newhost.cfg
		echo "        address                         $newip" >> $file_conf/$newhost.cfg
		echo "        max_check_attempts              5" >> $file_conf/$newhost.cfg
		echo "        check_period                    24x7" >> $file_conf/$newhost.cfg
		echo "        notification_interval           30" >> $file_conf/$newhost.cfg
		echo "        notification_period             24x7" >> $file_conf/$newhost.cfg
		echo "        check_interval                  0.05" >> $file_conf/$newhost.cfg
		echo "}" >> $file_conf/$newhost.cfg
		echo
		echo -e "${GREEN}Les services de base${NC}"
		echo
		read -p "Voulez-vous vérifier le ping (y/n)[n] " q
		if [ "$q" == "y" ]
		then
		    echo "define service{" >> $file_conf/$newhost.cfg
		    echo "    use generic-service" >> $file_conf/$newhost.cfg
		    echo "    host_name $newhost" >> $file_conf/$newhost.cfg
		    echo "    service_description PING" >> $file_conf/$newhost.cfg
		    echo "    check_command check_ping!100.0,20%!500.0,60%" >> $file_conf/$newhost.cfg
		    echo "}" >> $file_conf/$newhost.cfg
		    q=""
		fi
		read -p "Voulez-vous vérifier le service SSH (y/n)[n] " q
		if [ "$q" == "y" ]
		then
		    read -p "Quel est le port SSH [22] " portssh
	    	if [ "$portssh" != "" ]
	    	then
	    	    echo "define command{" >> $file_conf/$newhost.cfg
	    	    echo "    command_name check_ssh_$portssh_$newhost" >> $file_conf/$newhost.cfg
	    	    echo "    command_line \$USER1\$/check_ssh -p $portssh" >> $file_conf/$newhost.cfg
	    	    echo "}" >> $file_conf/$newhost.cfg
	    	    variable="_$portssh_$newhost"
	    	fi
	    	echo "define service{" >> $file_conf/$newhost.cfg
	    	echo "    use generic-service" >> $file_conf/$newhost.cfg
	    	echo "    host_name $newhost" >> $file_conf/$newhost.cfg
	    	echo "    service_description SSH" >> $file_conf/$newhost.cfg
	    	echo "    check_command check_ssh$variable" >> $file_conf/$newhost.cfg
	   	echo "}" >> $file_conf/$newhost.cfg
	   	q=""
		fi
		read -p "Voulez-vous vérifier le service users (y/n)[n] " q
		if [ "$q" == "y" ]
		then
		    echo "define command{" >> $file_conf/$newhost.cfg
		    echo "    command_name check_users_$newhost" >> $file_conf/$newhost.cfg
		    echo "    command_line \$USER1\$/check_users -w1 -c2" >> $file_conf/$newhost.cfg
		    echo "}" >> $file_conf/$newhost.cfg
		    echo "define service{" >> $file_conf/$newhost.cfg
		    echo "    use generic-service" >> $file_conf/$newhost.cfg
		    echo "    host_name $newhost" >> $file_conf/$newhost.cfg
		    echo "    service_description USERS" >> $file_conf/$newhost.cfg
		    echo "    check_command check_users_$newhost" >> $file_conf/$newhost.cfg
	    echo "}" >> $file_conf/$newhost.cfg
	    q=""
		fi
		read -p "Voulez-vous vérifier la charge du système (y/n)[n] " q
		if [ "$q" == "y" ]
		then
		    echo "define command{" >> $file_conf/$newhost.cfg
		    echo "    command_name check_load_$newhost" >> $file_conf/$newhost.cfg
		    echo "    command_line \$USER1\$/check_load -w 15,10,5 -c 30,25,20" >> $file_conf/$newhost.cfg
		    echo "}" >> $file_conf/$newhost.cfg
		    echo "define service{" >> $file_conf/$newhost.cfg
		    echo "    use generic-service" >> $file_conf/$newhost.cfg
		    echo "    host_name $newhost" >> $file_conf/$newhost.cfg
		    echo "    service_description LOAD" >> $file_conf/$newhost.cfg
		    echo "    check_command check_load_$newhost" >> $file_conf/$newhost.cfg
		    echo "}" >> $file_conf/$newhost.cfg
		    q=""
		fi
		read -p "Voulez-vous vérifier la partition système / (y/n)[n] " q
		if [ "$q" == "y" ]
		then
		    echo "define command{" >> $file_conf/$newhost.cfg
		    echo "    command_name check_disk_$newhost" >> $file_conf/$newhost.cfg
		    echo "    command_line \$USER1\$/check_disk -w 20% -c 10% -p /" >> $file_conf/$newhost.cfg
		    echo "}" >> $file_conf/$newhost.cfg
		    echo "define service{" >> $file_conf/$newhost.cfg
		    echo "    use generic-service" >> $file_conf/$newhost.cfg
		    echo "    host_name $newhost" >> $file_conf/$newhost.cfg
		    echo "    service_description ROOT" >> $file_conf/$newhost.cfg
		    echo "    check_command check_disk_$newhost" >> $file_conf/$newhost.cfg
		    echo "}" >> $file_conf/$newhost.cfg
		    q=""
		fi
		read -p "Voulez-vous vérifier le swap (y/n)[n] " q
		if [ "$q" == "y" ]
		then
		    echo "define command{" >> $file_conf/$newhost.cfg
		    echo "    command_name check_swap_$newhost" >> $file_conf/$newhost.cfg
		    echo "    command_line \$USER1\$/check_swap -a -w 50% -c 10%" >> $file_conf/$newhost.cfg
		    echo "}" >> $file_conf/$newhost.cfg
		    echo "define service{" >> $file_conf/$newhost.cfg
		    echo "    use generic-service" >> $file_conf/$newhost.cfg
		    echo "    host_name $newhost" >> $file_conf/$newhost.cfg
		    echo "    service_description SWAP" >> $file_conf/$newhost.cfg
		    echo "    check_command check_swap_$newhost" >> $file_conf/$newhost.cfg
		    echo "}" >> $file_conf/$newhost.cfg
		    q=""
		fi
		read -p "Voulez-vous vérifier tous les processus (y/n)[n] " q
		if [ "$q" == "y" ]
		then
		    echo "define command{" >> $file_conf/$newhost.cfg
		    echo "    command_name check_procs_$newhost" >> $file_conf/$newhost.cfg
		    echo "    command_line \$USER1\$/check_procs -w 150 -c 200" >> $file_conf/$newhost.cfg
		    echo "}" >> $file_conf/$newhost.cfg
		    echo "define service{" >> $file_conf/$newhost.cfg
		    echo "    use generic-service" >> $file_conf/$newhost.cfg
		    echo "    host_name $newhost" >> $file_conf/$newhost.cfg
		    echo "    service_description PROCESS" >> $file_conf/$newhost.cfg
		    echo "    check_command check_procs_$newhost" >> $file_conf/$newhost.cfg
		    echo "}" >> $file_conf/$newhost.cfg
		    q=""
		fi
		echo
		echo -e "${GREEN}Serveur Web${NC}"
		echo
		read -p "Voulez-vous vérifier le service web HTTP (y/n)[n] " q
		if [ "$q" == "y" ]
		then
		    read -p "Quel est le port d'écoute du serveur web [80]" port
		    if [ "$port" != "" ]
		    then
			echo "define command{" >> $file_conf/$newhost.cfg
			echo "    command_name check_http_$port_$newhost" >> $file_conf/$newhost.cfg
			echo "    command_line \$USER1\$/check_http -I \$HOSTADDRESS\$ \$ARG1\$-p $port" >> $file_conf/$newhost.cfg
			echo "}" >> $file_conf/$newhost.cfg
		    fi
		    echo "define service{" >> $file_conf/$newhost.cfg
		    echo "    use generic-service" >> $file_conf/$newhost.cfg
		    echo "    host_name $newhost" >> $file_conf/$newhost.cfg
		    if [ "$port" == "" ]
		    then
			echo "    service_description HTTP" >> $file_conf/$newhost.cfg
			echo "    check_command check_http" >> $file_conf/$newhost.cfg
		    else
			echo "    service_description HTTP_$port" >> $file_conf/$newhost.cfg
			echo "    check_command check_http_$port_$newhost" >> $file_conf/$newhost.cfg
		    fi
		    echo "}" >> $file_conf/$newhost.cfg
		    q=""
		fi

		echo ""
	        echo -e "${BLUE}""TRANSFERT DU FICHIE CONFIG${NC}"
		echo -e "${BLUE}""Saisir le mot de passe root du serveur nagios : ${NC}"
		echo ""
	        send_file $newhost.cfg

		echo ""
	        echo -e "${BLUE}REDEMARRER LE SERVICE NAGIOS${NC}"
		echo -e "${BLUE}Saisir le mot de passe root du serveur nagios : ${NC}"
		echo ""
		restart_nagios
	fi
}

## ENVOI EN SCP DU FICHIER DE CONFIGURATION VERS LE SERVEUR NAGIOS
send_file()
{
	scp $file_conf/$1 root@$ip_server:/etc/nagios3/conf.d/$1
}

#MAIN
head
check_base

echo  -e "${BLUE}IP du serveur NAGIOS :${NC}"
read -p '       > ' ip_server
echo ""
echo  -e "${BLUE}IP de la machine cliente NAGIOS ?${NC}"
echo -e "${RED}+${NC}"
ip -o addr | awk '!/^[0-9]*: ?lo|link\/ether/ {gsub("/", " "); print $2" "$4}'
read -p "       > " privateip
echo ""

menu

while :
do
	read -p '	> ' a
	echo ""
	if [ "$a" == "0" ]
	then
		install_agent
		echo ""
		echo ""
		conf_server newhost.cfg
		exit 0
	elif [ "$a" == "1" ]; then
	        install_agent
		exit 0
	elif [ "$a" == "2" ]; then
	        conf_server newhost.cfg
		exit 0
	elif [ "$a" == "q" ]; then
		exit 0
	fi
done
exit 0
