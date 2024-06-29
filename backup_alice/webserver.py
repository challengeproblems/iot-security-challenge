import hashlib
from binascii import a2b_base64, hexlify

from microWebSrv import MicroWebSrv
from ufastrsa import srandom

# import hmac._hashlib as hashlib

DEFAULT_BASIC_USERNAME = "Basic"
ADMIN_PASSWORD = open("adminpw.txt").read()
BASIC_AUTH_HASH = None

password_changed = False


def hash_sha256(string: str):
    hasher = hashlib.sha256()
    hasher.update(string)
    return hexlify(hasher.digest()).decode()


def gen_rand_string(length: int):
    ret = ""
    chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    for n in range(length):
        ret += chars[srandom.randint(0, len(chars) - 1)]
    return ret


def read_file(filename: str):
    f = open(filename)
    ret = f.read()
    f.close()
    return ret


def store_password(
    password: str, filename: str = "basicdefault.txt"
):  # Save hash, print plaintext for application on equipment
    f = open(f"{filename}", "w")
    hashed_tmp = hash_sha256(f"{DEFAULT_BASIC_USERNAME}:{password}")
    f.write(hashed_tmp)
    print(f"[WS] Storing hashed password in {filename}")
    print(f"[WS] Stored password hash: {hashed_tmp}")
    f.close()
    print(f"[WS] Verification of store in {filename}: {read_file(filename)}")


def log(*args, **kwargs):
    print(f"[WS]", *args, **kwargs)


def verify_hash(old: str, new: str):
    return old == new


def refresh_auth_hash():
    global password_changed
    global BASIC_AUTH_HASH
    BASIC_AUTH_HASH = (
        read_file("basicdefault.txt")
        if not password_changed
        else read_file("stored.txt")
    )


def change_password(old: str, new: str):
    global password_changed
    hashed_old = read_file("basicdefault.txt")

    if len(new) < 6:
        return (False, (f"Password must be 6 or more characters in length."))

    if verify_hash(hashed_old, hash_sha256(f"{DEFAULT_BASIC_USERNAME}:{old}")):
        log(f"Changing password from {old} to {new}")
        hashed_new = hash_sha256(f"{DEFAULT_BASIC_USERNAME}:{new}")
        store_password(new, "stored.txt")
        password_changed = True
        refresh_auth_hash()
        return (True, "")
    return (False, (f"Password '{old}' does not match the manufacturer password."))


BASIC_DEFAULT = read_file("basicdefault.txt")
STORED = read_file("stored.txt")
password_changed = STORED != ""

log(BASIC_DEFAULT)

if BASIC_DEFAULT == "":
    tmp = gen_rand_string(6)
    log(f"Generated new random password: {tmp}")
    store_password(tmp)
    tmp = None

refresh_auth_hash()


def _basicAuth(httpClient, httpResponse):
    headers = httpClient.GetRequestHeaders()

    def _authRequired():
        httpResponse.WriteResponse(
            code=401,
            headers={"WWW-Authenticate": "Basic"},
            contentType="text/html",
            contentCharset="UTF-8",
            content="Authorization for user admin required",
        )

    auth = headers.get("authorization", None)
    if auth is None:
        _authRequired()
        return False

    (basic, cred) = auth.split(" ")  # Basic wdjfhgaejscwkhihiwehiw
    if basic != "Basic":
        _authRequired()
        return False

    (user, pw) = (
        a2b_base64(cred).decode().split(":")
    )  # wdjfhgaejscwkhihiwehiw -> username:password

    our_hash = hash_sha256(f"{user}:{pw}")

    log(f"login from {user}, with password: {pw}")
    log(f"Request Hash: {our_hash}")
    log(f"Stored Hash: {BASIC_AUTH_HASH}")
    if our_hash != BASIC_AUTH_HASH:
        _authRequired()
        return False

    return True


@MicroWebSrv.route("/", "GET")
@MicroWebSrv.route("/", "POST")
def _httpHandlerIndex(httpClient, httpResponse):
    if not _basicAuth(httpClient, httpResponse):
        return

    if not password_changed:
        httpResponse.WriteResponsePyHTMLFile(
            "www/changepassword.pyhtml",
            headers={"Location": "/changepassword"},
            vars={
                "error_msg": "You must change the default password if you wish to log in.",
                "new_password": "",
                "old_password": "",
            },
        )
        return

    formData = httpClient.ReadRequestPostedFormData()
    httpResponse.WriteResponsePyHTMLFile(
        "www/index.pyhtml",
        headers=None,
        vars={"calc": formData.get("calc", None)},
    )


@MicroWebSrv.route("/changepassword", "GET")
@MicroWebSrv.route("/changepassword", "POST")
def _httpHandlerChangePassword(httpClient, httpResponse):
    if not _basicAuth(httpClient, httpResponse):
        return

    formData = httpClient.ReadRequestPostedFormData()
    new_password = formData.get("new_password")
    old_password = formData.get("old_password")
    if new_password == old_password:
        httpResponse.WriteResponsePyHTMLFile(
            "www/changepassword.pyhtml",
            headers=None,
            vars={
                "error_msg": "Passwords cannot match",
                "new_password": formData.get("new_password"),
                "old_password": formData.get("old_password"),
            },
        )
    else:
        successful, msg = change_password(old_password, new_password)
        if not successful:
            httpResponse.WriteResponsePyHTMLFile(
                "www/changepassword.pyhtml",
                headers=None,
                vars={
                    "error_msg": msg,
                    "new_password": formData.get("new_password"),
                    "old_password": formData.get("old_password"),
                },
            )
        else:
            httpResponse.WriteResponsePyHTMLFile(
                "www/index.pyhtml", headers=None, vars={"calc": None}
            )


@MicroWebSrv.route("/login", "GET")
@MicroWebSrv.route("/login", "POST")
def _httpHandlerLogin(httpClient, httpResponse):
    if not _basicAuth(httpClient, httpResponse):
        return

    formData = httpClient.ReadRequestPostedFormData()
    admin_login = (
        hash_sha256(formData.get("password", None).strip()) == ADMIN_PASSWORD.strip()
    )
    httpResponse.WriteResponsePyHTMLFile(
        "www/login.pyhtml",
        headers=None,
        vars={"admin_login": admin_login},
    )


def start_server():
    log(f"starting webserver")
    while True:
        try:
            srv = MicroWebSrv(webPath="www/")
            srv.Start(threaded=False)
        except Exception as ex:
            log(f"failed: {type(ex)} {ex}")
