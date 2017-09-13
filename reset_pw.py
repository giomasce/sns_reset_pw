#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Debian forces TLS 1.2 and the maximum version supported by
# password.sns.it is 1.0; the trick is to fake an unencrypted request
# routed through socat on a sufficiently old computer. For example:
# ssh soyuz -L2204:127.0.0.1:2204 socat tcp-listen:2204,fork openssl:password.sns.it:443,verify=0

import sys
import requests

ADDRESS = 'http://localhost:2204'
HOST = 'password.sns.it'
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.78 Safari/537.36',
    'Host': HOST,
}

# We explicitly set the cookie header, because all cookies are set for
# the domain password.sns.it and we think we are connecting to
# localhost
def headers(session):
    return {**HEADERS, **{"Cookie": "; ".join(["{}={}".format(k, v) for (k, v) in session.cookies.items()])}}

def change_pw(session, from_pw, to_pw):
    adscsrf = session.cookies['adscsrf']
    req = session.post(ADDRESS + '/SelfChangePassword.do?selectedTab=ChangePwd', data={'AD': 'enable', 'OtherPlatforms': 'enable', 'oldPassword': from_pw, 'newPassword': to_pw, 'confimPassword': to_pw, 'OK': ' OK  ', 'adscsrf': adscsrf}, headers=headers(session), verify=False, allow_redirects=False)
    for line in req.text.splitlines():
        if line.find('has been changed') != -1:
            return True
    return False

def main():
    username = sys.argv[1]
    orig_pw = sys.argv[2]

    session = requests.Session()
    req = session.get(ADDRESS + '/showLogin.cc', headers=headers(session), verify=False)
    req = session.get(ADDRESS + '/authorization.do', headers=headers(session), verify=False)
    req = session.post(ADDRESS + '/j_security_check', data={'j_username': username, 'j_password': orig_pw, 'AUTHRULE_NAME': 'ADAuthenticator', 'domainAuthen': 'true'}, headers=headers(session), verify=False, allow_redirects=False)
    location = req.headers['location'] if 'location' in req.headers else ''
    if not location.endswith('/authorization.do'):
        print("Login failed")
        return
    else:
        print("Login succeded")
    req = session.get(ADDRESS + '/authorization.do', headers=headers(session), verify=False, allow_redirects=False)

    last_pw = orig_pw
    variants = [orig_pw + str(i) for i in range(6)] + [orig_pw]
    for new_pw in variants:
        print("Changing password from \"{}\" to \"{}\"".format(last_pw, new_pw))
        if not change_pw(session, last_pw, new_pw):
            print("Failed, your password is still \"{}\"".format(last_pw))
            return
        last_pw = new_pw

    print("Done, your password is again \"{}\"".format(orig_pw))

if __name__ == '__main__':
    main()
