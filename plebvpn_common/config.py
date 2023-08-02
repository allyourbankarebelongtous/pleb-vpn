import configparser
import logging
from . import types

PLEB_CONF_FILE = "/mnt/hdd/admin/pleb-vpn/pleb-vpn.conf"

logging.basicConfig(level=logging.DEBUG)
logging.getLogger().setLevel(level=logging.DEBUG)


def _fix_quotes(_str: str):
    """Removes any weird quotes at the edges of strings, then adds some back in, because bash likes 'single quotes'"""
    _str = _str.strip('\'').strip('\"')
    _str = f"\'{_str}\'"
    return _str


class PlebConfig:
    _options = None

    def __init__(self, config_path=PLEB_CONF_FILE):
        """By default, tries to load the config in Raspiblitz' config path.
        config_path: Pass in full path to pleb-vpn.conf for non-Raspiblitz platforms or for testing"""
        self._config_path = config_path
        self._config = configparser.ConfigParser()
        logging.info(f"Reading config file {self._config_path}")
        self._config.read(self._config_path)
        self._options = self._config['PLEBVPN']

    def __set_on_off_option(self, _key: str, _on: bool):
        """Used specifically for options that can only be turned on or off"""
        if type(_on) is not bool:
            err = f"Got type {type(_on)} in set_on_off_option(), but expected bool."
            logging.error(err)
            raise TypeError(err)
        if _on is True:
            self._options[_key] = 'on'
        else:
            self._options[_key] = 'off'

    def __set_list_option(self, _key: str, _value: list):
        """Used for options that like to be stored as comma-separated lists"""
        if type(_value) is not list:
            err = f"Got type {type(_value)} in set_list_option(), but expected list."
            logging.error(err)
            raise TypeError(err)

        # Turn list into str
        _value = ",".join(map(str, _value))
        _value = _fix_quotes(_str=_value)
        self._options[_key] = _value

    def __set_string_option(self, _key: str, _value: str):
        """Used for all other options that like to be surrounded in 'single quotes'"""
        if type(_value) is not str:
            err = f"Got type {type(_value)} in set_string_option(), but expected string."
            logging.error(err)
            raise TypeError(err)

        _value = _fix_quotes(_str=_value)

        self._options[_key] = _value

    def set_option(self, _key, _value):
        """Generic interface for setting options. Use this one whenever possible.
        On/Off Option example usage: set_option('wireguard', True)
        String Option example usage: set_option('vpnip', '192.168.0.1')
        List Option example usage: set_option('availablePorts', [9573, 8333, 5029])"""
        if type(_value) is str:
            self.__set_string_option(_key, _value)
        elif type(_value) is list:
            self.__set_list_option(_key, _value)
        elif type(_value) is bool:
            self.__set_on_off_option(_key, _value)
        else:
            err = f"Got type {type(_value)} in set_option(), but expected string, list, or bool."
            logging.error(err)
            raise TypeError(err)

    def get_option(self, _key):
        """Generic interface for getting options. Unless you know your option can contain a list, use this one.
        returns: bool for On/Off Options
        returns: Cleaned-up str for String Options
        returns: None for empty Options"""
        value = self._options[_key].lower()
        if type(value) is str:
            if value == 'on':
                return True
            elif value == 'off':
                return False
            elif len(value) == 0:
                return None
            else:
                return value.strip('\'').strip('\"')

    def get_list_option(self, _key) -> list:
        """Interprets a config option string as a comma-seperated list
        returns: List[] for List Options"""
        return self._options[_key].strip('\'').strip('\"').split(',')

    def write(self):
        """Commits config file to disk"""
        if self._options is None:
            logging.error("Could not write config file -- file wasn't loaded")
            return types.PlebError.UNKNOWN
        with open(self._config_path, 'w') as configfile:
            self._config.write(fp=configfile, space_around_delimiters=False)

        return types.PlebError.SUCCESS
