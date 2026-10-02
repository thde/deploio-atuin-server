# atuin-server

This project allows to deploy [Atuin's server](https://docs.atuin.sh/cli/self-hosting/server-setup/) on [deplo.io](https://docs.nine.ch/docs/deplo-io/dockerfile-build/). It automatically configures the database from the credentials Deploio [injects for attached services](https://docs.nine.ch/docs/deplo-io/configuration/deploio-connecting-to-services/).

## Deploy

Requires [`nctl`](https://docs.nine.ch/docs/nctl/) and a fork or copy of this repository Deploio can access.

1. Log in, then create a project and make it the default for the following commands:

   ```sh
   nctl auth login
   nctl create project atuin --wait
   nctl auth set-project atuin
   ```

2. Create a database. PostgreSQL and MySQL are supported:

   ```sh
   nctl create postgresdatabase atuin --wait
   ```

3. Create the application and attach the database as a service:

   ```sh
   nctl create application atuin \
     --git-url=https://github.com/thde/deploio-atuin-server.git \
     --dockerfile \
     --service=db=postgresdatabase/atuin \
     --env='ATUIN_OPEN_REGISTRATION=true'
   ```

4. Get the app's URL. It is also listed in the `HOSTS` column of `nctl get application atuin`:

   ```sh
   nctl get application atuin -o json | jq -r '.status.atProvider.defaultURLs[0]'
   ```

5. Point your Atuin client at it in `~/.config/atuin/config.toml`, then register:

   ```toml
   sync_address = "<app-url>"
   ```

   ```sh
   atuin register -u <username> -e <email>
   ```

6. Disable registration once all accounts exist:

   ```sh
   nctl update application atuin --env='ATUIN_OPEN_REGISTRATION=false'
   ```

## Configuration

The entrypoint uses these environment variables:

| Variable           | Description                                                                                                                                                                         |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ATUIN_DB_URI`     | Database URI. If set, it is used as is and the injected service credentials are ignored.                                                                                            |
| `ATUIN_DB_SERVICE` | Reference name of the service to use (`db` in `--service=db=...`). Only needed when more than one database is attached.                                                             |
| `ATUIN_DB_NAME`    | Database name to append to the DSN. Needed for Business tier instances (`postgres`, `mysql`), whose DSN only points at the server. The database must already exist on the instance. |
| `ATUIN_HOST`       | Address to bind. Defaults to `0.0.0.0`.                                                                                                                                             |
| `ATUIN_PORT`       | Port to bind. Defaults to `$PORT`, which Deploio sets.                                                                                                                              |

Any other [Atuin server setting](https://docs.atuin.sh/cli/self-hosting/server-setup/) can be set with an `ATUIN_` prefixed environment variable.

To build a different Atuin release, change `ATUIN_VERSION` in the `Dockerfile`.
