import requests


class PocketBaseClient:
    def __init__(self, config):
        self.base = config['pocketbase']['url'].rstrip('/')
        self.email = config['pocketbase']['email']
        self.password = config['pocketbase']['password']
        self.token = None
        self._authenticate()

    def _authenticate(self):
        r = requests.post(
            f'{self.base}/api/collections/users/auth-with-password',
            json={'identity': self.email, 'password': self.password},
        )
        r.raise_for_status()
        self.token = r.json()['token']

    def _h(self):
        return {'Authorization': self.token}

    def get(self, path, **kwargs):
        return requests.get(f'{self.base}{path}', headers=self._h(), **kwargs)

    def post(self, path, **kwargs):
        return requests.post(f'{self.base}{path}', headers=self._h(), **kwargs)

    def patch(self, path, **kwargs):
        return requests.patch(f'{self.base}{path}', headers=self._h(), **kwargs)
