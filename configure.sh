#configure.sh VNC_USER_PASSWORD VNC_PASSWORD NGROK_AUTH_TOKEN

#disable spotlight indexing
sudo mdutil -i off -a

#Create new account
sudo dscl . -create /Users/vncuser
sudo dscl . -create /Users/vncuser UserShell /bin/bash
sudo dscl . -create /Users/vncuser RealName "VNC User"
sudo dscl . -create /Users/vncuser UniqueID 1001
sudo dscl . -create /Users/vncuser PrimaryGroupID 80
sudo dscl . -create /Users/vncuser NFSHomeDirectory /Users/vncuser
sudo dscl . -passwd /Users/vncuser $1
sudo dscl . -passwd /Users/vncuser $1
sudo createhomedir -c -u vncuser > /dev/null

#Enable VNC
KICKSTART="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart";
createARDAdminGroup() {
    dscl . -read /Groups/ard_admin  > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Creating group ard_admin";
        dseditgroup -o create -r "ARD Admins" ard_admin;
    else
        echo "Group ard_admin already exists";
    fi
}
addAdminGroupToARD_admin() {
        echo "Adding $ADMINGROUP to ard_admin";
        SAVEIFS=$IFS
        IFS=$(echo -en "\n\b")
        ADMINGROUPS=$(echo "$ADMINGROUP" | tr "," "\n");
        for AGROUP in $ADMINGROUPS; do
            echo "GROUP; $AGROUP";
            dseditgroup -o edit -a "$AGROUP" -t group ard_admin;
        done
        IFS=$SAVEIFS
}
if [ "$ADMINUSER" == "" ]; then
    echo "No admin user specified";
    ADMINUSER="$DEFAULTADMIN";
else
    ADMINUSER="$ADMINUSER,$DEFAULTADMIN";
fi
echo "Clearing ARD Settings"
$KICKSTART -uninstall -settings
#ENABLE ARD FOR DEFAULT ADMINS
$KICKSTART -configure -allowAccessFor -specifiedUsers
$KICKSTART -configure -users $ADMINUSER -access -on -privs  -all
if [ "$ADMINGROUP" == "" ]; then
        echo "No admin group specified skipping directory authentication config";
        $KICKSTART -configure -clientopts -setreqperm -reqperm yes
else
    createARDAdminGroup;
    addAdminGroupToARD_admin;
    $KICKSTART -configure -users ard_admin -access -on -privs -all
    $KICKSTART -configure -clientopts -setreqperm -reqperm yes -setdirlogins -dirlogins yes
fi
$KICKSTART -activate -restart -agent


#VNC password - http://hints.macworld.com/article.php?story=20071103011608872
echo $2 | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt

#Start VNC/reset changes
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate

#install ngrok
brew cask install ngrok

#configure ngrok and start it
ngrok authtoken $3
ngrok tcp 5900 &
