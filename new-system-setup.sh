#!/bin/bash

#FUNCTIONS
install_docker_packages()
{
    echo "################### installing docker packages"
    apt-get -qq update
    # update and install docker stuff
    apt-get -qq install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo "################### adding user to docker group"
    # add your user to the docker group so you do not have to sudo to do docker stuff
    usermod -aG docker $SUDO_USER
}

install_debian_docker_keys()
{
    echo "################### installing Debian docker keys"
    tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
}

install_ubuntu_docker_keys()
{
    echo "Ubuntu"
    tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
}

setup_nas()
{
    echo "################### creating mount directories"
    # mount nas
    # /mnt/nas
    mkdir -p $2
    
    #/etc/samba
    mkdir -p /etc/samba

    echo "################### creating credential file"
    # the first argument when running this script is the username the second is the password
    echo -e "username=$3\npassword=$4" > /etc/samba/credentials

    echo "################### Adding to fstab file"
    # add this line to the bottom of fstab file
    echo -e "\n$1 $2 cifs credentials=/etc/samba/credentials" >> /etc/fstab

    echo "################### restarting daemons"
    # restart daemons to make sure things mount correctly
    systemctl daemon-reload

    echo "################### mounting NAS"
    mount -a
}

initial_package_install()
{
    echo "################### getting latest pacakges"
    apt-get -qq update
    apt-get -qq upgrade -y

    echo "################### Adding fastfetch repo."
    # add fast fetch repo
    add-apt-repository -y ppa:zhangsongcui3371/fastfetch 

    echo "################### Installing needed packages."
    sudo apt-get -qq update
    # install Packages
    apt-get -qq install -y ca-certificates curl fastfetch zsh git nano cifs-utils fzf lsd tmux btop
}

install_docker()
{
    echo "################### installing docker repo"
    # add keys for docker repo
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # add docker repo to apt
    distroid=$(awk -F= '/^ID=/ {print tolower($2)}' /etc/os-release 2>/dev/null | tr -d '"')

    case "$distroid" in
        ubuntu)
            echo "################### installing Ubuntu docker keys"
            install_ubuntu_docker_keys
            install_docker_packages
            ;;
        debian)
            install_debian_docker_keys
            install_docker_packages
            ;; 
        *)
            echo "Not Ubuntu, or Debian skipping docker install"
            ;;
    esac
}

setup_zsh()
{
    echo "################### creating empty .zshrc file"
    # creating .zshrc file so we do not get prompted to create one
    touch .zshrc 

    echo "################### installing oh-my-zsh"
    # install oh-my-zsh
    sudo -u $SUDO_USER sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    if [ -z $1 ]
    then
        echo "################### Getting .zshrc from github"
        curl -fsSL https://raw.githubusercontent.com/elpenor23/ConfigFiles/refs/heads/main/my.zshrc > .zshrc
    else
        echo "################### copying .zshrc template"
        cp $1 .
    fi

    echo "################### Changing default shell to zsh."
    # make zsh default shell
    sudo -u $SUDO_USER chsh -s $(which zsh)
}
#END FUNCTIONS


# User Input
if [ -z "$SUDO_USER" ]
  then
    echo "Script needs to be run using sudo command."
    exit
fi

unset usenas
read -p "Mount NAS? (yN)" usenasraw
case "$usenasraw" in
    [Yy]* ) usenas=1;;
    [Nn]* ) usenas=0;;
    * ) usenas=0;;
esac

unset naspassword
unset nasusername
unset nasaddress
unset nasmountpoint

if [ $usenas == 1 ]
then
    read -p "Enter NAS address (//10.0.0.250/BradlowskiShare):" nasaddressraw
    
    if [ -z "$nasaddressraw" ]
    then
      nasaddress="//10.0.0.250/BradlowskiShare"  
    fi

    read -p "Enter mount point to create (/mnt/nas):" nasmoutpointraw
    if [ -z "$nasmoutpointraw" ]
    then
      nasmountpoint="/mnt/nas"  
    fi

    read -p "Enter NAS username:" nasusername
    if [ -z $nasusername ]
    then
        echo "Error! No username entered."
        exit -1
    fi
    
    prompt="Enter NAS Password:"
    while IFS= read -p "$prompt" -r -s -n 1 char
    do
        if [[ $char == $'\0' ]]
        then
            break
        fi
        prompt='*'
        naspassword+="$char"
    done

    echo

    if [ -z $naspassword ]
    then
        echo "Error! No password entered."
        exit -1
    fi
else
    echo "Not mounting NAS."
fi

unset usezshrctemplate
unset zshrctemplatepath
read -p "Use .zshrc template? (yN)" usezshrctemplateraw
case "$usezshrctemplateraw" in
    [Yy]* ) usezshrctemplate=1;;
    [Nn]* ) usezshrctemplate=0;;
    * ) usezshrctemplate=0;;
esac

if [ $usezshrctemplate == 1 ]
then
    read -p "Path and filename to .zshrc template:" zshrctemplatepath
    if [ -z $zshrctemplatepath ]
    then
        echo "Error: No .zshrc path in LAN entered."
        exit -1
    fi
fi

echo

if [ $usenas == 1 ]
then
    echo "Mounting NAS:"
    echo "   Address: $nasaddress"
    echo "   Mount Point: $nasmountpoint"
    echo "   Username: $nasusername"
    echo "   Password: ******"
else
    echo "No NAS configured."
fi

echo

if [ $usezshrctemplate == 1 ]
then
    echo "Path to .zshrc template: $zshrctemplatepath"
else
    echo "Using basic .zshrc"
fi

echo
echo "Check values before continuing."
read -p "Press <Enter> to continue Ctrl-c to quit and try again."

# END User Input

echo "################### Starting Setup."
initial_package_install

if [ $usenas == 1 ]
then
    setup_nas $nasaddress $nasmountpoint $nasusername $naspassword
fi

install_docker

setup_zsh $zshrctemplatepath

# disable login messages
chmod -x /etc/update-motd.d/*

# logout and log back in and you are golden
echo "################### All Done! Logout and back in again and things should be good!"
