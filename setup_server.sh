function __main {

  declare account

  # Colour codes stored as variables
  C_GREEN='\033[0;32m'
  C_YELLOW='\033[1;33m'
  C_RED='\033[0;31m'
  C_NC='\033[0m'

  install_dependencies

  # Create user account
  echo "This script will prohibit SSH login by the root account.  Please specify the name for a user account to be created.  This account will be added to the sudoers.  Leave blank to skip account creation:"

  until account_create; do
    echo -e "${C_RED}User $account already exists.  Please input a different username:${C_NC}"
  done

  # Store PKI
  account_pki_store

  # Configure SSH Service
  echo "This script will change the SSH port to 2345, and enable PKI, Password or two factor authentication.  Please select an option:"

  echo "[1] Password Only Authenication"
  echo "[2] PKI Only Authenication"
  echo "[3] Password or PKI Authenication"
  echo "[4] Password and PKI Two Factor Authentication"

  until configure_sshd; do
    echo -e "${C_RED}Invalid option.  Please try again.${C_NC}"
  done

  # Configure Swap
  echo "Please enter swap size in MB, or leave blank to skip setting up swap:".
  until configure_swap; do
    echo -e "${C_RED}Invalid number.  Please try again:${C_NC}".
  done

}

function install_dependencies {


  echo "Updating operating systems and installing dependencies"
  yum -y upgrade
  
  # policycoreutils-python required for semanage
  yum -y install nano policycoreutils-python ntp
  echo -e "${C_GREEN}Update Complete{$C_NC}"

}

function account_create {

  read account
 
  if [[ $account == "" ]]; then
    echo -e "${C_YELLOW}No account name supplied.  Skipping account generation.${C_NC}"
  else
    id -u $account > /dev/null 2>&1  
    if [[ $? == 1 ]]; then
      echo "Creating user account..."
      adduser $account  #Create user
      passwd $account   #Set password
      gpasswd -a $account wheel  #Add user to the wheel group
      echo -e "${C_GREEN}Account $account created.${C_NC}"
    else
      # Account already exists
      return 1
    fi
  fi

  return 0

}

function account_pki_store {

  if [[ $account != "" ]]; then  # Check that the account submitted is not blank 
    echo "This script will enable SSH key access.  Please provide your PUBLIC key to add to the AUTHORIZED_KEYS file. Leave blank to skip:"
    read pubkey
    if [[ $pubkey == "" ]]; then
      echo "${C_YELLOW}No SSH key provided.  Skipping PKI storage.${C_NC}"
    else
      # Store public key in authorized_keys file
      mkdir /home/$account/.ssh
      echo $pubkey > /home/$account/.ssh/authorized_keys  
      chown -R $account:$account /home/$account/.ssh
      chmod -R 0700 /home/$account/.ssh
      echo -e "${C_GREEN}SSH Certificate Stored.${C_NC}"
    fi
  fi

  return 0

}

function configure_sshd {

  conf_file="/etc/ssh/sshd_config"

  read authentication

  case $authentication in
    1)  cp conf/sshd_config_pwd $conf_file
        chmod 0700 $conf_file
        ;;
    2) 	cp conf/sshd_config_pki $conf_file          
       	chmod 0700 $conf_file
        ;;
    3) 	cp conf/sshd_config_pki_pwd $conf_file          
       	chmod 0700 $conf_file
        ;;
    4) 	cp conf/sshd_config_pki_and_pwd $conf_file          
       	chmod 0700 $conf_file
        ;;
    *)  return 1
        ;;
  esac

  semanage port -a -t ssh_port_t -p tcp 2345  #Allow port 2345 for SELinux
  firewall-cmd --zone=public --permanent --remove-service=ssh  #Remove old firewall rules
  firewall-cmd --zone=public --permanent --add-port=2345/tcp  #Add new firewall rule
  firewall-cmd --reload #Reload Firewall
  systemctl reload sshd  #Reload sshd
  
  echo -e "${C_GREEN}SSH Config successfully updated.${C_NC}"

  return 0

}

function set_time {

  echo "Setting time zone and enabling NTP service"

  timedatectl set-timezone Europe/London
  systemctl start ntpd
  systemctl enable ntpd

  echo -e "${C_GREEN}NTP Setup complete.${C_NC}"

}

function configure_swap {

  read size

  if [[ $size == "" ]]; then
    return 0
  elif ! [[ $size =~ ^[0-9]+$ ]]; then
    return 1
  else
    #Set up Swap
    dd if=/dev/zero of=/swapfile count=$size bs=1MiB
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    sh -c 'echo "/swapfile none swap sw 0 0" >> /etc/fstab'
   fi

  return 0
}

__main
