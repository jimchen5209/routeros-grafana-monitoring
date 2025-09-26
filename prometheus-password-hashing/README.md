## Setting up Prometheus with Hashed Passwords

This script will help you hash passwords for basic authentication in Prometheus.

Recommended to use [uv](https://docs.astral.sh/uv).

1. Install `uv` if you haven't already:

    ```bash
    curl -sSL https://install.astral.sh | sh
    ```
2. Install dependencies:

    ```bash
    uv sync
    ```
3. Run the hashing script:

    ```bash
    uv run main.py
    ```
4. Follow the prompt to enter your desired password. The script will output a hashed password.
5. Copy the hashed password and use it in your `prometheus/web.yml` file under `basic_auth_users`.

Source: https://prometheus.io/docs/guides/basic-auth/
