#!/bin/bash -e

KEEP_TEMP="no"

randpw(){ < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-13} | sed s/^/1/ | sed s/$/aA/;}

urlencode() {
    # urlencode <string>
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C
    
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    
    LC_COLLATE=$old_lc_collate
}

if [ -z "$1" ] || [ -z "$2" ]
then
    echo "Usage:   $0 username current_password"
    echo "example: $0 luca.versari my_fantastic_password"
    echo "         $0 luca.versari 'my fantastic password with spaces'"
    exit 1
fi

echo "This script will change 6 times your SNS password, to make it valid again."

USERNAME=$1
OLD_PASSWD=$2
USR_URL=`urlencode $USERNAME`
PWD_URL=`urlencode $OLD_PASSWD`
# We use five similar passwords, so that if your computer crashes
# while doing this you can easily recover the intermediate password
TEMP_PASSWD="${OLD_PASSWD}1 ${OLD_PASSWD}2 ${OLD_PASSWD}3 ${OLD_PASSWD}4 ${OLD_PASSWD}5"

tmpdir=`mktemp -d`

cleanup() {
    if [ "$KEEP_TEMP" == "no" ] ; then
        rm -rf $tmpdir
    else
        echo "Temp dir was left in $tmpdir"
    fi
}

trap cleanup EXIT

do_change_pw() {
    urlencoded_old=`urlencode $1`
    urlencoded_new=`urlencode $2`
    asdcsrf=`grep adscsrf $tmpdir/login_cookies.txt | cut -f 7`
    out=`mktemp -p $tmpdir`
    wget --load-cookies $tmpdir/login_cookies.txt --post-data="oldPassword=$urlencoded_old&newPassword=$urlencoded_new&confirmPassword=$urlencoded_new&adscsrf=$asdcsrf&AD=enable&OtherPlatforms=enable&OK=%C2%A0OK+%C2%A0" "https://password.sns.it/SelfChangePassword.do?selectedTab=ChangePwd" -O $out -o /dev/null
    grep '.*<td>.*Your password has been changed successfully.*</td>.*' "$out" > /dev/null
    return `echo $?`
}

wget --save-cookie $tmpdir/initial_cookies.txt --keep-session-cookies https://password.sns.it/showLogin.cc -O /dev/null -o /dev/null
wget --save-cookie $tmpdir/login_cookies.txt --keep-session-cookies --load-cookies $tmpdir/initial_cookies.txt --post-data "j_username=$USR_URL&j_password=$PWD_URL&AUTHRULE_NAME=ADAuthenticator&domainAuthen=true" https://password.sns.it/authorization.do -O /dev/null -o /dev/null
wget --save-cookie $tmpdir/login_cookies.txt --keep-session-cookies --load-cookies $tmpdir/initial_cookies.txt --post-data "j_username=$USR_URL&j_password=$PWD_URL&AUTHRULE_NAME=ADAuthenticator&domainAuthen=true" https://password.sns.it/j_security_check -O /dev/null -o /dev/null

for t in $TEMP_PASSWD
do
    echo -n "Setting your password to $t... "
    if ! do_change_pw "$OLD_PASSWD" "$t"
    then
        echo "Failure! your password is still $OLD_PASSWD!"
        exit 2
    fi
    echo "OK!"
    OLD_PASSWD="$t"
done

echo -n "Setting your password back to $2... "
if ! do_change_pw "$OLD_PASSWD" "$2"
then
    echo "Failure! your password is still $OLD_PASSWD!"
    exit 2
fi
echo "OK!"


echo "Your password has been reset."
